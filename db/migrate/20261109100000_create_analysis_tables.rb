# ============================================================
# Datei: db/migrate/20261109100000_create_analysis_tables.rb
#
# Desc:
#   Legt die sechs Analysetabellen an (vgl. Abb. 8).
#   Sie speichern die Ergebnisse eines Analyselaufs, den
#   lib/tasks/analysis.rake über Analysis::Runner startet:
#
#   analysis_runs                – ein Analyselauf
#   analysis_projections         – 2D-Koordinaten je Person und Methode
#   analysis_similarities        – Kosinus-Ähnlichkeit je Personenpaar
#   analysis_clusterings         – eine Clusterbildung je Parameterstufe
#   analysis_cluster_assignments – Clusternummer je Person
#   analysis_topics              – Schlagwörter je Cluster
#
# Design:
#   - Die SciPort-Tabellen bleiben unverändert und werden nur
#     gelesen. person_id verweist deshalb nur logisch auf
#     people.id, ohne Fremdschlüssel. So bleibt ein erneuter
#     Import unabhängig von den Analyseergebnissen.
#   - Fremdschlüssel gibt es nur innerhalb der Analysetabellen.
#     Mit on_delete: :cascade löscht ein entfernter Lauf alle
#     zugehörigen Ergebnisse mit.
# ============================================================

class CreateAnalysisTables < ActiveRecord::Migration[8.1]
  # Erlaubte Werte, als CHECK-Constraint in der Datenbank abgesichert.
  STATUSES   = %w[running finished failed].freeze
  METHODS    = %w[pca tsne umap].freeze
  ALGORITHMS = %w[kmeans dbscan].freeze

  def change
    create_runs
    create_projections
    create_similarities
    create_clusterings
    create_cluster_assignments
    create_topics
  end

  private

  # ----------------------------------------------------------
  # 1. Analyselauf
  #
  # Die Seiten lesen immer den letzten Lauf mit
  # status = "finished" (Analysis::Run.latest_finished).
  # ----------------------------------------------------------
  def create_runs
    create_table :analysis_runs do |t|
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.string   :status, null: false, default: "running"
    end

    add_index :analysis_runs, [ :status, :finished_at ]
    add_check_constraint :analysis_runs,
                         "status IN (#{quoted(STATUSES)})",
                         name: "analysis_runs_status_check"
  end

  # ----------------------------------------------------------
  # 2. Projektionen
  #
  # Pro Lauf und Person je eine Zeile für PCA, t-SNE und UMAP.
  # Alle drei werden in die Seite eingebettet, damit der
  # Wechsel der Projektion im Browser erfolgen kann.
  #
  # Die Spalte heißt projection_method und nicht method,
  # weil Active Record sonst die Ruby-Methode Object#method
  # überschreiben würde.
  # ----------------------------------------------------------
  def create_projections
    create_table :analysis_projections do |t|
      t.references :run, null: false,
                         foreign_key: { to_table: :analysis_runs, on_delete: :cascade },
                         index: false
      t.bigint :person_id,         null: false
      t.string :projection_method, null: false
      t.float  :x,                 null: false
      t.float  :y,                 null: false
    end

    add_index :analysis_projections, [ :run_id, :projection_method, :person_id ],
              unique: true, name: "index_analysis_projections_unique"
    add_check_constraint :analysis_projections,
                         "projection_method IN (#{quoted(METHODS)})",
                         name: "analysis_projections_method_check"
  end

  # ----------------------------------------------------------
  # 3. Ähnlichkeiten
  #
  # Jedes Personenpaar wird genau einmal gespeichert
  # (person_a_id < person_b_id). Der Index auf score
  # unterstützt Analysis::Similarity.above(min).
  # ----------------------------------------------------------
  def create_similarities
    create_table :analysis_similarities do |t|
      t.references :run, null: false,
                         foreign_key: { to_table: :analysis_runs, on_delete: :cascade },
                         index: false
      t.bigint :person_a_id, null: false
      t.bigint :person_b_id, null: false
      t.float  :score,       null: false
    end

    add_index :analysis_similarities, [ :run_id, :person_a_id, :person_b_id ],
              unique: true, name: "index_analysis_similarities_unique"
    add_index :analysis_similarities, [ :run_id, :score ]
    add_check_constraint :analysis_similarities,
                         "person_a_id < person_b_id",
                         name: "analysis_similarities_pair_order_check"
    add_check_constraint :analysis_similarities,
                         "score >= 0 AND score <= 1",
                         name: "analysis_similarities_score_check"
  end

  # ----------------------------------------------------------
  # 4. Clusterbildungen
  #
  # Eine Zeile pro Parameterstufe:
  #   k-Means  → k gesetzt, eps und min_pts leer
  #   DBSCAN   → eps und min_pts gesetzt, k leer
  # cluster_count und noise_count werden beim Speichern
  # berechnet, damit die Seite sie nicht zählen muss.
  # ----------------------------------------------------------
  def create_clusterings
    create_table :analysis_clusterings do |t|
      t.references :run, null: false,
                         foreign_key: { to_table: :analysis_runs, on_delete: :cascade },
                         index: false
      t.string  :algorithm,     null: false
      t.integer :k
      t.float   :eps
      t.integer :min_pts
      t.integer :cluster_count, null: false, default: 0
      t.integer :noise_count,   null: false, default: 0
    end

    add_index :analysis_clusterings, [ :run_id, :algorithm, :k, :eps, :min_pts ],
              unique: true, name: "index_analysis_clusterings_unique"
    add_check_constraint :analysis_clusterings,
                         "algorithm IN (#{quoted(ALGORITHMS)})",
                         name: "analysis_clusterings_algorithm_check"
    add_check_constraint :analysis_clusterings,
                         "(algorithm = 'kmeans' AND k IS NOT NULL) OR " \
                         "(algorithm = 'dbscan' AND eps IS NOT NULL AND min_pts IS NOT NULL)",
                         name: "analysis_clusterings_params_check"
  end

  # ----------------------------------------------------------
  # 5. Clusterzuordnungen
  #
  # cluster_number = -1 kennzeichnet bei DBSCAN Rauschpunkte.
  # ----------------------------------------------------------
  def create_cluster_assignments
    create_table :analysis_cluster_assignments do |t|
      t.references :clustering, null: false,
                                foreign_key: { to_table: :analysis_clusterings, on_delete: :cascade },
                                index: false
      t.bigint  :person_id,      null: false
      t.integer :cluster_number, null: false
    end

    add_index :analysis_cluster_assignments, [ :clustering_id, :person_id ],
              unique: true, name: "index_analysis_cluster_assignments_unique"
  end

  # ----------------------------------------------------------
  # 6. Themen
  #
  # terms enthält die wichtigsten Schlagwörter eines Clusters
  # in absteigender Reihenfolge (PostgreSQL-Array).
  # ----------------------------------------------------------
  def create_topics
    create_table :analysis_topics do |t|
      t.references :clustering, null: false,
                                foreign_key: { to_table: :analysis_clusterings, on_delete: :cascade },
                                index: false
      t.integer :cluster_number, null: false
      t.string  :terms, array: true, null: false, default: []
    end

    add_index :analysis_topics, [ :clustering_id, :cluster_number ],
              unique: true, name: "index_analysis_topics_unique"
  end

  # Wandelt ["a", "b"] in "'a', 'b'" für CHECK-Constraints um.
  def quoted(values)
    values.map { |value| "'#{value}'" }.join(", ")
  end
end
