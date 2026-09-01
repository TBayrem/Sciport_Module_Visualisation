json.extract! research_project, :id, :title, :description, :start_date, :end_date, :funding_by, :created_at, :updated_at
json.url research_project_url(research_project, format: :json)
