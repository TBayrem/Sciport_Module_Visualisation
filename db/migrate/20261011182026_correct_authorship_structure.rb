class CorrectAuthorshipStructure < ActiveRecord::Migration[8.1]
  def up
    # 1. Textfelder für Autorenangaben hinzufügen.
    add_column :authorships, :first_name, :string
    add_column :authorships, :last_name, :string

    # 2. Vorhandene Autorennamen aus people übernehmen.
    # Dadurch bleiben Anna Beispiel und Max Mustermann
    # als textuelle Autorenangaben erhalten.
    execute <<~SQL
      UPDATE authorships
      SET
        first_name = people.first_name,
        last_name  = people.last_name
      FROM people
      WHERE authorships.person_id = people.id;
    SQL

    # 3. Die bisherigen Person-Publikation-Zuordnungen
    # separat sichern, bevor person_id entfernt wird.
    create_join_table :people, :publications do |t|
      t.index [ :person_id, :publication_id ], unique: true
      t.index [ :publication_id, :person_id ]
    end

    execute <<~SQL
      INSERT INTO people_publications (person_id, publication_id)
      SELECT DISTINCT person_id, publication_id
      FROM authorships;
    SQL

    # 4. Falsche Beziehung Authorship -> Person entfernen.
    # Die Beziehung zu Publication bleibt bestehen.
    remove_reference :authorships, :person,
                     foreign_key: true,
                     index: true
  end

  def down
    # Diese Datenumstellung wird bewusst nicht automatisch
    # rückgängig gemacht, weil Autorenangaben ohne Person
    # nach dem neuen Modell gültig sind.
    raise ActiveRecord::IrreversibleMigration
  end
end
