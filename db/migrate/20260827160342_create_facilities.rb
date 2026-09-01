class CreateFacilities < ActiveRecord::Migration[8.1]
  def change
    create_table :facilities do |t|
      t.string :name
      t.string :facility_type
      t.string :city
      t.string :street
      t.string :zip_code
      t.string :phone_number
      t.string :website
      t.string :email_address

      t.timestamps
    end
  end
end
