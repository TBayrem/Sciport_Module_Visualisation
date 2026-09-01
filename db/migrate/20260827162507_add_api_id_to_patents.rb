class AddApiIdToPatents < ActiveRecord::Migration[7.1]
  def change
    add_column :patents, :api_id, :string
    add_column :patents, :href, :string
    add_index :patents, :api_id
  end
end
