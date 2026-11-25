// ============================================================
// Datei: app/javascript/legend.js
//
// Desc:
//   Blendet die Legende ("ⓘ Legende") ein und aus. Der Inhalt
//   kommt vollständig aus shared/_legend.html.erb; diese
//   Klasse steuert nur die Sichtbarkeit.
//
//   Schließen auf vier Wegen:
//     - erneuter Klick auf den Knopf
//     - Klick auf "×"
//     - Taste Escape
//     - Klick außerhalb der Legende
// ============================================================

export class Legend {
  #button
  #popup

  // root: Element mit data-legend (aus shared/_legend).
  constructor(root) {
    this.#button = root.querySelector("[data-legend-toggle]")
    this.#popup = root.querySelector("[data-legend-popup]")

    this.#button.addEventListener("click", () => this.toggle())
    root.querySelector("[data-legend-close]").addEventListener("click", () => this.toggle(false))

    document.addEventListener("keydown", event => {
      if (event.key === "Escape") this.toggle(false)
    })
    // Erfassungsphase (true): reagiert auch, wenn eine Grafik
    // den Klick selbst abfängt.
    document.addEventListener("pointerdown", event => {
      if (!root.contains(event.target)) this.toggle(false)
    }, true)
  }

  // Öffnet oder schließt die Legende. Ohne Argument wird der
  // Zustand umgeschaltet.
  toggle(open = this.#popup.hidden) {
    this.#popup.hidden = !open
    this.#button.setAttribute("aria-expanded", String(open))
  }
}