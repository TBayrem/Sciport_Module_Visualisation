# ============================================================
# Model: Person
#
# Desc:
# Repräsentiert eine forschende Person aus der SciPort-
# Datenbank. Das Model verwaltet ihre institutionellen
# Zugehörigkeiten sowie die Beziehungen zu Forschungsprojekten
# und wissenschaftlichen Publikationen.
#
# Namen aus Autorenlisten von Publikationen sind keine
# Personen, sondern Authorship-Einträge.
#
# Anwendungsfälle:
# - Forschende im Netzwerk darstellen
# - Forschende nach Namen suchen
# - Forschende nach Einrichtungen filtern
# - Projekt- und Publikationsbeziehungen analysieren
# ============================================================

class Person < ApplicationRecord
  # ----------------------------------------------------------
  # 1. Beziehungen zu Rollen und Einrichtungen
  #
  # Eine Person kann mehrere Rollen besitzen. Jede Rolle
  # verbindet die Person mit einer Einrichtung. Dadurch
  # können institutionelle Zugehörigkeiten im Netzwerk
  # dargestellt und nach Einrichtungen gefiltert werden.
  #
  # distinct verhindert doppelte Einrichtungen, wenn eine
  # Person in derselben Einrichtung mehrere Rollen hat.
  # ----------------------------------------------------------

  has_many :roles, dependent: :destroy, inverse_of: :person

  has_many :facilities, -> { distinct }, through: :roles


  # ----------------------------------------------------------
  # 2. Beziehungen zu Forschungsprojekten
  #
  # Eine Person kann an mehreren Forschungsprojekten
  # beteiligt sein. Umgekehrt kann ein Forschungsprojekt
  # mehrere Personen umfassen. Diese Beziehung bildet
  # später die Grundlage zur Analyse von Projektkooperationen.
  # ----------------------------------------------------------

  has_and_belongs_to_many :research_projects


  # ----------------------------------------------------------
  # 3. Beziehungen zu wissenschaftlichen Publikationen
  #
  # Eine Person kann mit mehreren Publikationen verknüpft
  # sein. Diese Beziehung ermöglicht später die Analyse
  # gemeinsamer Publikationen und wissenschaftlicher
  # Zusammenarbeit zwischen Forschenden.
  # ----------------------------------------------------------

  has_and_belongs_to_many :publications


  # ----------------------------------------------------------
  # 4. Validierung der externen ID
  #
  # Die external_id ist die ID der Person auf
  # rlp-forschung.de. Sie muss vorhanden und eindeutig sein,
  # damit der Importer eine Person bei erneutem Import
  # wiederfindet und keine Duplikate entstehen.
  # ----------------------------------------------------------

  validates :external_id, presence: true, uniqueness: true


  # ----------------------------------------------------------
  # 5. Scopes für Suche und Sortierung
  #
  # alphabetical sortiert Forschende nach Nachname und
  # Vorname. search_by_name sucht in Vor- und Nachname,
  # ohne auf Groß- und Kleinschreibung zu achten.
  # ----------------------------------------------------------

  scope :alphabetical, -> { order(:last_name, :first_name) }

  scope :search_by_name, lambda { |query|
    pattern = "%#{sanitize_sql_like(query.to_s.strip)}%"
    where("first_name ILIKE :q OR last_name ILIKE :q", q: pattern)
  }


  # ----------------------------------------------------------
  # 6. Methoden für die Visualisierung
  # ----------------------------------------------------------

  # /*
  # Title: full_name
  #
  # Desc:
  # Implementiert den Anwendungsfall
  # "Forschende im Forschungsnetzwerk identifizieren".
  #
  # Die Methode kombiniert den Vornamen und Nachnamen
  # einer Person zu einem vollständigen Anzeigenamen.
  # Fehlende Namensbestandteile werden übersprungen.
  #
  # Parameters:
  # - Keine expliziten Parameter.
  # - Verwendet first_name und last_name des Person-Objekts.
  #
  # Returns:
  # - String mit dem vollständigen Namen der Person.
  # */
  def full_name
    [ first_name, last_name ].compact_blank.join(" ")
  end


  # /*
  # Title: display_name
  #
  # Desc:
  # Implementiert den Anwendungsfall
  # "Forschende mit akademischem Titel anzeigen".
  #
  # Die Methode stellt dem vollständigen Namen den
  # akademischen Titel voran, z. B. "Dr. Hans Meier",
  # für Tooltips und den Detailbereich.
  #
  # Parameters:
  # - Keine expliziten Parameter.
  # - Verwendet title und full_name des Person-Objekts.
  #
  # Returns:
  # - String mit Titel und vollständigem Namen.
  # */
  def display_name
    [ title, full_name ].compact_blank.join(" ")
  end
end
