class CreateResearchProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :research_projects do |t|
      t.string :title
      t.text :description
      t.date :start_date
      t.date :end_date
      t.string :funding_by

      t.timestamps
    end
  end
end
