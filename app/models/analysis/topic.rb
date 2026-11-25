# ============================================================
# Datei: app/models/analysis/topic.rb
#
# Desc:
#   Thema eines Clusters: die wichtigsten Schlagwörter, die
#   Analysis::TopicNamer aus den TF-IDF-Werten der Mitglieder
#   ermittelt. TopicCards und TopicMapView zeigen daraus die
#   Bezeichnung des Clusters an.
#
# Tabelle: analysis_topics
# ============================================================

module Analysis
  class Topic < ApplicationRecord
    # Anzahl der Schlagwörter in der Kurzbezeichnung.
    LABEL_TERMS = 3

    # ----------------------------------------------------------
    # Assoziationen
    # ----------------------------------------------------------
    belongs_to :clustering, inverse_of: :topics

    # ----------------------------------------------------------
    # Validierungen
    # ----------------------------------------------------------
    validates :cluster_number, numericality: { only_integer: true,
                                               greater_than_or_equal_to: 0 }
    validates :cluster_number, uniqueness: { scope: :clustering_id }
    validates :terms, presence: true

    # Kurzbezeichnung, z. B. "Robotik, Sensorik, Automation".
    def label
      terms.first(LABEL_TERMS).join(", ")
    end
  end
end