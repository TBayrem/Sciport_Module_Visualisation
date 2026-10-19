
# ============================================================
# Model: Publication
#
# Desc:
# Repräsentiert eine wissenschaftliche Publikation
# innerhalb der SciPort-Datenbank.
#
# Das Model verwaltet die Beziehungen zu Autoreneinträgen,
# Forschenden, wissenschaftlichen Einrichtungen und
# Forschungsprojekten.
#
# Anwendungsfälle:
# - Wissenschaftliche Publikationen abfragen
# - Autoreneinträge einer Publikation ermitteln
# - Gemeinsame Publikationen von Forschenden untersuchen
# - Publikationen nach Einrichtungen auswerten
# - Publikationen mit Forschungsprojekten verknüpfen
# ============================================================

class Publication < ApplicationRecord
  # ----------------------------------------------------------
  # 1. Beziehungen zu Autoreneinträgen
  #
  # Eine Publikation kann mehrere Autoreneinträge besitzen.
  # Jeder Autoreneintrag enthält die Namensinformationen
  # einer an der Publikation beteiligten Person.
  #
  # Beim Löschen einer Publikation werden auch ihre
  # zugehörigen Autoreneinträge gelöscht.
  # ----------------------------------------------------------

  has_many :authorships, dependent: :destroy


  # ----------------------------------------------------------
  # 2. Beziehungen zu Forschenden
  #
  # Eine Publikation kann mit mehreren Personen aus der
  # SciPort-Datenbank verbunden sein. Eine Person kann
  # wiederum an mehreren Publikationen beteiligt sein.
  #
  # Diese Viele-zu-viele-Beziehung bildet die Grundlage
  # für die spätere Ermittlung von Publikationskooperationen
  # zwischen eindeutig verknüpften Forschenden.
  # ----------------------------------------------------------

  has_and_belongs_to_many :people


  # ----------------------------------------------------------
  # 3. Beziehungen zu wissenschaftlichen Einrichtungen
  #
  # Eine Publikation kann mehreren Einrichtungen
  # zugeordnet sein. Ebenso kann eine Einrichtung
  # mit mehreren Publikationen verbunden sein.
  #
  # Damit können wissenschaftliche Veröffentlichungen
  # nach institutioneller Beteiligung untersucht werden.
  # ----------------------------------------------------------

  has_and_belongs_to_many :facilities


  # ----------------------------------------------------------
  # 4. Beziehungen zu Forschungsprojekten
  #
  # Eine Publikation kann mehreren Forschungsprojekten
  # zugeordnet sein. Ein Forschungsprojekt kann wiederum
  # mehrere Publikationen besitzen.
  #
  # Diese Beziehung ermöglicht es, Publikationen und
  # die zugehörigen Forschungsprojekte gemeinsam
  # auszuwerten.
  # ----------------------------------------------------------

  has_and_belongs_to_many :research_projects


  # ----------------------------------------------------------
  # 5. Validierung des Publikationstitels
  #
  # Der Titel dient zur Identifikation einer Publikation
  # in der Datenbank und in der Visualisierung.
  #
  # Neue Publikationen müssen deshalb einen Titel besitzen.
  # ----------------------------------------------------------

  validates :title, presence: true
end
