class CreateJoinTableFacilityPublication < ActiveRecord::Migration[8.1]
  def change
    create_join_table :facilities, :publications do |t|
      # t.index [:facility_id, :publication_id]
      # t.index [:publication_id, :facility_id]
    end
  end
end
