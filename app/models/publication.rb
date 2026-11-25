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
  # Die Einträge werden immer nach ihrer Position sortiert
  # geliefert, damit die Reihenfolge der Autorenliste
  # erhalten bleibt.
  #
  # Beim Löschen einer Publikation werden auch ihre
  # zugehörigen Autoreneinträge gelöscht.
  # ----------------------------------------------------------

  has_many :authorships,
           -> { order(:position) },
           dependent: :destroy,
           inverse_of: :publication


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


  # ----------------------------------------------------------
  # 6. Validierung der externen ID und des Erscheinungsjahres
  #
  # Die external_id ist die ID der Publikation auf
  # rlp-forschung.de. Sie muss eindeutig sein, damit ein
  # erneuter Import keine Duplikate erzeugt. Sie darf leer
  # sein, weil bereits vorhandene Publikationen noch keine
  # external_id besitzen.
  #
  # Das Erscheinungsjahr muss eine ganze Zahl sein.
  # ----------------------------------------------------------

  validates :external_id, uniqueness: true, allow_nil: true

  validates :publication_year, numericality: { only_integer: true }, allow_nil: true


  # ----------------------------------------------------------
  # 7. Scopes für Filter und Sortierung
  #
  # published_in filtert nach einem Jahr oder Jahresbereich,
  # z. B. published_in(2010) oder published_in(2008..2012).
  # newest_first sortiert die neuesten Publikationen nach vorn.
  # ----------------------------------------------------------

  scope :published_in, ->(years) { where(publication_year: years) }

  scope :newest_first, -> { order(publication_year: :desc) }


  # ----------------------------------------------------------
  # 8. Methoden für die Visualisierung
  # ----------------------------------------------------------

  # /*
  # Title: author_list
  #
  # Desc:
  # Implementiert den Anwendungsfall
  # "Autorenliste einer Publikation anzeigen".
  #
  # Die Methode liefert die Autorennamen in Zitierform,
  # getrennt durch Semikolon, wie in den Publikationslisten
  # des SciPort-Webservice. Bei sehr langen Listen kann
  # gekürzt werden; dann wird "et al." angehängt.
  #
  # Parameters:
  # - limit (Integer, optional): maximale Anzahl angezeigter
  #   Namen. Ohne Angabe werden alle Namen ausgegeben.
  #
  # Returns:
  # - String mit den Autorennamen, z. B.
  #   "Keidel, Ralf; Conner, Eric Sean et al."
  # */
  def author_list(limit: nil)
    names = authorships.map(&:citation_name)
    return names.join("; ") if limit.nil? || names.size <= limit

    "#{names.first(limit).join('; ')} et al."
  end
end
