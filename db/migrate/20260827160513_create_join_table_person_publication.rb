class CreateJoinTablePersonPublication < ActiveRecord::Migration[8.1]
  def change
    create_join_table :people, :publications do |t|
      # t.index [:person_id, :publication_id]
      # t.index [:publication_id, :person_id]
    end
  end
end
