# ============================================================
# Datei: app/models/analysis/cluster_assignment.rb
#
# Desc:
#   Ordnet eine Person in einer Clusterbildung genau einem
#   Cluster zu. Bei DBSCAN steht cluster_number = -1 für
#   Rauschpunkte, also Personen ohne thematischen Cluster.
#
# Tabelle: analysis_cluster_assignments
# ============================================================

module Analysis
  class ClusterAssignment < ApplicationRecord
    # Clusternummer für DBSCAN-Rauschpunkte.
    NOISE = -1

    # ----------------------------------------------------------
    # Assoziationen
    #
    # person verweist auf die SciPort-Tabelle people
    # (ohne Fremdschlüssel in der Datenbank, vgl. Migration).
    # ----------------------------------------------------------
    belongs_to :clustering, inverse_of: :cluster_assignments
    belongs_to :person, class_name: "::Person"

    # ----------------------------------------------------------
    # Validierungen
    # ----------------------------------------------------------
    validates :cluster_number, numericality: { only_integer: true,
                                               greater_than_or_equal_to: NOISE }
    validates :person_id, uniqueness: { scope: :clustering_id }

    # ----------------------------------------------------------
    # Scopes
    # ----------------------------------------------------------
    scope :clustered, -> { where.not(cluster_number: NOISE) }
    scope :noise,     -> { where(cluster_number: NOISE) }

    def noise?
      cluster_number == NOISE
    end
  end
end
