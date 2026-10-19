# ============================================================
# Model: Facility
#
# Desc:
# Repräsentiert eine wissenschaftliche Einrichtung aus der
# SciPort-Datenbank.
#
# Das Model verwaltet:
# - die Hierarchie zwischen Einrichtungen,
# - die Zugehörigkeit von Forschenden über Rollen,
# - die Verknüpfung mit Forschungsprojekten,
# - die Verknüpfung mit wissenschaftlichen Publikationen.
#
# Anwendungsfälle:
# - Einrichtungen im Forschungsnetzwerk darstellen
# - Forschende nach Einrichtungen filtern
# - Institutionelle Zugehörigkeiten untersuchen
# - Einrichtungen und ihre Untereinrichtungen analysieren
# ============================================================

class Facility < ApplicationRecord
  # ----------------------------------------------------------
  # 1. Hierarchische Beziehungen zwischen Einrichtungen
  #
  # Eine Einrichtung kann einer übergeordneten Einrichtung
  # zugeordnet sein und mehrere Untereinrichtungen besitzen.
  # Dadurch lassen sich beispielsweise Hochschulen und
  # ihre organisatorischen Untereinheiten abbilden.
  # ----------------------------------------------------------

  belongs_to :parent,
             class_name: "Facility",
             optional: true

  has_many :sub_facilities,
           class_name: "Facility",
           foreign_key: :parent_id,
           inverse_of: :parent


  # ----------------------------------------------------------
  # 2. Beziehungen zu Rollen und Forschenden
  #
  # Rollen verbinden Einrichtungen mit Forschenden.
  # Über diese Beziehungen kann das Forschungsnetzwerk
  # anzeigen, welche Personen einer Einrichtung angehören.
  # ----------------------------------------------------------

  has_many :roles

  has_many :people, through: :roles


  # ----------------------------------------------------------
  # 3. Beziehungen zu Forschungsprojekten
  #
  # Eine Einrichtung kann an mehreren Forschungsprojekten
  # beteiligt sein. Ein Projekt kann wiederum mit mehreren
  # Einrichtungen verbunden sein.
  #
  # Diese Beziehung unterstützt später die Untersuchung
  # institutioneller Projektbeteiligungen.
  # ----------------------------------------------------------

  has_and_belongs_to_many :research_projects


  # ----------------------------------------------------------
  # 4. Beziehungen zu wissenschaftlichen Publikationen
  #
  # Einrichtungen können mit mehreren wissenschaftlichen
  # Publikationen verknüpft sein. Damit lassen sich später
  # Publikationen nach institutioneller Beteiligung auswerten.
  # ----------------------------------------------------------

  has_and_belongs_to_many :publications


  # ----------------------------------------------------------
  # 5. Methoden für die Visualisierung
  # ----------------------------------------------------------

  # /*
  # Title: display_name
  #
  # Desc:
  # Implementiert den Anwendungsfall
  # "Wissenschaftliche Einrichtungen identifizieren".
  #
  # Die Methode liefert den Namen einer Einrichtung für
  # die Anzeige im Einrichtungsfilter, in Tooltips und
  # im Detailbereich des Forschungsnetzwerks.
  #
  # Parameters:
  # - Keine expliziten Parameter.
  # - Verwendet das Attribut name des Facility-Objekts.
  #
  # Returns:
  # - String mit dem Namen der Einrichtung.
  # */
  def display_name
    name.to_s.strip
  end


  # /*
  # Title: root_facility?
  #
  # Desc:
  # Implementiert den Anwendungsfall
  # "Hierarchische Einrichtungen unterscheiden".
  #
  # Die Methode prüft, ob eine Einrichtung keine
  # übergeordnete Einrichtung besitzt. Solche Einrichtungen
  # können später als Ausgangspunkte für hierarchische
  # Einrichtungsfilter verwendet werden.
  #
  # Parameters:
  # - Keine expliziten Parameter.
  # - Verwendet parent_id des Facility-Objekts.
  #
  # Returns:
  # - true, wenn keine übergeordnete Einrichtung existiert.
  # - false, wenn eine übergeordnete Einrichtung existiert.
  # */
  def root_facility?
    parent_id.nil?
  end
end
