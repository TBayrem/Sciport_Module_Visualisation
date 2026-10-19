
# ============================================================
# Datei: config/importmap.rb
#
# Desc:
# Definiert die JavaScript-Module, die Rails über
# Importmap im Browser bereitstellt.
#
# Anwendungsfälle:
# - Rails Turbo und Stimulus laden
# - D3 für beide Visualisierungen bereitstellen
# - Forschungsnetzwerk initialisieren
# - Thematische Forschungscluster visualisieren
# ============================================================


# ------------------------------------------------------------
# 1. Zentraler JavaScript-Einstiegspunkt
#
# application.js importiert alle Module, die für
# die Rails-Anwendung benötigt werden.
# ------------------------------------------------------------

pin "application"


# ------------------------------------------------------------
# 2. Rails Turbo
#
# Ermöglicht die Navigation zwischen den Seiten
# und unterstützt den Turbo-Lebenszyklus.
# ------------------------------------------------------------

pin "@hotwired/turbo-rails",
    to: "turbo.min.js"


# ------------------------------------------------------------
# 3. Rails Stimulus
#
# Stellt Stimulus und die vorhandenen
# Rails-Controller bereit.
# ------------------------------------------------------------

pin "@hotwired/stimulus",
    to: "stimulus.min.js"

pin "@hotwired/stimulus-loading",
    to: "stimulus-loading.js"

pin_all_from "app/javascript/controllers",
             under: "controllers"


# ------------------------------------------------------------
# 4. D3-Bibliothek
#
# Beide Visualisierungen verwenden D3:
#
# - Network für das Forschungsnetzwerk
# - ClusterMap für die thematische Darstellung
#
# Die Bibliothek wird zentral eingebunden,
# damit beide Module denselben Import verwenden.
# ------------------------------------------------------------

pin "d3",
    to: "https://esm.sh/d3@7"


# ------------------------------------------------------------
# 5. Forschungsnetzwerk
#
# network/main.js:
# - Liest Netzwerkdaten aus der HTML-View.
# - Initialisiert die Klasse Network.
# - Verwaltet Filter und Detailinformationen.
#
# network/Network.js:
# - Zeichnet das Netzwerk mit D3.
# - Verwaltet die Force-Simulation.
# - Ermöglicht Zoom und Knoteninteraktionen.
# ------------------------------------------------------------

pin "network/main",
    to: "network/main.js"

pin "network/Network.js",
    to: "network/Network.js"
