// ============================================================
// Datei: app/javascript/selection_state.js
//
// Desc:
//   Zentrale Auswahl einer Seite (Beobachter-Muster).
//
//   Alle Komponenten (NetworkView, TopicMapView, SearchBox,
//   DetailPanel, BarChart, ...) melden eine Auswahl nur hier
//   mit select(item). SelectionState ermittelt daraus die
//   betroffenen Personen und benachrichtigt alle
//   angemeldeten Komponenten. Die Komponenten kennen sich
//   dadurch nicht gegenseitig.
//
//   Ein Element (item) hat immer die Form
//     { type: "person" | "facility" | "topic", id: "..." }
//   select(null) hebt die Auswahl auf.
// ============================================================

export class SelectionState {
  #selected = null
  #people = new Set()
  #listeners = []
  #resolvers

  // resolvers: je Elementtyp eine Funktion, die zu einer ID
  // die zugehörigen Personen-IDs liefert, z. B.
  //   { person: id => [id], facility: id => [...], topic: id => [...] }
  // Die Seite (Page) baut sie aus den eingebetteten Daten.
  constructor(resolvers) {
    this.#resolvers = resolvers
  }

  // Aktuell ausgewähltes Element oder null.
  get selected() {
    return this.#selected
  }

  // Personen-IDs, die zur aktuellen Auswahl gehören.
  get people() {
    return this.#people
  }

  // Setzt eine neue Auswahl und benachrichtigt alle
  // Komponenten. Eine erneute Auswahl desselben Elements
  // löst keine Benachrichtigung aus.
  select(item) {
    if (this.#isSelected(item)) return

    this.#selected = item
    this.#people = item ? this.#resolve(item) : new Set()
    this.#notify()
  }

  // Meldet eine Komponente an. listener wird bei jeder
  // Änderung mit dem SelectionState aufgerufen.
  subscribe(listener) {
    this.#listeners.push(listener)
  }

  // Liefert die Personen-IDs zu einem Element.
  #resolve(item) {
    const resolver = this.#resolvers[item.type]
    if (!resolver) throw new Error(`Unbekannter Auswahltyp: ${item.type}`)

    return new Set(resolver(item.id))
  }

  #notify() {
    this.#listeners.forEach(listener => listener(this))
  }

  #isSelected(item) {
    const current = this.#selected
    if (item === null || current === null) return item === current

    return item.type === current.type && item.id === current.id
  }
}