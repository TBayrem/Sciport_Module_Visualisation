# ============================================================
# Model: Person
#
# Desc:
# Repräsentiert eine forschende Person aus der SciPort-
# Datenbank. Das Model verwaltet ihre institutionellen
# Zugehörigkeiten sowie die Beziehungen zu Forschungsprojekten
# und wissenschaftlichen Publikationen.
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
  # ----------------------------------------------------------

  has_many :roles, dependent: :destroy

  has_many :facilities, through: :roles


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
  # 4. Methoden für die Visualisierung
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
    [ first_name, last_name ]
      .compact
      .reject(&:blank?)
      .join(" ")
  end
end
