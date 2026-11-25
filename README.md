# SciPort Visualization

**Visualisierungsmodul für SciPort RLP: Kooperationen und Forschungsthemen der rheinland-pfälzischen Hochschulen**

Diese Rails-Anwendung entsteht im Rahmen der Masterarbeit „Entwicklung eines produktionsreifen Visualisierungsmoduls für SciPort RLP“ (Bayrem Trabelsi, Hochschule Worms, Betreuung: Prof. Dr. Alexander Wiebel). Sie stellt die Daten des Forschungsportals SciPort RLP auf drei Seiten dar:

| Seite | Adresse | Inhalt |
|---|---|---|
| Netzwerk | `/` bzw. `/networks` | Hochschulen, Fachbereiche und Personen als Netzwerk mit Kooperationen über gemeinsame Projekte und Publikationen |
| Themenkarte | `/topic_maps` | Forschungsprofile als 2D-Karte (PCA, t-SNE oder UMAP), gruppiert nach Themen (k-Means oder DBSCAN) |
| Kombinierte Ansicht | `/combined_views` | Netzwerk und Themenkarte nebeneinander mit gemeinsamer Auswahl und thematischen Ähnlichkeitskanten |

## 1. Technik

| Komponente | Version / Technik |
|---|---|
| Programmiersprache | Ruby 4.0.6 (`.ruby-version`) |
| Framework | Ruby on Rails 8.1 |
| Datenbank | PostgreSQL 17 |
| Visualisierung | D3.js 7 (ES-Modul vom CDN jsDelivr) |
| JavaScript | ES-Module über Importmap, kein Build-Schritt |
| CSS | Propshaft, ein Stylesheet je Seite, Teilvorlage und Grafikkomponente |
| Thematische Analyse | reines Ruby, ohne externe Bibliotheken |

Der Browser braucht beim Aufruf Internetzugang, weil D3.js vom CDN geladen wird.

## 2. Architektur

Die Anwendung folgt dem MVC-Muster von Rails. Es gibt keine JSON-API: Jeder Controller gibt die Daten seiner Seite an die View, die sie als `data`-Attribut in die HTML-Seite einbettet. Alle Interaktionen (Auswahl, Zoom, Tooltip, Schwellenwert) laufen danach im Browser.

```text
app/
  controllers/        NetworksController, TopicMapsController, CombinedViewsController
  models/             SciPort-Modelle: Facility, Person, Role, ResearchProject, Publication, Authorship
  models/analysis/    Ergebnisse der Analyse: Run, Projection, Similarity, Clustering, ClusterAssignment, Topic
  models/visualization/  Fachlogik der Seiten: NetworkGraph, TopicMap, SimilarityGraph
  views/              Layout, je Seite index.html.erb, Teilvorlagen in shared/ und topic_maps/
  javascript/         page.js (Einstieg), network_view.js, topic_map_view.js, bar_chart.js,
                      topic_cards.js, similarity_slider.js, selection_state.js,
                      detail_panel.js, search_box.js, legend.js
  assets/stylesheets/ application.css und je Seite bzw. Komponente eine eigene Datei
lib/
  analysis/           Runner und die Rechenschritte der Analyse
  tasks/              Rake-Tasks für Datenimport und Analyse
db/migrate/           SciPort-Schema und Analyse-Tabellen
```

**Auswahl über alle Ansichten:** `SelectionState` hält die aktuelle Auswahl (Person, Einrichtung, Kante oder Thema) und benachrichtigt alle Komponenten der Seite (Beobachter-Muster). Dadurch heben Netzwerk, Themenkarte, Balkendiagramm und Detailbereich immer dieselben Personen hervor.

**Analyse-Tabellen:** Sie beginnen mit `analysis_` und liegen neben den SciPort-Tabellen. Auf die SciPort-Tabellen greift die Anwendung nur lesend zu; Fremdschlüssel gibt es nur zwischen den Analyse-Tabellen.

## 3. Voraussetzungen

- Ruby 4.0.6 mit Bundler
- PostgreSQL 17, lokal erreichbar unter `127.0.0.1:5432`, Benutzer `postgres`
- Zugang zur Webservice-Schnittstelle von SciPort RLP (nur für den einmaligen Datenimport)

## 4. Installation

```powershell
git clone <REPOSITORY-URL>
cd sciport_visualization
bundle install
```

### Datenbank-Passwort

Das Passwort steht nicht im Quellcode. `config/database.yml` liest es aus der Umgebungsvariable `POSTGRES_PASSWORD`, die `dotenv-rails` beim Start aus der Datei `.env` im Projektordner lädt:

```text
POSTGRES_PASSWORD=<Passwort des Benutzers postgres>
```

Die Datei `.env` ist in `.gitignore` eingetragen und darf weder committet noch weitergegeben werden.

### Datenbank anlegen

```powershell
ruby bin/rails db:create
ruby bin/rails db:migrate
```

Die Migrationen legen das SciPort-Schema (`CreateSciportSchema`) und die Analyse-Tabellen (`CreateAnalysisTables`) an.

## 5. Daten übernehmen (einmalig)

Für Entwicklung und Evaluation wird die Datenbank einmalig über die Webservice-Schnittstelle von SciPort RLP befüllt. Die Reihenfolge ist wichtig, weil Projekte und Publikationen auf Personen und Einrichtungen verweisen:

```powershell
ruby bin/rails facilities:import
ruby bin/rails people:import
ruby bin/rails research_projects:import
ruby bin/rails publications:import
```

Jeder Datensatz behält seine SciPort-Kennung (`external_id`); ein erneuter Import aktualisiert vorhandene Datensätze. Nach der Integration in SciPort RLP arbeitet das Modul direkt auf der Datenbank des Portals, und diese Tasks werden nicht mehr gebraucht.

## 6. Thematische Analyse

Themenkarte und kombinierte Ansicht lesen nur vorberechnete Ergebnisse. Die Berechnung läuft getrennt von den Seitenaufrufen:

```powershell
ruby bin/rails analysis:run      # vollständiger Lauf
ruby bin/rails analysis:status   # die letzten zehn Läufe mit Status und Dauer
```

`analysis:run` startet `Analysis::Runner`, der diese Schritte nacheinander ausführt:

| Schritt | Klasse | Ergebnis |
|---|---|---|
| 1 | `TextCollector` | je Person ein Text aus Projekten, Publikationen und Forschungsgebiet |
| 2 | `Vectorizer` | TF-IDF-Vektoren (bis 8.000 Begriffe, Stoppwörter Deutsch/Englisch, Pluralformen zusammengeführt) |
| 3 | `Reducer` | Reduktion auf 50 Dimensionen (randomisierte Singulärwertzerlegung) |
| 4 | `Projector` | 2D-Projektionen mit PCA, t-SNE und UMAP |
| 5 | `SimilarityCalculator` | Kosinus-Ähnlichkeiten, je Person die zehn ähnlichsten ab 0,5 |
| 6 | `Clusterer` | k-Means (k = 4, 6, 8, 10, 12, 15, 20) und DBSCAN (eps aus den Daten, min_pts = 5 und 10) |
| 7 | `TopicNamer` | kennzeichnende Begriffe je Cluster (klassenbasiertes TF-IDF) |

Alle Ergebnisse werden am Ende in einer Datenbanktransaktion gespeichert. Ein fehlgeschlagener Lauf hinterlässt keine Teilergebnisse; die Seiten zeigen dann weiter den letzten erfolgreichen Lauf. Erhalten bleiben die drei jüngsten erfolgreichen Läufe. Ein zweiter Start, während ein Lauf aktiv ist, bricht mit Exit-Code 2 ab.

Beim vorliegenden Datenbestand (2.895 Personen mit Texten) dauert ein Lauf etwa 5 Minuten.

### Regelmäßige Ausführung

Linux (cron), täglich um 3 Uhr:

```text
0 3 * * * cd /srv/sciport-visualization && RAILS_ENV=production bin/rails analysis:run >> log/analysis.log 2>&1
```

Windows (Aufgabenplanung):

```powershell
schtasks /Create /TN "SciPort Analyse" /SC DAILY /ST 03:00 /TR "cmd /c cd /d C:\Projects\sciport_visualization && ruby bin/rails analysis:run >> log\analysis.log 2>&1"
```

## 7. Anwendung starten

```powershell
ruby bin/rails server
```

Danach im Browser `http://localhost:3000` öffnen. Ohne abgeschlossenen Analyselauf zeigen Themenkarte und kombinierte Ansicht einen Hinweis; die Netzwerkseite funktioniert auch ohne Analyse.

Die Fußzeile zeigt den Zeitpunkt des jüngsten abgeschlossenen Analyselaufs.

## 8. Bedienung

- **Suche:** Personen und Einrichtungen; die Wahl eines Vorschlags wählt das Element aus.
- **Zoom:** Mausrad oder Knöpfe +, − und ⌂. Das Netzwerk zeigt je nach Zoomstufe Hochschulen (Stufe 1), zusätzlich Fachbereiche (Stufe 2) und zusätzlich Personen (Stufe 3).
- **Auswahl:** Klick auf ein Symbol, eine Kante, eine Themenkarte oder einen Eintrag im Detailbereich. „Zurücksetzen“ hebt die Auswahl auf.
- **Themenkarte:** Projektion und Clusterverfahren im Formular über der Karte wählen. Die Wahl gilt auch für die kombinierte Ansicht.
- **Kombinierte Ansicht:** Der Regler legt fest, ab welcher Ähnlichkeit thematische Kanten im Netzwerk erscheinen.
- **Legende:** Schaltfläche „ⓘ Legende“ unten auf jeder Seite.

## 9. Entwicklungsstand

**Stand: November 2026**

Umgesetzt:

- alle drei Seiten mit gemeinsamer Auswahl, Suche, Detailbereich und Legende
- Netzwerk als Galaxie-Layout mit drei Zoomstufen, Kooperationskanten und Sammelkanten
- Themenkarte mit drei Projektionen, zwei Clusterverfahren und Themenübersicht
- kombinierte Ansicht mit Ähnlichkeitskanten, Schwellenwert-Regler und Balkendiagramm für Projekte und Publikationen
- vollständige Analyse in Ruby mit nächtlicher Ausführung

Offen:

- automatisierte Tests (Ordner `test/` noch ohne eigene Tests)
- Suche und Auswahl für Projekte, Publikationen, Schlagwörter und Themen
- Tooltip der Themenkarte mit Einrichtung und Kennzahlen
- „Zurücksetzen“ auch für Zoom und Parameter

## 10. Sicherheit und Daten

- Zugangsdaten (Datenbank, SciPort-Webservice) gehören in `.env` bzw. Umgebungsvariablen, nicht in den Quellcode, in Commits oder in Screenshots.
- Die Daten stammen aus SciPort RLP und enthalten personenbezogene Angaben. Die Veröffentlichung des Quellcodes bedeutet nicht, dass diese Daten veröffentlicht werden dürfen.
- `db:drop`, `db:reset` und `db:setup` löschen alle importierten Daten; der Import dauert danach erneut.

## 11. Wissenschaftlicher Kontext und Lizenz

Entwurf, Umsetzung und Evaluation sind in der Masterarbeit beschrieben (Kapitel 4 bis 6). Lizenz und eine mögliche Veröffentlichung sind vor einer öffentlichen Freigabe mit der Hochschule Worms und den Betreibern von SciPort RLP zu klären.
