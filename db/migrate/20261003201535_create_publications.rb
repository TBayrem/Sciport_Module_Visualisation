class CreatePublications < ActiveRecord::Migration[8.1]
  def change
    create_table :publications do |t|
      t.string :title
      t.text :abstract
      t.integer :publication_year
      t.string :doi

      t.timestamps
    end
  end
end
