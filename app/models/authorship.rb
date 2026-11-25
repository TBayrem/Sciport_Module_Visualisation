# ============================================================
# Model: Authorship
#
# Desc:
# Repräsentiert einen Eintrag in der Autorenliste einer
# wissenschaftlichen Publikation.
#
# Ein Autoreneintrag ist keine verwaltete Person aus der
# SciPort-Datenbank. Er enthält nur die Namensangaben aus
# dem Publikations-XML. Eine Publikation kann sehr viele
# Autoren haben, von denen nur wenige als Person in der
# Tabelle people existieren. Die Verbindung zu verwalteten
# Personen läuft getrennt über people_publications.
#
# Anwendungsfälle:
# - Vollständige Autorenliste einer Publikation anzeigen
# - Reihenfolge der Autoren erhalten
# - Autorennamen in Zitierform ausgeben
# ============================================================

class Authorship < ApplicationRecord
  # ----------------------------------------------------------
  # 1. Beziehung zur Publikation
  #
  # Jeder Autoreneintrag gehört zu genau einer Publikation
  # und existiert nur zusammen mit ihr. Wird die Publikation
  # gelöscht, werden auch ihre Autoreneinträge gelöscht.
  # ----------------------------------------------------------

  belongs_to :publication, inverse_of: :authorships


  # ----------------------------------------------------------
  # 2. Validierung des Nachnamens
  #
  # Ein Autoreneintrag ohne Nachnamen ist nicht zitierfähig
  # und kann in der Autorenliste nicht angezeigt werden.
  # ----------------------------------------------------------

  validates :last_name, presence: true


  # ----------------------------------------------------------
  # 3. Validierung der Autorenposition
  #
  # Die Position gibt die Reihenfolge in der Autorenliste an
  # und wird wie im XML ab 0 gezählt. Innerhalb einer
  # Publikation darf jede Position nur einmal vorkommen.
  # Das verhindert doppelte Autoreneinträge bei erneutem
  # Import.
  # ----------------------------------------------------------

  validates :position,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            uniqueness: { scope: :publication_id },
            allow_nil: true


  # ----------------------------------------------------------
  # 4. Methoden für die Visualisierung
  # ----------------------------------------------------------

  # /*
  # Title: full_name
  #
  # Desc:
  # Implementiert den Anwendungsfall
  # "Autoren einer Publikation anzeigen".
  #
  # Die Methode kombiniert Vor- und Nachnamen eines
  # Autoreneintrags zu einem Anzeigenamen.
  # Fehlende Namensbestandteile werden übersprungen.
  #
  # Parameters:
  # - Keine expliziten Parameter.
  # - Verwendet first_name und last_name des Authorship-Objekts.
  #
  # Returns:
  # - String mit dem vollständigen Namen, z. B. "Ralf Keidel".
  # */
  def full_name
    [ first_name, last_name ].compact_blank.join(" ")
  end


  # /*
  # Title: citation_name
  #
  # Desc:
  # Implementiert den Anwendungsfall
  # "Autorennamen in Zitierform ausgeben".
  #
  # Die Methode liefert den Namen im Format der
  # Publikationslisten des SciPort-Webservice.
  #
  # Parameters:
  # - Keine expliziten Parameter.
  # - Verwendet first_name und last_name des Authorship-Objekts.
  #
  # Returns:
  # - String im Format "Nachname, Vorname", z. B. "Keidel, Ralf".
  # */
  def citation_name
    [ last_name, first_name ].compact_blank.join(", ")
  end
end
