class CreatePublicationsResearchProjects < ActiveRecord::Migration[8.1]
  def change
    # Join-Tabelle für die n:m-Beziehung:
    # Ein Forschungsprojekt kann mehrere Publikationen haben.
    # Eine Publikation kann mehreren Forschungsprojekten zugeordnet sein.
    create_join_table :publications, :research_projects do |t|
      # Verhindert doppelte Projekt-Publikation-Zuordnungen.
      t.index [ :publication_id, :research_project_id ], unique: true

      # Beschleunigt die Suche nach Publikationen eines Projekts.
      t.index [ :research_project_id, :publication_id ]
    end

    # Fremdschlüssel sichern die referenzielle Integrität.
    add_foreign_key :publications_research_projects, :publications
    add_foreign_key :publications_research_projects, :research_projects
  end
end
