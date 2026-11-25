// ============================================================
// Datei: app/javascript/detail_panel.js
//
// Desc:
//   Infobereich rechts neben der Grafik (UC 2). Zeigt die
//   Details der aktuellen Auswahl:
//     - Person:      Zugehörigkeit, Forschungsgebiet, Zahlen,
//                    Kooperationspartner
//     - Einrichtung: übergeordnete Einrichtungen, Zahlen,
//                    Untereinrichtungen, Partner-Einrichtungen
//     - Kante:       beide Enden und Art der Kooperation
//     - Thema:       Begriffe, Zahlen und Personen des Themas
//                    (Themenkarte, kombinierte Ansicht)
//
//   Auf Seiten mit Themen (data.topics und data.points
//   vorhanden) zeigt der Infobereich einer Person zusätzlich
//   ihr Thema als Verweis.
//
//   Namen in Listen sind Verweise: Ein Klick wählt das
//   Element über SelectionState aus. So kann man sich von
//   Person zu Partner zu Einrichtung weiterbewegen.
//
//   Alle Texte aus der Datenbank werden vor der Ausgabe
//   escaped.
// ============================================================

// Maximale Länge von Listen im Infobereich.
const LIST_LIMIT = 12
const RESEARCH_TEXT_LIMIT = 220

export class DetailPanel {
  #element
  #selection
  #placeholder
  #nodes                 // Map id → Knoten
  #children              // Map Einrichtungs-ID → [Untereinrichtungen]
  #partners              // Map Personen-ID → [{ id, projects, publications }]
  #facilityLinks         // Map Einrichtungs-ID → [Sammelkanten]
  #projectCounts         // Map Personen-ID → Anzahl Projekte
  #publicationCounts     // Map Personen-ID → Anzahl Publikationen
  #topics                // Map Clusternummer → { terms, size }
  #topicOf               // Map Personen-ID → Clusternummer

  // element:   <aside data-detail-panel>
  // data:      Visualization::NetworkGraph#to_h; optional
  //            zusätzlich publication_counts, topics und
  //            points (Visualization::TopicMap#to_h)
  // selection: SelectionState der Seite
  constructor(element, data, selection) {
    this.#element = element
    this.#selection = selection
    this.#placeholder = element.innerHTML

    this.#nodes = new Map(data.nodes.map(node => [ node.id, node ]))
    this.#children = groupBy(data.nodes.filter(node => node.parent), node => node.parent)
    this.#partners = this.#indexPartners(data.cooperations)
    this.#facilityLinks = this.#indexFacilityLinks(data.aggregated_edges)
    this.#projectCounts = new Map(data.project_counts.map(entry => [ entry.id, entry.count ]))
    this.#publicationCounts = new Map((data.publication_counts ?? []).map(entry => [ entry.id, entry.count ]))
    this.#topics = new Map((data.topics ?? []).map(topic => [ topic.cluster, topic ]))
    this.#topicOf = new Map((data.points ?? []).map(point => [ point.id, point.cluster ]))

    // Ein Klick auf einen Verweis wählt das Element aus.
    element.addEventListener("click", event => {
      const link = event.target.closest("[data-select-id]")
      if (link) this.#selection.select({ type: link.dataset.selectType, id: link.dataset.selectId })
    })
  }

  // Zeigt die Details der Auswahl (Aufruf über SelectionState).
  show(state) {
    const item = state.selected

    if (!item) {
      this.#element.innerHTML = this.#placeholder
    } else if (item.type === "person") {
      this.#element.innerHTML = this.#renderPerson(item.id)
    } else if (item.type === "facility") {
      this.#element.innerHTML = this.#renderFacility(item.id, state.people.size)
    } else if (item.type === "link") {
      this.#element.innerHTML = this.#renderLink(item.id)
    } else if (item.type === "topic") {
      this.#element.innerHTML = this.#renderTopic(Number(item.id), [ ...state.people ])
    }

    this.#element.scrollTop = 0
  }

  // ----------------------------------------------------------
  // Person
  // ----------------------------------------------------------

  #renderPerson(id) {
    const person = this.#nodes.get(id)
    const partners = [ ...(this.#partners.get(id) ?? []) ]
      .sort((a, b) => (b.projects + b.publications) - (a.projects + a.publications))

    return [
      `<span class="badge">Person</span>`,
      `<h3 class="pt">${escapeHtml(person.name)}</h3>`,
      section("Zugehörigkeit", person.facilities.map(facilityId => this.#crumb(facilityId)).join("")),
      this.#topics.has(this.#topicOf.get(id))
        ? section("Thema", this.#topicLink(this.#topicOf.get(id)))
        : "",
      person.field_of_research
        ? section("Forschungsgebiet", `<p class="hint">${escapeHtml(truncate(person.field_of_research))}</p>`)
        : "",
      this.#stats([
        [ this.#projectCounts.get(id) ?? 0, "Projekte" ],
        [ partners.length, "Partner" ],
        [ person.facilities.length, "Einrichtungen" ]
      ]),
      section(`Kooperationspartner (${partners.length})`, this.#list(partners, partner =>
        `${this.#link(partner.id)} <span class="via">${cooperationText(partner)}</span>`
      ))
    ].join("")
  }

  // ----------------------------------------------------------
  // Einrichtung
  // ----------------------------------------------------------

  #renderFacility(id, peopleCount) {
    const facility = this.#nodes.get(id)
    const subunits = this.#children.get(id) ?? []
    const partners = [ ...(this.#facilityLinks.get(id) ?? []) ].sort((a, b) => b.count - a.count)

    return [
      `<span class="badge">${facility.level === 1 ? "Hochschule" : "Fachbereich / Untereinrichtung"}</span>`,
      `<h3 class="pt">${escapeHtml(facility.name)}</h3>`,
      facility.parent ? section("Gehört zu", this.#crumb(facility.parent)) : "",
      this.#stats([
        [ peopleCount, "Personen" ],
        [ subunits.length, "Untereinh." ],
        [ partners.length, "Partner" ]
      ]),
      subunits.length > 0
        ? section(`Untereinrichtungen (${subunits.length})`, this.#list(subunits, unit => this.#link(unit.id)))
        : "",
      section(`Kooperiert mit (${partners.length})`, this.#list(partners, edge =>
        `${this.#link(edge.partner)} <span class="via">${edge.count} Personenpaare</span>`
      ))
    ].join("")
  }

  // ----------------------------------------------------------
  // Kante
  // ----------------------------------------------------------

  // Schlüssel "Stufe|Quelle|Ziel" (vgl. NetworkView.linkKey).
  #renderLink(key) {
    const [ level, source, target ] = key.split("|")
    const link = level === "3"
      ? this.#partners.get(source)?.find(partner => partner.id === target)
      : this.#facilityLinks.get(source)?.find(edge => edge.partner === target)

    if (!link) return this.#placeholder

    const body = level === "3"
      ? this.#stats([ [ link.projects, "Projekte" ], [ link.publications, "Publikationen" ] ])
      : this.#stats([
        [ link.count, "Personenpaare" ],
        [ link.projects, "über Projekte" ],
        [ link.publications, "über Publik." ]
      ])

    return [
      `<span class="badge">Kooperation</span>`,
      section("Zwischen", `<div class="row">${this.#link(source)}</div><div class="row">${this.#link(target)}</div>`),
      body,
      level === "3"
        ? `<p class="hint">Gemeinsame Projekte und Publikationen der beiden Personen.</p>`
        : `<p class="hint">Personenpaare aus beiden Einrichtungen, die über Projekte bzw. Publikationen zusammenarbeiten.</p>`
    ].join("")
  }

  // ----------------------------------------------------------
  // Thema
  // ----------------------------------------------------------

  // Begriffe, Zahlen und Personen eines Themas; die Personen
  // mit den meisten Projekten und Publikationen zuerst.
  #renderTopic(cluster, people) {
    const topic = this.#topics.get(cluster)
    if (!topic) return this.#placeholder

    const activity = id => (this.#projectCounts.get(id) ?? 0) + (this.#publicationCounts.get(id) ?? 0)
    const sorted = people.filter(id => this.#nodes.has(id)).sort((a, b) => activity(b) - activity(a))
    const sum = counts => people.reduce((total, id) => total + (counts.get(id) ?? 0), 0)

    return [
      `<span class="badge">Thema</span>`,
      `<h3 class="pt">${escapeHtml(topic.terms.slice(0, 3).join(", "))}</h3>`,
      section("Begriffe", `<p class="hint">${escapeHtml(topic.terms.join(", "))}</p>`),
      this.#stats([
        [ people.length, "Personen" ],
        [ sum(this.#projectCounts), "Projekte" ],
        [ sum(this.#publicationCounts), "Publikationen" ]
      ]),
      section(`Personen (${sorted.length})`, this.#list(sorted, id => this.#link(id)))
    ].join("")
  }

  // ----------------------------------------------------------
  // Bausteine
  // ----------------------------------------------------------

  // Klickbarer Name eines Themas (erste drei Begriffe).
  #topicLink(cluster) {
    const label = this.#topics.get(cluster).terms.slice(0, 3).join(", ")
    return `<button type="button" class="lk" data-select-type="topic" data-select-id="${cluster}">${escapeHtml(label)}</button>`
  }

  // Klickbarer Name eines Knotens.
  #link(id) {
    const node = this.#nodes.get(id)
    if (!node) return ""

    return `<button type="button" class="lk" data-select-type="${node.type}" data-select-id="${node.id}">` +
           `${escapeHtml(node.name)}</button>`
  }

  // Pfad einer Einrichtung: Hochschule › Fachbereich › Einheit.
  #crumb(facilityId) {
    const chain = []
    for (let id = facilityId; id; id = this.#nodes.get(id)?.parent) chain.unshift(id)

    return `<span class="crumb">${chain.map(id => this.#link(id)).join(" › ")}</span>`
  }

  // Kennzahlen als Kacheln.
  #stats(entries) {
    const tiles = entries.map(([ value, label ]) => `<div class="st"><b>${value}</b><span>${label}</span></div>`)
    return `<div class="stats">${tiles.join("")}</div>`
  }

  // Liste mit Obergrenze; der Rest wird als Anzahl genannt.
  #list(items, render) {
    if (items.length === 0) return `<p class="hint">keine</p>`

    const rows = items.slice(0, LIST_LIMIT).map(item => `<div class="row">${render(item)}</div>`)
    const rest = items.length - LIST_LIMIT
    if (rest > 0) rows.push(`<p class="hint">… und ${rest} weitere</p>`)

    return rows.join("")
  }

  // ----------------------------------------------------------
  // Indizes
  // ----------------------------------------------------------

  // Kooperationspartner je Person (in beide Richtungen).
  #indexPartners(cooperations) {
    const partners = new Map()
    const add = (from, to, cooperation) => {
      if (!partners.has(from)) partners.set(from, [])
      partners.get(from).push({ id: to, projects: cooperation.projects, publications: cooperation.publications })
    }

    for (const cooperation of cooperations) {
      add(cooperation.source, cooperation.target, cooperation)
      add(cooperation.target, cooperation.source, cooperation)
    }
    return partners
  }

  // Sammelkanten je Einrichtung, jeweils mit der Partnerseite.
  #indexFacilityLinks(edges) {
    const links = new Map()
    const add = (from, to, edge) => {
      if (!links.has(from)) links.set(from, [])
      links.get(from).push({ ...edge, partner: to })
    }

    for (const edge of edges) {
      add(edge.source, edge.target, edge)
      add(edge.target, edge.source, edge)
    }
    return links
  }
}

// ------------------------------------------------------------
// Hilfsfunktionen
// ------------------------------------------------------------

// Abschnitt mit kleiner Überschrift.
function section(title, content) {
  return `<div class="sec">${escapeHtml(title)}</div>${content}`
}

// "2 Projekte · 1 Publikation"
function cooperationText(partner) {
  const parts = []
  if (partner.projects > 0) parts.push(`${partner.projects} ${partner.projects === 1 ? "Projekt" : "Projekte"}`)
  if (partner.publications > 0) parts.push(`${partner.publications} ${partner.publications === 1 ? "Publikation" : "Publikationen"}`)
  return parts.join(" · ")
}

// Kürzt lange Texte (z. B. Forschungsgebiet) mit "…".
function truncate(text) {
  return text.length > RESEARCH_TEXT_LIMIT ? `${text.slice(0, RESEARCH_TEXT_LIMIT - 1)}…` : text
}

// Gruppiert eine Liste nach einem Schlüssel: Map Schlüssel → [Elemente].
function groupBy(items, key) {
  const groups = new Map()
  for (const item of items) {
    const value = key(item)
    if (!groups.has(value)) groups.set(value, [])
    groups.get(value).push(item)
  }
  return groups
}

// Ersetzt HTML-Sonderzeichen, damit Texte aus der Datenbank
// nicht als HTML interpretiert werden.
function escapeHtml(text) {
  return String(text ?? "").replace(/[&<>"']/g, char => (
    { "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;" }[char]
  ))
}