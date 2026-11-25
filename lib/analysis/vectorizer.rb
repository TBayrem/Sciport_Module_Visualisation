# ============================================================
# Datei: lib/analysis/vectorizer.rb
#
# Desc:
#   Schritt 2 der Analyse: wandelt die Texte der Personen in
#   TF-IDF-Vektoren um.
#
#   Ablauf:
#     1. Tokenisierung: Kleinbuchstaben, nur Wörter aus
#        Buchstaben mit mindestens MIN_TOKEN_LENGTH Zeichen,
#        ohne deutsche und englische Stoppwörter.
#     1a. Pluralformen zusammenführen: Ein Wort, das durch
#        Weglassen einer Endung (PLURAL_SUFFIXES) zu einem
#        anderen Wort des Korpus wird, zählt als dieses Wort
#        (cells → cell, untersuchungen → untersuchung,
#        kompetenzen → kompetenz). Das ist eine bewusst
#        einfache Grundformbildung ohne Wörterbuch; sie wirkt
#        nur, wenn die kürzere Form selbst im Korpus vorkommt.
#     2. Vokabular: nur Wörter, die in mindestens MIN_DF
#        Profilen und höchstens in MAX_DF_RATIO aller Profile
#        vorkommen; davon die MAX_FEATURES häufigsten.
#     3. Gewichtung: TF-IDF mit logarithmischer Termfrequenz
#          tf  = 1 + ln(Anzahl im Text)
#          idf = ln((1 + N) / (1 + df)) + 1
#        Die logarithmische Termfrequenz verhindert, dass sehr
#        lange Texte die Ähnlichkeiten dominieren.
#     4. Normierung: jeder Vektor erhält die Länge 1. Das
#        Skalarprodukt zweier Vektoren ist damit direkt ihre
#        Kosinus-Ähnlichkeit.
#
#   Die Vektoren sind dünn besetzt (Hash Index → Gewicht),
#   weil jedes Profil nur einen kleinen Teil des Vokabulars
#   enthält.
#
# Rückgabe von vectorize:
#   Result mit person_ids, vectors (gleiche Reihenfolge) und
#   terms (Index → Wort)
# ============================================================

module Analysis
  class Vectorizer
    Result = Struct.new(:person_ids, :vectors, :terms, keyword_init: true)

    MIN_TOKEN_LENGTH = 3
    MIN_DF = 3
    MAX_DF_RATIO = 0.5
    MAX_FEATURES = 8_000

    # Endungen für die Zusammenführung von Pluralformen, in
    # dieser Reihenfolge geprüft; die Grundform muss mindestens
    # MIN_STEM_LENGTH Zeichen haben. "n" vor "en", damit z. B.
    # schulen → schule wird und nicht → schul (Bruchstück aus
    # Bindestrich-Wörtern wie "Schul- und Unterrichtsforschung").
    PLURAL_SUFFIXES = %w[n s e en].freeze
    MIN_STEM_LENGTH = 4

    # Wörter, die in fast jedem Forschungstext vorkommen und
    # nichts über das Thema aussagen (Deutsch und Englisch).
    STOP_WORDS = %w[
      aber alle allem allen aller alles als also am an ander andere anderem anderen
      anderer anderes anders auch auf aus bei beim bereits besonders bis bzw da
      dabei dadurch dafür daher damit dann darauf daraus darin darüber das dass
      daß dem den denen denn der deren derer des deshalb dessen die dies diese
      diesem diesen dieser dieses doch dort du durch ein eine einem einen einer
      eines einige einigen einiger einiges einmal er es etwa etwas euch für gegen
      gibt hat hatte hatten haben hier hin hinter ich ihm ihn ihnen ihr ihre ihrem
      ihren ihrer ihres im immer in indem ins ist jede jedem jeden jeder jedes
      jedoch jene jenem jenen jener jenes kann kein keine keinem keinen keiner
      können könnte man manche manchem manchen mancher manches mehr mit muss
      müssen nach neben nicht nichts noch nun nur ob oder ohne sehr sein seine
      seinem seinen seiner seines seit sich sie sind so sodass solche solchem
      solchen solcher solches soll sollen sollte sondern sowie sowohl über um und
      uns unser unsere unserem unseren unter viel viele vom von vor wann war waren
      warum was weil welche welchem welchen welcher welches wenn wer werde werden
      wie wieder wir wird wo wurde wurden zu zum zur zwar zwischen

      projekt projekts projekte projekten vorhaben ziel ziele zielen rahmen
      ergebnisse ergebnis arbeiten arbeit beitrag hochschule universität
      förderung gefördert entwicklung ersten zweiten dritten neue neuen neuer
      neues insbesondere beispiel bzw sowie mittels hinblick bezug

      about above after again against all also among and any are because been
      before being below between both but can could did does doing down during
      each few for from further had has have having her here hers him his how
      however into its itself just more most must new not now off once only other
      our ours out over own same she should some such than that the their theirs
      them then there these they this those through too under until upon use used
      using very was were what when where which while who whom why will with
      within without would you your

      project paper study results result approach based different first second
      within university research

      verfügbar abstract available keine kein none berücksichtigung
      untersuchung untersuchungen untersucht untersuchen grundlage grundlagen
      anmerkung anmerkungen
      einfluss einfluß aspekt aspekte frage fragen bereich bereiche
      high low effect effects evidence self well may also two three one
      show shows shown found important significant various several many

      sup sub www http https html amp nbsp doi rheinland pfalz
    ].to_set.freeze

    # Erzeugt die TF-IDF-Vektoren.
    # texts: Hash { person_id => Text } aus TextCollector
    def vectorize(texts)
      person_ids = texts.keys
      counts = merge_plurals(texts.values.map { |text| term_counts(text) })
      terms = build_vocabulary(counts)
      index = terms.each_with_index.to_h
      idf = inverse_document_frequency(counts, terms)

      vectors = counts.map { |term_count| weight(term_count, index, idf) }

      Result.new(person_ids: person_ids, vectors: vectors, terms: terms)
    end

    private

    # Häufigkeit jedes Wortes in einem Text.
    def term_counts(text)
      tokens(text).tally
    end

    # Wörter eines Textes: Kleinbuchstaben, nur Buchstaben
    # (auch Umlaute), ohne Stoppwörter und sehr kurze Wörter.
    def tokens(text)
      text.downcase.scan(/\p{L}+/).reject do |token|
        token.length < MIN_TOKEN_LENGTH || STOP_WORDS.include?(token)
      end
    end

    # Führt Pluralformen mit ihrer Grundform zusammen (siehe
    # Schritt 1a). Die Zuordnung wird einmal für den ganzen
    # Korpus bestimmt und dann auf jeden Text angewendet.
    def merge_plurals(counts)
      corpus = Set.new
      counts.each { |term_count| corpus.merge(term_count.keys) }
      base_of = plural_map(corpus)
      return counts if base_of.empty?

      counts.map do |term_count|
        merged = Hash.new(0)
        term_count.each { |term, count| merged[base_of.fetch(term, term)] += count }
        merged
      end
    end

    # Hash { Pluralform => Grundform } für alle Wörter, deren
    # Grundform ebenfalls im Korpus vorkommt.
    def plural_map(corpus)
      corpus.each_with_object({}) do |term, base_of|
        PLURAL_SUFFIXES.each do |suffix|
          next unless term.end_with?(suffix)

          base = term.delete_suffix(suffix)
          next if base.length < MIN_STEM_LENGTH || !corpus.include?(base)

          base_of[term] = base
          break
        end
      end
    end

    # Vokabular: Wörter mit ausreichender, aber nicht zu hoher
    # Dokumenthäufigkeit; bei Überschreitung von MAX_FEATURES die
    # häufigsten. Alphabetisch sortiert, damit die Indizes bei
    # gleichen Daten immer gleich sind.
    def build_vocabulary(counts)
      document_frequency = Hash.new(0)
      counts.each { |term_count| term_count.each_key { |term| document_frequency[term] += 1 } }

      max_df = (MAX_DF_RATIO * counts.size).floor

      document_frequency
        .select { |_term, df| df >= MIN_DF && df <= max_df }
        .max_by(MAX_FEATURES) { |term, df| [ df, term ] }
        .map(&:first)
        .sort
    end

    # Inverse Dokumenthäufigkeit je Wort (geglättet).
    def inverse_document_frequency(counts, terms)
      vocabulary = terms.to_set
      document_frequency = Hash.new(0)
      counts.each do |term_count|
        term_count.each_key { |term| document_frequency[term] += 1 if vocabulary.include?(term) }
      end

      total = counts.size
      terms.to_h { |term| [ term, Math.log((1.0 + total) / (1.0 + document_frequency[term])) + 1.0 ] }
    end

    # TF-IDF-Vektor eines Textes, auf Länge 1 normiert.
    def weight(term_count, index, idf)
      vector = {}
      term_count.each do |term, count|
        position = index[term]
        vector[position] = (1.0 + Math.log(count)) * idf[term] if position
      end

      normalize(vector)
    end

    def normalize(vector)
      length = Math.sqrt(vector.values.sum { |value| value * value })
      return vector if length.zero?

      vector.transform_values { |value| value / length }
    end
  end
end
