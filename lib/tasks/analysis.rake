# ============================================================
# Datei: lib/tasks/analysis.rake
#
# Desc:
#   Rake-Aufgaben für die Analyse (Kapitel 4, Batch-Verarbeitung).
#
#   analysis:run     führt einen vollständigen Analyselauf aus
#                    (Analysis::Runner). Wird nachts vom Zeitplan
#                    des Betriebssystems aufgerufen (cron unter
#                    Linux, Aufgabenplanung unter Windows).
#   analysis:status  zeigt die letzten Läufe mit Status und Dauer.
#
#   Aufruf:
#     ruby bin/rails analysis:run
#     ruby bin/rails analysis:status
#
#   Exit-Codes von analysis:run (für cron und Aufgabenplanung):
#     0  Lauf erfolgreich
#     1  Lauf fehlgeschlagen (Status "failed" in analysis_runs)
#     2  es läuft bereits ein Lauf, nichts gestartet
# ============================================================

namespace :analysis do
  desc "Führt die Themenanalyse aus und speichert die Ergebnisse"
  task run: :environment do
    # Fortschritt auf der Konsole und zusätzlich im Rails-Log
    console = ActiveSupport::Logger.new($stdout)
    console.formatter = proc { |_severity, time, _progname, message| "#{time.strftime('%H:%M:%S')} #{message}\n" }
    logger = ActiveSupport::BroadcastLogger.new(console, Rails.logger)

    begin
      run = Analysis::Runner.new(logger: logger).call
      puts "Lauf #{run.id} erfolgreich beendet."
    rescue Analysis::Runner::AlreadyRunning => error
      warn error.message
      exit 2
    rescue StandardError => error
      warn "Lauf fehlgeschlagen: #{error.class}: #{error.message}"
      exit 1
    end
  end

  desc "Zeigt die letzten Analyseläufe"
  task status: :environment do
    runs = Analysis::Run.order(started_at: :desc).limit(10)

    if runs.empty?
      puts "Noch keine Analyse gelaufen."
      next
    end

    runs.each do |run|
      started = run.started_at.strftime("%d.%m.%Y %H:%M")
      duration = run.finished_at ? format("%5.1f min", (run.finished_at - run.started_at) / 60.0) : "  läuft"
      puts format("%5d  %-9s  %s  %s", run.id, run.status, started, duration)
    end
  end
end
