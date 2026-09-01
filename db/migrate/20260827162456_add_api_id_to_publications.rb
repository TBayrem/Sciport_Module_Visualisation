class AddApiIdToPublications < ActiveRecord::Migration[7.1]
  def change
    add_column :publications, :api_id, :string
    add_column :publications, :href, :string
    add_index :publications, :api_id
  end
end
