class CreatePatents < ActiveRecord::Migration[8.1]
  def change
    create_table :patents do |t|
      t.string :title
      t.string :number
      t.string :holder

      t.timestamps
    end
  end
end
