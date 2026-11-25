# ============================================================
# Datei: app/models/analysis/run.rb
#
# Desc:
#   Ein Analyselauf. Jeder Lauf von Analysis::Runner erzeugt
#   eine Zeile; alle Ergebnisse (Projektionen, Ähnlichkeiten,
#   Clusterbildungen) gehören zu genau einem Lauf.
#
#   Die Seiten zeigen immer den letzten abgeschlossenen Lauf
#   (latest_finished). Ein laufender oder fehlgeschlagener
#   Lauf ist damit für die Nutzer unsichtbar.
#
# Tabelle: analysis_runs
# ============================================================

module Analysis
  class Run < ApplicationRecord
    STATUSES = %w[running finished failed].freeze

    # ----------------------------------------------------------
    # Assoziationen
    #
    # Das Löschen der abhängigen Zeilen übernimmt die Datenbank
    # (on_delete: :cascade in der Migration).
    # ----------------------------------------------------------
    has_many :projections,  inverse_of: :run
    has_many :similarities, inverse_of: :run
    has_many :clusterings,  inverse_of: :run

    # ----------------------------------------------------------
    # Validierungen
    # ----------------------------------------------------------
    validates :started_at, presence: true
    validates :status, inclusion: { in: STATUSES }

    # ----------------------------------------------------------
    # Scopes
    # ----------------------------------------------------------
    scope :finished, -> { where(status: "finished") }
    scope :running,  -> { where(status: "running") }

    # Letzter erfolgreich abgeschlossener Lauf oder nil,
    # falls noch keine Analyse durchgelaufen ist.
    def self.latest_finished
      finished.order(finished_at: :desc).first
    end

    # Prüft, ob bereits ein Lauf aktiv ist. Analysis::Runner
    # startet in diesem Fall keinen zweiten Lauf.
    def self.running?
      running.exists?
    end

    # Legt einen neuen Lauf mit Status "running" an.
    def self.start!
      create!(started_at: Time.current, status: "running")
    end

    # ----------------------------------------------------------
    # Statuswechsel
    # ----------------------------------------------------------

    # Markiert den Lauf als erfolgreich abgeschlossen.
    # Ab jetzt lesen die Seiten diesen Lauf.
    def finish!
      update!(status: "finished", finished_at: Time.current)
    end

    # Markiert den Lauf als fehlgeschlagen. Die Seiten zeigen
    # weiterhin den vorherigen abgeschlossenen Lauf.
    def fail!
      update!(status: "failed", finished_at: Time.current)
    end

    def finished?
      status == "finished"
    end
  end
end
