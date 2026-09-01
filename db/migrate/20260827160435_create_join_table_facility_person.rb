class CreateJoinTableFacilityPerson < ActiveRecord::Migration[8.1]
  def change
    create_join_table :facilities, :people do |t|
      # t.index [:facility_id, :person_id]
      # t.index [:person_id, :facility_id]
    end
  end
end
