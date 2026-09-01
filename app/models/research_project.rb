# ================================================================
# RESEARCH PROJECT MODEL
# ================================================================
# Titel: Research Project Model
# Beschreibung: Repräsentiert ein Forschungsprojekt.
#
# @author Sciport Module Visualisation Team
# @version 1.0
# @since 2026-08-27
# ================================================================

class ResearchProject < ApplicationRecord
  # ==============================================================
  # ASSOZIATIONEN
  # ==============================================================
  has_and_belongs_to_many :facilities
  has_and_belongs_to_many :people
  has_and_belongs_to_many :publications

  # ==============================================================
  # VALIDIERUNGEN
  # ==============================================================
  validates :title, presence: true
end
