# ============================================================
# Datei: test/models/visualization/topic_map_test.rb
#
# Desc:
#   Tests für Visualization::TopicMap (FA20–FA24). Ohne Lauf
#   meldet das Modell, dass keine Karte vorliegt; mit Lauf
#   liefert es Punkte, Themen und die gewählten Verfahren.
# ============================================================
require "test_helper"

class Visualization::TopicMapTest < ActiveSupport::TestCase
  test "ohne fertigen Analyselauf ist keine Karte verfügbar" do
    assert_equal({ available: false }, Visualization::TopicMap.new(nil).to_h)
  end

  test "liefert einen Punkt je Person mit Clusternummer" do
    data = Visualization::TopicMap.new(build_analysis_run).to_h

    assert data[:available]
    assert_equal 3, data[:points].size
    assert_equal [ 0, 1 ], data[:points].map { |point| point[:cluster] }.uniq.sort
  end

  test "verwendet ohne Parameter UMAP und k-Means" do
    selection = Visualization::TopicMap.new(build_analysis_run).to_h[:selection]

    assert_equal "umap", selection[:projection_method]
    assert_equal "kmeans", selection[:algorithm]
  end

  test "übernimmt ein gültiges Projektionsverfahren aus den Parametern" do
    selection = Visualization::TopicMap.new(build_analysis_run, { projection_method: "pca" }).to_h[:selection]

    assert_equal "pca", selection[:projection_method]
  end

  test "ein ungültiges Verfahren fällt auf UMAP zurück" do
    selection = Visualization::TopicMap.new(build_analysis_run, { projection_method: "x" }).to_h[:selection]

    assert_equal "umap", selection[:projection_method]
  end

  test "liefert die Begriffe je Thema" do
    topics = Visualization::TopicMap.new(build_analysis_run).to_h[:topics]

    assert_includes topics.map { |topic| topic[:terms].first }, "optik"
  end
end
