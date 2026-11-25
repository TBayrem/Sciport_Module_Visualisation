# ============================================================
# Datei: app/models/visualization/similarity_graph.rb
#
# Desc:
#   Thematische Kanten für die kombinierte Ansicht (UC 5,
#   FA31, FA32). Liest die vorab berechneten Ähnlichkeiten
#   (Analysis::Similarity, Kosinus-Ähnlichkeit der Profile)
#   des letzten fertigen Analyselaufs.
#
#   Eingebettet werden alle gespeicherten Paare, ähnlichste
#   zuerst. Der Schwellenwert-Regler filtert sie im Browser:
#   Weil die Liste absteigend sortiert ist, reicht dort eine
#   binäre Suche, um alle Kanten oberhalb des Reglerwerts zu
#   finden. Ein Verschieben des Reglers braucht damit keine
#   neue Anfrage an den Server.
#
#   Startwert des Reglers: so, dass höchstens DEFAULT_EDGES
#   Kanten sichtbar sind; das Netzwerk bleibt beim Öffnen
#   lesbar.
#
# Rückgabe von to_h:
#   {
#     edges:     [{ source: "p1", target: "p7", score: 0.83 }, ...]
#                absteigend nach score
#     min:       kleinster gespeicherter Wert (untere Reglergrenze)
#     max:       größter Wert (obere Reglergrenze)
#     threshold: Startwert des Reglers
#   }
# ============================================================

module Visualization
  class SimilarityGraph
    DEFAULT_EDGES = 500
    PRECISION = 3

    # run: Analysis::Run (letzter fertiger Lauf)
    def initialize(run)
      @run = run
    end

    def to_h
      {
        edges: edges,
        min: edges.last&.dig(:score) || 0.0,
        max: edges.first&.dig(:score) || 1.0,
        threshold: default_threshold
      }
    end

    private

    # Alle Paare des Laufs, ähnlichste zuerst.
    def edges
      @edges ||= Analysis::Similarity
        .where(run_id: @run.id)
        .above(0)
        .pluck(:person_a_id, :person_b_id, :score)
        .map do |person_a_id, person_b_id, score|
          { source: "p#{person_a_id}", target: "p#{person_b_id}", score: score.round(PRECISION) }
        end
    end

    # Score der DEFAULT_EDGES-ten Kante; bei weniger Kanten der
    # kleinste Wert, sodass alle sichtbar sind.
    def default_threshold
      return 0.0 if edges.empty?

      edges[[ DEFAULT_EDGES, edges.size ].min - 1][:score]
    end
  end
end
