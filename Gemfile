source "https://rubygems.org"

# ==============================================================
# CORE RAILS
# ==============================================================
gem "rails", "~> 7.1.6"
gem "sqlite3", "~> 1.4"
gem "puma", ">= 5.0"

# ==============================================================
# ZEITZONEN (WICHTIG FÜR WINDOWS)
# ==============================================================
gem "tzinfo-data", platforms: %i[ windows jruby ]

# ==============================================================
# FRONTEND
# ==============================================================
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "sprockets-rails"

# ==============================================================
# API KOMMUNIKATION
# ==============================================================
gem "httparty"          # HTTP-Requests für API-Kommunikation
gem "nokogiri"          # XML-Parsing

# ==============================================================
# PERFORMANCE
# ==============================================================
gem "bootsnap", require: false

# ==============================================================
# ENTWICKLUNG
# ==============================================================
group :development, :test do
  gem "debug", platforms: %i[ mri windows ]
end

group :development do
  gem "web-console"
end