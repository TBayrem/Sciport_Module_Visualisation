class RenameNameToDescriptionInRoles < ActiveRecord::Migration[8.1]
  def change
    # Benennt die bestehende Spalte "name" in "description" um.
    # Vorhandene Rollenwerte bleiben dabei erhalten.
    rename_column :roles, :name, :description
  end
end
