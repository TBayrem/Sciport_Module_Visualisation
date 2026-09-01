# ================================================================
# HOME CONTROLLER
# ================================================================
# Titel: Home Controller
# Beschreibung: Startseite mit Statistiken und Import-Buttons.
#
# @author Sciport Module Visualisation Team
# @version 1.0
# @since 2026-08-27
# ================================================================

class HomeController < ApplicationController
  before_action :set_counts, only: [ :index ]

  # ==============================================================
  # INDEX - STARTSEITE
  # ==============================================================
  def index
    @facilities = Facility.limit(10)
    @people = Person.limit(10)
    @projects = ResearchProject.limit(10)
    @publications = Publication.limit(10)
    @patents = Patent.limit(10)
  end

  # ==============================================================
  # IMPORT FACILITIES
  # ==============================================================
  def import_facilities
    service = SciportApiService.new
    response = HTTParty.get("https://www.rlp-forschung.de/facilities.xml",
                           basic_auth: service.auth)

    if response.success?
      facilities_data = parse_facilities(response.body)
      imported_count = save_facilities(facilities_data)
      redirect_to root_path, notice: "✅ #{imported_count} Einrichtungen importiert!"
    else
      redirect_to root_path, alert: "❌ API-Fehler: #{response.code}"
    end
  rescue => e
    redirect_to root_path, alert: "❌ Fehler: #{e.message}"
  end

  # ==============================================================
  # IMPORT PEOPLE
  # ==============================================================
  def import_people
    service = SciportApiService.new
    facilities = Facility.where.not(api_id: nil)
    imported_count = 0

    facilities.each do |facility|
      response = HTTParty.get("https://www.rlp-forschung.de/public/facilities/#{facility.api_id}/people.xml",
                             basic_auth: service.auth)

      if response.success?
        people_data = parse_people(response.body)
        people_data.each do |data|
          person = Person.find_or_initialize_by(api_id: data[:id])
          person.update(
            first_name: data[:first_name],
            last_name: data[:last_name],
            api_id: data[:id],
            href: data[:href]
          )
          facility.people << person unless facility.people.include?(person)
          imported_count += 1 if person.persisted?
        end
      end
    end

    redirect_to root_path, notice: "✅ #{imported_count} Personen importiert!"
  rescue => e
    redirect_to root_path, alert: "❌ Fehler: #{e.message}"
  end

  # ==============================================================
  # IMPORT ALL DATA
  # ==============================================================
  def import_all
    service = SciportApiService.new
    stats = { facilities: 0, people: 0, projects: 0, publications: 0, patents: 0 }

    # Facilities
    response = HTTParty.get("https://www.rlp-forschung.de/facilities.xml",
                           basic_auth: service.auth)
    if response.success?
      facilities_data = parse_facilities(response.body)
      stats[:facilities] = save_facilities(facilities_data)
    end

    # People, Projects, Publications, Patents
    Facility.where.not(api_id: nil).each do |facility|
      # People
      response = HTTParty.get("https://www.rlp-forschung.de/public/facilities/#{facility.api_id}/people.xml",
                             basic_auth: service.auth)
      if response.success?
        people_data = parse_people(response.body)
        people_data.each do |data|
          person = Person.find_or_initialize_by(api_id: data[:id])
          person.update(
            first_name: data[:first_name],
            last_name: data[:last_name],
            api_id: data[:id],
            href: data[:href]
          )
          facility.people << person unless facility.people.include?(person)
          stats[:people] += 1 if person.persisted?

          # Projects for person
          project_response = HTTParty.get("https://www.rlp-forschung.de/public/people/#{person.api_id}/research_projects.xml",
                                         basic_auth: service.auth)
          if project_response.success?
            projects_data = parse_projects(project_response.body)
            projects_data.each do |pdata|
              project = ResearchProject.find_or_initialize_by(api_id: pdata[:id])
              project.update(
                title: pdata[:title],
                runtime: pdata[:runtime],
                api_id: pdata[:id],
                href: pdata[:href]
              )
              person.research_projects << project unless person.research_projects.include?(project)
              facility.research_projects << project unless facility.research_projects.include?(project)
              stats[:projects] += 1 if project.persisted?
            end
          end

          # Publications for person
          pub_response = HTTParty.get("https://www.rlp-forschung.de/public/people/#{person.api_id}/publications.xml",
                                     basic_auth: service.auth)
          if pub_response.success?
            pubs_data = parse_publications(pub_response.body)
            pubs_data.each do |pdata|
              pub = Publication.find_or_initialize_by(api_id: pdata[:id])
              pub.update(
                title: pdata[:title],
                authors: pdata[:authors],
                meta_info: pdata[:meta_info],
                api_id: pdata[:id],
                href: pdata[:href]
              )
              person.publications << pub unless person.publications.include?(pub)
              facility.publications << pub unless facility.publications.include?(pub)
              stats[:publications] += 1 if pub.persisted?
            end
          end

          # Patents for person
          patent_response = HTTParty.get("https://www.rlp-forschung.de/public/people/#{person.api_id}/patents.xml",
                                        basic_auth: service.auth)
          if patent_response.success?
            patents_data = parse_patents(patent_response.body)
            patents_data.each do |pdata|
              patent = Patent.find_or_initialize_by(api_id: pdata[:id])
              patent.update(
                title: pdata[:title],
                number: pdata[:number],
                api_id: pdata[:id],
                href: pdata[:href]
              )
              person.patents << patent unless person.patents.include?(patent)
              stats[:patents] += 1 if patent.persisted?
            end
          end
        end
      end
    end

    redirect_to root_path, notice: "✅ Importiert: #{stats[:facilities]} Einrichtungen, #{stats[:people]} Personen, #{stats[:projects]} Projekte, #{stats[:publications]} Publikationen, #{stats[:patents]} Patente"
  rescue => e
    redirect_to root_path, alert: "❌ Fehler: #{e.message}"
  end

  private

  def set_counts
    @facility_count = Facility.count
    @person_count = Person.count
    @project_count = ResearchProject.count
    @publication_count = Publication.count
    @patent_count = Patent.count
  end

  # ==============================================================
  # PARSER-METHODEN
  # ==============================================================

  def parse_facilities(xml)
    doc = Nokogiri::XML(xml)
    facilities = []
    doc.xpath("//facility").each do |element|
      href = element.attr("href")
      id = href.to_s.split("/").last.gsub(".xml", "") if href
      facilities << {
        id: id,
        name: element.at_xpath("name")&.text,
        facility_type: element.at_xpath("type")&.text,
        href: href
      }
    end
    facilities
  end

  def parse_people(xml)
    doc = Nokogiri::XML(xml)
    people = []
    doc.xpath("//person").each do |element|
      href = element.attr("href")
      id = href.to_s.split("/").last.gsub(".xml", "") if href
      people << {
        id: id,
        first_name: element.at_xpath("first-name")&.text,
        last_name: element.at_xpath("last-name")&.text,
        href: href
      }
    end
    people
  end

  def parse_projects(xml)
    doc = Nokogiri::XML(xml)
    projects = []
    doc.xpath("//research-project").each do |element|
      href = element.attr("href")
      id = href.to_s.split("/").last.gsub(".xml", "") if href
      projects << {
        id: id,
        title: element.at_xpath("title")&.text,
        runtime: element.at_xpath("runtime")&.text,
        href: href
      }
    end
    projects
  end

  def parse_publications(xml)
    doc = Nokogiri::XML(xml)
    publications = []
    doc.xpath("//publication").each do |element|
      href = element.attr("href")
      id = href.to_s.split("/").last.gsub(".xml", "") if href
      publications << {
        id: id,
        title: element.at_xpath("title")&.text,
        authors: element.at_xpath("authors")&.text,
        meta_info: element.at_xpath("meta-infos")&.text,
        href: href
      }
    end
    publications
  end

  def parse_patents(xml)
    doc = Nokogiri::XML(xml)
    patents = []
    doc.xpath("//patent").each do |element|
      href = element.attr("href")
      id = href.to_s.split("/").last.gsub(".xml", "") if href
      patents << {
        id: id,
        title: element.at_xpath("title")&.text,
        number: element.at_xpath("number")&.text,
        href: href
      }
    end
    patents
  end

  # ==============================================================
  # SPEICHER-METHODEN
  # ==============================================================

  def save_facilities(facilities_data)
    count = 0
    facilities_data.each do |data|
      facility = Facility.find_or_initialize_by(api_id: data[:id])
      facility.update(
        name: data[:name],
        facility_type: data[:facility_type],
        api_id: data[:id],
        href: data[:href]
      )
      count += 1 if facility.persisted?
    end
    count
  end
end
