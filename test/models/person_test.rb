# ============================================================
# Datei: test/models/person_test.rb
#
# Desc:
#   Tests für Person: Namen für Anzeige und Suche sowie die
#   Einrichtungen über die Rollen.
# ============================================================
require "test_helper"

class PersonTest < ActiveSupport::TestCase
  test "display_name setzt den Titel vor den Namen" do
    assert_equal "Prof. Dr. Anna Albrecht", people(:anna).display_name
    assert_equal "Ben Becker", people(:ben).display_name
  end

  test "die Suche findet Vor- und Nachnamen ohne Groß-/Kleinschreibung" do
    assert_includes Person.search_by_name("albr"), people(:anna)
    assert_includes Person.search_by_name("CARLA"), people(:carla)
    refute_includes Person.search_by_name("albr"), people(:ben)
  end

  test "Einrichtungen kommen über die Rollen und ohne Dopplung" do
    assert_equal [ facilities(:fb_informatik), facilities(:fb_physik) ].sort_by(&:id), people(:anna).facilities.sort_by(&:id)
  end
end
