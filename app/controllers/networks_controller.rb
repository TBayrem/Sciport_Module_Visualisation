# ============================================================
# Datei: app/controllers/networks_controller.rb
#
# Desc:
#   Controller der Seite "Forschungsnetzwerk"
#   (UC 1: Netzwerk erkunden, UC 2: Kooperationen einer
#   Person anzeigen).
#
#   Ablauf (vgl. Sequenzdiagramm UC 1):
#     1. GET /networks
#     2. Visualization::NetworkGraph baut Knoten und Kanten
#        aus den SciPort-Tabellen.
#     3. to_h liefert die Netzwerkdaten.
#     4. Die View networks/index bettet sie in die Seite ein.
#
#   Der Controller enthält keine Fachlogik; er verbindet
#   nur Model und View.
# ============================================================

class NetworksController < ApplicationController
  # GET /networks
  # GET /
  def index
    @network_data = Visualization::NetworkGraph.new.to_h
  end
end
