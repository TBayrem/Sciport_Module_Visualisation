# ================================================================
# FACILITY MODEL
# ================================================================
# Titel: Facility Model
# Beschreibung: Repräsentiert eine Einrichtung (Universität, FH, Institut).
#
# @author Sciport Module Visualisation Team
# @version 1.0
# @since 2026-08-27
# ================================================================

class Facility < ApplicationRecord
  # ==============================================================
  # ASSOZIATIONEN
  # ==============================================================
  has_and_belongs_to_many :people
  has_and_belongs_to_many :research_projects
  has_and_belongs_to_many :publications

  # ==============================================================
  # VALIDIERUNGEN
  # ==============================================================
  validates :name, presence: true

  # ==============================================================
  # INSTANZMETHODEN
  # ==============================================================

  # Title: Anzeigename
  # Beschreibung: Gibt einen lesbaren Namen mit Ort zurück.
  #
  # @return [String] Name und Ort der Einrichtung
  # ==============================================================
  def display_name
    city.present? ? "#{name} (#{city})" : name
  end
end
