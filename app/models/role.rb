
# ============================================================
# Model: Role
#
# Desc:
# Repräsentiert eine institutionelle Rolle einer Person
# innerhalb einer wissenschaftlichen Einrichtung.
#
# Eine Rolle verbindet genau eine Person mit genau einer
# Einrichtung und beschreibt deren Funktion oder Position.
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

  belongs_to :person


  # ----------------------------------------------------------
  # 2. Beziehung zu einer wissenschaftlichen Einrichtung
  #
  # Jede Rolle ist einer Einrichtung zugeordnet.
  # Die Verbindung zwischen Person und Einrichtung
  # bildet die Grundlage für den Einrichtungsfilter
  # und die institutionellen Kanten im Netzwerk.
  # ----------------------------------------------------------

  belongs_to :facility


  # ----------------------------------------------------------
  # 3. Validierung der Rollenbeschreibung
  #
  # Das Feld description enthält die Bezeichnung
  # einer institutionellen Funktion oder Position.
  # Die Validierung verhindert, dass neue Rollen
  # ohne eine Beschreibung gespeichert werden.
  # ----------------------------------------------------------

  validates :description, presence: true
end
