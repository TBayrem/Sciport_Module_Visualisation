class CreateRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :roles do |t|
      t.references :person, null: false, foreign_key: true
      t.references :facility, null: false, foreign_key: true
      t.string :name

      t.timestamps
    end
  end
end
