# ============================================================
# Title: SciPort Research Visualization - Gemfile
# Desc:
#   Definiert die Ruby-Abhängigkeiten des Rails-Projekts.
#
#   Ergänzung:
#   dotenv-rails lädt lokale Umgebungsvariablen aus .env,
#   insbesondere das PostgreSQL-Passwort.
# ============================================================

source "https://rubygems.org"

# ============================================================
# 1. RAILS FRAMEWORK
# ============================================================

# Rails 8.1
gem "rails", "~> 8.1.4"

# Moderne Asset-Pipeline
gem "propshaft"

# ============================================================
# 2. DATENBANK
# ============================================================

# PostgreSQL-Adapter für Active Record
gem "pg", "~> 1.1"

# ============================================================
# 3. WEBSERVER
# ============================================================

# Puma-Webserver
gem "puma", ">= 5.0"

# ============================================================
# 4. JAVASCRIPT UND FRONTEND
# ============================================================

# JavaScript-Module über Importmap
gem "importmap-rails"

# ============================================================
# 5. OPTIONALE AUTHENTIFIZIERUNG
# ============================================================

# Bei Bedarf aktivieren:
# gem "bcrypt", "~> 3.1.7"

# ============================================================
# 6. WINDOWS-UNTERSTÜTZUNG
# ============================================================

# Zeitzonendaten für Windows und JRuby
gem "tzinfo-data", platforms: %i[ windows jruby ]

# ============================================================
# 7. RAILS-INFRASTRUKTUR
# ============================================================

# Datenbankgestützter Cache
gem "solid_cache"

# Datenbankgestützte Hintergrundaufgaben
gem "solid_queue"

# Datenbankgestütztes Action Cable
gem "solid_cable"

# ============================================================
# 8. PERFORMANCE
# ============================================================

# Beschleunigt den Start der Rails-Anwendung
gem "bootsnap", require: false

# ============================================================
# 9. DEPLOYMENT
# ============================================================

# Docker-Deployment mit Kamal
gem "kamal", require: false

# HTTP-Komprimierung und Asset-Auslieferung
gem "thruster", require: false

# ============================================================
# 11. ENTWICKLUNG UND TESTS
# ============================================================

group :development, :test do
  # Ruby-Debugger
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Sicherheitsprüfung der Gem-Abhängigkeiten
  gem "bundler-audit", require: false

  # Statische Sicherheitsanalyse
  gem "brakeman", require: false

  # Ruby-Codeformatierung
  gem "rubocop-rails-omakase", require: false

  # ==========================================================
  # Title: dotenv-rails
  # Desc:
  #   Liest beim lokalen Rails-Start die Datei .env.
  #   Dadurch wird POSTGRES_PASSWORD automatisch geladen,
  #   auch für die automatisierten Tests (rails test), die
  #   sonst ohne Passwort keine Verbindung zur Test-
  #   datenbank bekommen.
  #
  # Security:
  #   Die Datei .env darf nicht versioniert werden.
  # ==========================================================
  gem "dotenv-rails"
end

# ============================================================
# 12. LOKALE ENTWICKLUNG
# ============================================================

group :development do
  # Interaktive Konsole auf Fehlerseiten
  gem "web-console"
end

# ============================================================
# 13. SYSTEMTESTS
# ============================================================

group :test do
  # Browserbasierte Tests
  gem "capybara"

  # Automatisierte Browsersteuerung
  gem "selenium-webdriver"
end

# ============================================================
# 14. ZUSÄTZLICHE BIBLIOTHEKEN
# ============================================================

# Zugriff auf native Bibliotheken
gem "fiddle"
