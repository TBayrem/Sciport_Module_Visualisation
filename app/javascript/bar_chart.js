// ============================================================
// Datei: app/javascript/bar_chart.js
//
// Desc:
//   Balkendiagramm "Projekte pro Person" unter dem Netzwerk
//   (UC 1, UC 2).
//
//   Ohne Auswahl zeigt es die Personen mit den meisten
//   Forschungsprojekten. Mit Auswahl zeigt es nur die
//   betroffenen Personen:
//     - Person:      die Person und ihre Kooperationspartner
//     - Einrichtung: alle Personen der Einrichtung
//     - Kante:       die Personen beider Enden
//   Die ausgewählte Person ist hervorgehoben.
//
//   Ein Klick auf einen Balken wählt die Person aus.
//
//   Datengrundlage: Visualization::NetworkGraph#project_counts.
// ============================================================

import * as d3 from "d3"

// Anzahl der angezeigten Balken.
const MAX_BARS = 15

// Maße in Pixeln.
const ROW_HEIGHT = 20
const BAR_HEIGHT = 13
const LABEL_WIDTH = 210
const VALUE_WIDTH = 34
const LABEL_MAX_LENGTH = 32

export class BarChart {
  #svg
  #hint
  #selection
  #counts        // Map Personen-ID → Anzahl Projekte
  #names         // Map Knoten-ID → Name
  #partners      // Map Personen-ID → Set der Partner-IDs
  #state = null  // letzte Auswahl (für Neuzeichnen bei Größenänderung)

  // svg:       <svg data-bar-chart>
  // hint:      Textzeile über dem Diagramm (data-bar-chart-hint)
  // data:      Visualization::NetworkGraph#to_h
  // selection: SelectionState der Seite
  constructor(svg, hint, data, selection) {
    this.#svg = d3.select(svg)
    this.#hint = hint
    this.#selection = selection
    this.#counts = new Map(data.project_counts.map(entry => [ entry.id, entry.count ]))
    this.#names = new Map(data.nodes.map(node => [ node.id, node.name ]))
    this.#partners = this.#indexPartners(data.cooperations)

    new ResizeObserver(() => this.render()).observe(svg)
  }

  // Zeichnet das Diagramm für die zuletzt bekannte Auswahl.
  render() {
    const rows = this.#rows(this.#state)
    const width = this.#svg.node().getBoundingClientRect().width
    if (width === 0) return

    const x = d3.scaleLinear()
      .domain([ 0, d3.max(rows, row => row.count) || 1 ])
      .range([ 0, Math.max(width - LABEL_WIDTH - VALUE_WIDTH, 10) ])

    this.#svg.attr("height", Math.max(rows.length, 1) * ROW_HEIGHT)

    const groups = this.#svg.selectAll("g.bar-row")
      .data(rows, row => row.id)
      .join(enter => {
        const group = enter.append("g")
          .attr("class", "bar-row")
          .on("click", (event, row) => this.#selection.select({ type: "person", id: row.id }))
        group.append("title")
        group.append("text").attr("class", "bar-label")
        group.append("rect").attr("class", "bar")
        group.append("text").attr("class", "bar-value")
        return group
      })

    groups
      .attr("transform", (row, index) => `translate(0,${index * ROW_HEIGHT})`)
      .classed("selected", row => row.id === this.#state?.selected?.id)

    groups.select("title").text(row => `${row.name}: ${row.count} Projekte`)

    groups.select(".bar-label")
      .attr("x", LABEL_WIDTH - 8)
      .attr("y", ROW_HEIGHT / 2)
      .text(row => shorten(row.name))

    groups.select(".bar")
      .attr("x", LABEL_WIDTH)
      .attr("y", (ROW_HEIGHT - BAR_HEIGHT) / 2)
      .attr("height", BAR_HEIGHT)
      .attr("width", row => x(row.count))

    groups.select(".bar-value")
      .attr("x", row => LABEL_WIDTH + x(row.count) + 4)
      .attr("y", ROW_HEIGHT / 2)
      .text(row => row.count)
  }

  // Reagiert auf eine geänderte Auswahl (SelectionState).
  highlight(state) {
    this.#state = state.selected ? state : null
    this.render()
  }

  // ----------------------------------------------------------
  // Daten
  // ----------------------------------------------------------

  // Zeilen des Diagramms, absteigend nach Anzahl Projekte.
  // Die Hinweiszeile beschreibt, was gerade zu sehen ist.
  #rows(state) {
    const people = state ? this.#peopleOf(state) : [ ...this.#counts.keys() ]

    const rows = people
      .filter(id => this.#counts.has(id))
      .map(id => ({ id, name: this.#names.get(id) ?? id, count: this.#counts.get(id) }))
      .sort((a, b) => b.count - a.count || a.name.localeCompare(b.name, "de"))

    this.#hint.textContent = this.#hintText(state, rows.length)

    return rows.slice(0, MAX_BARS)
  }

  // Betroffene Personen einer Auswahl. Bei einer Person kommen
  // ihre Kooperationspartner dazu, damit ein Vergleich möglich ist.
  #peopleOf(state) {
    const ids = new Set(state.people)

    if (state.selected.type === "person") {
      this.#partners.get(state.selected.id)?.forEach(id => ids.add(id))
    }

    return [ ...ids ]
  }

  #hintText(state, total) {
    if (total === 0) return state ? "Keine Personen mit Projekten in der Auswahl" : "Keine Projektdaten"

    const shown = Math.min(total, MAX_BARS)
    const scope = state ? `Auswahl: ${this.#selectionName(state.selected)}` : "Alle Personen"

    return `${scope} – ${shown} von ${total} Personen mit Projekten`
  }

  // Name der Auswahl für die Hinweiszeile.
  #selectionName(item) {
    if (item.type !== "link") return this.#names.get(item.id) ?? ""

    const [ , source, target ] = item.id.split("|")
    return `${this.#names.get(source)} – ${this.#names.get(target)}`
  }

  // Kooperationspartner je Person (in beide Richtungen).
  #indexPartners(cooperations) {
    const partners = new Map()
    const add = (from, to) => {
      if (!partners.has(from)) partners.set(from, new Set())
      partners.get(from).add(to)
    }

    for (const cooperation of cooperations) {
      add(cooperation.source, cooperation.target)
      add(cooperation.target, cooperation.source)
    }
    return partners
  }
}

// Kürzt lange Namen mit "…".
function shorten(text) {
  return text.length > LABEL_MAX_LENGTH ? `${text.slice(0, LABEL_MAX_LENGTH - 1)}…` : text
}