json.extract! facility, :id, :name, :facility_type, :city, :street, :zip_code, :phone_number, :website, :email_address, :created_at, :updated_at
json.url facility_url(facility, format: :json)
