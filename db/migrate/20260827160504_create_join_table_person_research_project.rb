class CreateJoinTablePersonResearchProject < ActiveRecord::Migration[8.1]
  def change
    create_join_table :people, :research_projects do |t|
      # t.index [:person_id, :research_project_id]
      # t.index [:research_project_id, :person_id]
    end
  end
end
