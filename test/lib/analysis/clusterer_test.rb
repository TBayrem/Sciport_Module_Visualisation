# ============================================================
# Datei: test/lib/analysis/clusterer_test.rb
#
# Desc:
#   Unit-Tests für Analysis::Clusterer (FA22, FA41, NFA15).
#   Testdaten sind vier deutlich getrennte Gruppen von Punkten.
#   k-Means mit k = 4 und DBSCAN müssen diese Gruppen finden.
#   Ein einzelner entfernter Punkt muss bei DBSCAN als Ausreißer
#   (Clusternummer −1) erkannt werden. Zwei Läufe mit denselben
#   Daten liefern wegen des festen Startwerts dasselbe Ergebnis.
# ============================================================
require "test_helper"

class Analysis::ClustererTest < ActiveSupport::TestCase
  GROUPS = 4
  PER_GROUP = 8
  DIMENSIONS = 6

  # Punkte nahe den Achsen e1 … e4 mit leichter Streuung.
  def grouped_points
    random = Random.new(1)
    (0...GROUPS).flat_map do |group|
      Array.new(PER_GROUP) do
        Array.new(DIMENSIONS) { |d| (d == group ? 1.0 : 0.0) + random.rand(-0.05..0.05) }
      end
    end
  end

  def group_of(index)
    index / PER_GROUP
  end

  # Jede Gruppe hat genau eine Clusternummer, und die vier
  # Gruppen haben vier verschiedene Nummern.
  def assert_groups_found(labels)
    per_group = (0...GROUPS).map { |group| labels.each_index.select { |i| group_of(i) == group }.map { |i| labels[i] }.uniq }

    assert per_group.all? { |group_labels| group_labels.size == 1 }, "eine Gruppe wurde geteilt: #{per_group.inspect}"
    assert_equal GROUPS, per_group.flatten.uniq.size
  end

  setup do
    @results = Analysis::Clusterer.new.cluster_all(grouped_points)
  end

  test "berechnet k-Means für alle k bis zur Zahl der Punkte und DBSCAN" do
    kmeans = @results.select { |result| result[:algorithm] == "kmeans" }

    assert_equal Analysis::Clusterer::KMEANS_K, kmeans.map { |result| result[:k] }
    assert @results.any? { |result| result[:algorithm] == "dbscan" }
  end

  test "k-Means mit k = 4 findet die vier Gruppen" do
    result = @results.find { |r| r[:algorithm] == "kmeans" && r[:k] == 4 }

    assert_groups_found result[:labels]
    assert_equal 4, result[:cluster_count]
    assert_equal 0, result[:noise_count]
  end

  # Die eps-Stufen ergeben sich aus den Daten (Quantile der
  # Abstände zum MinPts-nächsten Nachbarn). Mit der größten Stufe
  # sind die meisten Punkte Kernpunkte; dann muss DBSCAN die vier
  # Gruppen ohne Ausreißer finden.
  test "DBSCAN mit der größten eps-Stufe findet die vier Gruppen" do
    dbscan = @results.select { |result| result[:algorithm] == "dbscan" && result[:min_pts] == 5 }
    result = dbscan.max_by { |r| r[:eps] }

    assert_groups_found result[:labels]
    assert_equal 0, result[:noise_count]
  end

  test "kleinere eps-Stufen ergeben mindestens so viele Ausreißer wie größere" do
    dbscan = @results.select { |result| result[:algorithm] == "dbscan" && result[:min_pts] == 5 }
    noise = dbscan.sort_by { |r| r[:eps] }.map { |r| r[:noise_count] }

    assert_equal noise.sort.reverse, noise
  end

  test "DBSCAN kennzeichnet einen entfernten Punkt als Ausreißer" do
    outlier = Array.new(DIMENSIONS, 0.0).tap { |point| point[DIMENSIONS - 1] = 1.0 }
    results = Analysis::Clusterer.new.cluster_all(grouped_points + [ outlier ])

    results.select { |result| result[:algorithm] == "dbscan" }.each do |result|
      assert_equal Analysis::Clusterer::NOISE, result[:labels].last
      assert_operator result[:noise_count], :>=, 1
    end
  end

  test "gleiche Daten ergeben gleiche Cluster (fester Startwert)" do
    assert_equal @results, Analysis::Clusterer.new.cluster_all(grouped_points)
  end
end
