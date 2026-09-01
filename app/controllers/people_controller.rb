# ================================================================
# PEOPLE CONTROLLER
# ================================================================
# Titel: People Controller
# Beschreibung: Verwaltet Personen mit CRUD und API-Integration.
#
# @author Sciport Module Visualisation Team
# @version 1.0
# @since 2026-08-27
# ================================================================

class PeopleController < ApplicationController
  before_action :set_person, only: [ :show, :edit, :update, :destroy ]
  before_action :set_api_service, only: [ :fetch_api, :fetch_api_detail ]

  # ==============================================================
  # GET /people
  # ==============================================================
  def index
    @people = Person.all
  end

  # ==============================================================
  # GET /people/:id
  # ==============================================================
  def show
  end

  # ==============================================================
  # GET /people/new
  # ==============================================================
  def new
    @person = Person.new
  end

  # ==============================================================
  # GET /people/:id/edit
  # ==============================================================
  def edit
  end

  # ==============================================================
  # POST /people
  # ==============================================================
  def create
    @person = Person.new(person_params)
    if @person.save
      redirect_to @person, notice: "Person wurde erfolgreich erstellt."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # ==============================================================
  # PATCH/PUT /people/:id
  # ==============================================================
  def update
    if @person.update(person_params)
      redirect_to @person, notice: "Person wurde erfolgreich aktualisiert."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # ==============================================================
  # DELETE /people/:id
  # ==============================================================
  def destroy
    @person.destroy
    redirect_to people_url, notice: "Person wurde erfolgreich gelöscht."
  end

  # ==============================================================
  # GET /people/fetch_api/:facility_id
  # ==============================================================
  def fetch_api
    facility_id = params[:facility_id]
    if facility_id.blank?
      redirect_to people_path, alert: "❌ Bitte eine Einrichtungs-ID angeben."
      return
    end

    response = HTTParty.get("https://www.rlp-forschung.de/public/facilities/#{facility_id}/people.xml",
                           basic_auth: @api_service.auth)

    if response.success?
      imported_count = import_people_from_xml(response.body)
      redirect_to people_path, notice: "✅ #{imported_count} Personen von der API importiert!"
    else
      redirect_to people_path, alert: "❌ API-Fehler: #{response.code}"
    end
  rescue => e
    redirect_to people_path, alert: "❌ Fehler: #{e.message}"
  end

  # ==============================================================
  # GET /people/:id/fetch_api_detail
  # ==============================================================
  def fetch_api_detail
    id = params[:id]
    response = HTTParty.get("https://www.rlp-forschung.de/public/people/#{id}.xml",
                           basic_auth: @api_service.auth)

    if response.success?
      person_data = parse_person_detail(response.body)
      if person_data
        person = Person.find_or_initialize_by(api_id: person_data[:id])
        person.update(
          first_name: person_data[:first_name],
          last_name: person_data[:last_name],
          title: person_data[:title],
          city: person_data[:city],
          email_address: person_data[:email_address],
          phone_number: person_data[:phone_number],
          website: person_data[:website],
          api_id: person_data[:id],
          href: person_data[:href]
        )
        redirect_to person, notice: "✅ Person '#{person.full_name}' aktualisiert!"
      else
        redirect_to people_path, alert: "❌ Person mit ID #{id} nicht gefunden"
      end
    else
      redirect_to people_path, alert: "❌ API-Fehler: #{response.code}"
    end
  rescue => e
    redirect_to people_path, alert: "❌ Fehler: #{e.message}"
  end

  private

  def set_person
    @person = Person.find(params[:id])
  end

  def set_api_service
    @api_service = SciportApiService.new
  end

  def person_params
    params.require(:person).permit(:first_name, :last_name, :title, :gender,
                                   :year_of_birth, :zip_code, :city, :street,
                                   :building_room, :phone_number, :fax_number,
                                   :email_address, :website, :cv,
                                   :field_of_research, :field_of_teaching,
                                   :consultancy_functions, :honors,
                                   :editing_functions, :services_offered,
                                   :references_and_business_contacts,
                                   :awards_and_prizes, :description,
                                   :api_id, :href, :facility_name)
  end

  # ==============================================================
  # PARSER-METHODEN
  # ==============================================================

  def import_people_from_xml(xml)
    doc = Nokogiri::XML(xml)
    count = 0
    doc.xpath("//person").each do |element|
      href = element.attr("href")
      id = href.to_s.split("/").last.gsub(".xml", "") if href
      person = Person.find_or_initialize_by(api_id: id)
      person.update(
        first_name: element.at_xpath("first-name")&.text,
        last_name: element.at_xpath("last-name")&.text,
        api_id: id,
        href: href
      )
      count += 1 if person.persisted?
    end
    count
  end

  def parse_person_detail(xml)
    doc = Nokogiri::XML(xml)
    href = doc.at_xpath("//person")&.attr("href")
    id = href.to_s.split("/").last.gsub(".xml", "") if href
    {
      id: id,
      first_name: doc.at_xpath("//first-name")&.text,
      last_name: doc.at_xpath("//last-name")&.text,
      title: doc.at_xpath("//title")&.text,
      city: doc.at_xpath("//city")&.text,
      email_address: doc.at_xpath("//email-address")&.text,
      phone_number: doc.at_xpath("//phone-number")&.text,
      website: doc.at_xpath("//website")&.text,
      href: href
    }
  end
end
