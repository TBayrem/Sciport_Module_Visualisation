# ============================================================
# Datei: lib/analysis/topic_namer.rb
#
# Desc:
#   Schritt 7 der Analyse: benennt jeden Themencluster mit
#   seinen kennzeichnenden Begriffen. Die Begriffe erscheinen
#   in den Themenkarten (topic_cards.js) und in der Legende;
#   Analysis::Topic#label zeigt die ersten drei.
#
#   Verfahren: klassenbasiertes TF-IDF (c-TF-IDF, Grootendorst
#   2022). Alle Profile eines Clusters werden zu einem
#   "Clusterdokument" zusammengefasst:
#
#     tf(t, c) = Summe der TF-IDF-Gewichte von t im Cluster c,
#                geteilt durch die Summe aller Gewichte in c
#     idf(t)   = ln(1 + A / f(t))
#                A    = durchschnittliches Gesamtgewicht je Cluster
#                f(t) = Gesamtgewicht von t über alle Cluster
#     score    = tf(t, c) · idf(t)
#
#   Ein Begriff erhält damit einen hohen Wert, wenn er im
#   Cluster häufig und in den übrigen Clustern selten ist.
#   Rauschpunkte (Nummer −1, DBSCAN) bekommen kein Thema.
#
# Rückgabe von name:
#   Hash { Clusternummer => [Begriff, ...] }, je Cluster die
#   terms_per_topic Begriffe mit dem höchsten score.
# ============================================================

module Analysis
  class TopicNamer
    TERMS_PER_TOPIC = 10
    NOISE = -1

    def initialize(terms_per_topic: TERMS_PER_TOPIC)
      @terms_per_topic = terms_per_topic
    end

    # vectors: TF-IDF-Profile (Vectorizer), je ein Hash Index => Gewicht
    # terms:   Begriffe (Vectorizer), Index => Begriff
    # labels:  Clusternummer je Profil (Clusterer), gleiche Reihenfolge
    def name(vectors, terms, labels)
      raise ArgumentError, "vectors und labels sind unterschiedlich lang" if vectors.size != labels.size

      cluster_weights = sum_per_cluster(vectors, labels)
      return {} if cluster_weights.empty?

      idf = class_idf(cluster_weights)

      cluster_weights.sort.to_h.transform_values do |weights|
        total = weights.values.sum
        weights
          .map { |index, weight| [ index, weight / total * idf[index] ] }
          .max_by(@terms_per_topic, &:last)
          .map { |index, _score| terms[index] }
      end
    end

    private

    # Summe der Gewichte je Begriff und Cluster:
    # { Clusternummer => { Begriffsindex => Gewicht } }
    def sum_per_cluster(vectors, labels)
      sums = Hash.new { |hash, cluster| hash[cluster] = Hash.new(0.0) }

      vectors.each_with_index do |vector, i|
        next if labels[i] == NOISE

        weights = sums[labels[i]]
        vector.each { |index, weight| weights[index] += weight }
      end

      sums
    end

    # idf(t) = ln(1 + A / f(t))
    def class_idf(cluster_weights)
      frequency = Hash.new(0.0)
      cluster_weights.each_value do |weights|
        weights.each { |index, weight| frequency[index] += weight }
      end

      average = frequency.values.sum / cluster_weights.size
      frequency.transform_values { |f| Math.log(1.0 + average / f) }
    end
  end
end
