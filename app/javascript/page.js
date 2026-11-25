// ============================================================
// Datei: app/javascript/page.js
//
// Desc:
//   Einstiegspunkt aller drei Seiten. Liest den Seitentyp
//   (data-page) und die eingebetteten Daten aus dem HTML,
//   erzeugt SelectionState und setzt die Komponenten der
//   Seite zusammen (Komposition, vgl. Abb. 7).
//
//   Seitentypen:
//     network   → networks/index        (UC 1, UC 2)
//     topic-map → topic_maps/index      (UC 3, UC 4)
//     combined  → combined_views/index  (UC 5, UC 6)
//
//   Auswahltypen (SelectionState): person, facility, link und
//   topic. Ein Thema (Cluster der Themenkarte) lässt sich auf
//   der Themenkarte und in der kombinierten Ansicht auswählen;
//   alle Teilansichten heben dann dieselben Personen hervor
//   (FA33).
//
//   Die Seite startet direkt beim Laden: Importmap bindet
//   page.js als ES-Modul ein, und ES-Module werden erst
//   ausgeführt, wenn das HTML vollständig gelesen ist.
// ============================================================

import { SelectionState } from "selection_state"
import { NetworkView } from "network_view"
import { TopicMapView } from "topic_map_view"
import { TopicCards } from "topic_cards"
import { DetailPanel } from "detail_panel"
import { SearchBox } from "search_box"
import { BarChart } from "bar_chart"
import { SimilaritySlider } from "similarity_slider"
import { Legend } from "legend"

export class Page {
  #root
  #selection
  #facilitiesById = null
  #clusterOf = null

  // root: Element mit data-page und den eingebetteten Daten.
  constructor(root) {
    this.#root = root
  }

  // Baut die Komponenten für den jeweiligen Seitentyp auf.
  init() {
    switch (this.#root.dataset.page) {
      case "network":
        this.#initNetworkPage()
        break
      case "topic-map":
        this.#initTopicMapPage()
        break
      case "combined":
        this.#initCombinedPage()
        break
      default:
        throw new Error(`Unbekannter Seitentyp: ${this.#root.dataset.page}`)
    }

    this.#bindResetButton()
    this.#initLegend()
  }

  // ----------------------------------------------------------
  // Seite "Netzwerk"
  // ----------------------------------------------------------

  // Erzeugt SelectionState sowie Grafik, Infobereich, Suche und
  // Balkendiagramm und meldet sie als Beobachter der Auswahl an.
  #initNetworkPage() {
    const network = this.#readData("network")

    this.#selection = new SelectionState(this.#networkResolvers(network))

    const networkView = new NetworkView(
      this.#root.querySelector("[data-network-view]"),
      network,
      this.#selection,
      {
        tooltip: this.#root.querySelector("[data-tooltip]"),
        zoomControls: this.#root.querySelector("[data-zoom-controls]")
      }
    )

    const detailPanel = new DetailPanel(
      this.#root.querySelector("[data-detail-panel]"),
      network,
      this.#selection
    )

    const searchBox = new SearchBox(
      this.#root.querySelector("[data-search-box]"),
      network.nodes,
      this.#selection
    )

    const barChart = new BarChart(
      this.#root.querySelector("[data-bar-chart]"),
      this.#root.querySelector("[data-bar-chart-hint]"),
      network,
      this.#selection
    )

    this.#selection.subscribe(state => networkView.highlight(state))
    this.#selection.subscribe(state => detailPanel.show(state))
    this.#selection.subscribe(state => barChart.highlight(state))
    this.#selection.subscribe(state => { if (!state.selected) searchBox.clear() })
  }

  // ----------------------------------------------------------
  // Seite "Themenkarte"
  // ----------------------------------------------------------

  // Erzeugt SelectionState sowie Punktwolke, Themenkarten,
  // Infobereich und Suche. Die Themenkarte nutzt dieselben
  // Knoten wie das Netzwerk, deshalb funktionieren Auswahl,
  // Detailpanel und Suche wie auf der Netzwerkseite.
  // Ein Klick auf eine Themenkarte wählt das Thema aus; die
  // Karte zoomt dann auf seinen Bereich (FA29).
  #initTopicMapPage() {
    const topicMap = this.#readData("topicMap")

    this.#selection = new SelectionState({
      ...this.#networkResolvers(topicMap),
      ...this.#topicResolvers(topicMap)
    })

    const topicMapView = new TopicMapView(
      this.#root.querySelector("[data-topic-map-view]"),
      topicMap,
      {
        tooltip: this.#root.querySelector("[data-tooltip]"),
        zoomControls: this.#root.querySelector("[data-zoom-controls]"),
        onSelect: item => this.#selection.select(item)
      }
    )

    const topicCards = new TopicCards(
      this.#root.querySelector("[data-topic-cards]"),
      topicMap.topics,
      {
        onHover: cluster => topicMapView.highlightCluster(cluster),
        onFocus: cluster => this.#selection.select({ type: "topic", id: String(cluster) })
      }
    )

    const detailPanel = new DetailPanel(
      this.#root.querySelector("[data-detail-panel]"),
      topicMap,
      this.#selection
    )

    const searchBox = new SearchBox(
      this.#root.querySelector("[data-search-box]"),
      topicMap.nodes,
      this.#selection
    )

    this.#selection.subscribe(state => topicMapView.highlight(state))
    this.#selection.subscribe(state => detailPanel.show(state))
    this.#selection.subscribe(state => topicCards.markActive(this.#activeTopic(state, topicMap)))
    this.#selection.subscribe(state => { if (!state.selected) searchBox.clear() })

    this.#bindParametersForm()
  }

  // ----------------------------------------------------------
  // Seite "Kombinierte Ansicht"
  // ----------------------------------------------------------

  // Netzwerk und Themenkarte nebeneinander mit einem
  // gemeinsamen SelectionState (FA30, FA33): Jede Auswahl in
  // einer Teilansicht hebt in allen Teilansichten dieselben
  // Personen hervor. Darunter Balkendiagramm (Projekte und
  // Publikationen, FA34) und Themenkarten; oben der
  // Schwellenwert-Regler für die Ähnlichkeitskanten (FA31,
  // FA32).
  //
  // Eingebettete Daten:
  //   data-network     NetworkGraph#to_h
  //   data-topic-map   TopicMap#to_h ohne Netzwerkteile
  //   data-similarity  SimilarityGraph#to_h
  #initCombinedPage() {
    const network = this.#readData("network")
    const topicMap = this.#readData("topicMap")
    const similarity = this.#readData("similarity")

    // Netzwerkdaten und Themen zusammen: für Detailpanel und
    // Balkendiagramm (Themenname, Thema einer Person)
    const combined = { ...network, topics: topicMap.topics, points: topicMap.points }

    this.#selection = new SelectionState({
      ...this.#networkResolvers(network),
      ...this.#topicResolvers(topicMap)
    })

    const networkPanel = this.#root.querySelector("[data-network-panel]")
    const topicPanel = this.#root.querySelector("[data-topic-panel]")

    const networkView = new NetworkView(
      networkPanel.querySelector("[data-network-view]"),
      network,
      this.#selection,
      {
        tooltip: networkPanel.querySelector("[data-tooltip]"),
        zoomControls: networkPanel.querySelector("[data-zoom-controls]"),
        similarity
      }
    )

    const topicMapView = new TopicMapView(
      topicPanel.querySelector("[data-topic-map-view]"),
      { ...topicMap, nodes: network.nodes },
      {
        tooltip: topicPanel.querySelector("[data-tooltip]"),
        zoomControls: topicPanel.querySelector("[data-zoom-controls]"),
        onSelect: item => this.#selection.select(item)
      }
    )

    const topicCards = new TopicCards(
      this.#root.querySelector("[data-topic-cards]"),
      topicMap.topics,
      {
        onHover: cluster => topicMapView.highlightCluster(cluster),
        onFocus: cluster => this.#selection.select({ type: "topic", id: String(cluster) })
      }
    )

    const detailPanel = new DetailPanel(
      this.#root.querySelector("[data-detail-panel]"),
      combined,
      this.#selection
    )

    const searchBox = new SearchBox(
      this.#root.querySelector("[data-search-box]"),
      network.nodes,
      this.#selection
    )

    const barChart = new BarChart(
      this.#root.querySelector("[data-bar-chart]"),
      this.#root.querySelector("[data-bar-chart-hint]"),
      combined,
      this.#selection
    )

    new SimilaritySlider(
      this.#root.querySelector("[data-similarity-slider]"),
      { onChange: value => networkView.setSimilarityThreshold(value) }
    )

    this.#selection.subscribe(state => networkView.highlight(state))
    this.#selection.subscribe(state => topicMapView.highlight(state))
    this.#selection.subscribe(state => detailPanel.show(state))
    this.#selection.subscribe(state => barChart.highlight(state))
    this.#selection.subscribe(state => topicCards.markActive(this.#activeTopic(state, topicMap)))
    this.#selection.subscribe(state => { if (!state.selected) searchBox.clear() })
  }

  // Parameterformular: jede Änderung sendet das Formular ab
  // (GET, Seite wird neu gerendert). Beim Wechsel des
  // Algorithmus wird vorher die passende Feldgruppe
  // eingeblendet und freigegeben, die andere gesperrt, damit
  // nur die Parameter des gewählten Algorithmus in der URL
  // stehen.
  #bindParametersForm() {
    const form = this.#root.querySelector("[data-parameters-form]")
    if (!form) return

    // Mit JavaScript ist der Knopf "Anwenden" überflüssig.
    form.querySelector("[data-parameters-submit]")?.setAttribute("hidden", "")

    form.addEventListener("change", event => {
      if (event.target.matches("[data-algorithm-switch]")) {
        const algorithm = event.target.value

        form.querySelectorAll("[data-algorithm-group]").forEach(group => {
          const active = group.dataset.algorithmGroup === algorithm
          group.hidden = !active
          group.querySelectorAll("select").forEach(select => { select.disabled = !active })
        })
      }

      if (event.target.matches("[data-auto-submit], [data-algorithm-switch]")) form.requestSubmit()
    })
  }

  // ----------------------------------------------------------
  // Auflösung der Auswahl (Netzwerk und Themenkarte)
  // ----------------------------------------------------------

  // Liefert SelectionState je Auswahltyp die zugehörigen
  // Personen: eine Person selbst, alle Personen einer
  // Einrichtung (einschließlich Untereinrichtungen) oder die
  // Personen an beiden Enden einer Kante.
  #networkResolvers(network) {
    const peopleByFacility = new Map()

    for (const node of network.nodes) {
      if (node.type !== "person") continue

      for (const facilityId of node.facilities) {
        for (const ancestorId of this.#ancestors(facilityId, network)) {
          if (!peopleByFacility.has(ancestorId)) peopleByFacility.set(ancestorId, [])
          peopleByFacility.get(ancestorId).push(node.id)
        }
      }
    }

    const peopleOf = id => (id.startsWith("p") ? [ id ] : peopleByFacility.get(id) ?? [])

    return {
      person: id => [ id ],
      facility: id => peopleOf(id),
      // Kante "Stufe|Quelle|Ziel": Personen beider Enden
      link: key => {
        const [ , source, target ] = key.split("|")
        return [ ...peopleOf(source), ...peopleOf(target) ]
      }
    }
  }

  // Liefert SelectionState zu einem Thema (ID = Clusternummer
  // als Text) alle Personen des Clusters.
  #topicResolvers(topicMap) {
    const peopleByCluster = new Map()

    for (const point of topicMap.points) {
      if (!peopleByCluster.has(point.cluster)) peopleByCluster.set(point.cluster, [])
      peopleByCluster.get(point.cluster).push(point.id)
    }

    return { topic: id => peopleByCluster.get(Number(id)) ?? [] }
  }

  // Thema, dessen Themenkarte markiert wird: das ausgewählte
  // Thema oder das Thema der ausgewählten Person.
  #activeTopic(state, topicMap) {
    const item = state.selected
    if (item?.type === "topic") return Number(item.id)
    if (item?.type !== "person") return null

    this.#clusterOf ??= new Map(topicMap.points.map(point => [ point.id, point.cluster ]))
    return this.#clusterOf.get(item.id) ?? null
  }

  // Liefert eine Einrichtung und alle übergeordneten
  // Einrichtungen bis zur obersten.
  #ancestors(facilityId, network) {
    const facilities = this.#facilitiesById ??= new Map(
      network.nodes.filter(node => node.type === "facility").map(node => [ node.id, node ])
    )
    const chain = []

    for (let id = facilityId; id; id = facilities.get(id)?.parent) chain.push(id)

    return chain
  }

  // ----------------------------------------------------------
  // Gemeinsame Hilfsmethoden
  // ----------------------------------------------------------

  // Liest ein data-Attribut des Seitenelements als JSON.
  // name in camelCase, z. B. "topicMap" für data-topic-map.
  #readData(name) {
    return JSON.parse(this.#root.dataset[name])
  }

  // Legende (auf jeder Seite vorhanden).
  #initLegend() {
    const legend = this.#root.querySelector("[data-legend]")
    if (legend) new Legend(legend)
  }

  // "Zurücksetzen" hebt die Auswahl auf.
  #bindResetButton() {
    this.#root.querySelector("[data-reset]")
      ?.addEventListener("click", () => this.#selection.select(null))
  }
}

// Start: Seitenelement suchen und Seite aufbauen.
const root = document.querySelector("[data-page]")
if (root) new Page(root).init()