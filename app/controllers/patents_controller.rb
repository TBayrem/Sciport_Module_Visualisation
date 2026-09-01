# ================================================================
# PATENTS CONTROLLER
# ================================================================
# Titel: Patents Controller
# Beschreibung: Verwaltet Patente mit CRUD und API-Integration.
#
# @author Sciport Module Visualisation Team
# @version 1.0
# @since 2026-08-27
# ================================================================

class PatentsController < ApplicationController
  before_action :set_patent, only: [ :show, :edit, :update, :destroy ]
  before_action :set_api_service, only: [ :fetch_api ]

  # ==============================================================
  # GET /patents
  # ==============================================================
  def index
    @patents = Patent.all
  end

  # ==============================================================
  # GET /patents/:id
  # ==============================================================
  def show
  end

  # ==============================================================
  # GET /patents/new
  # ==============================================================
  def new
    @patent = Patent.new
  end

  # ==============================================================
  # GET /patents/:id/edit
  # ==============================================================
  def edit
  end

  # ==============================================================
  # POST /patents
  # ==============================================================
  def create
    @patent = Patent.new(patent_params)
    if @patent.save
      redirect_to @patent, notice: "Patent wurde erfolgreich erstellt."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # ==============================================================
  # PATCH/PUT /patents/:id
  # ==============================================================
  def update
    if @patent.update(patent_params)
      redirect_to @patent, notice: "Patent wurde erfolgreich aktualisiert."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # ==============================================================
  # DELETE /patents/:id
  # ==============================================================
  def destroy
    @patent.destroy
    redirect_to patents_url, notice: "Patent wurde erfolgreich gelöscht."
  end

  # ==============================================================
  # GET /patents/fetch_api/:person_id
  # ==============================================================
  def fetch_api
    person_id = params[:person_id]
    if person_id.blank?
      redirect_to patents_path, alert: "❌ Bitte eine Personen-ID angeben."
      return
    end

    response = HTTParty.get("https://www.rlp-forschung.de/public/people/#{person_id}/patents.xml",
                           basic_auth: @api_service.auth)

    if response.success?
      imported_count = import_patents_from_xml(response.body)
      redirect_to patents_path, notice: "✅ #{imported_count} Patente von der API importiert!"
    else
      redirect_to patents_path, alert: "❌ API-Fehler: #{response.code}"
    end
  rescue => e
    redirect_to patents_path, alert: "❌ Fehler: #{e.message}"
  end

  private

  def set_patent
    @patent = Patent.find(params[:id])
  end

  def set_api_service
    @api_service = SciportApiService.new
  end

  def patent_params
    params.require(:patent).permit(:title, :number, :website, :holder,
                                   :api_id, :href)
  end

  # ==============================================================
  # PARSER-METHODEN
  # ==============================================================

  def import_patents_from_xml(xml)
    doc = Nokogiri::XML(xml)
    count = 0
    doc.xpath("//patent").each do |element|
      href = element.attr("href")
      id = href.to_s.split("/").last.gsub(".xml", "") if href
      patent = Patent.find_or_initialize_by(api_id: id)
      patent.update(
        title: element.at_xpath("title")&.text,
        number: element.at_xpath("number")&.text,
        api_id: id,
        href: href
      )
      count += 1 if patent.persisted?
    end
    count
  end
end
