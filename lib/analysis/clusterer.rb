# ============================================================
# Datei: lib/analysis/clusterer.rb
#
# Desc:
#   Schritt 6 der Analyse: gruppiert die Personen nach ihren
#   50-dimensionalen Profilen (Reducer) in Themencluster.
#   Die Cluster färben die Punkte der Themenkarte (UC3).
#
#   Zwei Verfahren, beide mit Kosinus-Abstand auf den auf
#   Länge 1 normierten Profilen:
#
#   k-Means  (sphärisch) Startzentren nach k-means++
#            (Arthur und Vassilvitskii 2007), danach
#            abwechselnd Zuordnung zum ähnlichsten Zentrum und
#            Neuberechnung der Zentren, bis sich nichts mehr
#            ändert. Jede Person gehört zu genau einem Cluster.
#
#   DBSCAN   (Ester et al. 1996) Ein Punkt mit mindestens
#            min_pts Nachbarn im Abstand eps ist ein Kernpunkt;
#            zusammenhängende Kernpunkte und ihre Nachbarn bilden
#            einen Cluster. Punkte ohne Cluster sind Rauschen
#            (Nummer −1). Die Anzahl der Cluster ergibt sich
#            aus den Daten.
#
#   Weil die Analyse nachts vorab rechnet, werden feste
#   Parameterstufen berechnet (KMEANS_K, DBSCAN_MIN_PTS und
#   die eps-Stufen). Die Oberfläche wählt dann nur noch eine
#   fertige Stufe aus.
#
#   eps-Stufen aus den Daten (k-Distanz, Ester et al. 1996):
#   Für jeden Punkt wird der Abstand zu seinem (min_pts − 1)-
#   nächsten Nachbarn bestimmt. Das q-Quantil dieser Abstände
#   als eps bedeutet: ungefähr der Anteil q aller Punkte ist
#   Kernpunkt. DBSCAN_EPS_QUANTILES legt diese Anteile fest.
#   Feste eps-Werte passen dagegen nur zu einem bestimmten
#   Datenbestand (beim ersten Lauf mit eps 0,3–0,5 fiel fast
#   alles in einen einzigen Cluster).
#
# Rückgabe von cluster_all:
#   Array von Hashes
#   { algorithm:, k:, eps:, min_pts:, labels:,
#     cluster_count:, noise_count: }
#   labels enthält je Person (Reihenfolge wie die Eingabe) die
#   Clusternummer ab 0, bei DBSCAN −1 für Rauschen.
# ============================================================

module Analysis
  class Clusterer
    KMEANS_K = [ 4, 6, 8, 10, 12, 15, 20 ].freeze
    DBSCAN_MIN_PTS = [ 5, 10 ].freeze
    DBSCAN_EPS_QUANTILES = [ 0.25, 0.5, 0.75 ].freeze
    MAX_EPS = 0.5             # obere Grenze für eps (Kosinus-Abstand)
    EPS_PRECISION = 3
    MAX_ITERATIONS = 100
    NOISE = -1
    SEED = 42

    # embedding: Array von Profilen (je ein Array mit 50 Werten)
    def cluster_all(embedding)
      points = embedding.map { |row| unit(row) }

      kmeans_results = KMEANS_K.select { |k| k <= points.size }.map do |k|
        result(algorithm: "kmeans", k: k, labels: kmeans(points, k))
      end

      neighbors = neighbor_lists(points, MAX_EPS)
      dbscan_results = eps_steps(neighbors).product(DBSCAN_MIN_PTS).map do |eps, min_pts|
        result(algorithm: "dbscan", eps: eps, min_pts: min_pts, labels: dbscan(neighbors, eps, min_pts))
      end

      kmeans_results + dbscan_results
    end

    private

    # ----------------------------------------------------------
    # k-Means
    # ----------------------------------------------------------

    def kmeans(points, k)
      random = Random.new(SEED)
      centers = initial_centers(points, k, random)
      labels = Array.new(points.size, NOISE)

      MAX_ITERATIONS.times do
        new_labels = points.map { |point| nearest_center(point, centers) }
        break if new_labels == labels

        labels = new_labels
        centers = recompute_centers(points, labels, centers, random)
      end

      labels
    end

    # k-means++: das erste Zentrum zufällig, jedes weitere mit
    # einer Wahrscheinlichkeit proportional zum quadrierten
    # Abstand zum nächsten bereits gewählten Zentrum.
    def initial_centers(points, k, random)
      centers = [ points[random.rand(points.size)] ]
      nearest = points.map { |point| distance(point, centers.first) }

      while centers.size < k
        weights = nearest.map { |d| d * d }
        total = weights.sum
        index = total.zero? ? random.rand(points.size) : pick(weights, random.rand * total)
        centers << points[index]
        points.each_with_index { |point, i| nearest[i] = [ nearest[i], distance(point, centers.last) ].min }
      end

      centers
    end

    # Index, bei dem die laufende Summe der Gewichte target erreicht.
    def pick(weights, target)
      running = 0.0
      weights.each_with_index do |weight, i|
        running += weight
        return i if running >= target
      end
      weights.size - 1
    end

    # Index des ähnlichsten Zentrums (größtes Skalarprodukt).
    def nearest_center(point, centers)
      best = 0
      best_score = -Float::INFINITY
      centers.each_with_index do |center, c|
        score = dot(point, center)
        if score > best_score
          best = c
          best_score = score
        end
      end
      best
    end

    # Neues Zentrum = normierter Mittelwert der zugeordneten
    # Punkte. Ein leerer Cluster bekommt einen zufälligen Punkt.
    def recompute_centers(points, labels, centers, random)
      dimensions = points.first.size
      sums = Array.new(centers.size) { Array.new(dimensions, 0.0) }
      counts = Array.new(centers.size, 0)

      points.each_with_index do |point, i|
        c = labels[i]
        counts[c] += 1
        sum = sums[c]
        dimensions.times { |d| sum[d] += point[d] }
      end

      sums.each_with_index.map do |sum, c|
        counts[c].zero? ? points[random.rand(points.size)] : unit(sum)
      end
    end

    # ----------------------------------------------------------
    # DBSCAN
    # ----------------------------------------------------------

    # eps-Stufen als Quantile der k-Distanzen. Die k-Distanz
    # gehört zum kleinsten min_pts, damit dieselben eps-Werte
    # für alle min_pts-Stufen gelten (das Formular bietet eps
    # und min_pts getrennt an). Punkte mit zu wenigen Nachbarn
    # innerhalb MAX_EPS erhalten MAX_EPS.
    def eps_steps(neighbors)
      rank = DBSCAN_MIN_PTS.min - 2      # der Punkt selbst zählt mit
      distances = neighbors.map { |list| list[rank]&.last || MAX_EPS }.sort

      DBSCAN_EPS_QUANTILES
        .map { |q| distances[((distances.size - 1) * q).round].round(EPS_PRECISION) }
        .select(&:positive?)
        .uniq
    end

    # Für jeden Punkt alle Nachbarn mit Abstand ≤ max_eps:
    # Array von [[Index, Abstand], ...], aufsteigend nach
    # Abstand. Wird einmal berechnet und für alle eps-Stufen
    # gefiltert.
    def neighbor_lists(points, max_eps)
      size = points.size
      lists = Array.new(size) { [] }

      size.times do |i|
        a = points[i]
        (i + 1...size).each do |j|
          d = distance(a, points[j])
          next if d > max_eps

          lists[i] << [ j, d ]
          lists[j] << [ i, d ]
        end
      end

      lists.each { |list| list.sort_by!(&:last) }
    end

    def dbscan(neighbor_lists, eps, min_pts)
      neighbors = neighbor_lists.map { |list| list.filter_map { |j, d| j if d <= eps } }
      # Der Punkt selbst zählt als Nachbar mit (wie im Original).
      core = neighbors.map { |list| list.size + 1 >= min_pts }
      labels = Array.new(neighbors.size, NOISE)
      cluster = 0

      neighbors.each_index do |start|
        next unless core[start] && labels[start] == NOISE

        # Breitensuche über zusammenhängende Kernpunkte
        labels[start] = cluster
        queue = [ start ]
        until queue.empty?
          i = queue.shift
          next unless core[i]

          neighbors[i].each do |j|
            next unless labels[j] == NOISE

            labels[j] = cluster
            queue << j
          end
        end
        cluster += 1
      end

      labels
    end

    # ----------------------------------------------------------
    # Hilfsfunktionen
    # ----------------------------------------------------------

    # Ergebnis einer Parameterstufe mit Kennzahlen.
    def result(algorithm:, labels:, k: nil, eps: nil, min_pts: nil)
      {
        algorithm: algorithm,
        k: k,
        eps: eps,
        min_pts: min_pts,
        labels: labels,
        cluster_count: labels.reject { |label| label == NOISE }.uniq.size,
        noise_count: labels.count(NOISE)
      }
    end

    # Kosinus-Abstand normierter Vektoren.
    def distance(a, b)
      1.0 - dot(a, b)
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
