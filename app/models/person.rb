# ================================================================
# PERSON MODEL
# ================================================================
# Titel: Person Model
# Beschreibung: Repräsentiert eine Forscher-Person.
#
# @author Sciport Module Visualisation Team
# @version 1.0
# @since 2026-08-27
# ================================================================

class Person < ApplicationRecord
  # ==============================================================
  # ASSOZIATIONEN
  # ==============================================================
  has_and_belongs_to_many :facilities
  has_and_belongs_to_many :research_projects
  has_and_belongs_to_many :publications
  has_and_belongs_to_many :patents

  # ==============================================================
  # VALIDIERUNGEN
  # ==============================================================
  validates :first_name, presence: true
  validates :last_name, presence: true

  # ==============================================================
  # INSTANZMETHODEN
  # ==============================================================

  # Title: Vollständiger Name
  # Beschreibung: Gibt Vor- und Nachname zurück.
  #
  # @return [String] Vollständiger Name
  # ==============================================================
  def full_name
    "#{first_name} #{last_name}"
  end

  # Title: Anzeigename
  # Beschreibung: Gibt den vollständigen Namen mit Titel zurück.
  #
  # @return [String] Name mit Titel
  # ==============================================================
  def display_name
    title.present? ? "#{title} #{full_name}" : full_name
  end
end
