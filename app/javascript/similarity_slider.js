// ============================================================
// Datei: app/javascript/similarity_slider.js
//
// Desc:
//   Schwellenwert-Regler der kombinierten Ansicht (UC 5,
//   FA32). Der Regler legt die Mindestähnlichkeit der
//   thematischen Kanten im Netzwerk fest: Ein höherer Wert
//   zeigt weniger Kanten. Neben dem Regler stehen der
//   aktuelle Wert und die Anzahl der Kanten oberhalb.
//
//   Der Regler filtert nur im Browser (die Kanten sind
//   eingebettet); er sendet keine Anfrage an den Server.
//
// Markup (combined_views/index.html.erb):
//   [data-similarity-slider]   Container
//     input[type=range]        Regler (min, max, step, value)
//     [data-similarity-value]  Anzeige des Werts
//     [data-similarity-count]  Anzeige der Kantenzahl
//
// Schnittstelle:
//   new SimilaritySlider(element, { onChange })
//   onChange(value) liefert die Anzahl der Kanten zurück
//   (NetworkView#setSimilarityThreshold).
// ============================================================

export class SimilaritySlider {
  #input
  #value
  #count
  #onChange

  constructor(element, { onChange }) {
    this.#input = element.querySelector("input[type=range]")
    this.#value = element.querySelector("[data-similarity-value]")
    this.#count = element.querySelector("[data-similarity-count]")
    this.#onChange = onChange

    // input: während des Ziehens laufend aktualisieren
    this.#input.addEventListener("input", () => this.#update())
    this.#update()
  }

  // Aktueller Schwellenwert.
  get value() {
    return Number(this.#input.value)
  }

  #update() {
    const value = this.value
    const count = this.#onChange(value)

    this.#value.textContent = value.toLocaleString("de-DE", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.#count.textContent = `${count.toLocaleString("de-DE")} ${count === 1 ? "Kante" : "Kanten"}`
  }
}