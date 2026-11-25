# ============================================================
# Datei: test/test_helper.rb
#
# Desc:
#   Gemeinsame Einstellungen für alle Tests. Lädt die Fixtures
#   (kleines Testnetz) und stellt build_analysis_run bereit,
#   das einen fertigen Analyselauf für drei Personen anlegt.
#
# Ausführen (PowerShell):
#   ruby bin/rails db:test:prepare
#   ruby bin/rails test
# ============================================================
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Tests nacheinander ausführen. Parallel laufende Threads
    # laden die Fixtures gleichzeitig; PostgreSQL meldet dabei
    # Deadlocks, weil jeder Thread kurzzeitig die Fremdschlüssel
    # aller Tabellen sperrt. Bei 57 Tests kostet die serielle
    # Ausführung nur wenige Sekunden.
    parallelize(workers: 1)

    # Alle Fixtures aus test/fixtures laden
    fixtures :all

    # Legt einen fertigen Analyselauf an:
    #   - Projektionen (PCA, t-SNE, UMAP) für anna, ben, carla
    #   - k-Means mit k = 2: anna und ben in Cluster 0,
    #     carla in Cluster 1, dazu die Themenbegriffe
    #   - Ähnlichkeiten anna–ben 0,9 und ben–carla 0,6
    def build_analysis_run
      run = Analysis::Run.create!(started_at: 1.hour.ago, finished_at: Time.current, status: "finished")
      members = { people(:anna) => [ 0, -0.5, 0.5 ], people(:ben) => [ 0, -0.4, 0.4 ], people(:carla) => [ 1, 0.8, -0.6 ] }

      Analysis::Projection::METHODS.each do |method|
        members.each do |person, (_cluster, x, y)|
          run.projections.create!(person: person, projection_method: method, x: x, y: y)
        end
      end

      clustering = run.clusterings.create!(algorithm: "kmeans", k: 2, cluster_count: 2, noise_count: 0)
      members.each do |person, (cluster, _x, _y)|
        clustering.cluster_assignments.create!(person: person, cluster_number: cluster)
      end
      clustering.topics.create!(cluster_number: 0, terms: %w[netzwerk visualisierung lernen])
      clustering.topics.create!(cluster_number: 1, terms: %w[optik laser physik])

      add_similarity(run, people(:anna), people(:ben), 0.9)
      add_similarity(run, people(:ben), people(:carla), 0.6)
      run
    end

    private

    def add_similarity(run, one, two, score)
      a, b = Analysis::Similarity.ordered_pair(one.id, two.id)
      run.similarities.create!(person_a_id: a, person_b_id: b, score: score)
    end
  end
end
