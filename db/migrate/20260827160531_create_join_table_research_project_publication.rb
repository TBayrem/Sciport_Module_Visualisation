class CreateJoinTableResearchProjectPublication < ActiveRecord::Migration[8.1]
  def change
    create_join_table :research_projects, :publications do |t|
      # t.index [:research_project_id, :publication_id]
      # t.index [:publication_id, :research_project_id]
    end
  end
end
