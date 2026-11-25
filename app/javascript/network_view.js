// ============================================================
// Datei: app/javascript/network_view.js
//
// Desc:
//   Zeichnet das Forschungsnetzwerk nach dem Bild einer
//   Galaxie (UC 1, UC 2). Symbole: Hochschule, Fachbereich
//   (Untereinrichtung) und Person aus shared/_legend.
//
//   Bild:
//     Stufe 1  Die Hochschulen liegen verteilt wie Sterne.
//              Je mehr Untereinrichtungen und Personen eine
//              Hochschule hat, desto mehr Raum nimmt sie ein
//              und desto weiter liegen ihre Nachbarn entfernt.
//     Stufe 2  Beim Hineinzoomen wird die Hochschule größer
//              (Planet); ihre Untereinrichtungen liegen auf
//              Umlaufbahnen um sie.
//     Stufe 3  Die Personen erscheinen um ihre
//              Untereinrichtung.
//
//   Der Raum ist größer als die Fläche: Mit gedrückter
//   Maustaste lässt er sich verschieben, mit dem Mausrad
//   zoomen.
//
//   Zugehörigkeitskanten (grau, dünn) zeigen, wer wozu gehört:
//     ab Stufe 2  Fachbereich – Hochschule
//                 (tiefere Einheit – übergeordnete Einheit)
//     ab Stufe 3  Person – Fachbereich bzw. Person – Hochschule,
//                 wenn die Person direkt der Hochschule angehört
//
//   Kooperationskanten (vereinfacht): auf jeder Stufe genau
//   eine Kante je Paar – zwischen Hochschulen, zwischen
//   Untereinrichtungen bzw. zwischen Personen. Hover zeigt, wie
//   viele Kooperationen über Projekte und über Publikationen
//   bestehen; ein Klick wählt die Kante aus.
//
//   Auswahl: Klicks auf Symbole und Kanten gehen an
//   SelectionState; highlight() hebt die Auswahl hervor und
//   zoomt mit fitTo() auf die beteiligten Knoten. Ausgewählte
//   Elemente bleiben auf jeder Stufe sichtbar. Bei Auswahl
//   eines Themas (kombinierte Ansicht) sind das alle Personen
//   des Themas.
//
//   Thematische Ähnlichkeit (nur kombinierte Ansicht, FA31,
//   FA32): Wird similarity übergeben (SimilarityGraph#to_h),
//   verbinden gestrichelte Kanten Personen, deren Ähnlichkeit
//   mindestens den Schwellenwert erreicht. Gezeichnet werden
//   sie zwischen sichtbaren Personen (Stufe 3) und immer für
//   eine ausgewählte Person. Der Schwellenwert kommt vom
//   Regler (SimilaritySlider) über setSimilarityThreshold().
//   Die Kanten sind absteigend sortiert; die Kanten oberhalb
//   des Schwellenwerts sind deshalb immer ein Anfangsstück der
//   Liste (binäre Suche, countAbove).
//
//   Farben und Linien: network_view.css.
// ============================================================

import * as d3 from "d3"

// Abstände im Layoutraum (Einheit: Abstand zweier Personen).
const LAYOUT = {
  personSpacing: 1,      // Abstand der Personen in einer Wolke
  coreMinRadius: 2,      // Mindestgröße einer Einrichtung ohne Personen
  orbitGap: 3,           // Abstand zwischen zwei Umlaufbahnen
  moonGap: 2,            // Abstand zwischen Untereinrichtungen auf einer Bahn
  systemGap: 18,         // Mindestabstand zwischen zwei Hochschulen
  systemSpread: 0.35,    // zusätzlicher Abstand relativ zur Systemgröße
  simulationTicks: 400
}

// Bildschirmgrößen in Pixeln.
const SCREEN = {
  level2Distance: 80,    // ab diesem Bahnabstand gilt Stufe 2
  level3Spacing: 22,     // ab diesem Personenabstand gilt Stufe 3
  // Symbolgrößen: Hochschule > Fachbereich > tiefere Einheit > Person
  rootIcon: [ 34, 52 ],  // kleinstes / größtes Hochschulsymbol
  planetFactor: 1.25,    // Hochschule als Planet ab Stufe 2
  subIcon: 28,           // Fachbereich (Ebene 2)
  deepIcon: 24,          // tiefere Untereinrichtung (Ebene 3)
  personIcon: 20,
  selectedIcon: 30,      // ausgewählte Person bzw. Untereinrichtung
  ringPadding: 4,        // Abstand des Auswahlrings zum Symbol
  edgeWidth: [ 1, 6 ],
  hitWidth: 10,          // unsichtbare Klickfläche einer Kante
  labelHeight: 14,
  labelCharWidth: 6.2,
  labelOffset: 6,        // Abstand der Beschriftung unter dem Symbol
  viewportMargin: 30,
  fitPadding: 0.8
}

const LEVEL_LABELS = {
  1: "Stufe 1 · Einrichtungen",
  2: "Stufe 2 · + Fachbereiche",
  3: "Stufe 3 · + Personen"
}

const GOLDEN_ANGLE = Math.PI * (3 - Math.sqrt(5))
const ZOOM_STEP = 1.6
const LABEL_MAX_LENGTH = 34

export class NetworkView {
  #svg
  #selection
  #tooltip
  #levelLabel

  #data
  #nodes                 // Map id → Knoten aus den eingebetteten Daten
  #positions             // Map id → { x, y } im Layoutraum
  #rootIconSize          // Map Hochschul-ID → Symbolgröße (px)
  #links                 // Map Schlüssel → Kante (alle Stufen)
  #partners              // Map Personen-ID → [Kante]
  #levelScales           // Zoomfaktoren, ab denen Stufe 2 bzw. 3 gilt
  #similar = []          // Ähnlichkeitskanten, absteigend nach score
  #similarPartners       // Map Personen-ID → [Ähnlichkeitskante]
  #threshold = Infinity  // aktueller Schwellenwert (Infinity = keine)

  #zoom
  #transform = d3.zoomIdentity
  #width = 0
  #height = 0
  #frame = null

  #selected = null
  #emphasized = new Set()   // Knoten der Auswahl, immer sichtbar
  #selectedPeople = new Set()
  #points = new Map()       // Bildschirmposition je sichtbarem Knoten

  // svg:       <svg data-network-view>
  // data:      Visualization::NetworkGraph#to_h
  // selection: SelectionState der Seite
  // elements:  { tooltip, zoomControls }
  // similarity (optional): Visualization::SimilarityGraph#to_h
  constructor(svg, data, selection, { tooltip, zoomControls, similarity = null }) {
    this.#svg = d3.select(svg)
    this.#data = data
    this.#selection = selection
    this.#tooltip = tooltip
    this.#levelLabel = zoomControls.querySelector("[data-zoom-level]")

    this.#nodes = new Map(data.nodes.map(node => [ node.id, node ]))
    this.#links = this.#indexLinks()
    this.#partners = this.#indexPartners()
    this.#positions = this.#computeLayout()
    this.#rootIconSize = this.#computeRootIconSize()
    this.#levelScales = this.#computeLevelScales()

    if (similarity) {
      this.#similar = similarity.edges.filter(edge => this.#positions.has(edge.source) && this.#positions.has(edge.target))
      this.#similarPartners = this.#indexSimilarPartners()
      this.#threshold = similarity.threshold
    }

    this.#createLayers()
    this.#setupZoom()
    this.#bindZoomControls(zoomControls)
    this.#observeSize()
  }

  // ----------------------------------------------------------
  // Öffentliche Schnittstelle
  // ----------------------------------------------------------

  // Aktuelle Zoomstufe (1, 2 oder 3).
  get zoomLevel() {
    const k = this.#transform.k
    if (k >= this.#levelScales[3]) return 3
    if (k >= this.#levelScales[2]) return 2
    return 1
  }

  // Zeichnet alle Elemente der aktuellen Stufe neu.
  render() {
    const level = this.zoomLevel
    const nodes = this.#visibleNodes(level)

    this.#points = new Map(nodes.map(node => [ node.id, this.#screenPoint(node.id) ]))

    this.#drawStructure(this.#visibleStructure(level))
    this.#drawSimilar(this.#visibleSimilar())
    this.#drawLinks(this.#visibleLinks(level))
    this.#drawNodes(nodes, level)
    this.#drawLabels(nodes, level)
    this.#levelLabel.textContent = LEVEL_LABELS[level]
  }

  // Zoomt (animiert) auf eine Transformation.
  zoomTo(transform, duration = 700) {
    this.#svg.transition().duration(duration).call(this.#zoom.transform, transform)
  }

  // Reagiert auf eine geänderte Auswahl (SelectionState).
  highlight(state) {
    this.#selected = state.selected
    this.#selectedPeople = state.people
    this.#emphasized = this.#emphasizedNodes(this.#selected)
    this.#svg.classed("has-selection", Boolean(this.#selected))

    this.render()
    if (this.#emphasized.size > 0) this.fitTo([ ...this.#emphasized ])
  }

  // Setzt den Schwellenwert der Ähnlichkeitskanten und gibt
  // die Anzahl der Kanten oberhalb zurück. Ist eine Person
  // ausgewählt, ändern sich auch ihre hervorgehobenen Partner.
  setSimilarityThreshold(value) {
    this.#threshold = value
    if (this.#selected) this.#emphasized = this.#emphasizedNodes(this.#selected)
    this.render()
    return this.countAbove(value)
  }

  // Anzahl der Ähnlichkeitskanten mit score >= value
  // (binäre Suche in der absteigend sortierten Liste).
  countAbove(value) {
    let low = 0
    let high = this.#similar.length
    while (low < high) {
      const middle = (low + high) >> 1
      if (this.#similar[middle].score >= value) low = middle + 1
      else high = middle
    }
    return low
  }

  // Zoomt so, dass alle angegebenen Knoten sichtbar sind.
  fitTo(ids) {
    const points = ids.map(id => this.#positions.get(id)).filter(Boolean)
    if (points.length === 0) return

    const [ x0, x1 ] = d3.extent(points, point => point.x)
    const [ y0, y1 ] = d3.extent(points, point => point.y)
    const span = Math.max(x1 - x0, y1 - y0, 1)

    const [ minScale, maxScale ] = this.#zoom.scaleExtent()
    const fitScale = SCREEN.fitPadding * Math.min(this.#width, this.#height) / span
    const k = Math.max(minScale, Math.min(maxScale, fitScale, this.#levelScales[3] * 1.5))

    this.zoomTo(
      d3.zoomIdentity
        .translate(this.#width / 2, this.#height / 2)
        .scale(k)
        .translate(-(x0 + x1) / 2, -(y0 + y1) / 2)
    )
  }

  // ----------------------------------------------------------
  // Layout: Galaxie aus Systemen
  // ----------------------------------------------------------

  // Baut für jede Hochschule ein System (Untereinrichtungen
  // auf Umlaufbahnen, Personen als Wolke) und verteilt die
  // Systeme anschließend mit einer Kräftesimulation.
  #computeLayout() {
    const facilities = this.#data.nodes.filter(node => node.type === "facility")
    const children = d3.group(facilities.filter(node => node.parent), node => node.parent)
    const people = d3.group(
      this.#data.nodes.filter(node => node.type === "person"),
      node => node.facilities[0]
    )

    const systems = facilities
      .filter(node => !node.parent)
      .map(root => ({ id: root.id, ...this.#buildSystem(root, children, people) }))

    this.#arrangeSystems(systems)

    const positions = new Map()
    for (const system of systems) {
      for (const member of system.members) {
        positions.set(member.id, { x: system.x + member.x, y: system.y + member.y })
      }
    }
    return positions
  }

  // System einer Einrichtung, rekursiv:
  //   - im Zentrum die Einrichtung selbst,
  //   - darum ihre Personen als Spirale (Phyllotaxis),
  //   - außen die Untersysteme auf Umlaufbahnen.
  // Rückgabe: { radius, members: [{ id, x, y }] } relativ zum Zentrum
  #buildSystem(facility, children, people) {
    const members = [ { id: facility.id, x: 0, y: 0 } ]
    const ownPeople = people.get(facility.id) ?? []

    ownPeople.forEach((person, index) => {
      const radius = LAYOUT.personSpacing * (Math.sqrt(index + 0.5) + 1)
      const angle = index * GOLDEN_ANGLE
      members.push({ id: person.id, x: radius * Math.cos(angle), y: radius * Math.sin(angle) })
    })

    const coreRadius = ownPeople.length > 0
      ? LAYOUT.personSpacing * (Math.sqrt(ownPeople.length) + 1.5)
      : LAYOUT.coreMinRadius

    const moons = (children.get(facility.id) ?? [])
      .map(child => this.#buildSystem(child, children, people))
      .sort((a, b) => b.radius - a.radius)

    const radius = this.#placeOnOrbits(moons, coreRadius, members)

    return { radius, members }
  }

  // Verteilt Untersysteme auf konzentrische Umlaufbahnen. Jede
  // Bahn nimmt so viele Systeme auf, wie auf ihren Umfang
  // passen; der Rest wandert auf die nächste, äußere Bahn.
  // Gibt den Außenradius des gesamten Systems zurück.
  #placeOnOrbits(moons, coreRadius, members) {
    let innerRadius = coreRadius
    let next = 0
    let orbit = 0

    while (next < moons.length) {
      const widest = moons[next].radius
      const orbitRadius = innerRadius + LAYOUT.orbitGap + widest
      const ring = []
      let usedAngle = 0

      while (next < moons.length) {
        const angle = 2 * (moons[next].radius + LAYOUT.moonGap / 2) / orbitRadius
        if (ring.length > 0 && usedAngle + angle > 2 * Math.PI) break

        ring.push({ moon: moons[next], angle })
        usedAngle += angle
        next += 1
      }

      // Freien Platz gleichmäßig verteilen; jede Bahn leicht
      // gedreht, damit keine Speichen entstehen.
      const spread = (2 * Math.PI - usedAngle) / ring.length
      let cursor = orbit * 1.1

      for (const { moon, angle } of ring) {
        const center = cursor + angle / 2
        const cx = orbitRadius * Math.cos(center)
        const cy = orbitRadius * Math.sin(center)

        moon.members.forEach(member => members.push({ id: member.id, x: cx + member.x, y: cy + member.y }))
        cursor += angle + spread
      }

      innerRadius = orbitRadius + widest
      orbit += 1
    }

    return innerRadius
  }

  // Verteilt die Hochschulsysteme ohne Überlappung. Größere
  // Systeme halten mehr Abstand; kooperierende Hochschulen
  // ziehen sich leicht an. Die Simulation läuft vollständig
  // vor dem ersten Zeichnen; das Ergebnis ist bei gleichen
  // Daten immer gleich.
  #arrangeSystems(systems) {
    const ids = new Set(systems.map(system => system.id))
    const links = this.#data.aggregated_edges
      .filter(edge => edge.level === 1 && ids.has(edge.source) && ids.has(edge.target))
      .map(edge => ({ source: edge.source, target: edge.target, count: edge.count }))
    const maxCount = d3.max(links, link => link.count) ?? 1

    d3.forceSimulation(systems)
      .force("collide", d3.forceCollide(system => system.radius * (1 + LAYOUT.systemSpread) + LAYOUT.systemGap).iterations(3))
      .force("link", d3.forceLink(links)
        .id(system => system.id)
        .distance(link => (link.source.radius + link.target.radius) * (1 + LAYOUT.systemSpread) + LAYOUT.systemGap * 2)
        .strength(link => 0.05 * link.count / maxCount))
      .force("x", d3.forceX(0).strength(0.02))
      .force("y", d3.forceY(0).strength(0.02))
      .stop()
      .tick(LAYOUT.simulationTicks)
  }

  // Symbolgröße je Hochschule nach Anzahl ihrer Personen.
  #computeRootIconSize() {
    const peopleCount = new Map()
    for (const node of this.#data.nodes) {
      if (node.type === "facility" && !node.parent) peopleCount.set(node.id, 0)
    }
    for (const node of this.#data.nodes) {
      if (node.type !== "person") continue
      const root = this.#nodes.get(node.facilities[0])?.root
      if (peopleCount.has(root)) peopleCount.set(root, peopleCount.get(root) + 1)
    }

    const scale = d3.scaleSqrt()
      .domain([ 0, d3.max(peopleCount.values()) || 1 ])
      .range(SCREEN.rootIcon)

    return new Map([ ...peopleCount ].map(([ id, count ]) => [ id, scale(count) ]))
  }

  // Zoomfaktoren für Stufe 2 und 3: Stufe 2, sobald die
  // Umlaufbahnen typischer Untereinrichtungen weit genug von
  // ihrer Hochschule entfernt erscheinen; Stufe 3, sobald
  // Personen genügend Abstand haben.
  #computeLevelScales() {
    const distances = this.#data.nodes
      .filter(node => node.type === "facility" && node.level === 2)
      .map(node => this.#distance(node.id, node.parent))
      .filter(Number.isFinite)

    const level2 = SCREEN.level2Distance / (d3.median(distances) ?? 10)
    const level3 = SCREEN.level3Spacing / LAYOUT.personSpacing

    return { 2: level2, 3: Math.max(level3, level2 * 2) }
  }

  #distance(idA, idB) {
    const a = this.#positions.get(idA)
    const b = this.#positions.get(idB)
    return a && b ? Math.hypot(a.x - b.x, a.y - b.y) : NaN
  }

  // ----------------------------------------------------------
  // Kanten: eine Kante je Paar und Stufe
  // ----------------------------------------------------------

  // Alle Kanten mit eindeutigem Schlüssel "Stufe|Quelle|Ziel".
  // Stufe 3 sind die Kooperationen zwischen Personen.
  #indexLinks() {
    const links = new Map()

    for (const edge of this.#data.aggregated_edges) {
      links.set(linkKey(edge.level, edge.source, edge.target), { ...edge })
    }
    for (const cooperation of this.#data.cooperations) {
      const link = { ...cooperation, level: 3, count: 1 }
      links.set(linkKey(3, link.source, link.target), link)
    }

    return links
  }

  // Kooperationen je Person (in beide Richtungen).
  #indexPartners() {
    const partners = new Map()

    for (const link of this.#links.values()) {
      if (link.level !== 3) continue
      for (const id of [ link.source, link.target ]) {
        if (!partners.has(id)) partners.set(id, [])
        partners.get(id).push(link)
      }
    }

    return partners
  }

  // Kanten, die auf der aktuellen Stufe gezeichnet werden:
  // die Kanten der Stufe zwischen sichtbaren Knoten sowie alle
  // Kooperationen einer ausgewählten Person.
  #visibleLinks(level) {
    const visible = [ ...this.#links.values() ].filter(link =>
      link.level === level && this.#points.has(link.source) && this.#points.has(link.target)
    )

    if (this.#selected?.type === "person") {
      const own = this.#partners.get(this.#selected.id) ?? []
      own.forEach(link => { if (!visible.includes(link)) visible.push(link) })
    }

    if (this.#selected?.type === "link") {
      const link = this.#links.get(this.#selected.id)
      if (link && !visible.includes(link)) visible.push(link)
    }

    return visible
  }

  // Zugehörigkeitskanten der aktuellen Stufe zwischen
  // sichtbaren Knoten:
  //   ab Stufe 2: Untereinrichtung → übergeordnete Einrichtung
  //   ab Stufe 3: Person → jede Einrichtung, der sie angehört
  #visibleStructure(level) {
    const edges = []
    const visible = edge => this.#points.has(edge.source) && this.#points.has(edge.target)

    if (level >= 2) edges.push(...this.#data.hierarchy_edges.filter(visible))
    if (level >= 3) edges.push(...this.#data.affiliation_edges.filter(visible))

    // Zugehörigkeiten einer ausgewählten Person immer zeigen.
    if (this.#selected?.type === "person" && level < 3) {
      edges.push(...this.#data.affiliation_edges.filter(edge => edge.source === this.#selected.id && visible(edge)))
    }

    return edges
  }

  // Ähnlichkeitskanten je Person (in beide Richtungen),
  // weiterhin absteigend nach score.
  #indexSimilarPartners() {
    const partners = new Map()

    for (const edge of this.#similar) {
      for (const id of [ edge.source, edge.target ]) {
        if (!partners.has(id)) partners.set(id, [])
        partners.get(id).push(edge)
      }
    }

    return partners
  }

  // Ähnlichkeitskanten oberhalb des Schwellenwerts, deren
  // beide Personen gerade sichtbar sind. Eine ausgewählte
  // Person ist samt ihrer ähnlichen Personen immer sichtbar
  // (emphasized), ihre Kanten erscheinen also auf jeder Stufe.
  #visibleSimilar() {
    const above = this.#similar.slice(0, this.countAbove(this.#threshold))
    return above.filter(edge => this.#points.has(edge.source) && this.#points.has(edge.target))
  }

  // Ähnliche Personen einer Person oberhalb des Schwellenwerts.
  #similarTo(id) {
    return (this.#similarPartners?.get(id) ?? [])
      .filter(edge => edge.score >= this.#threshold)
      .map(edge => (edge.source === id ? edge.target : edge.source))
  }

  // Art der Kante für die Farbe: nur Projekte, nur
  // Publikationen oder beides.
  #linkKind(link) {
    if (link.projects > 0 && link.publications > 0) return "both"
    return link.projects > 0 ? "project" : "publication"
  }

  // ----------------------------------------------------------
  // Sichtbarkeit und Bildschirmpositionen
  // ----------------------------------------------------------

  // Knoten der Stufe im sichtbaren Ausschnitt plus alle
  // Knoten der Auswahl.
  #visibleNodes(level) {
    return this.#data.nodes.filter(node =>
      this.#positions.has(node.id) &&
      (this.#emphasized.has(node.id) || (this.#belongsToLevel(node, level) && this.#inViewport(node.id)))
    )
  }

  #belongsToLevel(node, level) {
    if (node.type === "person") return level === 3
    return node.level <= level
  }

  #inViewport(id) {
    const { x, y } = this.#screenPoint(id)
    const margin = SCREEN.viewportMargin

    return x > -margin && x < this.#width + margin && y > -margin && y < this.#height + margin
  }

  // Position eines Knotens in Bildschirmkoordinaten.
  #screenPoint(id) {
    const { x, y } = this.#positions.get(id)
    const [ sx, sy ] = this.#transform.apply([ x, y ])
    return { x: sx, y: sy }
  }

  // Knoten, die zur Auswahl gehören und immer sichtbar sind.
  #emphasizedNodes(item) {
    if (!item) return new Set()

    if (item.type === "link") {
      const link = this.#links.get(item.id)
      return new Set(link ? [ link.source, link.target ] : [])
    }

    // Thema: alle Personen des Themas (aus SelectionState)
    if (item.type === "topic") return new Set(this.#selectedPeople)

    const ids = new Set([ item.id ])
    if (item.type === "person") {
      // Partner und eigene Einrichtungen der Person
      for (const link of this.#partners.get(item.id) ?? []) {
        ids.add(link.source)
        ids.add(link.target)
      }
      this.#nodes.get(item.id)?.facilities.forEach(id => ids.add(id))
      // thematisch ähnliche Personen (kombinierte Ansicht)
      this.#similarTo(item.id).forEach(id => ids.add(id))
    }
    return ids
  }

  // ----------------------------------------------------------
  // Zeichnen
  // ----------------------------------------------------------

  // Fünf Ebenen: Zugehörigkeit ganz unten, darüber die
  // Ähnlichkeitskanten, die Kooperationskanten, dann Symbole,
  // Namen oben.
  #createLayers() {
    for (const name of [ "structure", "similar", "links", "nodes", "labels" ]) {
      this.#svg.append("g").attr("class", `layer-${name}`)
    }
  }

  #layer(name) {
    return this.#svg.select(`.layer-${name}`)
  }

  // Zugehörigkeitskanten: dünne graue Linien ohne Interaktion.
  #drawStructure(edges) {
    this.#layer("structure").selectAll("line")
      .data(edges, edge => `${edge.source}|${edge.target}`)
      .join("line")
      .attr("class", "edge-affiliation")
      .attr("x1", edge => this.#points.get(edge.source).x)
      .attr("y1", edge => this.#points.get(edge.source).y)
      .attr("x2", edge => this.#points.get(edge.target).x)
      .attr("y2", edge => this.#points.get(edge.target).y)
  }

  // Ähnlichkeitskanten: gestrichelte Linien; Hover zeigt die
  // beiden Personen und den Ähnlichkeitswert. Eine breite,
  // unsichtbare Linie darüber erleichtert das Treffen.
  #drawSimilar(edges) {
    const groups = this.#layer("similar").selectAll("g.similar")
      .data(edges, edge => `${edge.source}|${edge.target}`)
      .join(enter => {
        const group = enter.append("g").attr("class", "similar")
          .on("mouseenter", (event, edge) => this.#showTooltip(event, this.#similarTooltip(edge)))
          .on("mouseleave", () => this.#hideTooltip())
        group.append("line").attr("class", "edge-similarity")
        group.append("line").attr("class", "link-hit").style("stroke-width", SCREEN.hitWidth)
        return group
      })

    groups.classed("dimmed", edge => this.#selected !== null && !this.#touchesSelection(edge))

    groups.selectAll("line")
      .attr("x1", edge => this.#points.get(edge.source).x)
      .attr("y1", edge => this.#points.get(edge.source).y)
      .attr("x2", edge => this.#points.get(edge.target).x)
      .attr("y2", edge => this.#points.get(edge.target).y)
  }

  // Kanten mit sichtbarer Linie und breiter, unsichtbarer
  // Klickfläche darüber.
  #drawLinks(links) {
    const width = d3.scaleSqrt()
      .domain([ 1, d3.max(links, link => link.count) ?? 1 ])
      .range(SCREEN.edgeWidth)

    const groups = this.#layer("links").selectAll("g.link")
      .data(links, link => linkKey(link.level, link.source, link.target))
      .join(enter => {
        const group = enter.append("g").attr("class", "link")
          .on("mouseenter", (event, link) => this.#showTooltip(event, this.#linkTooltip(link)))
          .on("mouseleave", () => this.#hideTooltip())
          .on("click", (event, link) => {
            event.stopPropagation()
            this.#selection.select({ type: "link", id: linkKey(link.level, link.source, link.target) })
          })
        group.append("line").attr("class", "link-line")
        group.append("line").attr("class", "link-hit").style("stroke-width", SCREEN.hitWidth)
        return group
      })

    groups
      .attr("class", link => `link link-${this.#linkKind(link)}`)
      .classed("selected", link => this.#isSelectedLink(link))
      .classed("dimmed", link => this.#selected !== null && !this.#touchesSelection(link))

    groups.selectAll("line")
      .attr("x1", link => this.#points.get(link.source).x)
      .attr("y1", link => this.#points.get(link.source).y)
      .attr("x2", link => this.#points.get(link.target).x)
      .attr("y2", link => this.#points.get(link.target).y)

    groups.select(".link-line").style("stroke-width", link => width(link.count))
  }

  // Symbole: Hochschule, Fachbereich (Untereinrichtung), Person.
  // Jeder Knoten ist eine Gruppe aus weißem Hintergrund (verdeckt
  // Kanten), Auswahlring und Symbol (<use>).
  #drawNodes(nodes, level) {
    const groups = this.#layer("nodes").selectAll("g.node")
      .data(nodes, node => node.id)
      .join(enter => {
        const group = enter.append("g")
          .on("mouseenter", (event, node) => this.#showTooltip(event, this.#nodeTooltip(node)))
          .on("mouseleave", () => this.#hideTooltip())
          .on("click", (event, node) => {
            event.stopPropagation()
            this.#selection.select({ type: node.type, id: node.id })
          })
        group.append("circle").attr("class", "node-backdrop")
        group.append("circle").attr("class", "selection-ring")
        group.append("use").attr("href", node => `#${this.#iconOf(node)}`)
        return group
      })

    groups
      .attr("class", node => `node ${this.#nodeClass(node, level)}`)
      .classed("selected", node => node.id === this.#selected?.id)
      .classed("dimmed", node => this.#isDimmed(node))
      .attr("transform", node => `translate(${this.#points.get(node.id).x},${this.#points.get(node.id).y})`)

    groups.select(".node-backdrop").attr("r", node => this.#iconSize(node, level) * 0.42)
    groups.select(".selection-ring").attr("r", node => this.#iconSize(node, level) / 2 + SCREEN.ringPadding)
    groups.select("use")
      .attr("x", node => -this.#iconSize(node, level) / 2)
      .attr("y", node => -this.#iconSize(node, level) / 2)
      .attr("width", node => this.#iconSize(node, level))
      .attr("height", node => this.#iconSize(node, level))
  }

  // Symbol-ID aus shared/_legend.
  #iconOf(node) {
    if (node.type === "person") return "icon-person"
    return node.level === 1 ? "icon-facility" : "icon-department"
  }

  // Symbolgröße in Pixeln; bleibt beim Zoomen gleich.
  #iconSize(node, level) {
    if (node.id === this.#selected?.id && node.level !== 1) return SCREEN.selectedIcon
    if (node.type === "person") return SCREEN.personIcon
    if (node.level === 1) {
      const size = this.#rootIconSize.get(node.id) ?? SCREEN.rootIcon[0]
      return level >= 2 ? size * SCREEN.planetFactor : size
    }
    return node.level === 2 ? SCREEN.subIcon : SCREEN.deepIcon
  }

  // CSS-Klasse für Farbe und Form des Symbols.
  #nodeClass(node, level) {
    if (node.type === "person") return "node-person"
    if (node.level === 1) return level >= 2 ? "node-facility planet" : "node-facility"
    return "node-sub-facility"
  }

  // Personen außerhalb der Auswahl treten zurück.
  #isDimmed(node) {
    if (!this.#selected || node.type !== "person") return false
    return !this.#selectedPeople.has(node.id) && !this.#emphasized.has(node.id)
  }

  #isSelectedLink(link) {
    return this.#selected?.type === "link" &&
      this.#selected.id === linkKey(link.level, link.source, link.target)
  }

  #touchesSelection(link) {
    return this.#emphasized.has(link.source) || this.#emphasized.has(link.target)
  }

  // Beschriftungen ohne Überlappung: wichtige Einrichtungen
  // zuerst; überdeckt ein Name einen bereits gesetzten, entfällt er.
  #drawLabels(nodes, level) {
    const candidates = nodes
      .filter(node => node.type === "facility" && (node.level === level || node.level === level - 1 || this.#emphasized.has(node.id)))
      .sort((a, b) => this.#labelPriority(b, level) - this.#labelPriority(a, level))

    const placed = []
    const labels = []

    for (const node of candidates) {
      const text = shorten(node.name)
      const point = this.#labelPoint(node, level)
      const box = {
        x0: point.x - text.length * SCREEN.labelCharWidth / 2,
        x1: point.x + text.length * SCREEN.labelCharWidth / 2,
        y0: point.y - SCREEN.labelHeight,
        y1: point.y + 2
      }
      if (placed.some(other => overlaps(box, other))) continue

      placed.push(box)
      labels.push({ node, text, point })
    }

    this.#layer("labels").selectAll("text")
      .data(labels, label => label.node.id)
      .join("text")
      .attr("class", label => `node-label level-${label.node.level}`)
      .attr("x", label => label.point.x)
      .attr("y", label => label.point.y)
      .text(label => label.text)
  }

  // Grundlinie der Beschriftung unter dem Symbol.
  #labelPoint(node, level) {
    const point = this.#points.get(node.id)
    return { x: point.x, y: point.y + this.#iconSize(node, level) / 2 + SCREEN.labelOffset + 4 }
  }

  // Ausgewählte zuerst, dann die Ebene der aktuellen Stufe,
  // innerhalb einer Ebene größere Hochschulen zuerst.
  #labelPriority(node, level) {
    if (this.#emphasized.has(node.id)) return 1000
    const sameLevel = node.level === level ? 100 : 0
    return sameLevel + (this.#rootIconSize.get(node.id) ?? 0)
  }

  // ----------------------------------------------------------
  // Tooltip
  // ----------------------------------------------------------

  #showTooltip(event, html) {
    const panel = this.#tooltip.parentElement.getBoundingClientRect()

    this.#tooltip.innerHTML = html
    this.#tooltip.style.left = `${event.clientX - panel.left + 12}px`
    this.#tooltip.style.top = `${event.clientY - panel.top + 12}px`
    this.#tooltip.classList.add("open")
  }

  #hideTooltip() {
    this.#tooltip.classList.remove("open")
  }

  // Name und Zugehörigkeit eines Knotens.
  #nodeTooltip(node) {
    const lines = node.type === "person"
      ? node.facilities.map(id => this.#nodes.get(id)?.name)
      : [ this.#nodes.get(node.parent)?.name ]

    return [ `<b>${escapeHtml(node.name)}</b>`, ...lines.filter(Boolean).map(escapeHtml) ].join("<br>")
  }

  // Beide Enden der Kante und die Art der Kooperation.
  #linkTooltip(link) {
    const names = `${escapeHtml(this.#nodes.get(link.source)?.name)} – ${escapeHtml(this.#nodes.get(link.target)?.name)}`

    if (link.level === 3) {
      return `<b>${names}</b><br>${plural(link.projects, "gemeinsames Projekt", "gemeinsame Projekte")}` +
             ` · ${plural(link.publications, "gemeinsame Publikation", "gemeinsame Publikationen")}`
    }

    return `<b>${names}</b><br>${plural(link.count, "kooperierendes Personenpaar", "kooperierende Personenpaare")}` +
           `<br>davon über Projekte: ${link.projects} · über Publikationen: ${link.publications}`
  }

  // Beide Personen und der Ähnlichkeitswert (z. B. 0,87).
  #similarTooltip(edge) {
    const names = `${escapeHtml(this.#nodes.get(edge.source)?.name)} – ${escapeHtml(this.#nodes.get(edge.target)?.name)}`
    const score = edge.score.toLocaleString("de-DE", { minimumFractionDigits: 2, maximumFractionDigits: 2 })

    return `<b>${names}</b><br>thematische Ähnlichkeit ${score}`
  }

  // ----------------------------------------------------------
  // Zoom und Verschieben
  // ----------------------------------------------------------

  // d3.zoom übernimmt Mausrad (zoomen) und Ziehen (verschieben).
  // Doppelklick-Zoom ist abgeschaltet, damit Klicks eindeutig
  // eine Auswahl bedeuten.
  #setupZoom() {
    this.#zoom = d3.zoom().on("zoom", event => {
      this.#transform = event.transform
      this.#hideTooltip()
      this.#scheduleRender()
    })

    this.#svg.call(this.#zoom).on("dblclick.zoom", null)
  }

  // Gesamtansicht: alle Hochschulen passen in die Fläche.
  #homeTransform() {
    const points = [ ...this.#positions.values() ]
    const [ x0, x1 ] = d3.extent(points, point => point.x)
    const [ y0, y1 ] = d3.extent(points, point => point.y)
    const k = 0.92 * Math.min(this.#width / (x1 - x0), this.#height / (y1 - y0))

    return d3.zoomIdentity
      .translate(this.#width / 2, this.#height / 2)
      .scale(k)
      .translate(-(x0 + x1) / 2, -(y0 + y1) / 2)
  }

  // Knöpfe +, − und ⌂ unten rechts.
  #bindZoomControls(controls) {
    const actions = {
      in: () => this.#svg.transition().call(this.#zoom.scaleBy, ZOOM_STEP),
      out: () => this.#svg.transition().call(this.#zoom.scaleBy, 1 / ZOOM_STEP),
      home: () => this.zoomTo(this.#homeTransform())
    }

    controls.querySelectorAll("[data-zoom]").forEach(button =>
      button.addEventListener("click", () => actions[button.dataset.zoom]())
    )
  }

  // Passt viewBox und Zoomgrenzen an die Größe der Fläche an.
  // Beim ersten Aufruf startet die Gesamtansicht.
  #observeSize() {
    const resize = () => {
      const { width, height } = this.#svg.node().getBoundingClientRect()
      if (width === 0 || height === 0) return

      const firstTime = this.#width === 0
      this.#width = width
      this.#height = height
      this.#svg.attr("viewBox", `0 0 ${width} ${height}`)
      this.#zoom.scaleExtent([ this.#homeTransform().k * 0.5, this.#levelScales[3] * 3 ])

      if (firstTime) this.#svg.call(this.#zoom.transform, this.#homeTransform())
      else this.#scheduleRender()
    }

    new ResizeObserver(resize).observe(this.#svg.node())
  }

  // Bündelt Zoom-Ereignisse zu einem Neuzeichnen pro Frame.
  #scheduleRender() {
    if (this.#frame) return

    this.#frame = requestAnimationFrame(() => {
      this.#frame = null
      this.render()
    })
  }
}

// ------------------------------------------------------------
// Hilfsfunktionen
// ------------------------------------------------------------

// Eindeutiger Schlüssel einer Kante, z. B. "1|f3|f9".
export function linkKey(level, source, target) {
  return `${level}|${source}|${target}`
}

// Prüft, ob sich zwei Rechtecke überschneiden.
function overlaps(a, b) {
  return a.x0 < b.x1 && b.x0 < a.x1 && a.y0 < b.y1 && b.y0 < a.y1
}

// Kürzt lange Namen mit "…".
function shorten(text) {
  return text.length > LABEL_MAX_LENGTH ? `${text.slice(0, LABEL_MAX_LENGTH - 1)}…` : text
}

// "1 gemeinsames Projekt" / "3 gemeinsame Projekte"
function plural(count, singular, pluralForm) {
  return `${count} ${count === 1 ? singular : pluralForm}`
}

// Ersetzt HTML-Sonderzeichen, damit Namen aus der Datenbank
// nicht als HTML interpretiert werden.
function escapeHtml(text) {
  return String(text ?? "").replace(/[&<>"']/g, char => (
    { "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;" }[char]
  ))
}