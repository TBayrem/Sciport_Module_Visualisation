# ============================================================
# Rake Task: publications:import
#
# Desc:
# Importiert Publikationen aus rlp-forschung.de mit ihrer
# Autorenliste und verknüpft sie mit Personen, Einrichtungen
# und Forschungsprojekten.
#
# Ablauf:
# 1. Für jede Person aus der Datenbank wird ihre
#    Publikationsliste geladen (/public/people/:id/publications.xml).
#    Jede Publikation wird importiert und mit der Person verknüpft.
# 2. Aus dem Publikations-XML werden übernommen:
#    - Titel, Abstract, Erscheinungsjahr, persistenter Identifier
#    - die Autorenliste (<authors>) als Authorship-Einträge
#    - die Einrichtungen (<facilities>)
#    - die Forschungsprojekte (<research-projects>)
#
# Jede Publikation wird pro Lauf nur einmal abgerufen. Ein
# erneuter Lauf aktualisiert bestehende Publikationen über
# ihre external_id und ersetzt ihre Autorenliste.
#
# Voraussetzung:
# - bin/rails facilities:import
# - bin/rails people:import
# - bin/rails research_projects:import
#
# Aufruf:
# - bin/rails publications:import
# ============================================================

namespace :publications do
  desc "Import publications with authors and link them to people, facilities and research projects from rlp-forschung.de"
  task import: :environment do
    require "net/http"
    require "nokogiri"
    require "uri"
    require "set"

    BASE_URL = "https://www.rlp-forschung.de".freeze
    PUBLICATIONS_URL = "#{BASE_URL}/public/publications".freeze

USERNAME = ENV.fetch("SCIPORT_USERNAME")
PASSWORD = ENV.fetch("SCIPORT_PASSWORD")

    class PublicationImporter
      XML_NAMESPACE = "https://www.rlp-forschung.de/ws/1_0".freeze
      XLINK_NAMESPACES = [
        "http://www.w3.org/1999/xlink",
        "https://www.w3.org/1999/xlink"
      ].freeze
      MAX_PAGES = 1000

      def initialize(base_url:, publications_url:, username:, password:)
        @base_url = base_url
        @publications_url = publications_url
        @username = username
        @password = password
        @imported_publications = {}
      end

      # /*
      # Title: import
      #
      # Desc:
      # Startet den Import über die Publikationslisten
      # aller Personen aus der Datenbank.
      # */
      def import
        total = Person.count

        Person.where.not(external_id: nil).find_each.with_index(1) do |person, index|
          url = "#{@base_url}/public/people/#{person.external_id}/publications.xml"

          each_list_entry(url, "publication") do |entry_node|
            publication = publication_for(entry_node)
            link(person.publications, publication)
          end

          puts "Progress people: #{index}/#{total}" if (index % 100).zero?
        rescue StandardError => e
          warn "Error importing publications of person #{person.external_id}: #{e.message}"
        end

        puts "Publication import finished: #{@imported_publications.values.compact.size} publications."
      end

      private

      # /*
      # Title: publication_for
      #
      # Desc:
      # Liefert die Publikation zu einem Listeneintrag. Eine
      # Publikation wird pro Lauf nur einmal geladen.
      #
      # Returns:
      # - Publication oder nil, wenn der Import fehlschlug.
      # */
      def publication_for(entry_node)
        href = href_of(entry_node)
        return nil unless href

        external_id = external_id_from_url(href)
        return @imported_publications[external_id] if @imported_publications.key?(external_id)

        @imported_publications[external_id] = import_publication(external_id)
      end

      # /*
      # Title: import_publication
      #
      # Desc:
      # Lädt eine einzelne Publikation (/public/publications/:id.xml)
      # und speichert sie zusammen mit Autorenliste, Einrichtungen
      # und Forschungsprojekten in einer Transaktion. Schlägt ein
      # Teil fehl, wird nichts von dieser Publikation gespeichert.
      #
      # Returns:
      # - Publication oder nil bei Fehler.
      # */
      def import_publication(external_id)
        document = fetch_xml("#{@publications_url}/#{external_id}.xml")

        unless document
          warn "Skipping publication #{external_id}: not found"
          return nil
        end

        publication_node = document.at_xpath("/ws:publication", "ws" => XML_NAMESPACE)

        unless publication_node
          warn "Skipping publication #{external_id}: invalid XML"
          return nil
        end

        title = text(publication_node, "title")

        if title.blank?
          warn "Skipping publication #{external_id}: no title"
          return nil
        end

        publication = Publication.find_or_initialize_by(external_id: external_id)

        ActiveRecord::Base.transaction do
          publication.title = title
          publication.abstract = text(publication_node, "abstract")
          publication.publication_year = parse_year(text(publication_node, "year-of-publication"))
          publication.doi = text(publication_node, "persistent-identifier")
          publication.save!

          import_authorships(publication, publication_node)
          publication.facilities = linked_facilities(publication_node)
          publication.research_projects = linked_research_projects(publication_node)
        end

        puts "Imported publication #{external_id}: #{publication.title}"
        publication
      rescue StandardError => e
        warn "Error importing publication #{external_id}: #{e.message}"
        nil
      end

      # /*
      # Title: import_authorships
      #
      # Desc:
      # Ersetzt die Autorenliste der Publikation durch die
      # Autoren aus dem XML. Fehlt die Position, wird die
      # Reihenfolge im XML verwendet. Autoren ohne Nachnamen
      # oder mit doppelter Position werden übersprungen.
      # */
      def import_authorships(publication, publication_node)
        Authorship.where(publication_id: publication.id).delete_all
        used_positions = Set.new

        author_nodes = publication_node.xpath("ws:authors/ws:author", "ws" => XML_NAMESPACE)

        author_nodes.each_with_index do |author_node, index|
          last_name = text(author_node, "last-name")

          if last_name.blank?
            warn "Skipping author #{index} of publication #{publication.external_id}: no last name"
            next
          end

          position_text = text(author_node, "position")
          position = position_text&.match?(/\A\d+\z/) ? position_text.to_i : index

          unless used_positions.add?(position)
            warn "Skipping author #{last_name} of publication #{publication.external_id}: duplicate position #{position}"
            next
          end

          publication.authorships.create!(
            first_name: text(author_node, "first-name"),
            last_name: last_name,
            position: position,
            role: text(author_node, "role")
          )
        end
      end

      # /*
      # Title: linked_facilities
      #
      # Desc:
      # Liefert die Einrichtungen aus <facilities>, die bereits
      # in der Datenbank existieren.
      # */
      def linked_facilities(publication_node)
        external_ids = linked_external_ids(publication_node, "facilities/ws:facility")
        Facility.where(external_id: external_ids).to_a
      end

      # /*
      # Title: linked_research_projects
      #
      # Desc:
      # Liefert die Forschungsprojekte aus <research-projects>,
      # die bereits in der Datenbank existieren.
      # */
      def linked_research_projects(publication_node)
        external_ids = linked_external_ids(publication_node, "research-projects/ws:research-project")
        ResearchProject.where(external_id: external_ids).to_a
      end

      def linked_external_ids(publication_node, path)
        publication_node.xpath("ws:#{path}", "ws" => XML_NAMESPACE).filter_map do |node|
          href = href_of(node)
          external_id_from_url(href) if href
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
      # /*
      # Title: fetch_xml
      #
      # Desc:
      # Lädt ein XML-Dokument vom SciPort-Webservice.
      #
      # Bei Netzwerkfehlern (Zeitüberschreitung, Verbindung
      # abgebrochen) wird die Anfrage bis zu zweimal wiederholt,
      # mit 5 bzw. 10 Sekunden Pause. Erst wenn auch der dritte
      # Versuch scheitert, wird der Fehler weitergegeben.
      #
      # Parameters:
      # - url (String): vollständige Adresse des XML-Dokuments.
      #
      # Returns:
      # - Nokogiri::XML::Document
      # - nil, wenn der Webservice 404 (nicht gefunden) meldet.
      # */
      def fetch_xml(url)
        attempts = 0

        begin
          attempts += 1
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
        rescue Net::OpenTimeout, Net::ReadTimeout, IO::TimeoutError,
               Errno::ETIMEDOUT, Errno::ECONNRESET, Errno::ECONNREFUSED,
               Errno::EHOSTUNREACH, SocketError, EOFError,
               OpenSSL::SSL::SSLError => e
          raise if attempts >= 3

          warn "Retry #{attempts}/2 for #{url}: #{e.message}"
          sleep(5 * attempts)
          retry
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

      # external_id bleibt ein String (Spaltentyp string).
      def external_id_from_url(url)
        URI.parse(url.gsub(/\s+/, "")).path.split("/").last.to_s.delete_suffix(".xml")
      end

      def text(node, element)
        node.at_xpath(
          "ws:#{element}",
          "ws" => XML_NAMESPACE
        )&.text&.strip.presence
      end

      def parse_year(value)
        value&.match?(/\A\d{4}\z/) ? value.to_i : nil
      end
    end

    PublicationImporter.new(
      base_url: BASE_URL,
      publications_url: PUBLICATIONS_URL,
      username: USERNAME,
      password: PASSWORD
    ).import
  end
end
