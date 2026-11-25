# ============================================================
# Datei: config/importmap.rb
#
# Desc:
#   Importmap für die JavaScript-Module (ohne Build-Schritt).
#   Jede Komponente ist ein eigenes Modul in app/javascript;
#   D3 v7 kommt als ES-Modul vom CDN.
# ============================================================

# Einstieg: liest data-page und startet die Komponenten
pin "page"

# Gemeinsamer Auswahlzustand (Observer)
pin "selection_state"

# Netzwerkseite (UC1/UC2)
pin "network_view"
pin "bar_chart"

# Themenkarte (UC3)
pin "topic_map_view"
pin "topic_cards"

# Kombinierte Ansicht (UC 4, UC 5)
pin "similarity_slider"

# Gemeinsame Komponenten
pin "detail_panel"
pin "search_box"
pin "legend"

# Bibliothek
pin "d3", to: "https://cdn.jsdelivr.net/npm/d3@7/+esm"
