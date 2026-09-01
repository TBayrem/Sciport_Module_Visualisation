json.extract! patent, :id, :title, :number, :holder, :created_at, :updated_at
json.url patent_url(patent, format: :json)
