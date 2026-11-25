# ============================================================
# Datei: config/routes.rb
#
# Desc:
#   Ordnet jede URL genau einem Controller zu. Die
#   Anwendung hat drei Seiten, je eine pro Controller
#   (vgl. Abb. 7). Alle Routen sind lesende GET-Anfragen;
#   es gibt keine JSON-Endpunkte.
#
#   GET /                → NetworksController#index
#   GET /networks        → NetworksController#index
#   GET /topic_maps      → TopicMapsController#index
#   GET /combined_views  → CombinedViewsController#index
#   GET /up              → Statusprüfung für das Deployment
# ============================================================

Rails.application.routes.draw do
  # Startseite: das Forschungsnetzwerk (UC 1, UC 2).
  root "networks#index"

  # Seite 1: Forschungsnetzwerk (UC 1, UC 2).
  resources :networks, only: :index

  # Seite 2: Themenkarte mit Clustern (UC 3, UC 4).
  # Clusterverfahren und Parameterstufe kommen als
  # Query-Parameter, z. B. /topic_maps?algorithm=kmeans&k=8
  resources :topic_maps, only: :index

  # Seite 3: Kombinierte Ansicht (UC 5, UC 6).
  resources :combined_views, only: :index

  # Rails-Statusprüfung (antwortet mit 200, wenn die
  # Anwendung läuft). Wird von Kamal beim Deployment genutzt.
  get "up" => "rails/health#show", as: :rails_health_check
end
