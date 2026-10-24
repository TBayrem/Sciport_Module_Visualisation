
/* ============================================================
   Datei: app/javascript/network/main.js

   Desc:
   Verbindet die D3-Netzwerkvisualisierung mit der
   Benutzeroberfläche des Forschungsnetzwerks.

   Diese Datei übernimmt:

   - Initialisierung von Network.js
   - Einlesen der Netzwerkdaten aus Rails
   - Darstellung der ausgewählten Knoten
   - Darstellung vollständiger Einrichtungshierarchien
   - Darstellung mehrerer institutioneller Zugehörigkeiten
   - Anzeige direkt verbundener Netzwerkknoten
   - Steuerung des Einrichtungsfilters
   - Unterstützung von Rails Turbo
   - Bereinigung beim Verlassen der Netzwerkseite

   Die Darstellung unterscheidet:

   Personen:
   - Name
   - Akademischer Titel
   - Forschungsgebiet
   - Alle institutionellen Zugehörigkeiten
   - Verbundene Haupteinrichtungen

   Haupteinrichtungen:
   - Name
   - Vollständige Untereinrichtungshierarchie
   - Direkt verbundene Forschende
   ============================================================ */

import Network from "./Network";


// ============================================================
// 1. Modulzustand
//
// Speichert die aktuelle Netzwerk-Instanz.
// Dadurch kann eine vorhandene Visualisierung
// vor einer erneuten Initialisierung entfernt werden.
// ============================================================

let currentNetwork = null;


// ============================================================
// 2. HTML-Element mit Text erstellen
//
// Title: createTextElement
//
// Desc:
// Erstellt ein HTML-Element mit optionaler CSS-Klasse.
//
// Die Verwendung von textContent verhindert,
// dass Datenbankinhalte als HTML interpretiert werden.
//
// Parameters:
// - tagName: HTML-Elementtyp
// - text: anzuzeigender Text
// - className: optionale CSS-Klasse
//
// Returns:
// - Neues HTML-Element.
// ============================================================

function createTextElement(
  tagName,
  text,
  className = ""
) {

  const element = document.createElement(tagName);

  if (className) {
    element.className = className;
  }

  element.textContent =
    text === null || text === undefined
      ? ""
      : String(text);

  return element;
}


// ============================================================
// 3. Detailbereich leeren
//
// Title: clearDetails
//
// Desc:
// Entfernt bisher angezeigte Informationen.
//
// Parameters:
// - container: HTML-Element des Detailbereichs
//
// Returns:
// - Kein Rückgabewert.
// ============================================================

function clearDetails(container) {

  if (!container) {
    return;
  }

  container.replaceChildren();
}


// ============================================================
// 4. Hinweistext im Detailbereich anzeigen
//
// Title: showDetailsPlaceholder
//
// Desc:
// Zeigt den Ausgangszustand des Informationsbereichs,
// solange kein Netzwerkknoten ausgewählt wurde.
//
// Parameters:
// - container: HTML-Element des Detailbereichs
//
// Returns:
// - Kein Rückgabewert.
// ============================================================

function showDetailsPlaceholder(container) {

  if (!container) {
    return;
  }

  clearDetails(container);

  const message = createTextElement(
    "p",
    "Klicken Sie auf eine Person oder Haupteinrichtung " +
      "im Netzwerk, um die zugehörigen Informationen " +
      "und Einrichtungshierarchien anzuzeigen."
  );

  container.appendChild(message);
}


// ============================================================
// 5. Einrichtungshierarchie rekursiv erstellen
//
// Title: createFacilityHierarchy
//
// Desc:
// Erstellt aus dem Hierarchieobjekt des Controllers
// eine verschachtelte HTML-Liste.
//
// Beispiel:
//
// Universität
//   Fachbereich
//     Institut
//
// Die Hierarchie wird vollständig rekursiv aufgebaut.
//
// Parameters:
// - hierarchy: Einrichtung mit untergeordneten Elementen
//
// Returns:
// - HTML-Liste oder null.
// ============================================================

function createFacilityHierarchy(hierarchy) {

  if (!hierarchy || typeof hierarchy !== "object") {
    return null;
  }

  const list = document.createElement("ul");

  list.className = "network-hierarchy-list";

  const item = document.createElement("li");

  item.className = "network-hierarchy-item";

  const facilityName = createTextElement(
    "span",
    hierarchy.name || "Unbekannte Einrichtung",
    "network-hierarchy-name"
  );

  item.appendChild(facilityName);

  // Untereinrichtungen rekursiv hinzufügen.
  const children = Array.isArray(hierarchy.children)
    ? hierarchy.children
    : [];

  if (children.length > 0) {

    const childrenList = document.createElement("ul");

    childrenList.className = "network-hierarchy-list";

    children.forEach(child => {

      const childHierarchy = createFacilityHierarchy(child);

      if (!childHierarchy) {
        return;
      }

      // Die Funktion liefert eine Liste zurück.
      // Ihre Listenelemente werden in die Liste
      // der Untereinrichtungen übernommen.
      while (childHierarchy.firstChild) {

        childrenList.appendChild(
          childHierarchy.firstChild
        );
      }
    });

    if (childrenList.children.length > 0) {

      item.appendChild(childrenList);
    }
  }

  list.appendChild(item);

  return list;
}


// ============================================================
// 6. Hierarchie einer Haupteinrichtung anzeigen
//
// Title: appendFacilityHierarchy
//
// Desc:
// Fügt den vollständigen Einrichtungsbaum
// in den rechten Informationsbereich ein.
//
// Parameters:
// - container: HTML-Element des Detailbereichs
// - hierarchy: Hierarchieobjekt des Controllers
//
// Returns:
// - Kein Rückgabewert.
// ============================================================

function appendFacilityHierarchy(
  container,
  hierarchy
) {

  container.appendChild(
    createTextElement(
      "h3",
      "Einrichtungshierarchie",
      "network-detail-subheading"
    )
  );

  if (!hierarchy) {

    container.appendChild(
      createTextElement(
        "p",
        "Für diese Einrichtung sind keine " +
          "Hierarchiedaten vorhanden."
      )
    );

    return;
  }

  const hierarchyList = createFacilityHierarchy(hierarchy);

  if (hierarchyList) {

    container.appendChild(hierarchyList);
  }
}


// ============================================================
// 7. Einen institutionellen Zugehörigkeitspfad erstellen
//
// Title: createFacilityPath
//
// Desc:
// Erstellt einen hierarchischen Pfad aus einer
// Haupteinrichtung und ihren Untereinrichtungen.
//
// Beispiel:
//
// Universität
//   Fachbereich
//     Institut
//
// Parameters:
// - path: Array mit Einrichtungen
//
// Returns:
// - Verschachtelte HTML-Liste oder null.
// ============================================================

function createFacilityPath(path) {

  if (!Array.isArray(path) || path.length === 0) {
    return null;
  }

  // Der erste Eintrag ist die Haupteinrichtung.
  const root = {
    id: path[0].id,
    name: path[0].name,
    children: []
  };

  let current = root;

  // Jede weitere Einrichtung wird als Kind
  // der vorherigen Einrichtung eingetragen.
  for (let index = 1; index < path.length; index += 1) {

    const facility = path[index];

    const child = {
      id: facility.id,
      name: facility.name,
      children: []
    };

    current.children.push(child);

    current = child;
  }

  return createFacilityHierarchy(root);
}


// ============================================================
// 8. Zugehörigkeiten einer Person anzeigen
//
// Title: appendPersonFacilityPaths
//
// Desc:
// Zeigt alle institutionellen Zugehörigkeiten
// einer Person im rechten Informationsbereich.
//
// Mehrere Rollen an unterschiedlichen Einrichtungen
// können mehrere Einrichtungspfade ergeben.
//
// Doppelte Pfade werden bereits im Controller entfernt.
//
// Parameters:
// - container: HTML-Element des Detailbereichs
// - paths: Array von Einrichtungspfaden
//
// Returns:
// - Kein Rückgabewert.
// ============================================================

function appendPersonFacilityPaths(
  container,
  paths
) {

  container.appendChild(
    createTextElement(
      "h3",
      "Institutionelle Zugehörigkeiten",
      "network-detail-subheading"
    )
  );

  if (!Array.isArray(paths) || paths.length === 0) {

    container.appendChild(
      createTextElement(
        "p",
        "Für diese Person sind keine " +
          "Einrichtungszugehörigkeiten vorhanden."
      )
    );

    return;
  }

  paths.forEach((path, index) => {

    if (!Array.isArray(path) || path.length === 0) {
      return;
    }

    // Bei mehreren Zugehörigkeiten wird jede
    // Zugehörigkeit separat gekennzeichnet.
    if (paths.length > 1) {

      container.appendChild(
        createTextElement(
          "h4",
          `Zugehörigkeit ${index + 1}`,
          "network-detail-path-heading"
        )
      );
    }

    const hierarchyList = createFacilityPath(path);

    if (hierarchyList) {

      container.appendChild(hierarchyList);
    }
  });
}


// ============================================================
// 9. Verbundene Netzwerkknoten anzeigen
//
// Title: appendConnectedNodes
//
// Desc:
// Zeigt die unmittelbar verbundenen Knoten.
//
// Bei Personen sind dies die Haupteinrichtungen.
// Bei Haupteinrichtungen sind dies die Forschenden.
//
// Parameters:
// - container: HTML-Element des Detailbereichs
// - connectedNodes: Array verbundener Knoten
// - selectedType: Typ des ausgewählten Knotens
//
// Returns:
// - Kein Rückgabewert.
// ============================================================

function appendConnectedNodes(
  container,
  connectedNodes,
  selectedType
) {

  const heading = selectedType === "person"
    ? "Verbundene Haupteinrichtungen"
    : "Zugeordnete Forschende";

  container.appendChild(
    createTextElement(
      "h3",
      heading,
      "network-detail-subheading"
    )
  );

  if (
    !Array.isArray(connectedNodes) ||
    connectedNodes.length === 0
  ) {

    container.appendChild(
      createTextElement(
        "p",
        "Keine direkten Verbindungen vorhanden."
      )
    );

    return;
  }

  const list = document.createElement("ul");

  list.className = "network-detail-list";

  connectedNodes.forEach(node => {

    const item = createTextElement(
      "li",
      node.name || "Unbekannter Knoten"
    );

    list.appendChild(item);
  });

  container.appendChild(list);
}


// ============================================================
// 10. Informationen zu einer Person anzeigen
//
// Title: appendPersonDetails
//
// Desc:
// Ergänzt den Informationsbereich um:
// - akademischen Titel
// - Forschungsgebiet
// - institutionelle Zugehörigkeiten
//
// Parameters:
// - container: HTML-Element des Detailbereichs
// - node: ausgewählter Personenknoten
//
// Returns:
// - Kein Rückgabewert.
// ============================================================

function appendPersonDetails(
  container,
  node
) {

  // Akademischen Titel anzeigen, falls vorhanden.
  if (node.title) {

    container.appendChild(
      createTextElement(
        "p",
        `Titel: ${node.title}`
      )
    );
  }

  // Forschungsgebiet anzeigen, falls vorhanden.
  if (node.field_of_research) {

    container.appendChild(
      createTextElement(
        "p",
        `Forschungsgebiet: ${node.field_of_research}`
      )
    );
  }

  // Vollständige Einrichtungspfade anzeigen.
  appendPersonFacilityPaths(
    container,
    node.facility_paths
  );
}


// ============================================================
// 11. Informationen zu einer Haupteinrichtung anzeigen
//
// Title: appendFacilityDetails
//
// Desc:
// Zeigt die vollständige Hierarchie einer
// Haupteinrichtung.
//
// Parameters:
// - container: HTML-Element des Detailbereichs
// - node: ausgewählter Einrichtungsknoten
//
// Returns:
// - Kein Rückgabewert.
// ============================================================

function appendFacilityDetails(
  container,
  node
) {

  appendFacilityHierarchy(
    container,
    node.hierarchy
  );
}


// ============================================================
// 12. Detailinformationen zu einem Knoten anzeigen
//
// Title: showNodeDetails
//
// Desc:
// Wird von Network.js aufgerufen, wenn eine Person
// oder Haupteinrichtung angeklickt wird.
//
// Die Funktion unterscheidet die Knotentypen
// und erstellt die passenden Informationen.
//
// Parameters:
// - node: ausgewählter Netzwerkknoten
// - connectedNodes: direkt verbundene Knoten
//
// Returns:
// - Kein Rückgabewert.
// ============================================================

function showNodeDetails(
  node,
  connectedNodes = []
) {

  const container = document.getElementById(
    "network-details-content"
  );

  if (!container || !node) {
    return;
  }

  clearDetails(container);

  // Name des ausgewählten Knotens.
  container.appendChild(
    createTextElement(
      "h3",
      node.name || "Unbekannter Knoten",
      "network-detail-title"
    )
  );

  // Knotentyp als Kennzeichnung.
  const typeLabel = node.type === "facility"
    ? "Haupteinrichtung"
    : "Forschende Person";

  container.appendChild(
    createTextElement(
      "p",
      typeLabel,
      "network-detail-type"
    )
  );

  // Personenbezogene Informationen.
  if (node.type === "person") {

    appendPersonDetails(container, node);
  }

  // Einrichtungshierarchie.
  if (node.type === "facility") {

    appendFacilityDetails(container, node);
  }

  // Direkt verbundene Netzwerkknoten.
  appendConnectedNodes(
    container,
    connectedNodes,
    node.type
  );
}


// ============================================================
// 13. Einrichtungsfilter initialisieren
//
// Title: initializeFacilitySearch
//
// Desc:
// Verbindet das sichtbare Suchfeld mit der
// versteckten Einrichtungs-ID.
//
// Die HTML-Datalist zeigt Einrichtungsnamen an.
// Der Controller benötigt dagegen eine ID.
//
// Beispiel:
// Sichtbarer Wert: "Institut für Informatik"
// Versteckter Wert: "42"
//
// Parameters:
// - Keine.
//
// Returns:
// - Kein Rückgabewert.
// ============================================================

function initializeFacilitySearch() {

  const searchInput = document.getElementById(
    "network-facility-search"
  );

  const hiddenInput = document.getElementById(
    "network-facility-id"
  );

  const datalist = document.getElementById(
    "network-facility-options"
  );

  if (!searchInput || !hiddenInput || !datalist) {
    return;
  }

  // Das Formular wird über das Suchfeld ermittelt.
  const form = searchInput.closest("form");

  // Bereits registrierte Ereignisse vermeiden.
  if (searchInput.dataset.facilitySearchInitialized === "true") {
    return;
  }

  searchInput.dataset.facilitySearchInitialized = "true";

  // Alle Optionen der Vorschlagsliste ermitteln.
  const options = Array.from(
    datalist.querySelectorAll("option")
  );

  // Einrichtungsname -> Einrichtungs-ID.
  //
  // Bei gleichen Namen in unterschiedlichen
  // Einrichtungen ist eine eindeutige Zuordnung
  // über den Namen allein nicht möglich.
  // Deshalb wird bei Mehrdeutigkeit keine ID gesetzt.
  function findMatchingFacilityId(value) {

    const normalizedValue = value.trim().toLocaleLowerCase("de");

    if (!normalizedValue) {
      return "";
    }

    const matches = options.filter(option => {

      return option.value
        .trim()
        .toLocaleLowerCase("de") === normalizedValue;
    });

    if (matches.length !== 1) {
      return "";
    }

    return matches[0].dataset.facilityId || "";
  }


  // ----------------------------------------------------------
  // 13.1 Eingabeänderungen verarbeiten
  //
  // Bei jeder Änderung wird geprüft, ob der
  // eingegebene Name einer Datalist-Option entspricht.
  // ----------------------------------------------------------

  function synchronizeFacilityId() {

    hiddenInput.value = findMatchingFacilityId(
      searchInput.value
    );
  }

  searchInput.addEventListener(
    "input",
    synchronizeFacilityId
  );

  searchInput.addEventListener(
    "change",
    synchronizeFacilityId
  );


  // ----------------------------------------------------------
  // 13.2 Formular vor dem Absenden überprüfen
  //
  // Ein frei eingegebener Text darf nicht versehentlich
  // mit einer zuvor ausgewählten Einrichtungs-ID
  // abgeschickt werden.
  // ----------------------------------------------------------

  if (form) {

    form.addEventListener("submit", () => {

      synchronizeFacilityId();
    });
  }
}


// ============================================================
// 14. Netzwerkdaten aus dem HTML einlesen
//
// Title: readNetworkData
//
// Desc:
// Liest die JSON-Daten aus dem Attribut:
//
// data-network-data
//
// Das Attribut wird in network.html.erb durch
// den Rails-Controller befüllt.
//
// Parameters:
// - container: HTML-Element des Netzwerks
//
// Returns:
// - Objekt mit nodes und links.
// ============================================================

function readNetworkData(container) {

  const emptyData = {
    nodes: [],
    links: []
  };

  if (!container) {
    return emptyData;
  }

  const json = container.dataset.networkData;

  if (!json) {
    return emptyData;
  }

  try {

    const parsedData = JSON.parse(json);

    return {
      nodes: Array.isArray(parsedData.nodes)
        ? parsedData.nodes
        : [],

      links: Array.isArray(parsedData.links)
        ? parsedData.links
        : []
    };

  } catch (error) {

    console.error(
      "Forschungsnetzwerk: Netzwerkdaten konnten " +
        "nicht eingelesen werden.",
      error
    );

    return emptyData;
  }
}


// ============================================================
// 15. Netzwerk initialisieren
//
// Title: initializeNetwork
//
// Desc:
// Erstellt die D3-Netzwerkvisualisierung und
// verbindet sie mit dem Informationsbereich.
//
// Parameters:
// - Keine.
//
// Returns:
// - Kein Rückgabewert.
// ============================================================

function initializeNetwork() {

  const container = document.getElementById(
    "network-visualization"
  );

  if (!container) {
    return;
  }

  // Eine vorhandene Netzwerk-Instanz entfernen.
  if (currentNetwork) {

    currentNetwork.destroy();

    currentNetwork = null;
  }

  // Netzwerkdaten aus dem HTML lesen.
  const networkData = readNetworkData(container);

  // Neue Visualisierung erstellen.
  currentNetwork = new Network(
    container,
    networkData,
    showNodeDetails
  );

  // Detailbereich in den Ausgangszustand versetzen.
  const detailsContainer = document.getElementById(
    "network-details-content"
  );

  showDetailsPlaceholder(detailsContainer);
}


// ============================================================
// 16. Netzwerkseite initialisieren
//
// Title: initializePage
//
// Desc:
// Prüft, ob die aktuelle Seite die Netzwerkseite ist.
//
// Nur auf dieser Seite werden Filter und
// Visualisierung initialisiert.
//
// Parameters:
// - Keine.
//
// Returns:
// - Kein Rückgabewert.
// ============================================================

function initializePage() {

  const networkPage = document.querySelector(
    ".network-page"
  );

  if (!networkPage) {
    return;
  }

  initializeFacilitySearch();

  initializeNetwork();
}


// ============================================================
// 17. Netzwerk bereinigen
//
// Title: cleanupNetwork
//
// Desc:
// Beendet die laufende D3-Simulation,
// bevor Rails Turbo die Seite zwischenspeichert
// oder die Netzwerkseite verlassen wird.
//
// Parameters:
// - Keine.
//
// Returns:
// - Kein Rückgabewert.
// ============================================================

function cleanupNetwork() {

  if (!currentNetwork) {
    return;
  }

  currentNetwork.destroy();

  currentNetwork = null;
}


// ============================================================
// 18. Rails-Turbo-Ereignisse
//
// Desc:
// Rails Turbo lädt Seiten häufig ohne vollständigen
// Browser-Neustart.
//
// Deshalb wird die Netzwerkseite bei turbo:load
// initialisiert und vor dem Zwischenspeichern
// wieder bereinigt.
// ============================================================

document.addEventListener(
  "turbo:load",
  initializePage
);

document.addEventListener(
  "turbo:before-cache",
  cleanupNetwork
);


// ============================================================
// 19. Initialisierung ohne Turbo
//
// Desc:
// Falls die Seite ohne Turbo geladen wird,
// übernimmt DOMContentLoaded die Initialisierung.
//
// Die Prüfung auf document.readyState stellt sicher,
// dass das Skript auch bei späterem Import funktioniert.
// ============================================================

if (document.readyState === "loading") {

  document.addEventListener(
    "DOMContentLoaded",
    initializePage,
    { once: true }
  );

} else {

  initializePage();
}


// ============================================================
// Ende: app/javascript/network/main.js
// ============================================================
