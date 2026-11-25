# ============================================================
# Datei: app/controllers/topic_maps_controller.rb
#
# Desc:
#   Controller der Themenkarte (UC3). Nimmt die Parameter des
#   Formulars (_parameters-Partial) per GET entgegen und
#   übergibt sie mit dem letzten fertigen Analyselauf an
#   Visualization::TopicMap. Die View bettet das Ergebnis als
#   data-Attribut ein (keine JSON-API).
#
#   Die zuletzt gewählten Parameter werden in der Session
#   gespeichert. Damit bleiben sie beim erneuten Öffnen der
#   Seite erhalten, und die kombinierte Ansicht verwendet
#   dieselben Verfahren (FA35).
# ============================================================

class TopicMapsController < ApplicationController
  # GET /topic_maps
  def index
    @topic_map = Visualization::TopicMap.new(latest_run, topic_map_params).to_h
  end

  private

  # Neue Parameter aus dem Formular speichern; ohne Parameter
  # (z. B. Aufruf über die Navigation) die gespeicherten nehmen.
  def topic_map_params
    permitted = params.permit(:projection_method, :algorithm, :k, :eps, :min_pts).to_h
    session[:topic_map_params] = permitted if permitted.present?

    session.fetch(:topic_map_params, {})
  end
end
