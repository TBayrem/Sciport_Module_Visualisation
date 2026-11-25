# ============================================================
# Datei: test/lib/analysis/topic_namer_test.rb
#
# Desc:
#   Unit-Tests für Analysis::TopicNamer (FA24). Ein Thema wird
#   nach den Begriffen benannt, die in seinem Cluster stark und
#   in anderen Clustern selten sind (c-TF-IDF). Ausreißer
#   (Clusternummer −1) erhalten keinen Namen.
# ============================================================
require "test_helper"

class Analysis::TopicNamerTest < ActiveSupport::TestCase
  TERMS = %w[netzwerk graph protein zelle forschung].freeze

  # Profile als dünne Vektoren { Begriffsindex => Gewicht }.
  # "forschung" (Index 4) kommt in beiden Clustern gleich vor.
  VECTORS = [
    { 0 => 0.7, 1 => 0.5, 4 => 0.5 },
    { 0 => 0.6, 1 => 0.6, 4 => 0.5 },
    { 2 => 0.7, 3 => 0.5, 4 => 0.5 },
    { 2 => 0.6, 3 => 0.6, 4 => 0.5 },
    { 1 => 0.9 }
  ].freeze
  LABELS = [ 0, 0, 1, 1, -1 ].freeze

  setup do
    @topics = Analysis::TopicNamer.new(terms_per_topic: 2).name(VECTORS, TERMS, LABELS)
  end

  test "benennt jeden Cluster, aber nicht die Ausreißer" do
    assert_equal [ 0, 1 ], @topics.keys
  end

  test "die typischen Begriffe eines Clusters stehen vorne" do
    assert_equal %w[netzwerk graph], @topics[0]
    assert_equal %w[protein zelle], @topics[1]
  end

  test "Begriffe, die in allen Clustern gleich häufig sind, verlieren" do
    refute_includes @topics.values.flatten, "forschung"
  end

  test "unterschiedlich lange Eingaben sind ein Fehler" do
    assert_raises(ArgumentError) { Analysis::TopicNamer.new.name(VECTORS, TERMS, [ 0 ]) }
  end
end
