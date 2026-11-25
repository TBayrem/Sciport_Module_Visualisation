# ============================================================
# Datei: test/lib/analysis/vectorizer_test.rb
#
# Desc:
#   Unit-Tests für Analysis::Vectorizer (FA40). Geprüft wird,
#   dass aus Texten normierte TF-IDF-Vektoren entstehen und
#   dass Stoppwörter, seltene und zu häufige Wörter nicht ins
#   Vokabular kommen. Die Tests brauchen keine Datenbank.
# ============================================================
require "test_helper"

class Analysis::VectorizerTest < ActiveSupport::TestCase
  # Kleiner Korpus mit 8 Profilen. "netzwerk" und "visualisierung"
  # kommen in 3 Profilen vor (≥ MIN_DF), "proteine" in 3 anderen.
  # "forschung" steht in allen Profilen (über MAX_DF_RATIO = 50 %).
  TEXTS = {
    1 => "Netzwerk Visualisierung Forschung",
    2 => "Netzwerk Visualisierung Graphen Forschung",
    3 => "Netzwerk Visualisierung Forschung und Lehre",
    4 => "Proteine Zellen Forschung",
    5 => "Proteine Zellen Forschung Labor",
    6 => "Proteine Zellen Forschung",
    7 => "Forschung Recht",
    8 => "Forschung Wirtschaft"
  }.freeze

  setup do
    @result = Analysis::Vectorizer.new.vectorize(TEXTS)
  end

  test "liefert je Person einen Vektor in derselben Reihenfolge" do
    assert_equal TEXTS.keys, @result.person_ids
    assert_equal TEXTS.size, @result.vectors.size
  end

  test "Vokabular enthält nur Wörter mit passender Dokumenthäufigkeit" do
    assert_includes @result.terms, "netzwerk"
    assert_includes @result.terms, "proteine"
    refute_includes @result.terms, "forschung", "kommt in allen Profilen vor (MAX_DF)"
    refute_includes @result.terms, "recht", "kommt nur in einem Profil vor (MIN_DF)"
    refute_includes @result.terms, "und", "Stoppwort"
  end

  test "Vektoren sind auf Länge 1 normiert" do
    @result.vectors.reject(&:empty?).each do |vector|
      length = Math.sqrt(vector.values.sum { |value| value * value })
      assert_in_delta 1.0, length, 1e-9
    end
  end

  test "Profile ohne Begriff aus dem Vokabular ergeben einen leeren Vektor" do
    assert_empty @result.vectors[TEXTS.keys.index(7)]
  end

  test "Pluralformen werden mit ihrer Grundform zusammengeführt" do
    texts = {
      1 => "Netzwerke Analyse", 2 => "Netzwerk Analyse", 3 => "Netzwerke Analyse",
      4 => "Zellen", 5 => "Zellen", 6 => "Zellen", 7 => "Recht", 8 => "Recht"
    }
    terms = Analysis::Vectorizer.new.vectorize(texts).terms

    assert_includes terms, "netzwerk"
    refute_includes terms, "netzwerke"
  end
end
