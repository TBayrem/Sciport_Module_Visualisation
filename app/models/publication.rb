# ================================================================
# PUBLICATION MODEL
# ================================================================
# Titel: Publication Model
# Beschreibung: Repräsentiert eine wissenschaftliche Publikation.
#
# @author Sciport Module Visualisation Team
# @version 1.0
# @since 2026-08-27
# ================================================================

class Publication < ApplicationRecord
  # ==============================================================
  # ASSOZIATIONEN
  # ==============================================================
  has_and_belongs_to_many :facilities
  has_and_belongs_to_many :people
  has_and_belongs_to_many :research_projects

  # ==============================================================
  # VALIDIERUNGEN
  # ==============================================================
  validates :title, presence: true
end
