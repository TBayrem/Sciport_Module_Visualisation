# ================================================================
# APPLICATION CONTROLLER
# ================================================================
# Titel: Application Controller
# Beschreibung: Basis-Controller für alle anderen Controller.
#
# @author Sciport Module Visualisation Team
# @version 1.0
# @since 2026-08-27
# ================================================================

class ApplicationController < ActionController::Base
  # ==============================================================
  # CSRF-SCHUTZ
  # ==============================================================
  protect_from_forgery with: :exception
end
