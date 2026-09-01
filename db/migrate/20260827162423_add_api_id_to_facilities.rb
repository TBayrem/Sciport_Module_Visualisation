class AddApiIdToFacilities < ActiveRecord::Migration[7.1]
  def change
    add_column :facilities, :api_id, :string
    add_column :facilities, :href, :string
    add_index :facilities, :api_id
  end
end
