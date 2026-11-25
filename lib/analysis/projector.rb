# ============================================================
# Datei: lib/analysis/projector.rb
#
# Desc:
#   Schritt 4 der Analyse: bildet die 50-dimensionalen
#   Profile (Reducer) auf zwei Dimensionen ab, damit sie als
#   Punkte auf der Themenkarte erscheinen können.
#
#   Drei Verfahren, alle in Ruby umgesetzt:
#
#   PCA    Hauptkomponentenanalyse: lineare Projektion auf die
#          zwei Richtungen mit der größten Streuung. Erhält
#          große Abstände, trennt Themen aber oft schlecht.
#
#   t-SNE  t-distributed Stochastic Neighbor Embedding
#          (van der Maaten und Hinton 2008). Erhält Nachbar-
#          schaften. Vereinfachung: Die Anziehung wird nur
#          zwischen den k nächsten Nachbarn berechnet (wie bei
#          Barnes-Hut-t-SNE), die Abstoßung über eine zufällige
#          Stichprobe von Punkten geschätzt.
#
#   UMAP   Uniform Manifold Approximation and Projection
#          (McInnes, Healy und Melville 2018). Unscharfer
#          k-Nächste-Nachbarn-Graph, optimiert mit stochastischem
#          Gradientenabstieg und Negativstichproben wie im
#          Original.
#
#   Abstände: Kosinus-Abstand (1 − Kosinus-Ähnlichkeit) der auf
#   Länge 1 normierten Profile. Feste Startwerte machen die
#   Ergebnisse wiederholbar.
#
# Rückgabe von project:
#   Hash { "pca" => [[x, y], ...], "tsne" => ..., "umap" => ... }
#   in derselben Reihenfolge wie die Eingabe; jede Projektion
#   ist zentriert und auf den Bereich −1..1 skaliert.
# ============================================================

module Analysis
  class Projector
    METHODS = %w[pca tsne umap].freeze
    SEED = 42

    TSNE = {
      perplexity: 30.0,
      iterations: 500,
      exaggeration_iterations: 125,
      exaggeration: 12.0,
      repulsion_samples: 64,
      momentum: [ 0.5, 0.8 ]
    }.freeze

    UMAP = {
      neighbors: 15,
      epochs: 200,
      negative_samples: 5,
      learning_rate: 1.0,
      a: 1.577,              # Kurvenparameter für min_dist = 0,1
      b: 0.895
    }.freeze

    # embedding: Array von Profilen (je ein Array mit 50 Werten)
    def project(embedding)
      points = embedding.map { |row| unit(row) }
      neighbors = nearest_neighbors(points, (3 * TSNE[:perplexity]).to_i)
      pca = pca(points)

      {
        "pca" => scale(pca),
        "tsne" => scale(tsne(points.size, neighbors)),
        "umap" => scale(umap(points.size, neighbors.map { |list| list.first(UMAP[:neighbors]) }, pca))
      }
    end

    private

    # ----------------------------------------------------------
    # PCA
    # ----------------------------------------------------------

    # Zentriert die Punkte und projiziert sie mit der SVD des
    # Reducers auf die zwei Hauptkomponenten.
    def pca(points)
      dimensions = points.first.size
      mean = Array.new(dimensions) { |k| points.sum { |point| point[k] } / points.size }
      centered = points.map { |point| point.each_with_index.map { |value, k| value - mean[k] } }

      Reducer.new(dimensions: 2).reduce(centered, dimensions).embedding
    end

    # ----------------------------------------------------------
    # Nächste Nachbarn (für t-SNE und UMAP)
    # ----------------------------------------------------------

    # Für jeden Punkt die count nächsten Nachbarn nach
    # Kosinus-Abstand: Array von [[Index, Abstand], ...],
    # aufsteigend sortiert.
    def nearest_neighbors(points, count)
      size = points.size
      count = [ count, size - 1 ].min
      distances = Array.new(size) { [] }

      size.times do |i|
        a = points[i]
        (i + 1...size).each do |j|
          distance = 1.0 - dot(a, points[j])
          distances[i] << [ j, distance ]
          distances[j] << [ i, distance ]
          # Listen späterer Punkte regelmäßig kürzen (Speicher)
          distances[j] = distances[j].min_by(count, &:last) if distances[j].size > 4 * count
        end
        distances[i] = distances[i].min_by(count, &:last)
      end

      distances.map { |list| list.min_by(count, &:last) }
    end

    # ----------------------------------------------------------
    # t-SNE
    # ----------------------------------------------------------

    def tsne(size, neighbors)
      random = Random.new(SEED)
      affinities = tsne_affinities(neighbors)
      positions = Array.new(size) { [ gaussian(random) * 1e-4, gaussian(random) * 1e-4 ] }
      velocity = Array.new(size) { [ 0.0, 0.0 ] }
      gains = Array.new(size) { [ 1.0, 1.0 ] }
      learning_rate = [ size / TSNE[:exaggeration], 50.0 ].max

      TSNE[:iterations].times do |iteration|
        early = iteration < TSNE[:exaggeration_iterations]
        exaggeration = early ? TSNE[:exaggeration] : 1.0
        momentum = early ? TSNE[:momentum][0] : TSNE[:momentum][1]
        gradient = tsne_gradient(positions, affinities, exaggeration, random)

        size.times do |i|
          2.times do |d|
            same_sign = (gradient[i][d] > 0) == (velocity[i][d] > 0)
            gains[i][d] = same_sign ? [ gains[i][d] * 0.8, 0.01 ].max : gains[i][d] + 0.2
            velocity[i][d] = momentum * velocity[i][d] - learning_rate * gains[i][d] * gradient[i][d]
            positions[i][d] += velocity[i][d]
          end
        end
      end

      positions
    end

    # Symmetrische Nachbarschaftswahrscheinlichkeiten p_ij aus den
    # k nächsten Nachbarn. σ_i wird je Punkt so gesucht, dass die
    # Perplexität der Verteilung TSNE[:perplexity] entspricht.
    def tsne_affinities(neighbors)
      target_entropy = Math.log(TSNE[:perplexity])
      conditional = neighbors.map do |list|
        distances = list.map { |_j, distance| distance * distance }
        weights = binary_search_weights(distances, target_entropy)
        list.each_with_index.map { |(j, _distance), k| [ j, weights[k] ] }
      end

      symmetric = Hash.new(0.0)
      conditional.each_with_index do |list, i|
        list.each { |j, p| symmetric[[ i, j ].minmax] += p }
      end

      total = symmetric.values.sum
      symmetric.map { |(i, j), p| [ i, j, p / total ] }
    end

    # Gewichte exp(−β·d) mit Summe 1, β per Bisektion so gewählt,
    # dass die Entropie dem Zielwert entspricht.
    def binary_search_weights(distances, target_entropy)
      low = 0.0
      high = Float::INFINITY
      beta = 1.0
      weights = nil

      50.times do
        shifted = distances.map { |distance| Math.exp(-beta * (distance - distances.min)) }
        sum = shifted.sum
        weights = shifted.map { |weight| weight / sum }
        entropy = -weights.sum { |weight| weight.positive? ? weight * Math.log(weight) : 0.0 }

        break if (entropy - target_entropy).abs < 1e-5

        if entropy > target_entropy
          low = beta
          beta = high.infinite? ? beta * 2 : (beta + high) / 2
        else
          high = beta
          beta = (beta + low) / 2
        end
      end

      weights
    end

    # Gradient der t-SNE-Kostenfunktion: Anziehung über die
    # Nachbarpaare, Abstoßung über eine Stichprobe.
    def tsne_gradient(positions, affinities, exaggeration, random)
      size = positions.size
      gradient = Array.new(size) { [ 0.0, 0.0 ] }

      # Anziehung: 4 · p_ij · w_ij · (y_i − y_j)
      affinities.each do |i, j, p|
        dx = positions[i][0] - positions[j][0]
        dy = positions[i][1] - positions[j][1]
        force = 4.0 * exaggeration * p / (1.0 + dx * dx + dy * dy)
        gradient[i][0] += force * dx
        gradient[i][1] += force * dy
        gradient[j][0] -= force * dx
        gradient[j][1] -= force * dy
      end

      # Abstoßung: 4 · w_ij² · (y_i − y_j) / Z, geschätzt über
      # dieselbe Stichprobe für alle Punkte.
      sample = Array.new(TSNE[:repulsion_samples]) { random.rand(size) }
      scale = size.to_f / sample.size
      repulsion = Array.new(size) { [ 0.0, 0.0 ] }
      normalizer = 0.0

      size.times do |i|
        xi, yi = positions[i]
        sample.each do |j|
          next if i == j

          dx = xi - positions[j][0]
          dy = yi - positions[j][1]
          weight = 1.0 / (1.0 + dx * dx + dy * dy)
          normalizer += weight
          repulsion[i][0] += weight * weight * dx
          repulsion[i][1] += weight * weight * dy
        end
      end

      normalizer *= scale
      size.times do |i|
        gradient[i][0] -= 4.0 * scale * repulsion[i][0] / normalizer
        gradient[i][1] -= 4.0 * scale * repulsion[i][1] / normalizer
      end

      gradient
    end

    # ----------------------------------------------------------
    # UMAP
    # ----------------------------------------------------------

    def umap(size, neighbors, initial)
      random = Random.new(SEED)
      edges = umap_graph(neighbors)
      positions = scale(initial).map { |x, y| [ x * 10.0, y * 10.0 ] }

      max_weight = edges.map(&:last).max
      epochs_per_sample = edges.map { |_i, _j, weight| max_weight / weight }
      next_epoch = epochs_per_sample.dup

      UMAP[:epochs].times do |epoch|
        alpha = UMAP[:learning_rate] * (1.0 - epoch.to_f / UMAP[:epochs])

        edges.each_with_index do |(i, j, _weight), e|
          next if next_epoch[e] > epoch + 1

          attract(positions[i], positions[j], alpha)
          UMAP[:negative_samples].times { repel(positions[i], positions[random.rand(size)], alpha) }
          next_epoch[e] += epochs_per_sample[e]
        end
      end

      positions
    end

    # Unscharfer Nachbarschaftsgraph: je Punkt ρ (Abstand zum
    # nächsten Nachbarn) und σ, sodass die Gewichte sich zu
    # log2(k) summieren; danach symmetrisiert mit
    # w = a + b − a·b (unscharfe Vereinigung).
    def umap_graph(neighbors)
      target = Math.log2(neighbors.first.size)
      directed = Hash.new(0.0)

      neighbors.each_with_index do |list, i|
        rho = list.first.last
        sigma = umap_sigma(list.map(&:last), rho, target)
        list.each { |j, distance| directed[[ i, j ]] = Math.exp(-[ distance - rho, 0.0 ].max / sigma) }
      end

      undirected = {}
      directed.each do |(i, j), weight|
        key = [ i, j ].minmax
        next if undirected.key?(key)

        other = directed[[ j, i ]]
        undirected[key] = weight + other - weight * other
      end

      undirected.map { |(i, j), weight| [ i, j, weight ] }
    end

    # σ per Bisektion: Summe von exp(−(d − ρ)/σ) = target.
    def umap_sigma(distances, rho, target)
      low = 0.0
      high = Float::INFINITY
      sigma = 1.0

      64.times do
        sum = distances.sum { |distance| Math.exp(-[ distance - rho, 0.0 ].max / sigma) }
        break if (sum - target).abs < 1e-5

        if sum > target
          high = sigma
          sigma = (low + high) / 2
        else
          low = sigma
          sigma = high.infinite? ? sigma * 2 : (low + high) / 2
        end
      end

      [ sigma, 1e-3 ].max
    end

    # Anziehung entlang einer Kante (beide Punkte bewegen sich).
    def attract(a, b, alpha)
      dx = a[0] - b[0]
      dy = a[1] - b[1]
      distance = dx * dx + dy * dy
      return if distance.zero?

      coefficient = -2.0 * UMAP[:a] * UMAP[:b] * distance**(UMAP[:b] - 1.0) /
                    (1.0 + UMAP[:a] * distance**UMAP[:b])
      move(a, b, coefficient * dx, coefficient * dy, alpha, both: true)
    end

    # Abstoßung von einem zufälligen Punkt (nur a bewegt sich).
    def repel(a, b, alpha)
      dx = a[0] - b[0]
      dy = a[1] - b[1]
      distance = dx * dx + dy * dy
      return if distance.zero?

      coefficient = 2.0 * UMAP[:b] / ((0.001 + distance) * (1.0 + UMAP[:a] * distance**UMAP[:b]))
      move(a, b, coefficient * dx, coefficient * dy, alpha, both: false)
    end

    # Verschiebt Punkte um den auf ±4 begrenzten Gradienten.
    def move(a, b, gx, gy, alpha, both:)
      gx = gx.clamp(-4.0, 4.0) * alpha
      gy = gy.clamp(-4.0, 4.0) * alpha
      a[0] += gx
      a[1] += gy
      return unless both

      b[0] -= gx
      b[1] -= gy
    end

    # ----------------------------------------------------------
    # Hilfsfunktionen
    # ----------------------------------------------------------

    # Zentriert die Punkte und skaliert sie auf −1..1.
    def scale(positions)
      cx = positions.sum(&:first) / positions.size
      cy = positions.sum(&:last) / positions.size
      extent = positions.map { |x, y| [ (x - cx).abs, (y - cy).abs ].max }.max
      extent = 1.0 if extent.nil? || extent.zero?

      positions.map { |x, y| [ (x - cx) / extent, (y - cy) / extent ] }
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

    # Standardnormalverteilte Zufallszahl (Box-Muller).
    def gaussian(random)
      Math.sqrt(-2.0 * Math.log(1.0 - random.rand)) * Math.cos(2.0 * Math::PI * random.rand)
    end
  end
end
