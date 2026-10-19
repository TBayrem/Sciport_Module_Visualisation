
# ============================================================
# Controller: VisualizationsController
#
# Desc:
# Bereitet die Daten für die Netzwerkvisualisierung
# und die thematische Visualisierung auf.
#
# Anwendungsfälle:
# - Forschungsnetzwerk anzeigen
# - Forschende nach Einrichtungen filtern
# - Forschende nach Namen suchen
# - Institutionelle Zugehörigkeiten darstellen
# - Thematische Visualisierung aufrufen
# ============================================================

class VisualizationsController < ApplicationController
  # ----------------------------------------------------------
  # 1. Konfiguration
  #
  # Die Anzahl der gleichzeitig angezeigten Forschenden
  # wird begrenzt, damit das D3-Netzwerk bei umfangreichen
  # Datenmengen übersichtlich und bedienbar bleibt.
  # ----------------------------------------------------------

  MAX_PEOPLE = 150


  # ----------------------------------------------------------
  # 2. Öffentliche Actions
  # ----------------------------------------------------------

  # Title: network
  #
  # Desc:
  # Bereitet die Netzwerkvisualisierung vor.
  # Die Methode lädt die verfügbaren Einrichtungen,
  # filtert Forschende und erzeugt die Datenstruktur
  # für die Darstellung mit D3.
  #
  # Parameters:
  # - params[:facility_id]: optionale Einrichtungs-ID
  # - params[:q]: optionaler Suchbegriff
  #
  # Returns:
  # - Stellt die Daten für network.html.erb bereit.
  def network
    @facilities = Facility
      .where.not(external_id: nil)
      .order(:name, :id)
      .pluck(:id, :name)

    @selected_facility_id = params[:facility_id].to_s
    @search_query = params[:q].to_s.strip

    people_scope = filtered_people

    @total_people = people_scope.count

    @people = people_scope
      .order(:last_name, :first_name, :id)
      .limit(MAX_PEOPLE)
      .to_a

    @limited = @total_people > MAX_PEOPLE

    @network_data = {
      nodes: build_network_nodes,
      links: build_network_links
    }
  end


  # Title: themes
  #
  # Desc:
  # Bereitet den Einstiegspunkt für die thematische
  # Visualisierung vor.
  #
  # Die Cluster- und Koordinatendaten werden später
  # aus tatsächlichen Analyseergebnissen eingebunden.
  #
  # Parameters:
  # - Keine.
  #
  # Returns:
  # - Stellt die Daten für themes.html.erb bereit.
  def themes
    @theme_data = {
      nodes: [],
      clusters: []
    }
  end


  private


  # ----------------------------------------------------------
  # 3. Filterung der Forschenden
  # ----------------------------------------------------------

  # Title: filtered_people
  #
  # Desc:
  # Filtert Forschende anhand einer Einrichtung
  # und/oder eines Suchbegriffs.
  #
  # Mehrfach vorhandene Rollen werden durch distinct
  # berücksichtigt, ohne Personen doppelt anzuzeigen.
  #
  # Parameters:
  # - @selected_facility_id: ausgewählte Einrichtung
  # - @search_query: eingegebener Suchbegriff
  #
  # Returns:
  # - ActiveRecord::Relation mit passenden Personen.
  def filtered_people
    people = Person.all

    if @selected_facility_id.present?
      people = people
        .joins(:roles)
        .where(roles: { facility_id: @selected_facility_id })
        .distinct
    end

    if @search_query.present?
      search_term = "%#{Person.sanitize_sql_like(@search_query)}%"

      people = people.where(
        "people.first_name ILIKE :query OR " \
        "people.last_name ILIKE :query OR " \
        "CONCAT_WS(' ', people.first_name, people.last_name) ILIKE :query",
        query: search_term
      )
    end

    people
  end


  # ----------------------------------------------------------
  # 4. Erstellung der Netzwerkknoten
  # ----------------------------------------------------------

  # Title: build_network_nodes
  #
  # Desc:
  # Erstellt die Knoten für Forschende und Einrichtungen.
  #
  # Die Präfixe person- und facility- sorgen dafür,
  # dass die IDs der unterschiedlichen Knotentypen
  # eindeutig bleiben.
  #
  # Parameters:
  # - @people: aktuell ausgewählte Forschende
  #
  # Returns:
  # - Array mit Personen- und Einrichtungsknoten.
  def build_network_nodes
    person_nodes = @people.map do |person|
      {
        id: "person-#{person.id}",
        type: "person",
        name: person.full_name,
        title: person.title,
        field_of_research: person.field_of_research
      }
    end

    facility_nodes = network_facilities.map do |facility|
      {
        id: "facility-#{facility.id}",
        type: "facility",
        name: facility.display_name
      }
    end

    person_nodes + facility_nodes
  end


  # ----------------------------------------------------------
  # 5. Erstellung der Netzwerkverbindungen
  # ----------------------------------------------------------

  # Title: build_network_links
  #
  # Desc:
  # Erstellt institutionelle Verbindungen zwischen
  # Forschenden und ihren zugeordneten Einrichtungen.
  #
  # Die Kanten werden als affiliation gekennzeichnet,
  # weil eine gemeinsame Einrichtung allein noch
  # keine wissenschaftliche Kooperation nachweist.
  #
  # Mehrfache Rollen derselben Person an derselben
  # Einrichtung erzeugen keine doppelten Kanten.
  #
  # Parameters:
  # - @people: aktuell ausgewählte Forschende
  #
  # Returns:
  # - Array mit eindeutigen institutionellen Kanten.
  def build_network_links
    person_ids = @people.map(&:id)

    Role
      .where(person_id: person_ids)
      .distinct
      .pluck(:person_id, :facility_id)
      .map do |person_id, facility_id|
        {
          source: "person-#{person_id}",
          target: "facility-#{facility_id}",
          type: "affiliation"
        }
      end
  end


  # ----------------------------------------------------------
  # 6. Ermittlung der beteiligten Einrichtungen
  # ----------------------------------------------------------

  # Title: network_facilities
  #
  # Desc:
  # Ermittelt alle Einrichtungen, die über Rollen
  # mit den aktuell angezeigten Forschenden
  # verbunden sind.
  #
  # Dadurch werden nur relevante Einrichtungen
  # als Knoten an die Visualisierung übergeben.
  #
  # Parameters:
  # - @people: aktuell ausgewählte Forschende
  #
  # Returns:
  # - ActiveRecord::Relation mit Einrichtungen.
  def network_facilities
    person_ids = @people.map(&:id)

    Facility
      .joins(:roles)
      .where(roles: { person_id: person_ids })
      .distinct
      .order(:name, :id)
  end
end
