# ============================================================
# Datei: app/models/analysis/projection.rb
#
# Desc:
#   2D-Koordinate einer Person für eine Projektionsmethode.
#   Pro Lauf gibt es je Person drei Zeilen (PCA, t-SNE, UMAP).
#
#   Visualization::TopicMap liest alle drei Methoden und
#   bettet sie in die Seite ein, damit TopicMapView die
#   Projektion im Browser ohne neuen Request wechseln kann.
#
# Tabelle: analysis_projections
# ============================================================

module Analysis
  class Projection < ApplicationRecord
    METHODS = %w[pca tsne umap].freeze

    # ----------------------------------------------------------
    # Assoziationen
    #
    # person verweist auf die SciPort-Tabelle people. In der
    # Datenbank gibt es dafür bewusst keinen Fremdschlüssel
    # (vgl. Migration); "::Person" verhindert, dass Rails im
    # Namensraum Analysis nach einer Klasse Person sucht.
    # ----------------------------------------------------------
    belongs_to :run, inverse_of: :projections
    belongs_to :person, class_name: "::Person"

    # ----------------------------------------------------------
    # Validierungen
    # ----------------------------------------------------------
    validates :projection_method, inclusion: { in: METHODS }
    validates :x, :y, numericality: true
    validates :person_id, uniqueness: { scope: [ :run_id, :projection_method ] }

    # ----------------------------------------------------------
    # Scopes
    # ----------------------------------------------------------
    scope :for_method, ->(projection_method) { where(projection_method: projection_method) }
  end
end
