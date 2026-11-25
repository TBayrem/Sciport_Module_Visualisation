# ============================================================
# Datei: lib/analysis/reducer.rb
#
# Desc:
#   Schritt 3 der Analyse: verdichtet die TF-IDF-Vektoren
#   (bis zu 8.000 Dimensionen) auf wenige Dimensionen mit
#   einer abgeschnittenen Singulärwertzerlegung
#   (Truncated SVD, "latente semantische Analyse").
#
#   Wörter, die oft gemeinsam vorkommen, fallen dabei in
#   dieselben Dimensionen. Ähnliche Profile liegen danach auch
#   dann nah beieinander, wenn sie verschiedene, aber
#   verwandte Wörter verwenden.
#
#   Verfahren: randomisierte SVD (Halko, Martinsson und Tropp)
#     1. Zufallsmatrix Ω, Y = A·Ω            (Stichprobe des Bildraums)
#     2. Potenziteration Y = A·(Aᵀ·Y)        (schärft die Basis)
#     3. Q = orthonormale Basis von Y
#     4. kleine Matrix B = Qᵀ·A, Eigenzerlegung von B·Bᵀ
#     5. Ergebnis: Q·U_B·Σ  (Koordinaten jedes Profils)
#   Alle Schritte arbeiten direkt auf den dünn besetzten
#   Vektoren; eine 2.895 × 8.000-Matrix wird nie vollständig
#   angelegt. Der feste Startwert (SEED) macht das Ergebnis
#   wiederholbar.
#
#   Projector verwendet dieselbe Klasse auch für PCA auf
#   dichten, zentrierten Vektoren.
#
# Rückgabe von reduce:
#   Result mit embedding (eine Zeile je Profil) und
#   explained_variance (Anteil der erhaltenen Varianz, 0..1)
# ============================================================

module Analysis
  class Reducer
    Result = Struct.new(:embedding, :explained_variance, keyword_init: true)

    OVERSAMPLING = 20        # zusätzliche Zufallsrichtungen
    POWER_ITERATIONS = 4
    SEED = 42
    JACOBI_SWEEPS = 100
    JACOBI_TOLERANCE = 1e-12

    def initialize(dimensions: 50)
      @dimensions = dimensions
    end

    # rows:    Array von Zeilen; je Zeile ein Hash { Spalte => Wert }
    #          (dünn besetzt) oder ein Array von Werten (dicht)
    # columns: Anzahl der Spalten
    def reduce(rows, columns)
      rank = [ @dimensions + OVERSAMPLING, rows.size, columns ].min
      random = Random.new(SEED)

      omega = Array.new(columns) { Array.new(rank) { gaussian(random) } }
      basis = orthonormalize(multiply(rows, omega, rank))

      POWER_ITERATIONS.times do
        basis = orthonormalize(multiply(rows, orthonormalize(transpose_multiply(rows, basis, columns, rank)), rank))
      end

      # B·Bᵀ = (Aᵀ·Q)ᵀ·(Aᵀ·Q): klein (rank × rank)
      projected = transpose_multiply(rows, basis, columns, rank)
      eigenvalues, eigenvectors = eigen(gram(projected, rank))

      order = (0...rank).sort_by { |index| -eigenvalues[index] }.first(@dimensions)
      embedding = coordinates(basis, eigenvectors, eigenvalues, order)

      Result.new(
        embedding: embedding,
        explained_variance: order.sum { |index| eigenvalues[index].clamp(0, Float::INFINITY) } / total_variance(rows)
      )
    end

    private

    # ----------------------------------------------------------
    # Matrixprodukte mit den (dünnen oder dichten) Zeilen
    # ----------------------------------------------------------

    # A·M: für jede Zeile von A die gewichtete Summe der Zeilen
    # von M. Ergebnis: rows.size × width.
    def multiply(rows, matrix, width)
      rows.map do |row|
        result = Array.new(width, 0.0)
        each_entry(row) do |column, value|
          target = matrix[column]
          width.times { |k| result[k] += value * target[k] }
        end
        result
      end
    end

    # Aᵀ·M: Ergebnis columns × width.
    def transpose_multiply(rows, matrix, columns, width)
      result = Array.new(columns) { Array.new(width, 0.0) }
      rows.each_with_index do |row, index|
        source = matrix[index]
        each_entry(row) do |column, value|
          target = result[column]
          width.times { |k| target[k] += value * source[k] }
        end
      end
      result
    end

    # Durchläuft die Einträge einer Zeile ungleich null.
    def each_entry(row, &block)
      if row.is_a?(Hash)
        row.each(&block)
      else
        row.each_with_index { |value, column| block.call(column, value) unless value.zero? }
      end
    end

    # Mᵀ·M für eine Matrix mit width Spalten.
    def gram(matrix, width)
      result = Array.new(width) { Array.new(width, 0.0) }
      matrix.each do |row|
        width.times do |i|
          value = row[i]
          next if value.zero?

          target = result[i]
          (i...width).each { |j| target[j] += value * row[j] }
        end
      end
      width.times { |i| (0...i).each { |j| result[i][j] = result[j][i] } }
      result
    end

    # Spaltenweise Orthonormalisierung (modifiziertes
    # Gram-Schmidt). Spalten ohne neuen Anteil werden null.
    def orthonormalize(matrix)
      width = matrix.first.size
      width.times do |k|
        (0...k).each do |j|
          projection = matrix.sum { |row| row[k] * row[j] }
          matrix.each { |row| row[k] -= projection * row[j] }
        end

        length = Math.sqrt(matrix.sum { |row| row[k] * row[k] })
        matrix.each { |row| row[k] = length > 1e-12 ? row[k] / length : 0.0 }
      end
      matrix
    end

    # Koordinaten: Q · U_B · Σ für die gewählten Dimensionen.
    # Σ = Wurzel der Eigenwerte von B·Bᵀ.
    def coordinates(basis, eigenvectors, eigenvalues, order)
      scales = order.map { |index| Math.sqrt(eigenvalues[index].clamp(0, Float::INFINITY)) }

      basis.map do |row|
        order.each_with_index.map do |index, position|
          row.each_with_index.sum { |value, k| value * eigenvectors[k][index] } * scales[position]
        end
      end
    end

    # Gesamtvarianz = Summe der Quadrate aller Einträge.
    def total_variance(rows)
      total = 0.0
      rows.each { |row| each_entry(row) { |_column, value| total += value * value } }
      total.positive? ? total : 1.0
    end

    # ----------------------------------------------------------
    # Hilfsverfahren
    # ----------------------------------------------------------

    # Eigenwerte und Eigenvektoren einer symmetrischen Matrix
    # mit dem zyklischen Jacobi-Verfahren. Die Eigenvektoren
    # stehen in den Spalten.
    def eigen(matrix)
      size = matrix.size
      a = matrix.map(&:dup)
      vectors = Array.new(size) { |i| Array.new(size) { |j| i == j ? 1.0 : 0.0 } }

      JACOBI_SWEEPS.times do
        off_diagonal = 0.0
        size.times { |i| (i + 1...size).each { |j| off_diagonal += a[i][j]**2 } }
        break if off_diagonal < JACOBI_TOLERANCE

        size.times do |p|
          (p + 1...size).each do |q|
            next if a[p][q].abs < 1e-300

            theta = (a[q][q] - a[p][p]) / (2.0 * a[p][q])
            t = (theta >= 0 ? 1.0 : -1.0) / (theta.abs + Math.sqrt(theta * theta + 1.0))
            c = 1.0 / Math.sqrt(t * t + 1.0)
            s = t * c
            rotate(a, vectors, p, q, c, s, size)
          end
        end
      end

      [ Array.new(size) { |i| a[i][i] }, vectors ]
    end

    # Eine Jacobi-Rotation in der Ebene (p, q).
    def rotate(a, vectors, p, q, c, s, size)
      size.times do |k|
        akp = a[k][p]
        akq = a[k][q]
        a[k][p] = c * akp - s * akq
        a[k][q] = s * akp + c * akq
      end
      size.times do |k|
        apk = a[p][k]
        aqk = a[q][k]
        a[p][k] = c * apk - s * aqk
        a[q][k] = s * apk + c * aqk
      end
      size.times do |k|
        vkp = vectors[k][p]
        vkq = vectors[k][q]
        vectors[k][p] = c * vkp - s * vkq
        vectors[k][q] = s * vkp + c * vkq
      end
    end

    # Standardnormalverteilte Zufallszahl (Box-Muller).
    def gaussian(random)
      Math.sqrt(-2.0 * Math.log(1.0 - random.rand)) * Math.cos(2.0 * Math::PI * random.rand)
    end
  end
end
