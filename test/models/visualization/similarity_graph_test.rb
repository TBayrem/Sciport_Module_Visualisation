# ============================================================
# Datei: test/models/visualization/similarity_graph_test.rb
#
# Desc:
#   Tests für Visualization::SimilarityGraph (FA31, FA32).
#   Die Kanten kommen absteigend nach Ähnlichkeit; der
#   Startwert des Reglers zeigt bei wenigen Kanten alle.
# ============================================================
require "test_helper"

class Visualization::SimilarityGraphTest < ActiveSupport::TestCase
  setup do
    @data = Visualization::SimilarityGraph.new(build_analysis_run).to_h
  end

  test "liefert die Kanten absteigend nach Ähnlichkeit" do
    assert_equal [ 0.9, 0.6 ], @data[:edges].map { |edge| edge[:score] }
    assert @data[:edges].all? { |edge| edge[:source].start_with?("p") && edge[:target].start_with?("p") }
  end

  test "Minimum und Maximum für den Regler" do
    assert_equal 0.6, @data[:min]
    assert_equal 0.9, @data[:max]
  end

  test "bei weniger als DEFAULT_EDGES Kanten sind anfangs alle sichtbar" do
    assert_equal 0.6, @data[:threshold]
  end
end
