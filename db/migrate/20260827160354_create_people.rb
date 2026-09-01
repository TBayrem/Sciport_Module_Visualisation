class CreatePeople < ActiveRecord::Migration[8.1]
  def change
    create_table :people do |t|
      t.string :first_name
      t.string :last_name
      t.string :title
      t.string :email_address
      t.string :phone_number
      t.string :city

      t.timestamps
    end
  end
end
