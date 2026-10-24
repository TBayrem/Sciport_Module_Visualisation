
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
# - Einrichtungshierarchien bereitstellen
# - Thematische Visualisierung aufrufen
#
# Besonderheit:
# Im Netzwerk werden nur Personen und Haupteinrichtungen
# als Knoten dargestellt.
#
# Untereinrichtungen bleiben in der Datenbank erhalten
# und werden für Tooltips und Detailinformationen
# als Hierarchieinformationen übergeben.
# ============================================================

class VisualizationsController < ApplicationController
  # ----------------------------------------------------------
  # 1. Konfiguration
  #
  # Die maximale Anzahl angezeigter Forschender wird
  # begrenzt, damit das Netzwerk bedienbar bleibt.
  # ----------------------------------------------------------

  MAX_PEOPLE = 150


  # ----------------------------------------------------------
  # 2. Öffentliche Actions
  # ----------------------------------------------------------

  # Title: network
  #
  # Desc:
  # Lädt die verfügbaren Einrichtungen, filtert
  # Forschende und erstellt die Netzwerkdaten.
  #
  # Parameters:
  # - params[:facility_id]: optionale Einrichtungs-ID
  # - params[:q]: optionaler Suchbegriff
  #
  # Returns:
  # - Stellt Daten für network.html.erb bereit.
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

    # Einmalige Vorbereitung der Zugehörigkeiten.
    # So müssen die Rollen und Haupteinrichtungen
    # nicht für jede Ausgabemethode erneut ermittelt werden.
    prepare_network_affiliations

    @network_data = {
      nodes: build_network_nodes,
      links: build_network_links
    }
  end


  # Title: themes
  #
  # Desc:
  # Bereitet die thematische Visualisierung vor.
  #
  # Die Analyseergebnisse werden später eingebunden.
  #
  # Parameters:
  # - Keine.
  #
  # Returns:
  # - Stellt Daten für themes.html.erb bereit.
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
  # Filtert Forschende nach Einrichtung und/oder Namen.
  #
  # Die bisherige Filterlogik bleibt erhalten.
  # Eine ausgewählte Untereinrichtung filtert Personen,
  # die dort unmittelbar eine Rolle besitzen.
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
  # 4. Vorbereitung der institutionellen Zugehörigkeiten
  # ----------------------------------------------------------

  # Title: prepare_network_affiliations
  #
  # Desc:
  # Lädt die Einrichtungen und die Rollen der aktuell
  # angezeigten Forschenden.
  #
  # Für jede Einrichtung wird später die oberste
  # Haupteinrichtung bestimmt.
  #
  # Die Daten werden innerhalb des aktuellen Requests
  # zwischengespeichert, um wiederholte Abfragen zu vermeiden.
  #
  # Parameters:
  # - @people: aktuell ausgewählte Forschende
  #
  # Returns:
  # - Kein expliziter Rückgabewert.
  def prepare_network_affiliations
    person_ids = @people.map(&:id)

    # Alle Einrichtungen werden geladen, damit auch
    # mehrstufige Hierarchien vollständig aufgebaut
    # werden können.
    @network_facilities_by_id = Facility.all.index_by(&:id)

    # Die Rollen der angezeigten Personen werden
    # gesammelt und nach Personen-ID gruppiert.
    @network_roles_by_person = Role
      .where(person_id: person_ids)
      .pluck(:person_id, :facility_id)
      .group_by(&:first)

    # Zwischenspeicher für bereits ermittelte
    # Haupteinrichtungen und Einrichtungspfade.
    @root_facility_cache = {}
    @facility_path_cache = {}
  end


  # ----------------------------------------------------------
  # 5. Erstellung der Netzwerkknoten
  # ----------------------------------------------------------

  # Title: build_network_nodes
  #
  # Desc:
  # Erstellt Personen und Haupteinrichtungen
  # als sichtbare Netzwerkknoten.
  #
  # Personen erhalten ihre Einrichtungspfade.
  # Haupteinrichtungen erhalten einen Hierarchiebaum.
  #
  # Parameters:
  # - @people: aktuell ausgewählte Forschende
  #
  # Returns:
  # - Array mit Personen- und Haupteinrichtungsknoten.
  def build_network_nodes
    person_nodes = @people.map do |person|
      {
        id: "person-#{person.id}",
        type: "person",
        name: person.full_name,
        title: person.title,
        field_of_research: person.field_of_research,

        # Alle tatsächlichen organisatorischen
        # Zugehörigkeiten dieser Person.
        facility_paths: person_facility_paths(person)
      }
    end

    facility_nodes = network_facilities.map do |facility|
      {
        id: "facility-#{facility.id}",
        type: "facility",
        name: facility.display_name,

        # Vollständige Hierarchie der Haupteinrichtung.
        # Untereinrichtungen werden dadurch nicht
        # als eigene Netzwerkknoten benötigt.
        hierarchy: facility_hierarchy(facility)
      }
    end

    person_nodes + facility_nodes
  end


  # ----------------------------------------------------------
  # 6. Erstellung der Netzwerkverbindungen
  # ----------------------------------------------------------

  # Title: build_network_links
  #
  # Desc:
  # Verbindet jede Person direkt mit den zugehörigen
  # Haupteinrichtungen.
  #
  # Auch bei einer Rolle an einer Untereinrichtung
  # wird die Verbindung zur obersten Einrichtung gelegt.
  #
  # Doppelte Kanten werden entfernt.
  #
  # Parameters:
  # - @people: aktuell ausgewählte Forschende
  #
  # Returns:
  # - Array eindeutiger institutioneller Kanten.
  def build_network_links
    links = []

    @people.each do |person|
      facility_ids_for_person(person.id).each do |facility_id|
        facility = @network_facilities_by_id[facility_id]
        root = root_facility_for(facility)

        next unless root

        links << {
          source: "person-#{person.id}",
          target: "facility-#{root.id}",
          type: "affiliation"
        }
      end
    end

    links.uniq
  end


  # ----------------------------------------------------------
  # 7. Einrichtungen einer Person ermitteln
  # ----------------------------------------------------------

  # Title: facility_ids_for_person
  #
  # Desc:
  # Ermittelt die eindeutigen Einrichtungen, denen
  # eine Person über ihre Rollen zugeordnet ist.
  #
  # Parameters:
  # - person_id: ID der Person
  #
  # Returns:
  # - Array eindeutiger Einrichtungs-IDs.
  def facility_ids_for_person(person_id)
    (@network_roles_by_person[person_id] || [])
      .map(&:last)
      .compact
      .uniq
  end


  # ----------------------------------------------------------
  # 8. Beteiligte Haupteinrichtungen ermitteln
  # ----------------------------------------------------------

  # Title: network_facilities
  #
  # Desc:
  # Ermittelt ausschließlich die Haupteinrichtungen,
  # denen die angezeigten Personen zugeordnet sind.
  #
  # Parameters:
  # - @people: aktuell ausgewählte Forschende
  #
  # Returns:
  # - Array eindeutiger Haupteinrichtungen.
  def network_facilities
    roots = @people.flat_map do |person|
      facility_ids_for_person(person.id).filter_map do |facility_id|
        facility = @network_facilities_by_id[facility_id]

        root_facility_for(facility)
      end
    end

    roots
      .uniq(&:id)
      .sort_by { |facility| [ facility.display_name, facility.id ] }
  end


  # ----------------------------------------------------------
  # 9. Haupteinrichtung bestimmen
  # ----------------------------------------------------------

  # Title: root_facility_for
  #
  # Desc:
  # Durchläuft die übergeordneten Einrichtungen
  # bis zur obersten Hierarchieebene.
  #
  # Beispiel:
  # Universität -> Fachbereich -> Institut
  #
  # Für das Institut wird die Universität ermittelt.
  #
  # Eine Zykluserkennung verhindert Endlosschleifen.
  #
  # Parameters:
  # - facility: Ausgangseinrichtung
  #
  # Returns:
  # - Haupteinrichtung oder nil.
  def root_facility_for(facility)
    return nil unless facility

    # Bereits ermittelte Ergebnisse wiederverwenden.
    if @root_facility_cache.key?(facility.id)
      return @root_facility_cache[facility.id]
    end

    current = facility
    visited = Set.new

    while current
      # Zyklen sind keine gültigen Hierarchien.
      if visited.include?(current.id)
        @root_facility_cache[facility.id] = nil
        return nil
      end

      visited.add(current.id)

      if current.parent_id.nil?
        @root_facility_cache[facility.id] = current
        return current
      end

      # Die Elternbeziehung wird anhand der
      # bereits geladenen Einrichtungen aufgelöst.
      current = @network_facilities_by_id[current.parent_id]
    end

    # Fehlende Eltern-Einrichtungen werden nicht
    # fälschlich als Haupteinrichtungen behandelt.
    @root_facility_cache[facility.id] = nil
    nil
  end


  # ----------------------------------------------------------
  # 10. Vollständige Einrichtungshierarchie aufbauen
  # ----------------------------------------------------------

  # Title: facility_hierarchy
  #
  # Desc:
  # Erstellt einen verschachtelten Baum aus einer
  # Haupteinrichtung und allen Untereinrichtungen.
  #
  # Beispiel:
  # Universität
  #   Fachbereich
  #     Institut
  #
  # Parameters:
  # - facility: aktuelle Einrichtung
  # - visited: bereits besuchte Einrichtungen
  #
  # Returns:
  # - Hash mit id, name und children oder nil.
  def facility_hierarchy(facility, visited = Set.new)
    return nil unless facility
    return nil if visited.include?(facility.id)

    current_visited = visited.dup.add(facility.id)

    # Untereinrichtungen anhand der geladenen Daten
    # ermitteln, damit keine zusätzlichen SQL-Abfragen
    # pro Hierarchieebene notwendig sind.
    children = @network_facilities_by_id.values
      .select { |item| item.parent_id == facility.id }
      .sort_by { |item| [ item.display_name, item.id ] }
      .filter_map do |child|
        facility_hierarchy(child, current_visited)
      end

    {
      id: facility.id,
      name: facility.display_name,
      children: children
    }
  end


  # ----------------------------------------------------------
  # 11. Einrichtungspfad einer Person aufbauen
  # ----------------------------------------------------------

  # Title: person_facility_paths
  #
  # Desc:
  # Liefert für jede institutionelle Zugehörigkeit
  # den vollständigen Pfad von der Haupteinrichtung
  # bis zur tatsächlich zugeordneten Einrichtung.
  #
  # Mehrfache identische Pfade werden entfernt.
  #
  # Parameters:
  # - person: ausgewählte Person
  #
  # Returns:
  # - Array mit eindeutigen Einrichtungspfaden.
  def person_facility_paths(person)
    facility_ids_for_person(person.id).filter_map do |facility_id|
      facility = @network_facilities_by_id[facility_id]

      facility_path_for(facility)
    end.uniq
  end


  # ----------------------------------------------------------
  # 12. Vollständigen Pfad einer Einrichtung bestimmen
  # ----------------------------------------------------------

  # Title: facility_path_for
  #
  # Desc:
  # Durchläuft die Elternbeziehungen und erstellt
  # einen Pfad in der Reihenfolge:
  #
  # Haupteinrichtung -> Untereinrichtung -> Einrichtung.
  #
  # Ungültige oder zyklische Hierarchien werden
  # nicht ausgegeben.
  #
  # Parameters:
  # - facility: Ausgangseinrichtung
  #
  # Returns:
  # - Array mit Einrichtungsebenen oder nil.
  def facility_path_for(facility)
    return nil unless facility

    if @facility_path_cache.key?(facility.id)
      return @facility_path_cache[facility.id]
    end

    path = []
    current = facility
    visited = Set.new

    while current
      if visited.include?(current.id)
        @facility_path_cache[facility.id] = nil
        return nil
      end

      visited.add(current.id)

      path.unshift(
        {
          id: current.id,
          name: current.display_name
        }
      )

      # Die oberste Einrichtung ist erreicht.
      if current.parent_id.nil?
        @facility_path_cache[facility.id] = path
        return path
      end

      current = @network_facilities_by_id[current.parent_id]
    end

    # Bei einer fehlenden Eltern-Einrichtung
    # wird kein unvollständiger Pfad zurückgegeben.
    @facility_path_cache[facility.id] = nil
    nil
  end
end
