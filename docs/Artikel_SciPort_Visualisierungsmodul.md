# Wer forscht mit wem woran? Ein Visualisierungsmodul für das Forschungsportal SciPort RLP

*Von Bayrem Trabelsi. Masterarbeit (in Bearbeitung) im M.Sc. Wirtschaftsinformatik, Hochschule Worms, Betreuung: Prof. Dr. Alexander Wiebel. Quellcode: [Sciport_Module_Visualisation](https://github.com/TBayrem/Sciport_Module_Visualisation). Stand: November 2026.*

---

## Das Problem

SciPort RLP sammelt Einrichtungen, Personen, Projekte und Publikationen der rheinland-pfälzischen Hochschulen. Wer die Daten durchsucht, sieht Listen. Zwei Fragen beantworten Listen schlecht: **Wer arbeitet mit wem zusammen?** und **Wer forscht thematisch an ähnlichen Fragen?** Mein Modul macht beides sichtbar und soll später direkt auf der Datenbank des Portals laufen.

## Drei Ansichten

| Seite | Inhalt |
|---|---|
| Netzwerk | Hochschulen, Fachbereiche und Personen als Netzwerk, Kanten für Kooperationen über gemeinsame Projekte und Publikationen |
| Themenkarte | Forschungsprofile als 2D-Karte (PCA, t-SNE oder UMAP), gruppiert nach Themen (k-Means oder DBSCAN) |
| Kombinierte Ansicht | beide nebeneinander mit gemeinsamer Auswahl und thematischen Ähnlichkeitskanten |

Das Netzwerk arbeitet mit drei Zoomstufen: erst Hochschulen, dann Fachbereiche, dann Personen. So bleibt es auch bei fast 3.000 Personen lesbar.

## Architektur

Die Anwendung nutzt Ruby on Rails 8, PostgreSQL 17 und D3.js 7. Das JavaScript läuft als ES-Module über Importmap ohne Build-Schritt. Es gibt bewusst **keine JSON-API**: Jeder Controller gibt die Daten seiner Seite an die View, die sie als `data`-Attribut in die HTML-Seite einbettet. Danach läuft jede Interaktion im Browser.

Die **Auswahl über alle Ansichten** hält eine Klasse `SelectionState` und benachrichtigt alle Komponenten (Beobachter-Muster). Wer im Netzwerk eine Person anklickt, sieht sie deshalb gleichzeitig in der Themenkarte, im Balkendiagramm und im Detailbereich.

Die thematische Analyse ist **vom Seitenaufruf getrennt**: Sie rechnet nachts vor und speichert ihre Ergebnisse in eigenen Tabellen. Die Seiten lesen nur diese Ergebnisse. Das hält die Antwortzeiten klein.

## Die Analyse in sieben Schritten

1. **Texte sammeln:** je Person ein Text aus Forschungsgebiet, Projekttiteln, Beschreibungen, Schlagwörtern und Publikationsabstracts
2. **TF-IDF:** Tokenisierung, deutsche und englische Stoppwörter, einfache Zusammenführung von Pluralformen, logarithmische Termfrequenz, Vektoren auf Länge 1 normiert
3. **Reduktion auf 50 Dimensionen:** randomisierte Singulärwertzerlegung (latente semantische Analyse) direkt auf den dünn besetzten Vektoren, eine 2.895 × 8.000-Matrix wird nie vollständig angelegt
4. **Projektion auf 2D:** PCA, t-SNE und UMAP
5. **Ähnlichkeiten:** Kosinus-Ähnlichkeit, je Person die zehn ähnlichsten Personen ab 0,5
6. **Clustering:** k-Means mit k = 4 bis 20 und DBSCAN, jeweils feste Parameterstufen, die die Oberfläche nur noch auswählt
7. **Themenbegriffe:** klassenbasiertes TF-IDF (c-TF-IDF) benennt jeden Cluster mit seinen kennzeichnenden Begriffen

## Selbst umgesetzt, mit Quellen

Alle Verfahren sind **in reinem Ruby selbst geschrieben**, ohne externe Bibliotheken: randomisierte SVD nach Halko, Martinsson und Tropp, t-SNE nach van der Maaten und Hinton (2008, vereinfacht mit k-Nächste-Nachbarn-Anziehung und Stichproben-Abstoßung), UMAP nach McInnes et al. (2018), k-Means mit k-means++ (Arthur und Vassilvitskii 2007), DBSCAN (Ester et al. 1996) und c-TF-IDF (Grootendorst 2022). Feste Startwerte machen jeden Lauf wiederholbar. Das war eine bewusste Entscheidung: Nur wer einen Algorithmus selbst umsetzt, versteht seine Grenzen.

## Robustheit

- Alle Ergebnisse eines Laufs werden in **einer Transaktion** gespeichert. Ein Fehler hinterlässt nichts Halbfertiges.
- Die Seiten zeigen immer den **letzten erfolgreichen Lauf**, ein laufender oder fehlgeschlagener Lauf ändert nichts an der Anzeige.
- Ein **zweiter gleichzeitiger Lauf** wird mit einem eigenen Exit-Code abgelehnt.
- Der Ordner `test/` enthält **über 60 Testfälle** für Analyse-Schritte, Modelle, die Logik der Visualisierungen und die Seiten.
- **Zugangsdaten** stehen nicht im Quellcode, sondern in einer `.env`-Datei, die nicht committet wird.

## Grenzen und offene Punkte

- Eine **Bewertung der Clusterqualität** und eine **Nutzerevaluation** sind nicht Teil dieses Artikels. Sie gehören in die schriftliche Ausarbeitung.
- Noch offen sind Suche und Auswahl für Projekte, Publikationen, Schlagwörter und Themen, der Tooltip der Themenkarte und ein Zurücksetzen für Zoom und Parameter.
- Die SciPort-Daten enthalten **personenbezogene Angaben**. Der Quellcode ist öffentlich, die Daten sind es nicht und dürfen es nicht werden.
- D3.js wird vom CDN geladen, die Anwendung braucht deshalb Internet im Browser.

## Was ich mitnehme

1. **Vorberechnen und Anzeigen trennen.** So bleiben die Seiten schnell, und ein Fehler in der Analyse bricht die Anzeige nicht.
2. **Algorithmen selbst bauen.** t-SNE oder UMAP als Bibliotheksaufruf liefert ein Bild, die eigene Umsetzung liefert Verständnis für Parameter und Grenzen.
3. **Gemeinsame Auswahl macht Daten erkundbar.** Erst wenn mehrere Ansichten dasselbe hervorheben, wird aus Grafiken ein Werkzeug.

---

*Ich suche zum 01.03.2027 den Einstieg als Junior IT Consultant oder IT Business Analyst. [LinkedIn](https://linkedin.com/in/bayremtrabelsi) · [GitHub](https://github.com/TBayrem)*