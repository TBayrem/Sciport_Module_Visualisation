json.extract! person, :id, :first_name, :last_name, :title, :email_address, :phone_number, :city, :created_at, :updated_at
json.url person_url(person, format: :json)
