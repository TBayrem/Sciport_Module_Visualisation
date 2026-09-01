# ================================================================
# FACILITIES CONTROLLER
# ================================================================
# Titel: Facilities Controller
# Beschreibung: Verwaltet Einrichtungen mit CRUD und API-Integration.
#
# @author Sciport Module Visualisation Team
# @version 1.0
# @since 2026-08-27
# ================================================================

class FacilitiesController < ApplicationController
  before_action :set_facility, only: [ :show, :edit, :update, :destroy ]
  before_action :set_api_service, only: [ :fetch_api, :fetch_api_detail ]

  # ==============================================================
  # GET /facilities
  # ==============================================================
  def index
    @facilities = Facility.all
  end

  # ==============================================================
  # GET /facilities/:id
  # ==============================================================
  def show
  end

  # ==============================================================
  # GET /facilities/new
  # ==============================================================
  def new
    @facility = Facility.new
  end

  # ==============================================================
  # GET /facilities/:id/edit
  # ==============================================================
  def edit
  end

  # ==============================================================
  # POST /facilities
  # ==============================================================
  def create
    @facility = Facility.new(facility_params)
    if @facility.save
      redirect_to @facility, notice: "Einrichtung wurde erfolgreich erstellt."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # ==============================================================
  # PATCH/PUT /facilities/:id
  # ==============================================================
  def update
    if @facility.update(facility_params)
      redirect_to @facility, notice: "Einrichtung wurde erfolgreich aktualisiert."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # ==============================================================
  # DELETE /facilities/:id
  # ==============================================================
  def destroy
    @facility.destroy
    redirect_to facilities_url, notice: "Einrichtung wurde erfolgreich gelöscht."
  end

  # ==============================================================
  # GET /facilities/fetch_api
  # ==============================================================
  def fetch_api
    response = HTTParty.get("https://www.rlp-forschung.de/facilities.xml",
                           basic_auth: @api_service.auth)

    if response.success?
      imported_count = import_facilities_from_xml(response.body)
      redirect_to facilities_path, notice: "✅ #{imported_count} Einrichtungen von der API importiert!"
    else
      redirect_to facilities_path, alert: "❌ API-Fehler: #{response.code}"
    end
  rescue => e
    redirect_to facilities_path, alert: "❌ Fehler: #{e.message}"
  end

  # ==============================================================
  # GET /facilities/:id/fetch_api_detail
  # ==============================================================
  def fetch_api_detail
    id = params[:id]
    response = HTTParty.get("https://www.rlp-forschung.de/public/facilities/#{id}.xml",
                           basic_auth: @api_service.auth)

    if response.success?
      facility_data = parse_facility_detail(response.body)
      if facility_data
        facility = Facility.find_or_initialize_by(api_id: facility_data[:id])
        facility.update(
          name: facility_data[:name],
          facility_type: facility_data[:facility_type],
          description: facility_data[:description],
          zip_code: facility_data[:zip_code],
          city: facility_data[:city],
          street: facility_data[:street],
          phone_number: facility_data[:phone_number],
          fax_number: facility_data[:fax_number],
          website: facility_data[:website],
          email_address: facility_data[:email_address],
          number_of_employees: facility_data[:number_of_employees],
          number_of_researchers: facility_data[:number_of_researchers],
          api_id: facility_data[:id],
          href: facility_data[:href]
        )
        redirect_to facility, notice: "✅ Einrichtung '#{facility.name}' aktualisiert!"
      else
        redirect_to facilities_path, alert: "❌ Einrichtung mit ID #{id} nicht gefunden"
      end
    else
      redirect_to facilities_path, alert: "❌ API-Fehler: #{response.code}"
    end
  rescue => e
    redirect_to facilities_path, alert: "❌ Fehler: #{e.message}"
  end

  private

  def set_facility
    @facility = Facility.find(params[:id])
  end

  def set_api_service
    @api_service = SciportApiService.new
  end

  def facility_params
    params.require(:facility).permit(:name, :facility_type, :description, :zip_code,
                                     :city, :street, :phone_number, :fax_number,
                                     :website, :email_address, :equipment,
                                     :number_of_employees, :number_of_researchers,
                                     :services, :api_id, :href)
  end

  # ==============================================================
  # PARSER-METHODEN
  # ==============================================================

  def import_facilities_from_xml(xml)
    doc = Nokogiri::XML(xml)
    count = 0
    doc.xpath("//facility").each do |element|
      href = element.attr("href")
      id = href.to_s.split("/").last.gsub(".xml", "") if href
      facility = Facility.find_or_initialize_by(api_id: id)
      facility.update(
        name: element.at_xpath("name")&.text,
        facility_type: element.at_xpath("type")&.text,
        api_id: id,
        href: href
      )
      count += 1 if facility.persisted?
    end
    count
  end

  def parse_facility_detail(xml)
    doc = Nokogiri::XML(xml)
    href = doc.at_xpath("//facility")&.attr("href")
    id = href.to_s.split("/").last.gsub(".xml", "") if href
    {
      id: id,
      name: doc.at_xpath("//name")&.text,
      facility_type: doc.at_xpath("//type")&.text,
      description: doc.at_xpath("//description")&.text,
      zip_code: doc.at_xpath("//zip-code")&.text,
      city: doc.at_xpath("//city")&.text,
      street: doc.at_xpath("//street")&.text,
      phone_number: doc.at_xpath("//phone-number")&.text,
      fax_number: doc.at_xpath("//fax-number")&.text,
      website: doc.at_xpath("//website")&.text,
      email_address: doc.at_xpath("//email-address")&.text,
      number_of_employees: doc.at_xpath("//number-of-employees")&.text,
      number_of_researchers: doc.at_xpath("//number-of-researchers")&.text,
      href: href
    }
  end
end
