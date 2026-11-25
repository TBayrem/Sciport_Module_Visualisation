# ============================================================
# Datei: app/models/analysis/similarity.rb
#
# Desc:
#   Kosinus-Ähnlichkeit der Forschungsthemen zweier Personen
#   (Wert zwischen 0 und 1). Jedes Paar wird genau einmal
#   gespeichert, immer mit person_a_id < person_b_id.
#
#   Visualization::SimilarityGraph liest über above(min) alle
#   Paare oberhalb eines Mindestwerts, absteigend sortiert.
#   NetworkView kann den Schwellenwert dann im Browser per
#   binärer Suche anwenden (visiblePairs).
#
# Tabelle: analysis_similarities
# ============================================================

module Analysis
  class Similarity < ApplicationRecord
    # ----------------------------------------------------------
    # Assoziationen
    #
    # Beide Personen verweisen auf die SciPort-Tabelle people
    # (ohne Fremdschlüssel in der Datenbank, vgl. Migration).
    # ----------------------------------------------------------
    belongs_to :run, inverse_of: :similarities
    belongs_to :person_a, class_name: "::Person"
    belongs_to :person_b, class_name: "::Person"

    # ----------------------------------------------------------
    # Validierungen
    # ----------------------------------------------------------
    validates :score, numericality: { greater_than_or_equal_to: 0,
                                      less_than_or_equal_to: 1 }
    validates :person_b_id, uniqueness: { scope: [ :run_id, :person_a_id ] }
    validate :pair_is_ordered

    # ----------------------------------------------------------
    # Scopes
    # ----------------------------------------------------------

    # Alle Paare mit score >= min, ähnlichste zuerst.
    scope :above, ->(min) { where(score: min..).order(score: :desc) }

    # Liefert die IDs zweier Personen in der gespeicherten
    # Reihenfolge (kleinere ID zuerst). Analysis::Runner nutzt
    # dies beim Speichern, damit jedes Paar nur einmal vorkommt.
    def self.ordered_pair(id_one, id_two)
      [ id_one, id_two ].minmax
    end

    private

    # Stellt sicher, dass person_a_id kleiner als person_b_id ist
    # (entspricht dem CHECK-Constraint in der Datenbank).
    def pair_is_ordered
      return if person_a_id.nil? || person_b_id.nil?
      return if person_a_id < person_b_id

      errors.add(:person_b_id, "muss größer als person_a_id sein")
    end
  end
end
