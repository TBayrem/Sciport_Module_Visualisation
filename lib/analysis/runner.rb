# ============================================================
# Datei: lib/analysis/runner.rb
#
# Desc:
#   Steuert den gesamten Analyselauf und speichert die
#   Ergebnisse in den Analysetabellen. Aufgerufen von der
#   Rake-Aufgabe analysis:run (nächtlich per Zeitplan).
#
#   Ablauf:
#   1. Prüfen, ob bereits ein Lauf läuft (kein Doppellauf).
#   2. Analysis::Run anlegen (Status "running").
#   3. Schritte 1–7 nacheinander:
#        TextCollector        → Texte je Person
#        Vectorizer           → TF-IDF-Profile
#        Reducer              → 50-dimensionale Profile (LSA)
#        Projector            → PCA, t-SNE, UMAP (2D)
#        SimilarityCalculator → ähnliche Personenpaare
#        Clusterer            → k-Means- und DBSCAN-Stufen
#        TopicNamer           → Begriffe je Cluster
#   4. Alle Ergebnisse in einer Transaktion speichern. Bei
#      einem Fehler bleibt nichts Halbfertiges zurück.
#   5. Lauf als "finished" markieren, ältere Läufe löschen
#      (abhängige Zeilen per on_delete: :cascade).
#
#   Die Seiten lesen immer Analysis::Run.latest_finished.
#   Ein laufender oder fehlgeschlagener Lauf ändert deshalb
#   nichts an der Anzeige.
#
#   Gespeichert wird mit insert_all in Blöcken: Das sind
#   mehrere zehntausend Zeilen, einzelne create-Aufrufe wären
#   zu langsam. Die Analysetabellen haben keine Zeitstempel-
#   spalten; der Zeitpunkt steht in analysis_runs
#   (started_at, finished_at).
# ============================================================

module Analysis
  class Runner
    class AlreadyRunning < StandardError; end

    DIMENSIONS = 50
    KEEP_RUNS = 3          # fertige Läufe, die erhalten bleiben
    BATCH_SIZE = 5_000

    def initialize(logger: Rails.logger)
      @logger = logger
    end

    # Führt einen vollständigen Lauf aus und gibt ihn zurück.
    def call
      raise AlreadyRunning, "Es läuft bereits eine Analyse" if Run.running?

      run = Run.start!
      results = compute
      store(run, results)
      run.finish!
      remove_old_runs
      log "Analyse #{run.id} fertig"
      run
    rescue AlreadyRunning
      raise
    rescue StandardError => error
      run&.fail!
      log "Analyse fehlgeschlagen: #{error.class}: #{error.message}"
      raise
    end

    private

    # ----------------------------------------------------------
    # Berechnung
    # ----------------------------------------------------------

    def compute
      texts = step("Texte sammeln") { TextCollector.new.collect }
      vectors = step("TF-IDF") { Vectorizer.new.vectorize(texts) }
      reduced = step("SVD") { Reducer.new(dimensions: DIMENSIONS).reduce(vectors.vectors, vectors.terms.size) }
      embedding = reduced.embedding

      projections = step("Projektionen") { Projector.new.project(embedding) }
      similarities = step("Ähnlichkeiten") { SimilarityCalculator.new.calculate(vectors.person_ids, embedding) }
      clusterings = step("Clustering") { Clusterer.new.cluster_all(embedding) }

      namer = TopicNamer.new
      topics = step("Themen") do
        clusterings.map { |clustering| namer.name(vectors.vectors, vectors.terms, clustering[:labels]) }
      end

      log "#{vectors.person_ids.size} Personen, #{vectors.terms.size} Begriffe, " \
          "erklärte Varianz #{(reduced.explained_variance * 100).round(1)} %"

      {
        person_ids: vectors.person_ids,
        projections: projections,
        similarities: similarities,
        clusterings: clusterings,
        topics: topics
      }
    end

    # ----------------------------------------------------------
    # Speichern
    # ----------------------------------------------------------

    def store(run, results)
      step("Speichern") do
        ActiveRecord::Base.transaction do
          store_projections(run, results[:person_ids], results[:projections])
          store_similarities(run, results[:similarities])
          results[:clusterings].each_with_index do |clustering, i|
            store_clustering(run, results[:person_ids], clustering, results[:topics][i])
          end
        end
      end
    end

    # Eine Zeile je Person und Verfahren (pca, tsne, umap).
    def store_projections(run, person_ids, projections)
      rows = projections.flat_map do |projection_method, points|
        points.each_with_index.map do |(x, y), i|
          { run_id: run.id, person_id: person_ids[i], projection_method: projection_method, x: x, y: y }
        end
      end

      insert(Projection, rows)
    end

    def store_similarities(run, similarities)
      insert(Similarity, similarities.map { |pair| pair.merge(run_id: run.id) })
    end

    # Eine Clustering-Zeile je Parameterstufe, dazu die
    # Zuordnungen aller Personen und die Themen je Cluster.
    def store_clustering(run, person_ids, clustering, topics)
      record = Clustering.create!(
        run_id: run.id,
        algorithm: clustering[:algorithm],
        k: clustering[:k],
        eps: clustering[:eps],
        min_pts: clustering[:min_pts],
        cluster_count: clustering[:cluster_count],
        noise_count: clustering[:noise_count]
      )

      assignments = clustering[:labels].each_with_index.map do |cluster_number, i|
        { clustering_id: record.id, person_id: person_ids[i], cluster_number: cluster_number }
      end
      insert(ClusterAssignment, assignments)

      topic_rows = topics.map do |cluster_number, terms|
        { clustering_id: record.id, cluster_number: cluster_number, terms: terms }
      end
      insert(Topic, topic_rows)
    end

    # insert_all in Blöcken (ohne Validierungen; die Prüf-
    # bedingungen der Datenbank gelten trotzdem).
    def insert(model, rows)
      rows.each_slice(BATCH_SIZE) { |batch| model.insert_all!(batch) }
    end

    # ----------------------------------------------------------
    # Aufräumen und Protokoll
    # ----------------------------------------------------------

    # Behält die KEEP_RUNS neuesten fertigen Läufe; löscht alle
    # älteren Läufe (fertig oder fehlgeschlagen).
    def remove_old_runs
      keep = Run.finished.order(finished_at: :desc).limit(KEEP_RUNS).pluck(:id)
      return if keep.empty?

      oldest_kept = Run.where(id: keep).minimum(:started_at)
      Run.where.not(id: keep).where(started_at: ...oldest_kept).delete_all
    end

    # Führt einen Schritt aus und protokolliert seine Dauer.
    def step(name)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      log "#{name}: #{seconds.round(1)} s"
      result
    end

    def log(message)
      @logger.info("[Analyse] #{message}")
    end
  end
end
