# ============================================================
# Datei: test/controllers/pages_test.rb
#
# Desc:
#   Integrationstests für die drei Seiten (FA01, FA35). Geprüft
#   wird, dass jede Seite lädt, ihre Daten als data-Attribut
#   einbettet und ohne Analyselauf einen Hinweis zeigt.
# ============================================================
require "test_helper"

class PagesTest < ActionDispatch::IntegrationTest
  test "Netzwerkseite lädt und bettet das Netzwerk ein" do
    get root_path

    assert_response :success
    assert_select "[data-page=network][data-network]"
    assert_includes response.body, "Albrecht"
  end

  test "Navigation verlinkt alle drei Ansichten (FA01)" do
    get root_path

    assert_select "a[href=?]", networks_path
    assert_select "a[href=?]", topic_maps_path
    assert_select "a[href=?]", combined_views_path
  end

  test "Themenkarte ohne Analyselauf zeigt einen Hinweis" do
    get topic_maps_path

    assert_response :success
    assert_includes response.body, "kein fertiger Analyselauf"
  end

  test "Themenkarte mit Analyselauf zeigt den Datenstand (FA03)" do
    build_analysis_run
    get topic_maps_path

    assert_response :success
    assert_select "[data-topic-map]"
    assert_includes response.body, "Stand der Analyse"
  end

  test "kombinierte Ansicht übernimmt die Verfahren der Themenkarte (FA35)" do
    build_analysis_run
    get topic_maps_path, params: { projection_method: "pca", algorithm: "kmeans", k: 2 }
    get combined_views_path

    assert_response :success
    assert_select "[data-network][data-topic-map][data-similarity]"
    assert_includes response.body, "PCA"
  end

  test "ungültige Parameter führen nicht zu einem Fehler" do
    build_analysis_run
    get topic_maps_path, params: { projection_method: "<script>", k: "abc" }

    assert_response :success
  end
end
