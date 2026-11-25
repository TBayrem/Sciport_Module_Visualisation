# ============================================================
# Datei: app/models/visualization/topic_map.rb
#
# Desc:
#   Modell der Themenkarte (UC3). Liest die vorab berechneten
#   Ergebnisse des letzten fertigen Analyselaufs und bereitet
#   sie für topic_map_view.js auf. Gerechnet wird hier nichts.
#
#   Gewählt werden können (über GET-Parameter des Formulars):
#     projection_method  pca | tsne | umap      (Standard umap)
#     algorithm          kmeans | dbscan        (Standard kmeans)
#     k                  Clusteranzahl bei k-Means (Standard 8)
#     eps, min_pts       Parameter bei DBSCAN
#   Ungültige oder nicht berechnete Werte fallen auf die
#   nächste vorhandene Stufe zurück.
#
#   Personen, Einrichtungen, Kooperationen und Projektzahlen
#   kommen aus Visualization::NetworkGraph. Suche, Detailpanel
#   und Auswahlzustand funktionieren damit genauso wie auf der
#   Netzwerkseite. Die kombinierte Ansicht übergibt ihr
#   NetworkGraph-Objekt (network:), damit es nur einmal
#   berechnet wird.
#
# Rückgabe von to_h:
#   {
#     available:        false, wenn noch kein Lauf fertig ist
#     run:              { id:, finished_at: }
#     selection:        { projection_method:, algorithm:, k:, eps:, min_pts: }
#     options:          { projection_methods:, kmeans_k:, dbscan: [[eps, min_pts], ...] }
#     clustering:       { cluster_count:, noise_count: }
#     points:           [{ id: "p12", x:, y:, cluster: }, ...]
#     topics:           [{ cluster:, terms:, size: }, ...]
#     nodes:            Personen der Analyse und alle Einrichtungen
#     cooperations:     Kooperationen zwischen Personen der Analyse
#     aggregated_edges: Sammelkanten zwischen Einrichtungen
#     project_counts:   Projekte je Person der Analyse
#   }
#   Die letzten vier Schlüssel haben dasselbe Format wie in
#   NetworkGraph#to_h; DetailPanel braucht sie unverändert.
# ============================================================

module Visualization
  class TopicMap
    DEFAULT_METHOD = "umap"
    DEFAULT_ALGORITHM = "kmeans"
    DEFAULT_K = 8
    NOISE = Analysis::ClusterAssignment::NOISE

    # run:     Analysis::Run oder nil
    # params:  erlaubte Parameter aus dem Controller
    # network: vorhandenes NetworkGraph-Objekt (optional)
    def initialize(run, params = {}, network: nil)
      @run = run
      @params = params.to_h.symbolize_keys
      @network = network
    end

    def to_h
      return { available: false } unless @run && clustering

      {
        available: true,
        run: { id: @run.id, finished_at: @run.finished_at.strftime("%d.%m.%Y, %H:%M Uhr") },
        selection: selection,
        options: options,
        clustering: { cluster_count: clustering.cluster_count, noise_count: clustering.noise_count },
        points: points,
        topics: topics,
        nodes: nodes,
        cooperations: cooperations,
        aggregated_edges: network.aggregated_edges,
        project_counts: project_counts
      }
    end

    private

    # ----------------------------------------------------------
    # Auswahl der Parameterstufe
    # ----------------------------------------------------------

    def projection_method
      @projection_method ||= Analysis::Projection::METHODS.include?(@params[:projection_method]) ? @params[:projection_method] : DEFAULT_METHOD
    end

    def clusterings
      @clusterings ||= Analysis::Clustering.where(run_id: @run.id).to_a
    end

    # Gewählte Stufe; sonst die erste passende des Algorithmus;
    # sonst k-Means mit DEFAULT_K; sonst irgendeine.
    def clustering
      @clustering ||= begin
        algorithm = %w[kmeans dbscan].include?(@params[:algorithm]) ? @params[:algorithm] : DEFAULT_ALGORITHM
        of_algorithm = clusterings.select { |c| c.algorithm == algorithm }

        exact = if algorithm == "kmeans"
          of_algorithm.find { |c| c.k == @params[:k].to_i }
        else
          of_algorithm.find { |c| c.eps.to_f == @params[:eps].to_f && c.min_pts == @params[:min_pts].to_i }
        end

        exact ||
          of_algorithm.min_by { |c| c.algorithm == "kmeans" ? (c.k - DEFAULT_K).abs : 0 } ||
          clusterings.find { |c| c.algorithm == DEFAULT_ALGORITHM && c.k == DEFAULT_K } ||
          clusterings.first
      end
    end

    def selection
      {
        projection_method: projection_method,
        algorithm: clustering.algorithm,
        k: clustering.k,
        eps: clustering.eps&.to_f,
        min_pts: clustering.min_pts
      }
    end

    # Alle berechneten Stufen, damit das Formular nur
    # vorhandene Werte anbietet.
    def options
      {
        projection_methods: Analysis::Projection::METHODS,
        kmeans_k: clusterings.select(&:kmeans?).map(&:k).sort,
        dbscan: clusterings.select(&:dbscan?).map { |c| [ c.eps.to_f, c.min_pts ] }.sort
      }
    end

    # ----------------------------------------------------------
    # Daten der Karte
    # ----------------------------------------------------------

    # Clusternummer je Person der gewählten Stufe.
    def assignments
      @assignments ||= Analysis::ClusterAssignment
        .where(clustering_id: clustering.id)
        .pluck(:person_id, :cluster_number)
        .to_h
    end

    def points
      Analysis::Projection
        .where(run_id: @run.id, projection_method: projection_method)
        .pluck(:person_id, :x, :y)
        .map do |person_id, x, y|
          { id: "p#{person_id}", x: x.to_f.round(4), y: y.to_f.round(4), cluster: assignments.fetch(person_id, NOISE) }
        end
    end

    # Themen mit Begriffen und Anzahl Personen, größte zuerst.
    def topics
      sizes = assignments.values.tally

      Analysis::Topic
        .where(clustering_id: clustering.id)
        .order(:cluster_number)
        .map { |topic| { cluster: topic.cluster_number, terms: topic.terms, size: sizes.fetch(topic.cluster_number, 0) } }
        .sort_by { |topic| -topic[:size] }
    end

    # ----------------------------------------------------------
    # Daten aus dem Netzwerkmodell
    # ----------------------------------------------------------

    def network
      @network ||= NetworkGraph.new
    end

    # Knoten-IDs ("p12") der Personen in der Analyse.
    def analysed
      @analysed ||= assignments.keys.to_set { |id| "p#{id}" }
    end

    # Alle Einrichtungen (für Zugehörigkeit und Suche) und nur
    # die Personen, die in der Analyse vorkommen.
    def nodes
      network.nodes.select { |node| node[:type] == "facility" || analysed.include?(node[:id]) }
    end

    # Nur Kooperationen, bei denen beide Personen auf der
    # Karte sind; das Detailpanel verweist sonst ins Leere.
    def cooperations
      network.cooperations.select { |edge| analysed.include?(edge[:source]) && analysed.include?(edge[:target]) }
    end

    def project_counts
      network.project_counts.select { |entry| analysed.include?(entry[:id]) }
    end
  end
end
