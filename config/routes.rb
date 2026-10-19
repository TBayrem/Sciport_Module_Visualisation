
Rails.application.routes.draw do
  # ----------------------------------------------------------
  # 1. Startseite
  #
  # Beim Aufruf der Anwendung wird direkt das
  # Forschungsnetzwerk angezeigt.
  # ----------------------------------------------------------

  root "visualizations#network"


  # ----------------------------------------------------------
  # 2. Forschungsnetzwerk
  #
  # Zeigt Forschende und ihre institutionellen
  # Zugehörigkeiten an.
  #
  # Anwendungsfälle:
  # - Forschungsnetzwerk anzeigen
  # - Forschende nach Einrichtungen filtern
  # - Forschende nach Namen suchen
  # ----------------------------------------------------------

  get "/network",
      to: "visualizations#network",
      as: :network
end
