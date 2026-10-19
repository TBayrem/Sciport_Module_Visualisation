class CreatePeople < ActiveRecord::Migration[8.1]
  def change
    create_table :people do |t|
      t.string :first_name
      t.string :last_name
      t.string :title
      t.text :field_of_research

      t.timestamps
    end
  end
end
