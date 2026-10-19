
# ============================================================
# Datei: app/models/application_record.rb
#
# Desc:
# Definiert die gemeinsame Basisklasse aller
# Active-Record-Modelle der Rails-Anwendung.
#
# Anwendungsfälle:
# - Gemeinsame Grundlage für Datenbankmodelle bereitstellen
# - Vererbung von ActiveRecord::Base ermöglichen
# - Modelle wie Person, Facility und Role unterstützen
# - Zentrale Erweiterungen für Datenbankmodelle ermöglichen
# ============================================================

class ApplicationRecord < ActiveRecord::Base
  # ----------------------------------------------------------
  # 1. Abstrakte Basisklasse
  #
  # ApplicationRecord besitzt keine eigene Datenbanktabelle.
  #
  # Die Klasse dient ausschließlich als gemeinsame
  # Grundlage für die eigentlichen Datenbankmodelle.
  #
  # Beispiele:
  #
  # class Person < ApplicationRecord
  # class Facility < ApplicationRecord
  # class Role < ApplicationRecord
  #
  # abstract_class verhindert, dass Rails für
  # ApplicationRecord eine eigene Tabelle erwartet.
  # ----------------------------------------------------------

  self.abstract_class = true
end
