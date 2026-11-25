# ============================================================
# Datei: app/models/analysis.rb
#
# Desc:
#   Namensraum für alle Modelle der Analyseergebnisse
#   (Analysis::Run, Analysis::Projection, ...).
#
#   table_name_prefix sorgt dafür, dass z. B. Analysis::Run
#   automatisch die Tabelle analysis_runs verwendet.
#   So bleiben die Analysetabellen klar von den
#   SciPort-Tabellen getrennt (vgl. Abb. 8).
# ============================================================

module Analysis
  def self.table_name_prefix
    "analysis_"
  end
end
