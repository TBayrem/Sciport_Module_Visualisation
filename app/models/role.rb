# ============================================================
# Model: Role
#
# Desc:
# Repräsentiert eine institutionelle Rolle einer Person
# innerhalb einer wissenschaftlichen Einrichtung.
#
# Eine Rolle verbindet genau eine Person mit genau einer
# Einrichtung und beschreibt deren Funktion oder Position.
# Eine Rolle hat keine Beziehung zu Forschungsprojekten.
#
# Die Beschreibung ist optional, weil sie im Personen-XML
# von rlp-forschung.de fehlen kann. Auch ohne Beschreibung
# bleibt die Zugehörigkeit einer Person zu einer Einrichtung
# erhalten.
#
# Anwendungsfälle:
# - Institutionelle Zugehörigkeiten von Forschenden ermitteln
# - Forschende nach wissenschaftlichen Einrichtungen filtern
# - Beziehungen zwischen Personen und Einrichtungen darstellen
# - Funktionen und Positionen von Forschenden anzeigen
# ============================================================

class Role < ApplicationRecord
  # ----------------------------------------------------------
  # 1. Beziehung zu einer forschenden Person
  #
  # Jede Rolle gehört zu genau einer Person. Eine Person
  # kann mehrere Rollen besitzen, beispielsweise an
  # unterschiedlichen wissenschaftlichen Einrichtungen.
  # Über diese Beziehung können die institutionellen
  # Zugehörigkeiten einer Person abgefragt werden.
  # ----------------------------------------------------------

  belongs_to :person, inverse_of: :roles


  # ----------------------------------------------------------
  # 2. Beziehung zu einer wissenschaftlichen Einrichtung
  #
  # Jede Rolle ist einer Einrichtung zugeordnet.
  # Die Verbindung zwischen Person und Einrichtung
  # bildet die Grundlage für den Einrichtungsfilter
  # und die institutionellen Kanten im Netzwerk.
  # ----------------------------------------------------------

  belongs_to :facility, inverse_of: :roles


  # ----------------------------------------------------------
  # 3. Normalisierung der Rollenbeschreibung
  #
  # Leerzeichen am Anfang und Ende werden entfernt. Eine
  # leere Beschreibung wird als nil gespeichert, damit es
  # in der Datenbank nur eine Form von "keine Beschreibung"
  # gibt.
  # ----------------------------------------------------------

  normalizes :description, with: ->(description) { description.strip.presence }


  # ----------------------------------------------------------
  # 4. Eindeutigkeit der Rolle
  #
  # Dieselbe Person darf in derselben Einrichtung dieselbe
  # Rolle nur einmal besitzen. Das gilt auch für Rollen ohne
  # Beschreibung. Dadurch entstehen bei einem erneuten
  # Import keine doppelten Rollen.
  # ----------------------------------------------------------

  validates :description, uniqueness: { scope: %i[person_id facility_id] }


  # ----------------------------------------------------------
  # 5. Methoden für die Visualisierung
  # ----------------------------------------------------------

  # /*
  # Title: display_description
  #
  # Desc:
  # Implementiert den Anwendungsfall
  # "Funktionen und Positionen von Forschenden anzeigen".
  #
  # Die Methode liefert die Rollenbeschreibung für Tooltips
  # und den Detailbereich. Fehlt die Beschreibung, wird ein
  # Platzhalter angezeigt.
  #
  # Parameters:
  # - Keine expliziten Parameter.
  # - Verwendet description des Role-Objekts.
  #
  # Returns:
  # - String mit der Beschreibung oder "Ohne Bezeichnung".
  # */
  def display_description
    description || "Ohne Bezeichnung"
  end


  # /*
  # Title: root_facility
  #
  # Desc:
  # Implementiert den Anwendungsfall
  # "Zugehörige Hochschule einer Rolle ermitteln".
  #
  # Die Methode liefert die oberste Einrichtung, zu der
  # die Einrichtung der Rolle gehört, z. B. die Hochschule
  # zu einem Fachbereich. Sie ersetzt das Element
  # <root-facility> aus dem Personen-XML.
  #
  # Parameters:
  # - Keine expliziten Parameter.
  # - Verwendet die Einrichtung des Role-Objekts.
  #
  # Returns:
  # - Facility-Objekt ohne übergeordnete Einrichtung.
  # */
  def root_facility
    facility.root_facility
  end
end
