Rails.application.routes.draw do
  # ==============================================================
  # HAUPTROUTE
  # ==============================================================
  root "home#index"

  # ==============================================================
  # HOME - API-IMPORT
  # ==============================================================
  post "import_facilities", to: "home#import_facilities"
  post "import_people", to: "home#import_people"
  post "import_all", to: "home#import_all"

  # ==============================================================
  # FACILITIES
  # ==============================================================
  resources :facilities do
    collection do
      get "fetch_api"
    end
    member do
      get "fetch_api_detail"
    end
  end

  # ==============================================================
  # PEOPLE
  # ==============================================================
  resources :people do
    collection do
      get "fetch_api"
    end
    member do
      get "fetch_api_detail"
    end
  end

  # ==============================================================
  # RESEARCH PROJECTS
  # ==============================================================
  resources :research_projects do
    collection do
      get "fetch_api"
    end
    member do
      get "fetch_api_detail"
    end
  end

  # ==============================================================
  # PUBLICATIONS
  # ==============================================================
  resources :publications do
    collection do
      get "fetch_api"
    end
    member do
      get "fetch_api_detail"
    end
  end

  # ==============================================================
  # PATENTS
  # ==============================================================
  resources :patents do
    collection do
      get "fetch_api"
    end
  end
end
