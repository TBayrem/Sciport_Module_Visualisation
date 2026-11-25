# ============================================================
# Datei: app/models/visualization/network_graph.rb
#
# Desc:
#   Baut aus den SciPort-Tabellen das Forschungsnetzwerk für
#   die Seite "Netzwerk" (UC 1 und UC 2) und für die
#   kombinierte Ansicht (UC 5).
#
#   Knoten:
#     - Einrichtungen (Ebene 1 = oberste Einrichtung,
#       Ebene 2 = Untereinrichtung, Ebene 3 = tiefer)
#     - Personen mit mindestens einer Rolle
#
#   Kanten:
#     - hierarchy_edges   Untereinrichtung → Einrichtung
#     - affiliation_edges Person → Einrichtung (über Rollen)
#     - cooperations      Person ↔ Person (gemeinsame
#                         Projekte und Publikationen)
#     - aggregated_edges  Sammelkanten zwischen Einrichtungen
#                         für Zoomstufe 1 und 2
#
#   to_h liefert alles als Hash. Der Controller bettet ihn
#   als data-Attribut in die Seite ein; NetworkView liest
#   ihn dort aus. Es gibt keinen JSON-Endpunkt.
#
# Knoten-IDs:
#   Einrichtungen erhalten das Präfix "f", Personen "p"
#   (z. B. "f12", "p5"). So können sich IDs aus beiden
#   Tabellen im Graphen nicht überschneiden.
# ============================================================

module Visualization
  class NetworkGraph
    # Zoomstufen, für die Sammelkanten berechnet werden.
    # Auf Stufe 3 zeigt das Netzwerk die einzelnen
    # Kooperationen zwischen Personen.
    AGGREGATION_LEVELS = [ 1, 2 ].freeze

    # ----------------------------------------------------------
    # Öffentliche Schnittstelle
    # ----------------------------------------------------------

    # Alle Knoten: zuerst Einrichtungen, dann Personen.
    def nodes
      @nodes ||= facility_nodes + person_nodes
    end

    # Kanten von jeder Untereinrichtung zu ihrer
    # übergeordneten Einrichtung.
    def hierarchy_edges
      @hierarchy_edges ||= facilities.reject(&:root_facility?).map do |facility|
        { source: facility_key(facility.id), target: facility_key(facility.parent_id) }
      end
    end

    # Kanten von jeder Person zu jeder Einrichtung, in der sie
    # eine Rolle hat. Mehrere Rollen in derselben Einrichtung
    # ergeben nur eine Kante.
    def affiliation_edges
      @affiliation_edges ||= facility_ids_by_person.flat_map do |person_id, facility_ids|
        facility_ids.map do |facility_id|
          { source: person_key(person_id), target: facility_key(facility_id) }
        end
      end
    end

    # Kooperationen zwischen zwei Personen. Eine Kooperation
    # besteht, wenn beide an mindestens einem gemeinsamen
    # Projekt oder einer gemeinsamen Publikation beteiligt sind.
    #
    # Rückgabe: Array von Hashes, z. B.
    #   { source: "p1", target: "p7", projects: 2, publications: 1 }
    def cooperations
      @cooperations ||= cooperation_counts.map do |(person_a_id, person_b_id), counts|
        { source: person_key(person_a_id),
          target: person_key(person_b_id),
          projects: counts[:projects],
          publications: counts[:publications] }
      end
    end

    # Sammelkanten: genau eine Kante je Einrichtungspaar und
    # Zoomstufe. Jedes kooperierende Personenpaar zwischen den
    # beiden Einrichtungen zählt einmal; projects und
    # publications sagen, wie viele dieser Paare über Projekte
    # bzw. über Publikationen verbunden sind.
    #
    # Rückgabe: Array von Hashes, z. B.
    #   { level: 1, source: "f1", target: "f4",
    #     count: 37, projects: 30, publications: 12 }
    def aggregated_edges
      @aggregated_edges ||= AGGREGATION_LEVELS.flat_map do |level|
        aggregate_cooperations(level).map do |(source_id, target_id), totals|
          { level: level,
            source: facility_key(source_id),
            target: facility_key(target_id),
            **totals }
        end
      end
    end

    # Anzahl der Forschungsprojekte je Person, absteigend
    # sortiert. Grundlage für das Balkendiagramm
    # "Projekte pro Person". Enthält nur Personen, die im
    # Netzwerk vorkommen und mindestens ein Projekt haben.
    #
    # Rückgabe: Array von Hashes, z. B. { id: "p5", count: 7 }
    def project_counts
      @project_counts ||= project_count_rows
        .select { |person_id, _count| affiliated?(person_id) }
        .map { |person_id, count| { id: person_key(person_id), count: count } }
        .sort_by { |entry| -entry[:count] }
    end

    # Anzahl der Publikationen je Person, absteigend sortiert.
    # Ergänzt project_counts für das Balkendiagramm der
    # kombinierten Ansicht (Publikationen und Projekte je
    # Person, FA34). Gleiche Einschränkungen wie project_counts.
    #
    # Rückgabe: Array von Hashes, z. B. { id: "p5", count: 12 }
    def publication_counts
      @publication_counts ||= publication_count_rows
        .select { |person_id, _count| affiliated?(person_id) }
        .map { |person_id, count| { id: person_key(person_id), count: count } }
        .sort_by { |entry| -entry[:count] }
    end

    # Gesamtes Netzwerk als Hash für die View.
    def to_h
      {
        nodes: nodes,
        hierarchy_edges: hierarchy_edges,
        affiliation_edges: affiliation_edges,
        cooperations: cooperations,
        aggregated_edges: aggregated_edges,
        project_counts: project_counts,
        publication_counts: publication_counts
      }
    end

    private

    # ----------------------------------------------------------
    # Knoten
    # ----------------------------------------------------------

    def facility_nodes
      facilities.map do |facility|
        { id: facility_key(facility.id),
          type: "facility",
          name: facility.display_name,
          facility_type: facility.facility_type,
          level: level_of(facility),
          parent: facility.parent_id && facility_key(facility.parent_id),
          root: facility_key(facility.root_facility.id),
          second_level: facility_key(facility.second_level_facility.id) }
      end
    end

    def person_nodes
      people.map do |person|
        { id: person_key(person.id),
          type: "person",
          name: person.display_name,
          field_of_research: person.field_of_research,
          facilities: facility_ids_by_person[person.id].map { |id| facility_key(id) } }
      end
    end

    # Hierarchieebene einer Einrichtung:
    # 1 = oberste, 2 = direkt darunter, 3 = alle tieferen.
    def level_of(facility)
      return 1 if facility.root_facility?
      return 2 if facility.second_level_facility == facility

      3
    end

    # ----------------------------------------------------------
    # Kooperationen
    # ----------------------------------------------------------

    # Gemeinsame Projekte und Publikationen je Personenpaar.
    # Berücksichtigt nur Personen mit Rolle, da nur sie im
    # Netzwerk als Knoten erscheinen.
    #
    # Rückgabe: Hash { [person_a_id, person_b_id] =>
    #                  { projects: n, publications: m } }
    def cooperation_counts
      @cooperation_counts ||= begin
        projects     = shared_projects
        publications = shared_publications

        (projects.keys | publications.keys)
          .select { |pair| pair.all? { |person_id| affiliated?(person_id) } }
          .index_with do |pair|
            { projects: projects.fetch(pair, 0), publications: publications.fetch(pair, 0) }
          end
      end
    end

    # Anzahl gemeinsamer Projekte je Personenpaar.
    def shared_projects
      count_shared("people_research_projects", "research_project_id")
    end

    # Anzahl gemeinsamer Publikationen je Personenpaar.
    def shared_publications
      count_shared("people_publications", "publication_id")
    end

    # Zählt per Self-Join auf einer Verknüpfungstabelle, wie
    # viele Einträge zwei Personen gemeinsam haben. Durch
    # a.person_id < b.person_id wird jedes Paar nur einmal
    # gezählt. Tabellen- und Spaltennamen sind feste Werte
    # aus diesem Code, keine Nutzereingaben.
    #
    # Rückgabe: Hash { [person_a_id, person_b_id] => Anzahl }
    def count_shared(join_table, item_column)
      sql = <<~SQL
        SELECT a.person_id, b.person_id, COUNT(*)
        FROM #{join_table} a
        JOIN #{join_table} b
          ON a.#{item_column} = b.#{item_column}
         AND a.person_id < b.person_id
        GROUP BY a.person_id, b.person_id
      SQL

      connection.select_rows(sql).to_h do |person_a_id, person_b_id, count|
        [ [ person_a_id.to_i, person_b_id.to_i ], count.to_i ]
      end
    end

    # Fasst die Kooperationen zu Einrichtungspaaren der
    # gegebenen Ebene zusammen. Kooperationen innerhalb
    # derselben Einrichtung erzeugen keine Sammelkante.
    #
    # Rückgabe: Hash { [facility_id_a, facility_id_b] =>
    #                  { count:, projects:, publications: } }
    def aggregate_cooperations(level)
      totals = Hash.new { |hash, pair| hash[pair] = { count: 0, projects: 0, publications: 0 } }

      cooperation_counts.each do |(person_a_id, person_b_id), counts|
        unit_pairs(person_a_id, person_b_id, level).each do |pair|
          totals[pair][:count] += 1
          totals[pair][:projects] += 1 if counts[:projects].positive?
          totals[pair][:publications] += 1 if counts[:publications].positive?
        end
      end

      totals
    end

    # Alle Einrichtungspaare der Ebene, die zwei Personen
    # verbinden, jedes Paar einmal und ohne Paare einer
    # Einrichtung mit sich selbst.
    def unit_pairs(person_a_id, person_b_id, level)
      units_of(person_a_id, level).product(units_of(person_b_id, level))
                                  .reject { |unit_a, unit_b| unit_a == unit_b }
                                  .map(&:minmax)
                                  .uniq
    end

    # Einrichtungen einer Person auf der gegebenen Ebene:
    # Ebene 1 → oberste Einrichtungen, Ebene 2 → Untereinrichtungen.
    def units_of(person_id, level)
      facility_ids_by_person[person_id].filter_map do |facility_id|
        facility = facilities_by_id[facility_id]
        next unless facility

        level == 1 ? facility.root_facility.id : facility.second_level_facility.id
      end.uniq
    end

    # ----------------------------------------------------------
    # Daten aus der Datenbank
    # ----------------------------------------------------------

    # Alle Einrichtungen, einmal geladen. Die parent-Verknüpfung
    # wird im Speicher gesetzt, damit root_facility und
    # second_level_facility keine weiteren Abfragen auslösen.
    def facilities
      @facilities ||= Facility.alphabetical.to_a.tap do |all|
        by_id = all.index_by(&:id)
        all.each { |facility| facility.association(:parent).target = by_id[facility.parent_id] }
      end
    end

    def facilities_by_id
      @facilities_by_id ||= facilities.index_by(&:id)
    end

    # Alle Personen mit mindestens einer Rolle. Personen ohne
    # Einrichtung lassen sich im Netzwerk nicht verorten.
    def people
      @people ||= Person.where(id: Role.select(:person_id)).alphabetical.to_a
    end

    # Hash { person_id => [facility_id, ...] } aus den Rollen.
    def facility_ids_by_person
      @facility_ids_by_person ||= Role.distinct.pluck(:person_id, :facility_id)
                                      .group_by(&:first)
                                      .transform_values { |rows| rows.map(&:last) }
    end

    def affiliated?(person_id)
      facility_ids_by_person.key?(person_id)
    end

    # Zeilen [person_id, Anzahl Projekte] aus der
    # Verknüpfungstabelle Person–Projekt.
    def project_count_rows
      connection.select_rows(<<~SQL).map { |person_id, count| [ person_id.to_i, count.to_i ] }
        SELECT person_id, COUNT(*)
        FROM people_research_projects
        GROUP BY person_id
      SQL
    end

    # Zeilen [person_id, Anzahl Publikationen] aus der
    # Verknüpfungstabelle Person–Publikation.
    def publication_count_rows
      connection.select_rows(<<~SQL).map { |person_id, count| [ person_id.to_i, count.to_i ] }
        SELECT person_id, COUNT(*)
        FROM people_publications
        GROUP BY person_id
      SQL
    end

    def connection
      ActiveRecord::Base.connection
    end

    # ----------------------------------------------------------
    # Knoten-IDs
    # ----------------------------------------------------------

    def facility_key(id)
      "f#{id}"
    end

    def person_key(id)
      "p#{id}"
    end
  end
end
