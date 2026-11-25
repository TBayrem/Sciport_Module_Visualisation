# ============================================================
# Model: ResearchProject
#
# Desc:
# Repräsentiert ein wissenschaftliches Forschungsprojekt
# innerhalb der SciPort-Datenbank.
#
# Das Model verwaltet die Beziehungen zwischen Projekten,
# beteiligten Forschenden, wissenschaftlichen Einrichtungen
# und zugehörigen Publikationen. Projekte sind direkt mit
# Personen verknüpft und nicht über Rollen.
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


  # ----------------------------------------------------------
  # 5. Validierung der externen ID
  #
  # Die external_id ist die ID des Projekts auf
  # rlp-forschung.de. Sie muss eindeutig sein, damit ein
  # erneuter Import keine Duplikate erzeugt. Sie darf leer
  # sein, weil bereits vorhandene Projekte noch keine
  # external_id besitzen.
  # ----------------------------------------------------------

  validates :external_id, uniqueness: true, allow_nil: true


  # ----------------------------------------------------------
  # 6. Validierung der Projektlaufzeit
  #
  # Das Enddatum eines Projekts darf nicht vor seinem
  # Startdatum liegen.
  # ----------------------------------------------------------

  validate :end_date_not_before_start_date


  # ----------------------------------------------------------
  # 7. Scope für laufende Projekte
  #
  # running liefert alle Projekte, die heute laufen.
  # Ein fehlendes Start- oder Enddatum gilt als offen.
  # ----------------------------------------------------------

  scope :running, lambda {
    today = Date.current
    where("start_date IS NULL OR start_date <= ?", today)
      .where("end_date IS NULL OR end_date >= ?", today)
  }


  # ----------------------------------------------------------
  # 8. Methoden für die Visualisierung
  # ----------------------------------------------------------

  # /*
  # Title: runtime
  #
  # Desc:
  # Implementiert den Anwendungsfall
  # "Projektlaufzeit anzeigen".
  #
  # Die Methode liefert die Laufzeit eines Projekts im
  # Format der Projektlisten des SciPort-Webservice.
  #
  # Parameters:
  # - Keine expliziten Parameter.
  # - Verwendet start_date und end_date des Projekts.
  #
  # Returns:
  # - String mit Start- und Endjahr, z. B. "2000-2010".
  # - "-2010", wenn das Startdatum fehlt.
  # */
  def runtime
    "#{start_date&.year}-#{end_date&.year}"
  end

  private

  # /*
  # Title: end_date_not_before_start_date
  #
  # Desc:
  # Implementiert den Anwendungsfall
  # "Gültige Projektlaufzeit sicherstellen".
  #
  # Die Methode prüft, ob das Enddatum vor dem Startdatum
  # liegt. Fehlt eines der beiden Daten, wird nicht geprüft.
  #
  # Parameters:
  # - Keine expliziten Parameter.
  # - Verwendet start_date und end_date des Projekts.
  #
  # Returns:
  # - Nichts. Bei ungültiger Laufzeit wird ein Fehler zu
  #   :end_date hinzugefügt und das Speichern verhindert.
  # */
  def end_date_not_before_start_date
    return if start_date.blank? || end_date.blank?

    errors.add(:end_date, "darf nicht vor dem Startdatum liegen") if end_date < start_date
  end
end
