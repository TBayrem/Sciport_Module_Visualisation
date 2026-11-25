# ============================================================
# Rake Task: research_projects:import
#
# Desc:
# Importiert Forschungsprojekte aus rlp-forschung.de und
# verknüpft sie mit Personen und Einrichtungen.
#
# Ablauf:
# 1. Für jede Person aus der Datenbank wird ihre Projektliste
#    geladen (/public/people/:id/research_projects.xml).
#    Jedes Projekt wird importiert und mit der Person verknüpft.
# 2. Die im Projekt-XML genannten Personen (<people>) werden
#    ebenfalls mit dem Projekt verknüpft.
# 3. Für jede Einrichtung wird ihre Projektliste geladen
#    (/public/facilities/:id/research_projects.xml) und die
#    Einrichtung mit den Projekten verknüpft.
#
# Jedes Projekt wird pro Lauf nur einmal abgerufen. Ein
# erneuter Lauf aktualisiert bestehende Projekte über ihre
# external_id, statt Duplikate anzulegen.
#
# Voraussetzung:
# - bin/rails facilities:import
# - bin/rails people:import
#
# Aufruf:
# - bin/rails research_projects:import
# ============================================================

namespace :research_projects do
  desc "Import research projects and link them to people and facilities from rlp-forschung.de"
  task import: :environment do
    require "net/http"
    require "nokogiri"
    require "uri"
    require "set"

    BASE_URL = "https://www.rlp-forschung.de".freeze
    RESEARCH_PROJECTS_URL = "#{BASE_URL}/public/research_projects".freeze

    USERNAME = "Trabelsi"
    PASSWORD = "!dpsVT67fsTB)"

    class ResearchProjectImporter
      XML_NAMESPACE = "https://www.rlp-forschung.de/ws/1_0".freeze
      XLINK_NAMESPACES = [
        "http://www.w3.org/1999/xlink",
        "https://www.w3.org/1999/xlink"
      ].freeze
      MAX_PAGES = 1000

      def initialize(base_url:, research_projects_url:, username:, password:)
        @base_url = base_url
        @research_projects_url = research_projects_url
        @username = username
        @password = password
        @imported_projects = {}
      end

      # /*
      # Title: import
      #
      # Desc:
      # Startet den gesamten Import: zuerst über die
      # Projektlisten der Personen, danach über die
      # Projektlisten der Einrichtungen.
      # */
      def import
        import_from_people
        import_from_facilities

        puts "Research project import finished: #{@imported_projects.values.compact.size} projects."
      end

      private

      # /*
      # Title: import_from_people
      #
      # Desc:
      # Lädt für jede Person die Projektliste, importiert
      # die Projekte und verknüpft sie mit der Person.
      # Ein Fehler bei einer Person stoppt den Import nicht.
      # */
      def import_from_people
        total = Person.count

        Person.where.not(external_id: nil).find_each.with_index(1) do |person, index|
          url = "#{@base_url}/public/people/#{person.external_id}/research_projects.xml"

          each_list_entry(url, "research-project") do |entry_node|
            project = project_for(entry_node)
            link(person.research_projects, project)
          end

          puts "Progress people: #{index}/#{total}" if (index % 100).zero?
        rescue StandardError => e
          warn "Error importing research projects of person #{person.external_id}: #{e.message}"
        end
      end

      # /*
      # Title: import_from_facilities
      #
      # Desc:
      # Lädt für jede Einrichtung die Projektliste und
      # verknüpft die Einrichtung mit den Projekten.
      # Noch unbekannte Projekte werden dabei importiert.
      # */
      def import_from_facilities
        total = Facility.count

        Facility.where.not(external_id: nil).find_each.with_index(1) do |facility, index|
          url = "#{@base_url}/public/facilities/#{facility.external_id}/research_projects.xml"

          each_list_entry(url, "research-project") do |entry_node|
            project = project_for(entry_node)
            link(facility.research_projects, project)
          end

          puts "Progress facilities: #{index}/#{total}" if (index % 100).zero?
        rescue StandardError => e
          warn "Error importing research projects of facility #{facility.external_id}: #{e.message}"
        end
      end

      # /*
      # Title: project_for
      #
      # Desc:
      # Liefert das Projekt zu einem Listeneintrag. Ein Projekt
      # wird pro Lauf nur einmal vom Webservice geladen.
      #
      # Returns:
      # - ResearchProject oder nil, wenn der Import fehlschlug.
      # */
      def project_for(entry_node)
        href = href_of(entry_node)
        return nil unless href

        external_id = external_id_from_url(href)
        return @imported_projects[external_id] if @imported_projects.key?(external_id)

        @imported_projects[external_id] = import_project(external_id)
      end

      # /*
      # Title: import_project
      #
      # Desc:
      # Lädt ein einzelnes Projekt (/public/research_projects/:id.xml),
      # speichert es und verknüpft die genannten Personen.
      #
      # Returns:
      # - ResearchProject oder nil bei Fehler.
      # */
      def import_project(external_id)
        document = fetch_xml("#{@research_projects_url}/#{external_id}.xml")

        unless document
          warn "Skipping research project #{external_id}: not found"
          return nil
        end

        project_node = document.at_xpath("/ws:research-project", "ws" => XML_NAMESPACE)

        unless project_node
          warn "Skipping research project #{external_id}: invalid XML"
          return nil
        end

        title = text(project_node, "title")

        if title.blank?
          warn "Skipping research project #{external_id}: no title"
          return nil
        end

        project = ResearchProject.find_or_initialize_by(external_id: external_id)

        project.title = title
        project.description = text(project_node, "description")
        project.keywords = text(project_node, "keywords")
        project.start_date = parse_date(text(project_node, "start-date"))
        project.end_date = parse_date(text(project_node, "end-date"))
        project.save!

        link_people(project, project_node)

        puts "Imported research project #{external_id}: #{project.title}"
        project
      rescue StandardError => e
        warn "Error importing research project #{external_id}: #{e.message}"
        nil
      end

      # /*
      # Title: link_people
      #
      # Desc:
      # Verknüpft das Projekt mit allen Personen aus <people>,
      # die bereits in der Datenbank existieren.
      # */
      def link_people(project, project_node)
        project_node.xpath("ws:people/ws:person", "ws" => XML_NAMESPACE).each do |person_node|
          href = href_of(person_node)
          next unless href

          person = Person.find_by(external_id: external_id_from_url(href))
          link(project.people, person)
        end
      end

      # /*
      # Title: link
      #
      # Desc:
      # Fügt einen Datensatz einer HABTM-Beziehung hinzu,
      # falls er dort noch nicht vorhanden ist.
      # */
      def link(collection, record)
        return if record.nil?
        return if collection.exists?(record.id)

        collection << record
      rescue ActiveRecord::RecordNotUnique
        nil
      end

      # /*
      # Title: each_list_entry
      #
      # Desc:
      # Läuft durch eine seitenweise Liste des Webservice
      # (<next-page>) und liefert jeden Eintrag an den Block.
      # Bereits besuchte Seiten werden nicht erneut geladen.
      # */
      def each_list_entry(url, element)
        visited = Set.new
        pages = 0

        while url && visited.add?(url) && pages < MAX_PAGES
          pages += 1
          document = fetch_xml(url)
          return unless document

          document.root.xpath("ws:#{element}", "ws" => XML_NAMESPACE).each do |entry_node|
            yield entry_node
          end

          next_node = document.root.at_xpath("ws:next-page", "ws" => XML_NAMESPACE)
          next_href = next_node && href_of(next_node)
          url = next_href.present? ? normalize_url(next_href) : nil
        end
      end

      def fetch_xml(url)
        uri = URI.parse(url)

        request = Net::HTTP::Get.new(uri)
        request.basic_auth(@username, @password)
        request["Accept"] = "application/xml"

        response = Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: 10,
          read_timeout: 30
        ) do |http|
          http.request(request)
        end

        return nil if response.code == "404"

        unless response.is_a?(Net::HTTPSuccess)
          raise "HTTP #{response.code} while fetching #{url}"
        end

        Nokogiri::XML(response.body)
      end

      def href_of(node)
        XLINK_NAMESPACES.each do |namespace|
          value = node.attribute_with_ns("href", namespace)&.value
          return value if value.present?
        end

        node["href"].presence
      end

      # Links im XML können auf andere Hosts zeigen (z. B. 127.0.0.1)
      # oder Zeilenumbrüche enthalten. Verwendet wird nur Pfad + Query.
      def normalize_url(href)
        uri = URI.parse(href.gsub(/\s+/, ""))
        query = uri.query ? "?#{uri.query}" : ""

        "#{@base_url}#{uri.path}#{query}"
      end

      # external_id bleibt ein String (Spaltentyp string),
      # damit auch IDs wie "hans_meier" funktionieren.
      def external_id_from_url(url)
        URI.parse(url.gsub(/\s+/, "")).path.split("/").last.to_s.delete_suffix(".xml")
      end

      def text(node, element)
        node.at_xpath(
          "ws:#{element}",
          "ws" => XML_NAMESPACE
        )&.text&.strip.presence
      end

      # Akzeptiert "2010-03-01", "01.03.2010" und reine Jahreszahlen ("2010").
      def parse_date(value)
        return nil if value.blank?
        return Date.new(value.to_i, 1, 1) if value.match?(/\A\d{4}\z/)

        Date.parse(value)
      rescue Date::Error
        nil
      end
    end

    ResearchProjectImporter.new(
      base_url: BASE_URL,
      research_projects_url: RESEARCH_PROJECTS_URL,
      username: USERNAME,
      password: PASSWORD
    ).import
  end
end
