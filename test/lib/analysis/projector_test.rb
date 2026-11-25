# ============================================================
# Datei: test/lib/analysis/projector_test.rb
#
# Desc:
#   Unit-Tests für Analysis::Projector (FA21, NFA15). Alle drei
#   Verfahren liefern für jede Person einen Punkt im Bereich
#   −1 … 1. Ähnliche Profile liegen in der Projektion näher
#   beieinander als unähnliche. Wiederholte Läufe sind gleich.
# ============================================================
require "test_helper"

class Analysis::ProjectorTest < ActiveSupport::TestCase
  # Zwei getrennte Gruppen mit je 60 Profilen in 8 Dimensionen.
  # t-SNE arbeitet mit Perplexität 30 und betrachtet dafür die
  # 90 nächsten Nachbarn; bei weniger Profilen verschwimmen die
  # Gruppen. 120 Profile liegen sicher darüber.
  GROUP_SIZE = 60

  def embedding
    random = Random.new(3)
    Array.new(2 * GROUP_SIZE) do |i|
      Array.new(8) { |d| (d == i / GROUP_SIZE ? 1.0 : 0.0) + random.rand(-0.1..0.1) }
    end
  end

  setup do
    @projections = Analysis::Projector.new.project(embedding)
  end

  test "liefert PCA, t-SNE und UMAP mit einem Punkt je Profil" do
    assert_equal %w[pca tsne umap], @projections.keys

    @projections.each_value do |points|
      assert_equal 2 * GROUP_SIZE, points.size
      points.flatten.each { |value| assert_operator value.abs, :<=, 1.0 + 1e-9 }
    end
  end

  # Verglichen werden die mittleren Abstände über alle Paare.
  # Einzelne Paare sind kein guter Maßstab: t-SNE und UMAP
  # erhalten die Nachbarschaften, nicht jeden einzelnen Abstand.
  test "Punkte derselben Gruppe liegen im Mittel näher beieinander als Punkte verschiedener Gruppen" do
    @projections.each do |method, points|
      within = []
      between = []
      points.each_with_index.to_a.combination(2) do |(a, i), (b, j)|
        distance = Math.hypot(a[0] - b[0], a[1] - b[1])
        (i / GROUP_SIZE == j / GROUP_SIZE ? within : between) << distance
      end
      mean = ->(values) { values.sum / values.size }

      assert_operator mean.(within), :<, mean.(between), "#{method}: Gruppen nicht getrennt"
    end
  end

  test "gleiche Daten ergeben gleiche Projektionen (fester Startwert)" do
    assert_equal @projections, Analysis::Projector.new.project(embedding)
  end
end
