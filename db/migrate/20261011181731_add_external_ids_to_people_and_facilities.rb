class AddExternalIdsToPeopleAndFacilities < ActiveRecord::Migration[8.1]
  def change
    # SciPort-ID einer Person speichern.
    # Die ID wird beim Import zur Wiedererkennung verwendet.
    add_column :people, :external_id, :string

    # SciPort-ID einer Einrichtung speichern.
    add_column :facilities, :external_id, :string

    # Eindeutige IDs verhindern doppelte Importe.
    # NULL bleibt erlaubt für vorhandene Testdaten.
    add_index :people, :external_id, unique: true
    add_index :facilities, :external_id, unique: true
  end
end
