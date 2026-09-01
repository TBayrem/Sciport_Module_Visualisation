# ================================================================
# PATENT MODEL
# ================================================================
# Titel: Patent Model
# Beschreibung: Repräsentiert ein Patent.
#
# @author Sciport Module Visualisation Team
# @version 1.0
# @since 2026-08-27
# ================================================================

class Patent < ApplicationRecord
  # ==============================================================
  # ASSOZIATIONEN
  # ==============================================================
  has_and_belongs_to_many :people

  # ==============================================================
  # VALIDIERUNGEN
  # ==============================================================
  validates :title, presence: true
  validates :number, presence: true
end
