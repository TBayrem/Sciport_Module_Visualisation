# ============================================================
# Datei: app/controllers/combined_views_controller.rb
#
# Desc:
#   Controller der kombinierten Ansicht (UC 4: Thema in der
#   kombinierten Ansicht auswählen, UC 5: Schwellenwert
#   ändern).
#
#   Die Seite zeigt Netzwerk und Themenkarte nebeneinander
#   und verbindet thematisch ähnliche Personen im Netzwerk
#   (FA30–FA34). Sie bettet dazu drei Datensätze ein:
#     @network_data  Visualization::NetworkGraph#to_h
#     @topic_map     Visualization::TopicMap#to_h (ohne die
#                    Netzwerkteile, die stehen schon in
#                    @network_data)
#     @similarity    Visualization::SimilarityGraph#to_h
#
#   Projektion und Clusterverfahren übernimmt die Seite von
#   der Themenkarte (FA35): TopicMapsController merkt sich die
#   zuletzt gewählten Parameter in der Session.
#
#   Ein NetworkGraph-Objekt wird für Netzwerk und Themenkarte
#   gemeinsam genutzt, damit die Netzwerkdaten nur einmal aus
#   der Datenbank gelesen werden.
# ============================================================

class CombinedViewsController < ApplicationController
  # Schlüssel, die schon in @network_data enthalten sind
  NETWORK_KEYS = %i[nodes cooperations aggregated_edges project_counts].freeze

  # GET /combined_views
  def index
    network = Visualization::NetworkGraph.new
    @network_data = network.to_h

    topic_map = Visualization::TopicMap.new(latest_run, session.fetch(:topic_map_params, {}), network: network)
    @topic_map = topic_map.to_h.except(*NETWORK_KEYS)

    @similarity = Visualization::SimilarityGraph.new(latest_run).to_h if @topic_map[:available]
  end
end
