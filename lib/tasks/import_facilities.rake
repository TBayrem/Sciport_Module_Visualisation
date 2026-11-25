namespace :facilities do
  desc "Import facilities from rlp-forschung.de"
  task import: :environment do
    require "net/http"
    require "nokogiri"

    BASE_URL = "https://www.rlp-forschung.de".freeze
    FACILITIES_URL = "#{BASE_URL}/facilities.xml".freeze

USERNAME = ENV.fetch("SCIPORT_USERNAME")
PASSWORD = ENV.fetch("SCIPORT_PASSWORD")

    class FacilityImporter
      XML_NAMESPACE = "https://www.rlp-forschung.de/ws/1_0".freeze

      def initialize(base_url:, username:, password:)
        @base_url = base_url
        @username = username
        @password = password
      end

      def import
        document = fetch_xml("/facilities.xml")

        document.xpath("//ws:facility", "ws" => XML_NAMESPACE).each do |facility_node|
          import_facility(facility_node, nil)
        end
      end

      private

      def import_facility(node, parent)
        url = node.attributes["href"]&.value
        raise "Facility has no xlink:href" unless url

        facility_id = facility_id_from_url(url)

        puts "Importing facility #{facility_id}: #{text(node, "name")}"

        document = fetch_xml(url)
        facility_node = document.at_xpath("/ws:facility", "ws" => XML_NAMESPACE)

        facility = Facility.find_or_initialize_by(external_id: facility_id)

        facility.name = text(facility_node, "name")
        facility.facility_type = text(facility_node, "type")
        facility.parent = parent

        facility.save!

        puts "  -> #{facility.persisted? ? "saved" : "created"}: #{facility.name}"

        sub_facilities = facility_node.xpath(
          "/ws:facility/ws:sub-facilities/ws:sub-facility",
          "ws" => XML_NAMESPACE
        )

        sub_facilities.each do |sub_facility|
          import_facility(sub_facility, facility)
        end

        facility
      end

      def fetch_xml(url)
        uri = URI.parse(url.start_with?("http") ? url : "#{@base_url}#{url}")

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

        unless response.is_a?(Net::HTTPSuccess)
          raise "HTTP #{response.code} while fetching #{uri}"
        end

        Nokogiri::XML(response.body)
      end

      def facility_id_from_url(url)
        URI.parse(url).path.split("/").last.delete_suffix(".xml").to_i
      end

      def text(node, element)
        node.at_xpath(
          "ws:#{element}",
          "ws" => XML_NAMESPACE
        )&.text&.strip
      end
    end

    FacilityImporter.new(
      base_url: BASE_URL,
      username: USERNAME,
      password: PASSWORD
    ).import
  end
end
