// ============================================================
// Datei: app/javascript/search_box.js
//
// Desc:
//   Suchfeld mit Vorschlagsliste (UC 2: Person suchen).
//   Durchsucht Personen und Einrichtungen der eingebetteten
//   Daten direkt im Browser; es gibt keine Anfrage an den
//   Server.
//
//   Ablauf:
//     suggest() – zeigt bei jeder Eingabe passende Vorschläge,
//                 gruppiert nach Personen und Einrichtungen
//     choose()  – übergibt den gewählten Vorschlag an
//                 SelectionState
//
//   Suche: Groß-/Kleinschreibung und Akzente spielen keine
//   Rolle ("muller" findet "Müller"); alle eingegebenen Wörter
//   müssen im Namen vorkommen. Treffer am Wortanfang stehen
//   vorn.
//
//   Tastatur: ↑/↓ wählen, Enter übernimmt, Escape schließt.
// ============================================================

// Mindestlänge der Eingabe und Vorschläge je Gruppe.
const MIN_QUERY_LENGTH = 2
const MAX_PER_GROUP = 8

const GROUPS = [
  { type: "person", title: "Personen" },
  { type: "facility", title: "Einrichtungen" }
]

export class SearchBox {
  #input
  #list
  #selection
  #entries          // [{ id, type, name, key, context }]
  #suggestions = [] // aktuell angezeigte Vorschläge
  #active = -1      // per Tastatur markierter Vorschlag

  // root:      Element mit data-search-box (aus shared/_search)
  // nodes:     Knoten der Seite (Personen und Einrichtungen)
  // selection: SelectionState der Seite
  constructor(root, nodes, selection) {
    this.#input = root.querySelector("[data-search-input]")
    this.#list = root.querySelector("[data-search-suggestions]")
    this.#selection = selection
    this.#entries = this.#buildIndex(nodes)

    this.#input.addEventListener("input", () => this.suggest(this.#input.value))
    this.#input.addEventListener("keydown", event => this.#onKey(event))
    this.#input.addEventListener("blur", () => this.#close())

    // mousedown statt click: wird vor dem blur des Eingabefelds
    // ausgelöst, sonst wäre die Liste schon geschlossen.
    this.#list.addEventListener("mousedown", event => {
      const item = event.target.closest("[data-index]")
      if (!item) return

      event.preventDefault()
      this.choose(this.#suggestions[Number(item.dataset.index)])
    })
  }

  // Zeigt die Vorschläge zur Eingabe query.
  suggest(query) {
    const words = normalize(query).split(/\s+/).filter(Boolean)

    this.#suggestions = normalize(query).length < MIN_QUERY_LENGTH
      ? []
      : GROUPS.flatMap(group => this.#matches(group.type, words))
    this.#active = this.#suggestions.length > 0 ? 0 : -1

    this.#render()
  }

  // Übernimmt einen Vorschlag als Auswahl.
  choose(entry) {
    if (!entry) return

    this.#input.value = entry.name
    this.#close()
    this.#selection.select({ type: entry.type, id: entry.id })
  }

  // Leert das Suchfeld (z. B. nach "Zurücksetzen").
  clear() {
    this.#input.value = ""
    this.#close()
  }

  // ----------------------------------------------------------
  // Suche
  // ----------------------------------------------------------

  // Bereitet alle Einträge einmalig vor: normalisierter Name
  // zum Vergleichen und ein Zusatz (Einrichtung bzw. Hochschule)
  // zur Unterscheidung gleichnamiger Einträge.
  #buildIndex(nodes) {
    const names = new Map(nodes.map(node => [ node.id, node.name ]))

    return nodes.map(node => ({
      id: node.id,
      type: node.type,
      name: node.name,
      key: normalize(node.name),
      context: node.type === "person"
        ? names.get(node.facilities[0]) ?? ""
        : (node.parent ? names.get(node.root) ?? "" : "Hochschule")
    }))
  }

  // Treffer eines Typs: alle Wörter kommen im Namen vor.
  // Sortierung: Treffer am Wortanfang zuerst, dann alphabetisch.
  #matches(type, words) {
    return this.#entries
      .filter(entry => entry.type === type && words.every(word => entry.key.includes(word)))
      .map(entry => ({ entry, rank: words.every(word => startsWord(entry.key, word)) ? 0 : 1 }))
      .sort((a, b) => a.rank - b.rank || a.entry.name.localeCompare(b.entry.name, "de"))
      .slice(0, MAX_PER_GROUP)
      .map(match => match.entry)
  }

  // ----------------------------------------------------------
  // Darstellung
  // ----------------------------------------------------------

  // Liste mit Gruppenüberschriften; jeder Vorschlag kennt seine
  // Position in #suggestions (data-index).
  #render() {
    if (this.#suggestions.length === 0) {
      this.#list.innerHTML = this.#input.value.trim().length >= MIN_QUERY_LENGTH
        ? `<li class="g">Keine Treffer</li>`
        : ""
      this.#list.classList.toggle("open", this.#list.innerHTML !== "")
      return
    }

    const rows = []
    GROUPS.forEach(group => {
      const items = this.#suggestions
        .map((entry, index) => ({ entry, index }))
        .filter(({ entry }) => entry.type === group.type)
      if (items.length === 0) return

      rows.push(`<li class="g">${group.title}</li>`)
      items.forEach(({ entry, index }) => rows.push(
        `<li class="it${index === this.#active ? " on" : ""}" role="option" data-index="${index}">` +
        `<b>${escapeHtml(entry.name)}</b><span class="c">${escapeHtml(entry.context)}</span></li>`
      ))
    })

    this.#list.innerHTML = rows.join("")
    this.#list.classList.add("open")
  }

  #close() {
    this.#list.classList.remove("open")
    this.#active = -1
  }

  // ----------------------------------------------------------
  // Tastatur
  // ----------------------------------------------------------

  #onKey(event) {
    const count = this.#suggestions.length

    switch (event.key) {
      case "ArrowDown":
        if (count === 0) return
        this.#active = (this.#active + 1) % count
        break
      case "ArrowUp":
        if (count === 0) return
        this.#active = (this.#active - 1 + count) % count
        break
      case "Enter":
        this.choose(this.#suggestions[this.#active])
        break
      case "Escape":
        this.#close()
        return
      default:
        return
    }

    event.preventDefault()
    if (this.#list.classList.contains("open")) this.#render()
  }
}

// ------------------------------------------------------------
// Hilfsfunktionen
// ------------------------------------------------------------

// Kleinbuchstaben ohne Akzente: "Müller" → "muller".
function normalize(text) {
  return String(text ?? "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .trim()
}

// Beginnt ein Wort im Text mit word?
function startsWord(text, word) {
  return text.startsWith(word) || text.includes(` ${word}`) || text.includes(`-${word}`)
}

// Ersetzt HTML-Sonderzeichen, damit Namen aus der Datenbank
// nicht als HTML interpretiert werden.
function escapeHtml(text) {
  return String(text ?? "").replace(/[&<>"']/g, char => (
    { "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;" }[char]
  ))
}