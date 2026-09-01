class CreateJoinTableFacilityResearchProject < ActiveRecord::Migration[8.1]
  def change
    create_join_table :facilities, :research_projects do |t|
      # t.index [:facility_id, :research_project_id]
      # t.index [:research_project_id, :facility_id]
    end
  end
end
