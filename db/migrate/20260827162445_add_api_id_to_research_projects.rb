class AddApiIdToResearchProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :research_projects, :api_id, :string
    add_column :research_projects, :href, :string
    add_index :research_projects, :api_id
  end
end
