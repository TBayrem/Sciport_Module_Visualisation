
# ============================================================
# Model: ResearchProject
#
# Desc:
# Repräsentiert ein wissenschaftliches Forschungsprojekt
# innerhalb der SciPort-Datenbank.
#
# Das Model verwaltet die Beziehungen zwischen Projekten,
# beteiligten Forschenden, wissenschaftlichen Einrichtungen
# und zugehörigen Publikationen.
#
# Anwendungsfälle:
# - Forschungsprojekte verwalten und abfragen
# - Beteiligte Forschende eines Projekts ermitteln
# - Projektkooperationen zwischen Forschenden untersuchen
# - Forschungsprojekte nach Einrichtungen auswerten
# - Zusammenhänge zwischen Projekten und Publikationen erfassen
# ============================================================

class ResearchProject < ApplicationRecord
  # ----------------------------------------------------------
  # 1. Beziehungen zu Forschenden
  #
  # Ein Forschungsprojekt kann mehrere beteiligte Personen
  # besitzen. Gleichzeitig kann eine Person an mehreren
  # Projekten beteiligt sein. Diese Viele-zu-viele-Beziehung
  # ermöglicht später die Ermittlung gemeinsamer Projekte
  # als Grundlage für Kooperationsverbindungen im Netzwerk.
  # ----------------------------------------------------------

  has_and_belongs_to_many :people


  # ----------------------------------------------------------
  # 2. Beziehungen zu wissenschaftlichen Einrichtungen
  #
  # Ein Forschungsprojekt kann mehreren Einrichtungen
  # zugeordnet sein. Ebenso kann eine Einrichtung an
  # mehreren Forschungsprojekten beteiligt sein.
  # Diese Beziehung ermöglicht institutionelle Analysen
  # und eine spätere Filterung nach Projekteinrichtungen.
  # ----------------------------------------------------------

  has_and_belongs_to_many :facilities


  # ----------------------------------------------------------
  # 3. Beziehungen zu wissenschaftlichen Publikationen
  #
  # Ein Forschungsprojekt kann mit mehreren Publikationen
  # verbunden sein. Eine Publikation kann wiederum mehreren
  # Forschungsprojekten zugeordnet werden.
  # Damit können Forschungsergebnisse und Projektbeziehungen
  # gemeinsam ausgewertet werden.
  # ----------------------------------------------------------

  has_and_belongs_to_many :publications


  # ----------------------------------------------------------
  # 4. Validierung des Projekttitels
  #
  # Der Titel dient zur Identifikation eines Projekts
  # in der Datenbank, in Suchergebnissen und später
  # in den Filtern der Netzwerkvisualisierung.
  # Neue Projekte müssen deshalb einen Titel besitzen.
  # ----------------------------------------------------------

  validates :title, presence: true
end
