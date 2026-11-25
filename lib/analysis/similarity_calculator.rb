# ============================================================
# Datei: lib/analysis/similarity_calculator.rb
#
# Desc:
#   Schritt 5 der Analyse: berechnet die thematische
#   Ähnlichkeit zwischen Personen. Grundlage für den
#   Ähnlichkeitsgraphen der kombinierten Ansicht (UC4).
#
#   Verfahren:
#   1. Jedes 50-dimensionale Profil (Reducer) wird auf Länge 1
#      normiert. Das Skalarprodukt zweier Profile ist dann ihre
#      Kosinus-Ähnlichkeit (Latent Semantic Analysis).
#   2. Alle Personenpaare werden verglichen (n·(n−1)/2 Paare).
#   3. Gespeichert werden nur Paare mit einer Ähnlichkeit von
#      mindestens min_score. Zusätzlich behält jede Person nur
#      ihre max_per_person ähnlichsten Partner, damit der Graph
#      lesbar bleibt und die Tabelle nicht zu groß wird. Ein
#      Paar bleibt erhalten, wenn es für mindestens eine der
#      beiden Personen zu den besten gehört.
#
# Rückgabe von calculate:
#   Array von Hashes { person_a_id:, person_b_id:, score: }
#   mit person_a_id < person_b_id (wie die Prüfbedingung der
#   Tabelle analysis_similarities) und score im Bereich 0..1,
#   absteigend nach score sortiert.
# ============================================================

module Analysis
  class SimilarityCalculator
    MIN_SCORE = 0.5
    MAX_PER_PERSON = 10

    def initialize(min_score: MIN_SCORE, max_per_person: MAX_PER_PERSON)
      @min_score = min_score
      @max_per_person = max_per_person
    end

    # person_ids: IDs in derselben Reihenfolge wie embedding
    # embedding:  Array von Profilen (je ein Array mit 50 Werten)
    def calculate(person_ids, embedding)
      raise ArgumentError, "person_ids und embedding sind unterschiedlich lang" if person_ids.size != embedding.size

      points = embedding.map { |row| unit(row) }
      best = best_partners(points)

      pairs(best, person_ids)
    end

    private

    # Für jeden Punkt die max_per_person ähnlichsten Partner mit
    # score ≥ min_score: Array von [[Index, score], ...].
    def best_partners(points)
      size = points.size
      best = Array.new(size) { [] }

      size.times do |i|
        a = points[i]
        (i + 1...size).each do |j|
          score = dot(a, points[j])
          next if score < @min_score

          best[i] << [ j, score ]
          best[j] << [ i, score ]
          # Listen späterer Punkte regelmäßig kürzen (Speicher)
          best[j] = top(best[j]) if best[j].size > 4 * @max_per_person
        end
        best[i] = top(best[i])
      end

      best
    end

    # Wandelt die Partnerlisten in eindeutige Paare um. Jedes Paar
    # erscheint nur einmal, die kleinere ID steht vorne.
    def pairs(best, person_ids)
      unique = {}

      best.each_with_index do |list, i|
        list.each do |j, score|
          a, b = [ person_ids[i], person_ids[j] ].minmax
          unique[[ a, b ]] = score
        end
      end

      unique
        .map { |(a, b), score| { person_a_id: a, person_b_id: b, score: score.clamp(0.0, 1.0).round(4) } }
        .sort_by { |pair| -pair[:score] }
    end

    # Die max_per_person Einträge mit dem höchsten score.
    def top(list)
      list.max_by(@max_per_person, &:last)
    end

    # Vektor auf Länge 1 bringen.
    def unit(vector)
      length = Math.sqrt(dot(vector, vector))
      length.zero? ? vector : vector.map { |value| value / length }
    end

    # Skalarprodukt; while-Schleife, weil sie in Ruby am
    # schnellsten ist (wird mehrere Millionen Mal aufgerufen).
    def dot(a, b)
      sum = 0.0
      index = 0
      size = a.size
      while index < size
        sum += a[index] * b[index]
        index += 1
      end
      sum
    end
  end
end
