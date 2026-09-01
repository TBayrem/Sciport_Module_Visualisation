class CreatePublications < ActiveRecord::Migration[8.1]
  def change
    create_table :publications do |t|
      t.string :title
      t.string :authors
      t.integer :year_of_publication
      t.string :publication_type

      t.timestamps
    end
  end
end
