# ============================================================
# Datei: app/controllers/application_controller.rb
#
# Desc:
#   Gemeinsame Basisklasse der drei Seiten-Controller
#   (NetworksController, TopicMapsController,
#   CombinedViewsController).
#
#   Stellt dem gemeinsamen Layout den letzten abgeschlossenen
#   Analyselauf bereit. Der Footer zeigt daraus den Datenstand
#   ("Datenstand: Analyselauf vom ...").
# ============================================================

class ApplicationController < ActionController::Base
  # Nur Browser mit aktueller Unterstützung für ES-Module,
  # CSS-Variablen und Importmaps. Ältere Browser erhalten
  # eine Hinweisseite (Rails-Standard).
  allow_browser versions: :modern

  # latest_run ist auch in Views und im Layout aufrufbar.
  helper_method :latest_run

  private

  # Letzter abgeschlossener Analyselauf oder nil, falls noch
  # keine Analyse gelaufen ist. Wird pro Anfrage nur einmal
  # aus der Datenbank gelesen.
  def latest_run
    return @latest_run if defined?(@latest_run)

    @latest_run = Analysis::Run.latest_finished
  end
end
