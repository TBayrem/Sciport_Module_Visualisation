# ============================================================
# Datei: lib/analysis/text_collector.rb
#
# Desc:
#   Schritt 1 der Analyse: sammelt für jede Person den Text,
#   der ihr Forschungsprofil beschreibt.
#
#   Quellen je Person:
#     - Forschungsgebiet (people.field_of_research)
#     - Titel, Beschreibung und Schlagwörter ihrer
#       Forschungsprojekte
#     - Titel und Abstracts ihrer Publikationen
#
#   Berücksichtigt werden nur Personen mit mindestens einer
#   Rolle, also dieselben Personen, die auch im Netzwerk
#   erscheinen. Personen ohne jeden Text fallen heraus, weil
#   sich für sie kein Profil berechnen lässt.
#
#   Die Texte werden mit drei Abfragen (string_agg in
#   PostgreSQL) gesammelt, nicht Person für Person.
#
# Rückgabe von collect:
#   Hash { person_id => "zusammengefügter Text" }
# ============================================================

module Analysis
  class TextCollector
    # Personen mit weniger Zeichen haben kein aussagekräftiges
    # Profil und werden nicht analysiert.
    MIN_TEXT_LENGTH = 30

    # Sammelt die Texte aller Personen.
    def collect
      texts = Hash.new { |hash, person_id| hash[person_id] = [] }

      add_rows(texts, research_field_rows)
      add_rows(texts, project_rows)
      add_rows(texts, publication_rows)

      texts
        .transform_values { |parts| parts.join(" ").squish }
        .select { |_person_id, text| text.length >= MIN_TEXT_LENGTH }
    end

    private

    # Hängt die Textzeilen [person_id, text] an die Sammlung an.
    def add_rows(texts, rows)
      rows.each do |person_id, text|
        texts[person_id.to_i] << text if text.present?
      end
    end

    # Forschungsgebiet je Person (nur Personen mit Rolle).
    def research_field_rows
      select_rows(<<~SQL)
        SELECT p.id, p.field_of_research
        FROM people p
        WHERE p.id IN (SELECT person_id FROM roles)
      SQL
    end

    # Titel, Beschreibung und Schlagwörter aller Projekte einer
    # Person, zu einem Text zusammengefügt.
    def project_rows
      select_rows(<<~SQL)
        SELECT pr.person_id,
               string_agg(concat_ws(' ', r.title, r.description, r.keywords), ' ')
        FROM people_research_projects pr
        JOIN research_projects r ON r.id = pr.research_project_id
        WHERE pr.person_id IN (SELECT person_id FROM roles)
        GROUP BY pr.person_id
      SQL
    end

    # Titel und Abstracts aller Publikationen einer Person.
    def publication_rows
      select_rows(<<~SQL)
        SELECT pp.person_id,
               string_agg(concat_ws(' ', pu.title, pu.abstract), ' ')
        FROM people_publications pp
        JOIN publications pu ON pu.id = pp.publication_id
        WHERE pp.person_id IN (SELECT person_id FROM roles)
        GROUP BY pp.person_id
      SQL
    end

    def select_rows(sql)
      ActiveRecord::Base.connection.select_rows(sql)
    end
  end
end
