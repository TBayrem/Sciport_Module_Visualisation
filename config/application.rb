require_relative "boot"
require "rails/all"

Bundler.require(*Rails.groups)

module SciportModuleVisualisation
  class Application < Rails::Application
    config.load_defaults 7.1
    
    # ==============================================================
    # ZEITZONEN KONFIGURATION (für Windows)
    # ==============================================================
    # Verwende die Windows-Zeitzonen-Daten
    config.time_zone = "Berlin"
    config.active_record.default_timezone = :utc
    
    config.autoload_lib(ignore: %w(assets tasks))
    config.autoload_paths << Rails.root.join('app', 'services')
  end
end