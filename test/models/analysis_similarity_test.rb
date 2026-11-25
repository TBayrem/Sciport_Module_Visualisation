# ============================================================
# Datei: test/models/analysis_similarity_test.rb
#
# Desc:
#   Tests für Analysis::Similarity: Jedes Paar wird nur einmal
#   gespeichert (kleinere ID vorne), der Wert liegt in 0 … 1.
# ============================================================
require "test_helper"

class Analysis::SimilarityTest < ActiveSupport::TestCase
  setup do
    @run = Analysis::Run.start!
    @low, @high = [ people(:anna).id, people(:ben).id ].minmax
  end

  test "ein geordnetes Paar ist gültig" do
    assert Analysis::Similarity.new(run: @run, person_a_id: @low, person_b_id: @high, score: 0.7).valid?
  end

  test "ein Paar in falscher Reihenfolge ist ungültig" do
    refute Analysis::Similarity.new(run: @run, person_a_id: @high, person_b_id: @low, score: 0.7).valid?
  end

  test "Werte außerhalb von 0 bis 1 sind ungültig" do
    refute Analysis::Similarity.new(run: @run, person_a_id: @low, person_b_id: @high, score: 1.2).valid?
  end
end
