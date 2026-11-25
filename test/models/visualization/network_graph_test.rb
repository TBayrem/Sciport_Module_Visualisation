# ============================================================
# Datei: test/models/visualization/network_graph_test.rb
#
# Desc:
#   Tests für Visualization::NetworkGraph (FA10–FA13, FA19,
#   FA34) mit dem Testnetz aus den Fixtures. Geprüft werden
#   Knoten, Hierarchie, Zugehörigkeit, Kooperationskanten,
#   Sammelkanten und die Zahlen für das Balkendiagramm.
# ============================================================
require "test_helper"

class Visualization::NetworkGraphTest < ActiveSupport::TestCase
  setup do
    @graph = Visualization::NetworkGraph.new
  end

  def key(fixture) = "#{fixture.is_a?(Facility) ? 'f' : 'p'}#{fixture.id}"

  # Kante zwischen zwei Knoten unabhängig von der Richtung
  def edge_between(edges, one, two)
    edges.find { |edge| [ edge[:source], edge[:target] ].sort == [ key(one), key(two) ].sort }
  end

  test "enthält alle Einrichtungen und nur Personen mit Rolle" do
    ids = @graph.nodes.map { |node| node[:id] }

    Facility.find_each { |facility| assert_includes ids, key(facility) }
    assert_includes ids, key(people(:anna))
    refute_includes ids, key(people(:dirk)), "Person ohne Rolle darf nicht erscheinen"
  end

  test "bestimmt die Ebene jeder Einrichtung" do
    level = ->(fixture) { @graph.nodes.find { |node| node[:id] == key(fixture) }[:level] }

    assert_equal 1, level.(facilities(:hs_worms))
    assert_equal 2, level.(facilities(:fb_physik))
    assert_equal 3, level.(facilities(:institut_optik))
  end

  test "bildet die Hierarchie als Kanten zur übergeordneten Einrichtung ab" do
    edge = @graph.hierarchy_edges.find { |e| e[:source] == key(facilities(:institut_optik)) }

    assert_equal key(facilities(:fb_physik)), edge[:target]
    assert_equal 3, @graph.hierarchy_edges.size
  end

  test "eine Person mit zwei Einrichtungen ist ein Knoten mit zwei Kanten (FA12)" do
    anna_nodes = @graph.nodes.count { |node| node[:id] == key(people(:anna)) }
    anna_edges = @graph.affiliation_edges.select { |edge| edge[:source] == key(people(:anna)) }

    assert_equal 1, anna_nodes
    assert_equal [ key(facilities(:fb_informatik)), key(facilities(:fb_physik)) ].sort, anna_edges.map { |e| e[:target] }.sort
  end

  test "zählt gemeinsame Projekte und Publikationen je Personenpaar (FA13)" do
    anna_ben = edge_between(@graph.cooperations, people(:anna), people(:ben))
    anna_carla = edge_between(@graph.cooperations, people(:anna), people(:carla))

    assert_equal [ 2, 0 ], anna_ben.values_at(:projects, :publications)
    assert_equal [ 1, 1 ], anna_carla.values_at(:projects, :publications)
    assert_equal 3, @graph.cooperations.size, "dirk hat keine Rolle und zählt nicht"
  end

  test "fasst Kooperationen auf Stufe 1 zu einer Sammelkante zusammen" do
    level1 = @graph.aggregated_edges.select { |edge| edge[:level] == 1 }
    edge = edge_between(level1, facilities(:hs_worms), facilities(:uni_mainz))

    assert_equal 1, level1.size
    # anna–ben (anna auch in Mainz), anna–carla, ben–carla
    assert_equal 3, edge[:count]
    assert_equal 1, edge[:publications]
  end

  test "Kooperationen innerhalb einer Einrichtung erzeugen keine Sammelkante" do
    @graph.aggregated_edges.each { |edge| refute_equal edge[:source], edge[:target] }
  end

  test "liefert Projekte und Publikationen je Person absteigend (FA19, FA34)" do
    projects = @graph.project_counts.to_h { |entry| [ entry[:id], entry[:count] ] }
    publications = @graph.publication_counts.to_h { |entry| [ entry[:id], entry[:count] ] }

    assert_equal 2, projects[key(people(:anna))]
    assert_equal 1, projects[key(people(:carla))]
    assert_equal @graph.project_counts.map { |e| e[:count] }.sort.reverse, @graph.project_counts.map { |e| e[:count] }
    assert_nil publications[key(people(:dirk))]
  end

  test "to_h enthält alle Teile für die View" do
    assert_equal %i[nodes hierarchy_edges affiliation_edges cooperations aggregated_edges project_counts publication_counts].sort,
                 @graph.to_h.keys.sort
  end
end
