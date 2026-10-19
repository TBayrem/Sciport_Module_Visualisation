
import Network from "network/Network.js";

// ============================================================
// Datei: network/main.js
//
// Desc:
// Verbindet die HTML-Oberfläche des Forschungsnetzwerks
// mit der D3-Klasse Network.
//
// Die Datei verarbeitet die Einrichtungsfilter,
// initialisiert die Visualisierung und zeigt
// Informationen zu ausgewählten Netzwerkknoten an.
//
// Anwendungsfälle:
// - Forschungsnetzwerk initialisieren
// - Forschende nach Einrichtungen filtern
// - Informationen zu Forschenden anzeigen
// - Informationen zu Einrichtungen anzeigen
// - Netzwerk bei Seitenwechseln korrekt bereinigen
// ============================================================


// ------------------------------------------------------------
// 1. Verwaltung der Netzwerk-Instanz
//
// Es wird nur eine aktive Netzwerk-Instanz verwaltet,
// damit bei Turbo-Seitenwechseln keine mehrfachen
// Force-Simulationen entstehen.
// ------------------------------------------------------------

let networkInstance = null;


// ------------------------------------------------------------
// 2. Sichere Erstellung von HTML-Elementen
// ------------------------------------------------------------

/**
 * Title: createTextElement
 *
 * Desc:
 * Erstellt ein HTML-Element mit einem Textinhalt.
 *
 * Der Text wird über textContent eingesetzt,
 * damit Namen und andere Daten nicht als
 * ausführbarer HTML-Code interpretiert werden.
 *
 * Parameters:
 * - tagName: Name des HTML-Elements
 * - text: anzuzeigender Text
 * - className: optionale CSS-Klasse
 *
 * Returns:
 * - Erstelltes HTML-Element.
 */
function createTextElement(tagName, text, className = "") {
  const element = document.createElement(tagName);

  element.textContent = String(text ?? "");

  if (className) {
    element.className = className;
  }

  return element;
}


// ------------------------------------------------------------
// 3. Anzeige der Detailinformationen
// ------------------------------------------------------------

/**
 * Title: showNodeDetails
 *
 * Desc:
 * Zeigt Informationen zu einer ausgewählten Person
 * oder wissenschaftlichen Einrichtung an.
 *
 * Bei Personen werden der Name, der akademische Titel,
 * das Forschungsgebiet und die im Netzwerk verbundenen
 * Einrichtungen dargestellt.
 *
 * Bei Einrichtungen werden der Name und die
 * im Netzwerk verbundenen Forschenden angezeigt.
 *
 * Parameters:
 * - node: ausgewählter Netzwerkknoten oder null
 * - connectedNodes: direkt verbundene Knoten
 *
 * Returns:
 * - Kein Rückgabewert.
 */
function showNodeDetails(node, connectedNodes = []) {
  const container = document.getElementById(
    "network-details-content"
  );

  if (!container) {
    return;
  }

  container.replaceChildren();

  if (!node) {
    container.appendChild(
      createTextElement(
        "p",
        "Klicken Sie auf eine Person oder Einrichtung " +
          "im Netzwerk, um Informationen anzuzeigen."
      )
    );

    return;
  }

  const isPerson = node.type === "person";

  container.appendChild(
    createTextElement(
      "h3",
      node.name || "Unbekannt",
      "network-detail-title"
    )
  );

  container.appendChild(
    createTextElement(
      "p",
      isPerson ? "Forschende Person" : "Wissenschaftliche Einrichtung",
      "network-detail-type"
    )
  );

  if (isPerson) {
    if (node.title) {
      container.appendChild(
        createTextElement(
          "p",
          `Akademischer Titel: ${node.title}`
        )
      );
    }

    if (node.field_of_research) {
      container.appendChild(
        createTextElement(
          "p",
          `Forschungsgebiet: ${node.field_of_research}`
        )
      );
    }
  }

  const relatedNodes = connectedNodes
    .filter(relatedNode =>
      isPerson
        ? relatedNode.type === "facility"
        : relatedNode.type === "person"
    )
    .sort((first, second) =>
      String(first.name || "").localeCompare(
        String(second.name || ""),
        "de"
      )
    );

  container.appendChild(
    createTextElement(
      "h4",
      isPerson
        ? `Verbundene Einrichtungen (${relatedNodes.length})`
        : `Angezeigte Forschende (${relatedNodes.length})`,
      "network-detail-subheading"
    )
  );

  if (relatedNodes.length === 0) {
    container.appendChild(
      createTextElement(
        "p",
        "Keine zugehörigen Knoten in der aktuellen Ansicht."
      )
    );

    return;
  }

  const list = document.createElement("ul");
  list.className = "network-detail-list";

  relatedNodes.forEach(relatedNode => {
    list.appendChild(
      createTextElement(
        "li",
        relatedNode.name || "Unbekannt"
      )
    );
  });

  container.appendChild(list);
}


// ------------------------------------------------------------
// 4. Zuordnung der Einrichtungs-ID
// ------------------------------------------------------------

/**
 * Title: initializeFacilitySearch
 *
 * Desc:
 * Verbindet das sichtbare Einrichtungs-Suchfeld
 * mit dem versteckten Feld facility_id.
 *
 * Der Controller benötigt die eindeutige ID,
 * während die Benutzeroberfläche den Namen
 * der Einrichtung anzeigt.
 *
 * Wenn mehrere Einrichtungen denselben Namen
 * besitzen, wird keine mehrdeutige ID übernommen.
 *
 * Parameters:
 * - Keine.
 *
 * Returns:
 * - Kein Rückgabewert.
 */
function initializeFacilitySearch() {
  const input = document.getElementById(
    "network-facility-search"
  );

  const hiddenInput = document.getElementById(
    "network-facility-id"
  );

  const datalist = document.getElementById(
    "network-facility-options"
  );

  if (!input || !hiddenInput || !datalist) {
    return;
  }

  const options = Array.from(
    datalist.querySelectorAll("option")
  );

  /**
   * Title: updateFacilityId
   *
   * Desc:
   * Prüft den eingegebenen Einrichtungsnamen
   * und übernimmt nur bei eindeutiger Übereinstimmung
   * die passende Einrichtungs-ID.
   *
   * Parameters:
   * - Keine.
   *
   * Returns:
   * - Kein Rückgabewert.
   */
  const updateFacilityId = () => {
    const enteredName = input.value.trim();

    const matches = options.filter(option =>
      option.value.trim() === enteredName
    );

    hiddenInput.value =
      matches.length === 1
        ? matches[0].dataset.facilityId || ""
        : "";
  };

  input.addEventListener("input", updateFacilityId);
  input.addEventListener("change", updateFacilityId);

  const form = input.closest("form");

  if (form) {
    form.addEventListener("submit", updateFacilityId);
  }
}


// ------------------------------------------------------------
// 5. Initialisierung der Netzwerkvisualisierung
// ------------------------------------------------------------

/**
 * Title: initializeNetwork
 *
 * Desc:
 * Liest die Netzwerkdaten aus dem HTML-Attribut
 * data-network-data und erzeugt eine neue
 * Instanz der Klasse Network.
 *
 * Die Auswahl eines Knotens wird mit der
 * Detailansicht verbunden.
 *
 * Parameters:
 * - Keine.
 *
 * Returns:
 * - Kein Rückgabewert.
 */
function initializeNetwork() {
  const container = document.getElementById(
    "network-visualization"
  );

  if (!container) {
    return;
  }

  const rawData = container.dataset.networkData;

  if (!rawData) {
    showNodeDetails(null);
    return;
  }

  try {
    const data = JSON.parse(rawData);

    networkInstance = new Network(
      container,
      data,
      showNodeDetails
    );
  } catch (error) {
    console.error(
      "Netzwerkdaten konnten nicht geladen werden:",
      error
    );

    container.textContent =
      "Die Netzwerkvisualisierung konnte nicht geladen werden.";
  }
}


// ------------------------------------------------------------
// 6. Bereinigung vor einer neuen Initialisierung
// ------------------------------------------------------------

/**
 * Title: destroyNetwork
 *
 * Desc:
 * Beendet eine vorhandene Netzwerk-Instanz
 * und gibt die zugehörigen D3-Ressourcen frei.
 *
 * Dadurch werden doppelte Simulationen
 * bei Turbo-Seitenwechseln vermieden.
 *
 * Parameters:
 * - Keine.
 *
 * Returns:
 * - Kein Rückgabewert.
 */
function destroyNetwork() {
  if (networkInstance) {
    networkInstance.destroy();
    networkInstance = null;
  }
}


// ------------------------------------------------------------
// 7. Initialisierung der Netzwerkseite
// ------------------------------------------------------------

/**
 * Title: initializePage
 *
 * Desc:
 * Bereitet die Netzwerkseite nach dem Laden vor.
 *
 * Zuerst wird eine möglicherweise vorhandene
 * Netzwerk-Instanz beendet. Danach werden
 * Einrichtungsfilter und Netzwerk initialisiert.
 *
 * Parameters:
 * - Keine.
 *
 * Returns:
 * - Kein Rückgabewert.
 */
function initializePage() {
  destroyNetwork();

  if (!document.querySelector(".network-page")) {
    return;
  }

  initializeFacilitySearch();
  initializeNetwork();
}


// ------------------------------------------------------------
// 8. Integration in den Rails-Turbo-Lebenszyklus
//
// turbo:load wird nach dem ersten Laden und nach
// Turbo-Navigationen ausgelöst.
//
// turbo:before-cache sorgt dafür, dass keine laufende
// D3-Simulation im Turbo-Seitencache gespeichert wird.
// ------------------------------------------------------------

document.addEventListener("turbo:load", initializePage);

document.addEventListener("turbo:before-cache", destroyNetwork);

// Falls das Modul erst nach dem initialen Turbo-Ereignis
// geladen wird, wird die vorhandene Seite einmalig
// initialisiert.
if (document.readyState === "loading") {
  document.addEventListener(
    "DOMContentLoaded",
    initializePage,
    { once: true }
  );
} else {
  initializePage();
}
