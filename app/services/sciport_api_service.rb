# ================================================================
# SCIPORT API SERVICE
# ================================================================
# Titel: Sciport API Service
# Beschreibung: Service-Klasse für die Kommunikation mit der
#               Sciport-Webservice-API. Enthält Authentifizierung
#               und HTTP-Requests.
#
# @author Sciport Module Visualisation Team
# @version 1.0
# @since 2026-08-27
# ================================================================

require "httparty"

class SciportApiService
  include HTTParty

  # ==============================================================
  # BASIS-URL
  # ==============================================================
  base_uri "https://www.rlp-forschung.de"

  # ==============================================================
  # AUTHENTIFIZIERUNG
  # ==============================================================
  USERNAME = "Trabelsi"
  PASSWORD = "!dpsVT67fsTB)"

  # ==============================================================
  # KONSTRUKTOR
  # ==============================================================
  def initialize
    @auth = { username: USERNAME, password: PASSWORD }
  end

  # ==============================================================
  # GET AUTH
  # ==============================================================
  # Title: Authentifizierung zurückgeben
  # Beschreibung: Gibt die Authentifizierungsdaten zurück.
  #
  # @return [Hash] Authentifizierungs-Hash
  # ==============================================================
  def auth
    @auth
  end
end
