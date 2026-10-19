class CreateAuthorships < ActiveRecord::Migration[8.1]
  def change
    create_table :authorships do |t|
      t.references :person, null: false, foreign_key: true
      t.references :publication, null: false, foreign_key: true
      t.integer :position
      t.string :role

      t.timestamps
    end
  end
end
