namespace :people do
  desc "Import people and their facility roles from rlp-forschung.de"
  task import: :environment do
    require "net/http"
    require "nokogiri"
    require "uri"

USERNAME = ENV.fetch("SCIPORT_USERNAME")
PASSWORD = ENV.fetch("SCIPORT_PASSWORD")

    class PeopleImporter
      BASE_URL = "https://www.rlp-forschung.de".freeze
      PEOPLE_RANGE = 1..8410
      XML_NAMESPACE = "https://www.rlp-forschung.de/ws/1_0".freeze
      XLINK_NAMESPACE = "http://www.w3.org/1999/xlink".freeze

      def initialize(username:, password:)
        @username = username
        @password = password
      end

      def import
        PEOPLE_RANGE.each do |external_id|
          import_person(external_id)

          puts "Progress: #{external_id}/#{PEOPLE_RANGE.end}" if (external_id % 100).zero?
        rescue StandardError => e
          warn "Error importing person #{external_id}: #{e.message}"
        end

        puts "Person import finished."
      end

      private

      def import_person(external_id)
        url = "#{BASE_URL}/public/people/#{external_id}.xml"
        document = fetch_xml(url)

        unless document
          puts "Skipping person #{external_id}: not found"
          return
        end

        person_node = document.at_xpath(
          "/ws:person",
          "ws" => XML_NAMESPACE
        )

        unless person_node
          warn "Skipping person #{external_id}: invalid XML"
          return
        end

        person = Person.find_or_initialize_by(external_id: external_id)

        person.first_name = text(person_node, "first-name")
        person.last_name = text(person_node, "last-name")
        person.save!

        import_roles(person, person_node)

        puts "Imported person #{external_id}: #{person.first_name} #{person.last_name}"
      end

      def import_roles(person, person_node)
        role_nodes = person_node.xpath(
          "ws:roles/ws:role",
          "ws" => XML_NAMESPACE
        )

        role_nodes.each do |role_node|
          description = text(role_node, "description")

          facility_node = role_node.at_xpath(
            "ws:facility",
            "ws" => XML_NAMESPACE
          )

          unless facility_node
            warn "Skipping role for person #{person.external_id}: no facility"
            next
          end

          facility_href = facility_node.attribute_with_ns(
            "href",
            XLINK_NAMESPACE
          )&.value

          unless facility_href
            warn "Skipping role for person #{person.external_id}: no facility href"
            next
          end

          facility_external_id = external_id_from_url(facility_href)

          facility = Facility.find_by(external_id: facility_external_id)

          unless facility
            warn "Facility #{facility_external_id} not found for person #{person.external_id}"
            next
          end

          role = Role.find_or_initialize_by(
            person: person,
            facility: facility,
            description: description
          )

          role.description = description
          role.save!
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
          use_ssl: uri.scheme == "https"
        ) do |http|
          http.request(request)
        end

        return nil if response.code == "404"

        unless response.is_a?(Net::HTTPSuccess)
          raise "HTTP #{response.code} while fetching #{url}"
        end

        Nokogiri::XML(response.body)
      end

      def text(node, element)
        node.at_xpath(
          "ws:#{element}",
          "ws" => XML_NAMESPACE
        )&.text&.strip
      end

      def external_id_from_url(url)
        URI.parse(url).path.split("/").last.delete_suffix(".xml").to_i
      end
    end

    PeopleImporter.new(
      username: USERNAME,
      password: PASSWORD
    ).import
  end
end
