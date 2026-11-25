# ============================================================
# Datei: app/models/analysis/clustering.rb
#
# Desc:
#   Eine Clusterbildung für genau eine feste Parameterstufe:
#     k-Means → k (Anzahl der Cluster)
#     DBSCAN  → eps (Radius) und min_pts (Mindestnachbarn)
#
#   Analysis::Runner berechnet alle Stufen im Voraus. Ändert
#   die Nutzerin die Parameter, lädt die Seite per GET neu und
#   TopicMapsController sucht die passende Stufe mit for_params.
#
# Tabelle: analysis_clusterings
# ============================================================

module Analysis
  class Clustering < ApplicationRecord
    ALGORITHMS = %w[kmeans dbscan].freeze

    # ----------------------------------------------------------
    # Assoziationen
    # ----------------------------------------------------------
    belongs_to :run, inverse_of: :clusterings
    has_many :cluster_assignments, inverse_of: :clustering
    has_many :topics, inverse_of: :clustering

    # ----------------------------------------------------------
    # Validierungen
    #
    # Je nach Algorithmus müssen die passenden Parameter
    # gesetzt sein (entspricht dem CHECK-Constraint).
    # ----------------------------------------------------------
    validates :algorithm, inclusion: { in: ALGORITHMS }
    validates :k, numericality: { only_integer: true, greater_than: 1 }, if: :kmeans?
    validates :eps, numericality: { greater_than: 0 }, if: :dbscan?
    validates :min_pts, numericality: { only_integer: true, greater_than: 0 }, if: :dbscan?
    validates :cluster_count, :noise_count,
              numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    # ----------------------------------------------------------
    # Scopes
    # ----------------------------------------------------------

    # Feste Reihenfolge der Stufen für die Parameterauswahl.
    scope :ordered, -> { order(:algorithm, :k, :eps, :min_pts) }

    # Sucht die Clusterbildung zu den gewählten Parametern.
    # Wird auf run.clusterings aufgerufen, also immer innerhalb
    # eines Laufs. Gibt nil zurück, wenn es die Stufe nicht gibt.
    def self.for_params(algorithm:, k: nil, eps: nil, min_pts: nil)
      if algorithm == "kmeans"
        find_by(algorithm: "kmeans", k: k)
      else
        find_by(algorithm: "dbscan", eps: eps, min_pts: min_pts)
      end
    end

    # ----------------------------------------------------------
    # Instanzmethoden
    # ----------------------------------------------------------

    def kmeans?
      algorithm == "kmeans"
    end

    def dbscan?
      algorithm == "dbscan"
    end

    # Parameter dieser Stufe als Hash, z. B. für die
    # Parameterauswahl in der View (parameter_steps).
    def parameters
      if kmeans?
        { algorithm: algorithm, k: k }
      else
        { algorithm: algorithm, eps: eps, min_pts: min_pts }
      end
    end
  end
end
