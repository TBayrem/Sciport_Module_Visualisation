class CreateFacilitiesPublications < ActiveRecord::Migration[8.1]
  def change
    # Join-Tabelle für die n:m-Beziehung:
    # Eine Einrichtung kann mehrere Publikationen haben.
    # Eine Publikation kann mehreren Einrichtungen zugeordnet sein.
    create_join_table :facilities, :publications do |t|
      # Verhindert doppelte Verknüpfungen.
      t.index [ :facility_id, :publication_id ], unique: true

      # Beschleunigt die Suche nach Einrichtungen
      # einer bestimmten Publikation.
      t.index [ :publication_id, :facility_id ]
    end

    # Fremdschlüssel sichern die Datenintegrität.
    # Eine Verknüpfung darf nur auf existierende
    # Einrichtungen und Publikationen verweisen.
    add_foreign_key :facilities_publications, :facilities
    add_foreign_key :facilities_publications, :publications
  end
end
