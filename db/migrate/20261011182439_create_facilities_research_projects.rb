class CreateFacilitiesResearchProjects < ActiveRecord::Migration[8.1]
  def change
    # Join-Tabelle für die n:m-Beziehung:
    # Eine Einrichtung kann mehrere Forschungsprojekte haben.
    # Ein Forschungsprojekt kann mehreren Einrichtungen zugeordnet sein.
    create_join_table :facilities, :research_projects do |t|
      # Verhindert doppelte Zuordnungen derselben Einrichtung
      # zu demselben Forschungsprojekt.
      t.index [ :facility_id, :research_project_id ], unique: true

      # Beschleunigt die Suche nach Einrichtungen eines Projekts.
      t.index [ :research_project_id, :facility_id ]
    end

    # Stellt sicher, dass nur vorhandene Einrichtungen
    # und Forschungsprojekte miteinander verknüpft werden.
    add_foreign_key :facilities_research_projects, :facilities
    add_foreign_key :facilities_research_projects, :research_projects
  end
end
