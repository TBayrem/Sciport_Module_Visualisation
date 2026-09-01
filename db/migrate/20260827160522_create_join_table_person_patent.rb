class CreateJoinTablePersonPatent < ActiveRecord::Migration[8.1]
  def change
    create_join_table :people, :patents do |t|
      # t.index [:person_id, :patent_id]
      # t.index [:patent_id, :person_id]
    end
  end
end
