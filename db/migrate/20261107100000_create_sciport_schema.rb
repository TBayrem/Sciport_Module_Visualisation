# ============================================================
# Migration: CreateSciportSchema
#
# Desc:
# Legt das vollständige Datenbankschema für die aus SciPort
# RLP abgeleitete Datenstruktur auf einmal an.
#
# Das Schema setzt die Ergebnisse der Besprechung um:
# - Eine Rolle verbindet nur Person und Einrichtung.
# - Forschungsprojekte sind direkt mit Personen,
#   Einrichtungen und Publikationen verknüpft.
# - Autoreneinträge (authorships) sind von verwalteten
#   Personen (people) getrennt.
# - Publikationen sind direkt mit Personen, Einrichtungen
#   und Forschungsprojekten verknüpft.
#
# Anwendungsfälle:
# - Einrichtungen, Personen, Projekte und Publikationen
#   aus rlp-forschung.de speichern
# - Datensätze beim erneuten Import über external_id
#   wiederfinden
# - Doppelte Zuordnungen und verwaiste Einträge verhindern
# ============================================================

class CreateSciportSchema < ActiveRecord::Migration[8.1]
  def change
    # ----------------------------------------------------------
    # 1. Einrichtungen
    #
    # Eine Einrichtung kann einer übergeordneten Einrichtung
    # angehören (parent_id). Wird die übergeordnete
    # Einrichtung gelöscht, bleiben die Untereinrichtungen
    # erhalten und verlieren nur ihren Elternteil.
    #
    # external_id ist die ID aus rlp-forschung.de und eindeutig.
    # ----------------------------------------------------------

    create_table :facilities do |t|
      t.string :external_id, null: false
      t.string :name, null: false
      t.string :facility_type
      t.references :parent, foreign_key: { to_table: :facilities, on_delete: :nullify }
      t.timestamps
    end

    add_index :facilities, :external_id, unique: true


    # ----------------------------------------------------------
    # 2. Personen
    #
    # Verwaltete Forschende aus rlp-forschung.de.
    # Der Index auf Nach- und Vorname beschleunigt die
    # Namenssuche und die alphabetische Sortierung.
    # ----------------------------------------------------------

    create_table :people do |t|
      t.string :external_id, null: false
      t.string :first_name
      t.string :last_name
      t.string :title
      t.text :field_of_research
      t.timestamps
    end

    add_index :people, :external_id, unique: true
    add_index :people, %i[last_name first_name]


    # ----------------------------------------------------------
    # 3. Rollen
    #
    # Eine Rolle verbindet genau eine Person mit genau einer
    # Einrichtung. Die Beschreibung ist optional, weil sie im
    # XML fehlen kann. Dieselbe Rolle darf eine Person in
    # derselben Einrichtung nur einmal haben.
    #
    # Wird eine Person oder Einrichtung gelöscht, werden ihre
    # Rollen mitgelöscht.
    # ----------------------------------------------------------

    create_table :roles do |t|
      t.references :person, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :facility, null: false, foreign_key: { on_delete: :cascade }
      t.string :description
      t.timestamps
    end

    add_index :roles, %i[person_id facility_id description],
              unique: true, name: "index_roles_on_person_facility_description"


    # ----------------------------------------------------------
    # 4. Forschungsprojekte
    #
    # external_id ist die ID aus rlp-forschung.de, z. B. 458
    # aus /public/research_projects/458.xml.
    # ----------------------------------------------------------

    create_table :research_projects do |t|
      t.string :external_id
      t.string :title, null: false
      t.text :description
      t.text :keywords
      t.date :start_date
      t.date :end_date
      t.timestamps
    end

    add_index :research_projects, :external_id, unique: true


    # ----------------------------------------------------------
    # 5. Publikationen
    #
    # external_id ist die ID aus rlp-forschung.de, z. B. 778
    # aus /public/publications/778.xml.
    # doi speichert den persistenten Identifier aus dem XML.
    # ----------------------------------------------------------

    create_table :publications do |t|
      t.string :external_id
      t.string :title, null: false
      t.text :abstract
      t.integer :publication_year
      t.string :doi
      t.timestamps
    end

    add_index :publications, :external_id, unique: true
    add_index :publications, :publication_year


    # ----------------------------------------------------------
    # 6. Autoreneinträge
    #
    # Ein Autoreneintrag gehört zu genau einer Publikation und
    # ist keine verwaltete Person. Die Position gibt die
    # Reihenfolge in der Autorenliste an und ist pro
    # Publikation eindeutig.
    #
    # Wird die Publikation gelöscht, werden ihre
    # Autoreneinträge mitgelöscht.
    # ----------------------------------------------------------

    create_table :authorships do |t|
      t.references :publication, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.string :first_name
      t.string :last_name, null: false
      t.integer :position
      t.string :role
      t.timestamps
    end

    add_index :authorships, %i[publication_id position],
              unique: true, name: "index_authorships_on_publication_id_and_position"


    # ----------------------------------------------------------
    # 7. Zuordnungstabellen für has_and_belongs_to_many
    #
    # Rails erwartet die Tabellennamen in alphabetischer
    # Reihenfolge (z. B. facilities_publications).
    # Jede Zuordnung darf nur einmal vorkommen. Ein zweiter
    # Index in umgekehrter Richtung beschleunigt Abfragen
    # von der anderen Seite.
    #
    # Wird ein beteiligter Datensatz gelöscht, wird die
    # Zuordnung mitgelöscht.
    # ----------------------------------------------------------

    # Einrichtung <-> Publikation
    create_join_table :facilities, :publications do |t|
      t.index %i[facility_id publication_id], unique: true, name: "index_facilities_publications_unique"
      t.index :publication_id
    end
    add_foreign_key :facilities_publications, :facilities, on_delete: :cascade
    add_foreign_key :facilities_publications, :publications, on_delete: :cascade

    # Einrichtung <-> Forschungsprojekt
    create_join_table :facilities, :research_projects do |t|
      t.index %i[facility_id research_project_id], unique: true, name: "index_facilities_research_projects_unique"
      t.index :research_project_id
    end
    add_foreign_key :facilities_research_projects, :facilities, on_delete: :cascade
    add_foreign_key :facilities_research_projects, :research_projects, on_delete: :cascade

    # Person <-> Publikation
    create_join_table :people, :publications do |t|
      t.index %i[person_id publication_id], unique: true, name: "index_people_publications_unique"
      t.index :publication_id
    end
    add_foreign_key :people_publications, :people, on_delete: :cascade
    add_foreign_key :people_publications, :publications, on_delete: :cascade

    # Person <-> Forschungsprojekt
    create_join_table :people, :research_projects do |t|
      t.index %i[person_id research_project_id], unique: true, name: "index_people_research_projects_unique"
      t.index :research_project_id
    end
    add_foreign_key :people_research_projects, :people, on_delete: :cascade
    add_foreign_key :people_research_projects, :research_projects, on_delete: :cascade

    # Publikation <-> Forschungsprojekt
    create_join_table :publications, :research_projects do |t|
      t.index %i[publication_id research_project_id], unique: true, name: "index_publications_research_projects_unique"
      t.index :research_project_id
    end
    add_foreign_key :publications_research_projects, :publications, on_delete: :cascade
    add_foreign_key :publications_research_projects, :research_projects, on_delete: :cascade
  end
end
