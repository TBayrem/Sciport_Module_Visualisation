class AddApiIdToPeople < ActiveRecord::Migration[7.1]
  def change
    add_column :people, :api_id, :string
    add_column :people, :href, :string
    add_index :people, :api_id
  end
end
