// ============================================================
// Datei: app/javascript/topic_map_view.js
//
// Desc:
//   Punktwolke der Themenkarte (UC3), gezeichnet mit D3 in
//   ein SVG-Element.
//
//   - Jede Person erscheint mit dem Personensymbol
//     (#icon-person aus dem Legenden-Partial) an ihrer
//     2D-Position aus der Projektion (PCA, t-SNE oder UMAP,
//     Werte −1..1).
//   - Die Farbe zeigt den Themencluster (CSS-Klassen topic-0,
//     topic-1, … setzen color; Rauschen bei DBSCAN: noise).
//   - Jeder Cluster bekommt eine Hülle (konvexe Hülle der 90 %
//     zentralsten Punkte, damit Ausreißer sie nicht aufblähen)
//     und eine Beschriftung mit seinen ersten zwei Begriffen.
//     Klick auf eine Hülle wählt das Thema aus (FA26); die
//     Karte zoomt dann über highlight auf seinen Bereich.
//   - Zoom und Verschieben mit Maus oder Zoomknöpfen; die
//     Symbole behalten dabei ihre Bildschirmgröße.
//   - Hover zeigt einen Tooltip, Klick wählt die Person aus,
//     Klick auf den Hintergrund hebt die Auswahl auf.
//
// Schnittstelle (wird von page.js genutzt):
//   new TopicMapView(svg, data, { tooltip, zoomControls, onSelect })
//   highlight(state)         Auswahl hervorheben; state ist der
//                            SelectionState (selected, people).
//                            Bei einem Thema zoomt die Karte auf
//                            dessen Bereich (FA29).
//   highlightCluster(nr)     einen Cluster hervorheben
//                            (Themenkarte unter der Maus),
//                            null hebt das wieder auf
//   focusCluster(nr)         auf einen Cluster zoomen
//   clear()                  alles zurücksetzen
// ============================================================

import * as d3 from "d3"

// Größen und Verhalten
const LAYOUT = {
  worldRadius: 500,      // Projektion −1..1 → −500..500
  padding: 40,           // Rand in Pixeln bei der Gesamtansicht
  iconSize: 16,          // Personensymbol in Pixeln
  selectedIconSize: 28,  // ausgewählte Person
  hullQuantile: 0.9,     // Anteil der Punkte für die Hülle
  hullPadding: 14,       // Rand der Hülle in Pixeln
  labelSize: 13,         // Schriftgröße der Clusterbeschriftung
  labelMaxZoom: 6,       // bei starkem Zoom ausblenden
  scaleExtent: [0.2, 40],
  transition: 600
}

const NOISE = -1

export class TopicMapView {
  #svg
  #data
  #tooltip
  #zoomLevel
  #onSelect
  #zoom
  #transform = d3.zoomIdentity
  #root
  #layers = {}
  #names = new Map()
  #topics = new Map()
  #pointSelection
  #hulls = []
  #selectedId = null

  constructor(svg, data, { tooltip = null, zoomControls = null, onSelect = () => {} } = {}) {
    this.#svg = d3.select(svg)
    this.#data = data
    this.#tooltip = tooltip
    this.#onSelect = onSelect
    this.#zoomLevel = zoomControls?.querySelector("[data-zoom-level]")

    // Namen der Personen aus den Knoten des Netzwerkmodells
    for (const node of data.nodes) this.#names.set(node.id, node.name || node.id)
    for (const topic of data.topics) this.#topics.set(topic.cluster, topic)

    this.#buildLayers()
    this.#drawHulls()
    this.#drawPoints()
    this.#drawLabels()
    this.#setupZoom()
    this.#bindZoomControls(zoomControls)
    this.#fit(false)

    // Bei Größenänderung des Panels die Gesamtansicht neu einpassen
    new ResizeObserver(() => this.#fit(false)).observe(svg)
  }

  // ----------------------------------------------------------
  // Öffentliche Methoden
  // ----------------------------------------------------------

  // state.people ist ein Set von Personen-IDs ("p12", …).
  highlight(state = { selected: null, people: new Set() }) {
    const ids = new Set(state.people)
    const selected = state.selected
    this.#selectedId = selected?.type === "person" ? selected.id : null

    const active = ids.size > 0
    this.#svg.classed("has-selection", active)
    this.#pointSelection
      .classed("dimmed", d => active && !ids.has(d.id))
      .classed("highlighted", d => active && ids.has(d.id))
      .classed("selected", d => d.id === this.#selectedId)
    this.#updatePointSize()

    // Hülle eines ausgewählten Themas hervorheben und auf das
    // Thema zoomen
    const topic = selected?.type === "topic" ? Number(selected.id) : null
    this.#layers.hulls.selectAll("path").classed("active", d => d.cluster === topic)
    this.#layers.labels.selectAll("text").classed("active", d => d.cluster === topic)
    if (topic !== null) {
      this.focusCluster(topic)
      return
    }

    // Ausgewählte Person vor die anderen Punkte holen und bei
    // Bedarf in den sichtbaren Bereich schieben
    this.#pointSelection.filter(d => d.id === this.#selectedId).raise()
    const point = this.#data.points.find(d => d.id === this.#selectedId)
    if (point && !this.#isVisible(point)) this.#centerOn(point)
  }

  highlightCluster(cluster) {
    const active = cluster !== null && cluster !== undefined
    this.#pointSelection.classed("muted", d => active && d.cluster !== cluster)
    this.#layers.hulls.selectAll("path").classed("muted", d => active && d.cluster !== cluster)
    this.#layers.labels.selectAll("text").classed("muted", d => active && d.cluster !== cluster)
  }

  focusCluster(cluster) {
    const members = this.#data.points.filter(d => d.cluster === cluster)
    if (members.length > 0) this.#fitPoints(members, true)
  }

  clear() {
    this.highlight()
    this.highlightCluster(null)
  }

  // ----------------------------------------------------------
  // Aufbau
  // ----------------------------------------------------------

  #buildLayers() {
    this.#svg.selectAll("*").remove()

    // Hintergrund fängt Klicks zum Aufheben der Auswahl
    this.#svg.append("rect")
      .attr("class", "background")
      .attr("width", "100%")
      .attr("height", "100%")
      .attr("fill", "transparent")
      .attr("pointer-events", "all")
      .on("click", () => this.#onSelect(null))

    this.#root = this.#svg.append("g")
    this.#layers.hulls = this.#root.append("g").attr("class", "hulls")
    this.#layers.points = this.#root.append("g").attr("class", "points")
    this.#layers.labels = this.#root.append("g").attr("class", "cluster-labels")
  }

  // Weltkoordinaten eines Punktes (y nach oben)
  #x(d) { return d.x * LAYOUT.worldRadius }
  #y(d) { return -d.y * LAYOUT.worldRadius }

  #drawPoints() {
    this.#pointSelection = this.#layers.points
      .selectAll("use")
      .data(this.#data.points, d => d.id)
      .join("use")
      .attr("href", "#icon-person")
      .attr("class", d => `point ${clusterClass(d.cluster)}`)
      .on("pointerenter", (event, d) => this.#showTooltip(event, d))
      .on("pointermove", event => this.#moveTooltip(event))
      .on("pointerleave", () => this.#hideTooltip())
      .on("click", (event, d) => {
        event.stopPropagation()
        this.#onSelect({ type: "person", id: d.id })
      })
  }

  // Konvexe Hülle je Cluster aus den zentralsten Punkten
  #drawHulls() {
    const groups = d3.group(this.#data.points.filter(d => d.cluster !== NOISE), d => d.cluster)

    this.#hulls = []
    for (const [cluster, members] of groups) {
      const coords = members.map(d => [this.#x(d), this.#y(d)])
      const center = [d3.mean(coords, c => c[0]), d3.mean(coords, c => c[1])]
      const distances = coords.map(c => Math.hypot(c[0] - center[0], c[1] - center[1]))
      const limit = d3.quantile([...distances].sort(d3.ascending), LAYOUT.hullQuantile)
      const core = coords.filter((_c, i) => distances[i] <= limit)
      const polygon = core.length >= 3 ? d3.polygonHull(core) : null

      if (polygon) this.#hulls.push({ cluster, polygon, center: d3.polygonCentroid(polygon) })
    }

    this.#layers.hulls
      .selectAll("path")
      .data(this.#hulls, d => d.cluster)
      .join("path")
      .attr("class", d => `cluster-hull ${clusterClass(d.cluster)}`)
      .attr("d", d => `M${d.polygon.join("L")}Z`)
      .on("click", (event, d) => {
        event.stopPropagation()
        this.#onSelect({ type: "topic", id: String(d.cluster) })
      })
  }

  // Beschriftung je Cluster: die ersten zwei Begriffe
  #drawLabels() {
    this.#layers.labels
      .selectAll("text")
      .data(this.#hulls, d => d.cluster)
      .join("text")
      .attr("class", d => `cluster-label ${clusterClass(d.cluster)}`)
      .attr("text-anchor", "middle")
      .attr("x", d => d.center[0])
      .attr("y", d => d.center[1])
      .text(d => (this.#topics.get(d.cluster)?.terms || []).slice(0, 2).join(" · "))
  }

  // ----------------------------------------------------------
  // Zoom
  // ----------------------------------------------------------

  #setupZoom() {
    this.#zoom = d3.zoom()
      .scaleExtent(LAYOUT.scaleExtent)
      .on("zoom", event => {
        this.#transform = event.transform
        this.#root.attr("transform", event.transform)
        this.#updatePointSize()
        this.#updateLabels()
        if (this.#zoomLevel) this.#zoomLevel.textContent = `${Math.round(event.transform.k * 100)} %`
      })

    this.#svg.call(this.#zoom).on("dblclick.zoom", null)
  }

  #bindZoomControls(controls) {
    if (!controls) return

    controls.addEventListener("click", event => {
      const button = event.target.closest("[data-zoom]")
      if (!button) return

      const action = button.dataset.zoom
      if (action === "home") this.#fit(true)
      else this.#svg.transition().duration(300).call(this.#zoom.scaleBy, action === "in" ? 1.5 : 1 / 1.5)
    })
  }

  // Symbole, Hüllenrand und Beschriftung behalten ihre
  // Bildschirmgröße: Größen werden durch den Zoomfaktor geteilt.
  #updatePointSize() {
    const k = this.#transform.k
    const size = d => (d.id === this.#selectedId ? LAYOUT.selectedIconSize : LAYOUT.iconSize) / k
    this.#pointSelection
      .attr("width", size)
      .attr("height", size)
      .attr("x", d => this.#x(d) - size(d) / 2)
      .attr("y", d => this.#y(d) - size(d) / 2)
    this.#layers.hulls.selectAll("path").attr("stroke-width", (2 * LAYOUT.hullPadding) / k)
  }

  #updateLabels() {
    const k = this.#transform.k
    this.#layers.labels.selectAll("text")
      .attr("display", k <= LAYOUT.labelMaxZoom ? null : "none")
      .attr("font-size", LAYOUT.labelSize / k)
      .attr("stroke-width", 4 / k)
  }

  #size() {
    const box = this.#svg.node().getBoundingClientRect()
    return [box.width || 800, box.height || 600]
  }

  // Gesamtansicht: alle Punkte passen ins Panel
  #fit(animate) {
    this.#fitPoints(this.#data.points, animate)
  }

  #fitPoints(points, animate) {
    const [width, height] = this.#size()
    const [x0, x1] = d3.extent(points, d => this.#x(d))
    const [y0, y1] = d3.extent(points, d => this.#y(d))
    const spanX = Math.max(x1 - x0, 1)
    const spanY = Math.max(y1 - y0, 1)
    const k = Math.min((width - 2 * LAYOUT.padding) / spanX, (height - 2 * LAYOUT.padding) / spanY)
    const scale = Math.max(LAYOUT.scaleExtent[0], Math.min(LAYOUT.scaleExtent[1], k))
    const transform = d3.zoomIdentity
      .translate(width / 2, height / 2)
      .scale(scale)
      .translate(-(x0 + x1) / 2, -(y0 + y1) / 2)

    const target = animate ? this.#svg.transition().duration(LAYOUT.transition) : this.#svg
    target.call(this.#zoom.transform, transform)
  }

  #isVisible(d) {
    const [width, height] = this.#size()
    const [sx, sy] = this.#transform.apply([this.#x(d), this.#y(d)])
    return sx >= 0 && sx <= width && sy >= 0 && sy <= height
  }

  #centerOn(d) {
    const [width, height] = this.#size()
    const k = this.#transform.k
    const transform = d3.zoomIdentity.translate(width / 2, height / 2).scale(k).translate(-this.#x(d), -this.#y(d))
    this.#svg.transition().duration(LAYOUT.transition).call(this.#zoom.transform, transform)
  }

  // ----------------------------------------------------------
  // Tooltip
  // ----------------------------------------------------------

  // Inhalt per DOM aufgebaut (textContent), damit Namen und
  // Begriffe nicht als HTML interpretiert werden.
  #showTooltip(event, d) {
    if (!this.#tooltip) return

    const name = document.createElement("strong")
    name.textContent = this.#names.get(d.id) || d.id
    const topic = document.createElement("span")
    const terms = this.#topics.get(d.cluster)?.terms
    topic.textContent = d.cluster === NOISE || !terms ? "kein Cluster" : terms.slice(0, 3).join(", ")

    this.#tooltip.replaceChildren(name, document.createElement("br"), topic)
    this.#tooltip.classList.add("open")
    this.#moveTooltip(event)
  }

  // Position relativ zum Panel (wie in NetworkView)
  #moveTooltip(event) {
    if (!this.#tooltip?.classList.contains("open")) return

    const panel = this.#tooltip.parentElement.getBoundingClientRect()
    this.#tooltip.style.left = `${event.clientX - panel.left + 12}px`
    this.#tooltip.style.top = `${event.clientY - panel.top + 12}px`
  }

  #hideTooltip() {
    this.#tooltip?.classList.remove("open")
  }
}

// CSS-Klasse für eine Clusternummer: topic-0 … topic-19,
// danach wiederholen sich die Farben; −1 ist Rauschen.
export function clusterClass(cluster) {
  return cluster === NOISE ? "noise" : `topic-${cluster % 20}`
}