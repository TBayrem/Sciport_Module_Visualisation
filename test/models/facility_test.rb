# ============================================================
# Datei: test/models/facility_test.rb
#
# Desc:
#   Tests für die Einrichtungshierarchie (FA11): oberste
#   Einrichtung, Einrichtung der zweiten Ebene und Schutz vor
#   Zyklen in der Hierarchie.
# ============================================================
require "test_helper"

class FacilityTest < ActiveSupport::TestCase
  test "findet die oberste Einrichtung" do
    assert_equal facilities(:uni_mainz), facilities(:institut_optik).root_facility
    assert facilities(:uni_mainz).root_facility?
  end

  test "findet die Einrichtung der zweiten Ebene" do
    assert_equal facilities(:fb_physik), facilities(:institut_optik).second_level_facility
    assert_equal facilities(:uni_mainz), facilities(:uni_mainz).second_level_facility
  end

  test "eine Einrichtung darf nicht unter einer eigenen Untereinrichtung hängen" do
    mainz = facilities(:uni_mainz)
    mainz.parent = facilities(:institut_optik)

    refute mainz.valid?
    assert mainz.errors[:parent].any?
  end

  test "external_id ist Pflicht und eindeutig" do
    refute Facility.new(name: "Ohne Kennung").valid?
    refute Facility.new(name: "Doppelt", external_id: facilities(:hs_worms).external_id).valid?
  end
end
