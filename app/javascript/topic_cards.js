// ============================================================
// Datei: app/javascript/topic_cards.js
//
// Desc:
//   Themenkarten neben der Themenkarte (UC3). Eine Karte je
//   Cluster mit Farbfeld, den ersten drei Begriffen als Titel,
//   der Anzahl der Personen und den übrigen Begriffen.
//   Die größten Cluster stehen oben (Reihenfolge aus
//   Visualization::TopicMap).
//
//   Zusammenspiel mit der Punktwolke (über page.js):
//   - Maus über einer Karte → onHover(cluster): die Punktwolke
//     hebt den Cluster hervor; Maus weg → onHover(null).
//   - Klick auf eine Karte → onFocus(cluster): die Punktwolke
//     zoomt auf den Cluster.
//   - markActive(cluster) markiert die Karte des Clusters der
//     ausgewählten Person; null hebt die Markierung auf.
//
//   Karten sind <button>-Elemente, damit sie auch mit Tastatur
//   (Tab, Enter) bedienbar sind.
//
// Schnittstelle:
//   new TopicCards(container, topics, { onHover, onFocus })
//   markActive(cluster)
// ============================================================

import { clusterClass } from "topic_map_view"

const TITLE_TERMS = 3
const MORE_TERMS = 7

export class TopicCards {
  #container
  #onHover
  #onFocus
  #cards = new Map()

  constructor(container, topics, { onHover = () => {}, onFocus = () => {} } = {}) {
    this.#container = container
    this.#onHover = onHover
    this.#onFocus = onFocus

    this.#render(topics)
  }

  // Karte des Clusters markieren und in den sichtbaren
  // Bereich der Liste scrollen
  markActive(cluster) {
    for (const [number, card] of this.#cards) {
      card.classList.toggle("active", number === cluster)
    }

    const card = this.#cards.get(cluster)
    if (card) card.scrollIntoView({ block: "nearest", behavior: "smooth" })
  }

  // ----------------------------------------------------------
  // Aufbau
  // ----------------------------------------------------------

  #render(topics) {
    this.#container.replaceChildren()

    if (topics.length === 0) {
      const empty = document.createElement("p")
      empty.className = "hint"
      empty.textContent = "Für diese Einstellung gibt es keine Themen."
      this.#container.append(empty)
      return
    }

    for (const topic of topics) {
      const card = this.#card(topic)
      this.#cards.set(topic.cluster, card)
      this.#container.append(card)
    }
  }

  // Inhalt per DOM aufgebaut (textContent), damit Begriffe
  // nicht als HTML interpretiert werden.
  #card(topic) {
    const card = document.createElement("button")
    card.type = "button"
    card.className = "topic-card"
    card.dataset.cluster = topic.cluster

    const swatch = document.createElement("span")
    swatch.className = `swatch ${clusterClass(topic.cluster)}`

    const title = document.createElement("strong")
    title.textContent = topic.terms.slice(0, TITLE_TERMS).join(", ")

    const size = document.createElement("span")
    size.className = "size"
    size.textContent = `${topic.size} ${topic.size === 1 ? "Person" : "Personen"}`

    const header = document.createElement("span")
    header.className = "topic-card-header"
    header.append(swatch, title, size)

    const terms = document.createElement("span")
    terms.className = "terms"
    for (const term of topic.terms.slice(TITLE_TERMS, TITLE_TERMS + MORE_TERMS)) {
      const tag = document.createElement("span")
      tag.className = "term"
      tag.textContent = term
      terms.append(tag)
    }

    card.append(header, terms)

    // Hover und Tastaturfokus heben den Cluster hervor
    card.addEventListener("pointerenter", () => this.#onHover(topic.cluster))
    card.addEventListener("pointerleave", () => this.#onHover(null))
    card.addEventListener("focus", () => this.#onHover(topic.cluster))
    card.addEventListener("blur", () => this.#onHover(null))
    card.addEventListener("click", () => this.#onFocus(topic.cluster))

    return card
  }
}