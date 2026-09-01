json.extract! publication, :id, :title, :authors, :year_of_publication, :publication_type, :created_at, :updated_at
json.url publication_url(publication, format: :json)
