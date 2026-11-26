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

Die Anwendung nutzt Ruby on Rails 8 [1], PostgreSQL 17 und D3.js 7 [2]. Das JavaScript läuft als ES-Module über Importmap ohne Build-Schritt. Es gibt bewusst **keine JSON-API**: Jeder Controller gibt die Daten seiner Seite an die View, die sie als `data`-Attribut in die HTML-Seite einbettet. Danach läuft jede Interaktion im Browser.

Die **Auswahl über alle Ansichten** hält eine Klasse `SelectionState` und benachrichtigt alle Komponenten (Beobachter-Muster). Wer im Netzwerk eine Person anklickt, sieht sie deshalb gleichzeitig in der Themenkarte, im Balkendiagramm und im Detailbereich.

Die thematische Analyse ist **vom Seitenaufruf getrennt**: Sie rechnet nachts vor und speichert ihre Ergebnisse in eigenen Tabellen. Die Seiten lesen nur diese Ergebnisse. Das hält die Antwortzeiten klein.

## Die Analyse in sieben Schritten

1. **Texte sammeln:** je Person ein Text aus Forschungsgebiet, Projekttiteln, Beschreibungen, Schlagwörtern und Publikationsabstracts
2. **TF-IDF:** Tokenisierung, deutsche und englische Stoppwörter, einfache Zusammenführung von Pluralformen, logarithmische Termfrequenz, Vektoren auf Länge 1 normiert
3. **Reduktion auf 50 Dimensionen:** randomisierte Singulärwertzerlegung nach [3] (latente semantische Analyse) direkt auf den dünn besetzten Vektoren, eine 2.895 × 8.000-Matrix wird nie vollständig angelegt
4. **Projektion auf 2D:** PCA, t-SNE und UMAP
5. **Ähnlichkeiten:** Kosinus-Ähnlichkeit, je Person die zehn ähnlichsten Personen ab 0,5
6. **Clustering:** k-Means mit k = 4 bis 20 und DBSCAN, jeweils feste Parameterstufen, die die Oberfläche nur noch auswählt
7. **Themenbegriffe:** klassenbasiertes TF-IDF (c-TF-IDF) benennt jeden Cluster mit seinen kennzeichnenden Begriffen

## Selbst umgesetzt, mit Quellen

Alle Verfahren sind **in reinem Ruby selbst geschrieben**, ohne externe Bibliotheken: randomisierte SVD nach Halko, Martinsson und Tropp, t-SNE nach van der Maaten und Hinton (2008, [4]; vereinfacht mit k-Nächste-Nachbarn-Anziehung und Stichproben-Abstoßung), UMAP nach McInnes et al. (2018, [5]), k-Means mit k-means++ (Arthur und Vassilvitskii 2007, [6]), DBSCAN (Ester et al. 1996, [7]) und c-TF-IDF (Grootendorst 2022, [8]). Feste Startwerte machen jeden Lauf wiederholbar. Das war eine bewusste Entscheidung: Nur wer einen Algorithmus selbst umsetzt, versteht seine Grenzen.

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

## Quellen

1. Ruby on Rails Guides (Framework-Dokumentation). https://guides.rubyonrails.org/
2. Bostock, M., Ogievetsky, V., Heer, J. (2011): D3: Data-Driven Documents. IEEE Transactions on Visualization and Computer Graphics 17(12), S. 2301–2309. https://doi.org/10.1109/TVCG.2011.185
3. Halko, N., Martinsson, P.-G., Tropp, J. A. (2011): Finding Structure with Randomness: Probabilistic Algorithms for Constructing Approximate Matrix Decompositions. SIAM Review 53(2), S. 217–288. https://arxiv.org/abs/0909.4061
4. van der Maaten, L., Hinton, G. (2008): Visualizing Data using t-SNE. Journal of Machine Learning Research 9, S. 2579–2605. https://jmlr.org/papers/v9/vandermaaten08a.html
5. McInnes, L., Healy, J., Melville, J. (2018): UMAP: Uniform Manifold Approximation and Projection for Dimension Reduction. arXiv:1802.03426. https://arxiv.org/abs/1802.03426
6. Arthur, D., Vassilvitskii, S. (2007): k-means++: The Advantages of Careful Seeding. Proc. ACM-SIAM SODA, S. 1027–1035. https://dblp.org/rec/conf/soda/ArthurV07.html
7. Ester, M., Kriegel, H.-P., Sander, J., Xu, X. (1996): A Density-Based Algorithm for Discovering Clusters in Large Spatial Databases with Noise. Proc. KDD-96, S. 226–231. https://www.aaai.org/Papers/KDD/1996/KDD96-037.pdf
8. Grootendorst, M. (2022): BERTopic: Neural topic modeling with a class-based TF-IDF procedure. arXiv:2203.05794. https://arxiv.org/abs/2203.05794

*Hinweis: Preise, Herstellerangaben und Aussagen zu Produkten geben den Stand der jeweiligen Studienarbeit wieder. Alle Links wurden zuletzt im November 2026 gesucht oder abgerufen; Quellen mit dem Vermerk "wie in der Studienarbeit zitiert" sind dort im Literaturverzeichnis nachzuschlagen.*

---

*Ich suche zum 01.03.2027 den Einstieg als Junior IT Consultant oder IT Business Analyst. [LinkedIn](https://linkedin.com/in/bayremtrabelsi) · [GitHub](https://github.com/TBayrem)*