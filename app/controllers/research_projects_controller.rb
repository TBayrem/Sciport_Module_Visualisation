# ================================================================
# RESEARCH PROJECTS CONTROLLER
# ================================================================
# Titel: Research Projects Controller
# Beschreibung: Verwaltet Forschungsprojekte mit CRUD und API-Integration.
#
# @author Sciport Module Visualisation Team
# @version 1.0
# @since 2026-08-27
# ================================================================

class ResearchProjectsController < ApplicationController
  before_action :set_research_project, only: [ :show, :edit, :update, :destroy ]
  before_action :set_api_service, only: [ :fetch_api, :fetch_api_detail ]

  # ==============================================================
  # GET /research_projects
  # ==============================================================
  def index
    @research_projects = ResearchProject.all
  end

  # ==============================================================
  # GET /research_projects/:id
  # ==============================================================
  def show
  end

  # ==============================================================
  # GET /research_projects/new
  # ==============================================================
  def new
    @research_project = ResearchProject.new
  end

  # ==============================================================
  # GET /research_projects/:id/edit
  # ==============================================================
  def edit
  end

  # ==============================================================
  # POST /research_projects
  # ==============================================================
  def create
    @research_project = ResearchProject.new(research_project_params)
    if @research_project.save
      redirect_to @research_project, notice: "Forschungsprojekt wurde erfolgreich erstellt."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # ==============================================================
  # PATCH/PUT /research_projects/:id
  # ==============================================================
  def update
    if @research_project.update(research_project_params)
      redirect_to @research_project, notice: "Forschungsprojekt wurde erfolgreich aktualisiert."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # ==============================================================
  # DELETE /research_projects/:id
  # ==============================================================
  def destroy
    @research_project.destroy
    redirect_to research_projects_url, notice: "Forschungsprojekt wurde erfolgreich gelöscht."
  end

  # ==============================================================
  # GET /research_projects/fetch_api/:person_id
  # ==============================================================
  def fetch_api
    person_id = params[:person_id]
    if person_id.blank?
      redirect_to research_projects_path, alert: "❌ Bitte eine Personen-ID angeben."
      return
    end

    response = HTTParty.get("https://www.rlp-forschung.de/public/people/#{person_id}/research_projects.xml",
                           basic_auth: @api_service.auth)

    if response.success?
      imported_count = import_projects_from_xml(response.body)
      redirect_to research_projects_path, notice: "✅ #{imported_count} Forschungsprojekte von der API importiert!"
    else
      redirect_to research_projects_path, alert: "❌ API-Fehler: #{response.code}"
    end
  rescue => e
    redirect_to research_projects_path, alert: "❌ Fehler: #{e.message}"
  end

  # ==============================================================
  # GET /research_projects/:id/fetch_api_detail
  # ==============================================================
  def fetch_api_detail
    id = params[:id]
    response = HTTParty.get("https://www.rlp-forschung.de/public/research_projects/#{id}.xml",
                           basic_auth: @api_service.auth)

    if response.success?
      project_data = parse_project_detail(response.body)
      if project_data
        project = ResearchProject.find_or_initialize_by(api_id: project_data[:id])
        project.update(
          title: project_data[:title],
          description: project_data[:description],
          keywords: project_data[:keywords],
          start_date: project_data[:start_date],
          end_date: project_data[:end_date],
          funding_by: project_data[:funding_by],
          api_id: project_data[:id],
          href: project_data[:href]
        )
        redirect_to project, notice: "✅ Forschungsprojekt '#{project.title}' aktualisiert!"
      else
        redirect_to research_projects_path, alert: "❌ Projekt mit ID #{id} nicht gefunden"
      end
    else
      redirect_to research_projects_path, alert: "❌ API-Fehler: #{response.code}"
    end
  rescue => e
    redirect_to research_projects_path, alert: "❌ Fehler: #{e.message}"
  end

  private

  def set_research_project
    @research_project = ResearchProject.find(params[:id])
  end

  def set_api_service
    @api_service = SciportApiService.new
  end

  def research_project_params
    params.require(:research_project).permit(:title, :description, :keywords,
                                             :start_date, :end_date, :external_partners,
                                             :funding_by, :funding_id, :website,
                                             :email_address, :api_id, :href,
                                             :runtime, :people)
  end

  # ==============================================================
  # PARSER-METHODEN
  # ==============================================================

  def import_projects_from_xml(xml)
    doc = Nokogiri::XML(xml)
    count = 0
    doc.xpath("//research-project").each do |element|
      href = element.attr("href")
      id = href.to_s.split("/").last.gsub(".xml", "") if href
      project = ResearchProject.find_or_initialize_by(api_id: id)
      project.update(
        title: element.at_xpath("title")&.text,
        runtime: element.at_xpath("runtime")&.text,
        people: element.at_xpath("people")&.text,
        api_id: id,
        href: href
      )
      count += 1 if project.persisted?
    end
    count
  end

  def parse_project_detail(xml)
    doc = Nokogiri::XML(xml)
    href = doc.at_xpath("//research-project")&.attr("href")
    id = href.to_s.split("/").last.gsub(".xml", "") if href
    {
      id: id,
      title: doc.at_xpath("//title")&.text,
      description: doc.at_xpath("//description")&.text,
      keywords: doc.at_xpath("//keywords")&.text,
      start_date: doc.at_xpath("//start-date")&.text,
      end_date: doc.at_xpath("//end-date")&.text,
      funding_by: doc.at_xpath("//funding-by")&.text,
      href: href
    }
  end
end
