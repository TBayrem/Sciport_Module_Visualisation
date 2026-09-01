# ================================================================
# PUBLICATIONS CONTROLLER
# ================================================================
# Titel: Publications Controller
# Beschreibung: Verwaltet Publikationen mit CRUD und API-Integration.
#
# @author Sciport Module Visualisation Team
# @version 1.0
# @since 2026-08-27
# ================================================================

class PublicationsController < ApplicationController
  before_action :set_publication, only: [ :show, :edit, :update, :destroy ]
  before_action :set_api_service, only: [ :fetch_api, :fetch_api_detail ]

  # ==============================================================
  # GET /publications
  # ==============================================================
  def index
    @publications = Publication.all
  end

  # ==============================================================
  # GET /publications/:id
  # ==============================================================
  def show
  end

  # ==============================================================
  # GET /publications/new
  # ==============================================================
  def new
    @publication = Publication.new
  end

  # ==============================================================
  # GET /publications/:id/edit
  # ==============================================================
  def edit
  end

  # ==============================================================
  # POST /publications
  # ==============================================================
  def create
    @publication = Publication.new(publication_params)
    if @publication.save
      redirect_to @publication, notice: "Publikation wurde erfolgreich erstellt."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # ==============================================================
  # PATCH/PUT /publications/:id
  # ==============================================================
  def update
    if @publication.update(publication_params)
      redirect_to @publication, notice: "Publikation wurde erfolgreich aktualisiert."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # ==============================================================
  # DELETE /publications/:id
  # ==============================================================
  def destroy
    @publication.destroy
    redirect_to publications_url, notice: "Publikation wurde erfolgreich gelöscht."
  end

  # ==============================================================
  # GET /publications/fetch_api/:person_id
  # ==============================================================
  def fetch_api
    person_id = params[:person_id]
    if person_id.blank?
      redirect_to publications_path, alert: "❌ Bitte eine Personen-ID angeben."
      return
    end

    response = HTTParty.get("https://www.rlp-forschung.de/public/people/#{person_id}/publications.xml",
                           basic_auth: @api_service.auth)

    if response.success?
      imported_count = import_publications_from_xml(response.body)
      redirect_to publications_path, notice: "✅ #{imported_count} Publikationen von der API importiert!"
    else
      redirect_to publications_path, alert: "❌ API-Fehler: #{response.code}"
    end
  rescue => e
    redirect_to publications_path, alert: "❌ Fehler: #{e.message}"
  end

  # ==============================================================
  # GET /publications/:id/fetch_api_detail
  # ==============================================================
  def fetch_api_detail
    id = params[:id]
    response = HTTParty.get("https://www.rlp-forschung.de/public/publications/#{id}.xml",
                           basic_auth: @api_service.auth)

    if response.success?
      pub_data = parse_publication_detail(response.body)
      if pub_data
        pub = Publication.find_or_initialize_by(api_id: pub_data[:id])
        pub.update(
          title: pub_data[:title],
          authors: pub_data[:authors],
          year_of_publication: pub_data[:year_of_publication],
          publication_type: pub_data[:publication_type],
          meta_info: pub_data[:meta_info],
          api_id: pub_data[:id],
          href: pub_data[:href]
        )
        redirect_to pub, notice: "✅ Publikation '#{pub.title}' aktualisiert!"
      else
        redirect_to publications_path, alert: "❌ Publikation mit ID #{id} nicht gefunden"
      end
    else
      redirect_to publications_path, alert: "❌ API-Fehler: #{response.code}"
    end
  rescue => e
    redirect_to publications_path, alert: "❌ Fehler: #{e.message}"
  end

  private

  def set_publication
    @publication = Publication.find(params[:id])
  end

  def set_api_service
    @api_service = SciportApiService.new
  end

  def publication_params
    params.require(:publication).permit(:title, :authors, :multi_volume_title,
                                        :year_of_publication, :meta_info, :isn,
                                        :persistent_identifier, :notice,
                                        :publication_type, :type_detail,
                                        :language, :abstract, :ddc, :dfg,
                                        :api_id, :href)
  end

  # ==============================================================
  # PARSER-METHODEN
  # ==============================================================

  def import_publications_from_xml(xml)
    doc = Nokogiri::XML(xml)
    count = 0
    doc.xpath("//publication").each do |element|
      href = element.attr("href")
      id = href.to_s.split("/").last.gsub(".xml", "") if href
      pub = Publication.find_or_initialize_by(api_id: id)
      pub.update(
        title: element.at_xpath("title")&.text,
        authors: element.at_xpath("authors")&.text,
        meta_info: element.at_xpath("meta-infos")&.text,
        api_id: id,
        href: href
      )
      count += 1 if pub.persisted?
    end
    count
  end

  def parse_publication_detail(xml)
    doc = Nokogiri::XML(xml)
    href = doc.at_xpath("//publication")&.attr("href")
    id = href.to_s.split("/").last.gsub(".xml", "") if href
    {
      id: id,
      title: doc.at_xpath("//title")&.text,
      authors: doc.at_xpath("//authors")&.text,
      year_of_publication: doc.at_xpath("//year-of-publication")&.text,
      publication_type: doc.at_xpath("//type")&.text,
      meta_info: doc.at_xpath("//meta-info")&.text,
      href: href
    }
  end
end
