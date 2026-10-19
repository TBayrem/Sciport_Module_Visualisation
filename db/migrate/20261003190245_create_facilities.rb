class CreateFacilities < ActiveRecord::Migration[8.1]
  def change
    create_table :facilities do |t|
      t.string :name
      t.string :facility_type
t.references :parent,
             null: true,
             foreign_key: { to_table: :facilities }
      t.timestamps
    end
  end
end
