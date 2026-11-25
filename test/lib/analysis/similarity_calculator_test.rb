# ============================================================
# Datei: test/lib/analysis/similarity_calculator_test.rb
#
# Desc:
#   Unit-Tests für Analysis::SimilarityCalculator (FA31, FA42).
#   Geprüft werden die Kosinus-Ähnlichkeit, der Mindestwert,
#   die Begrenzung auf die ähnlichsten Partner je Person und
#   die Form der Paare (kleinere ID vorne, absteigend sortiert).
# ============================================================
require "test_helper"

class Analysis::SimilarityCalculatorTest < ActiveSupport::TestCase
  test "berechnet die Kosinus-Ähnlichkeit und lässt Paare unter dem Mindestwert weg" do
    pairs = Analysis::SimilarityCalculator.new.calculate(
      [ 10, 20, 30 ],
      [ [ 1.0, 0.0 ], [ 3.0, 4.0 ], [ 0.0, 1.0 ] ]
    )

    # cos(10, 20) = 0,6; cos(20, 30) = 0,8; cos(10, 30) = 0 → fällt weg
    assert_equal [ [ 20, 30, 0.8 ], [ 10, 20, 0.6 ] ],
                 pairs.map { |pair| pair.values_at(:person_a_id, :person_b_id, :score) }
  end

  test "die kleinere Personen-ID steht immer vorne" do
    pairs = Analysis::SimilarityCalculator.new.calculate([ 9, 2 ], [ [ 1.0, 0.0 ], [ 1.0, 0.1 ] ])

    assert_equal 2, pairs.first[:person_a_id]
    assert_equal 9, pairs.first[:person_b_id]
  end

  test "Werte liegen zwischen 0 und 1" do
    pairs = Analysis::SimilarityCalculator.new.calculate([ 1, 2 ], [ [ 2.0, 0.0 ], [ 2.0, 0.0 ] ])

    assert_equal 1.0, pairs.first[:score]
  end

  test "jede Person behält höchstens max_per_person Partner" do
    ids = (1..6).to_a
    embedding = ids.map { |i| [ 1.0, i * 0.01 ] }   # alle sehr ähnlich
    pairs = Analysis::SimilarityCalculator.new(max_per_person: 2).calculate(ids, embedding)

    partners = Hash.new(0)
    pairs.each do |pair|
      partners[pair[:person_a_id]] += 1
      partners[pair[:person_b_id]] += 1
    end

    # Ein Paar bleibt erhalten, wenn es für eine der beiden
    # Personen zu den besten gehört; daher höchstens 2 · 2.
    assert partners.values.all? { |count| count <= 4 }
    assert_operator pairs.size, :<, ids.combination(2).count
  end

  test "unterschiedlich lange Eingaben sind ein Fehler" do
    assert_raises(ArgumentError) do
      Analysis::SimilarityCalculator.new.calculate([ 1, 2 ], [ [ 1.0 ] ])
    end
  end
end
