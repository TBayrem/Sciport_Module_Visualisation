
/* ============================================================
   Datei: app/javascript/network/Network.js

   Desc:
   Implementiert die interaktive Forschungsnetzwerk-
   visualisierung mit D3.js.

   Im Netzwerk werden ausschließlich folgende
   Knotentypen dargestellt:

   - Personen
   - Haupteinrichtungen

   Untereinrichtungen erscheinen nicht als eigene
   Netzwerkknoten. Stattdessen werden sie in
   hierarchischer Form in den Tooltips und im
   Informationsbereich dargestellt.

   Funktionen:
   - D3-Force-Simulation
   - Zoom und Verschieben
   - Drag-and-Drop einzelner Knoten
   - Auswahl von Knoten
   - Hervorhebung von Verbindungen
   - Tooltips mit Einrichtungshierarchien
   - Übergabe von Knotendaten an main.js
   - Responsive Größenanpassung
   - Bereinigung aller Ereignisbehandlungen
   ============================================================ */

import * as d3 from "d3";


export default class Network {

  /* ----------------------------------------------------------
     1. Konstruktor

     Parameters:
     - container: HTML-Element für die Visualisierung
     - data: Netzwerkdaten aus dem Rails-Controller
     - onNodeSelect: Callback für die Detailansicht

     Die Netzwerkdaten enthalten:
     {
       nodes: [...],
       links: [...]
     }
     ---------------------------------------------------------- */

  constructor(container, data, onNodeSelect = null) {

    this.container = container;

    this.onNodeSelect =
      typeof onNodeSelect === "function"
        ? onNodeSelect
        : null;

    // Kopien der Daten verwenden, da D3 die
    // Knoten und Verbindungen intern verändert.
    this.nodes = Array.isArray(data?.nodes)
      ? data.nodes.map(node => ({ ...node }))
      : [];

    this.links = Array.isArray(data?.links)
      ? data.links.map(link => ({ ...link }))
      : [];

    // Schneller Zugriff auf Knoten anhand ihrer ID.
    this.nodeById = new Map(
      this.nodes.map(node => [String(node.id), node])
    );

    // Aktuell ausgewählter Knoten.
    this.selectedNode = null;

    // Kennzeichnet eine bereits entfernte Instanz.
    this.destroyed = false;

    // Darstellungsparameter.
    this.personRadius = 8;
    this.facilityRadius = 17;

    // Farben der Knotentypen.
    this.personColor = "#2563eb";
    this.facilityColor = "#e58b32";

    // Standardwerte für die Größe.
    this.width = 800;
    this.height = 650;

    // D3-Objekte werden beim Initialisieren erzeugt.
    this.svg = null;
    this.graphGroup = null;
    this.linkSelection = null;
    this.nodeSelection = null;
    this.simulation = null;
    this.zoomBehavior = null;
    this.tooltip = null;

    // Größenänderungen des Containers beobachten.
    this.resizeObserver = null;

    // Netzwerk aufbauen.
    this.initialize();
  }


  /* ----------------------------------------------------------
     2. Netzwerk initialisieren

     Desc:
     Erstellt das SVG-Element, die D3-Simulation,
     die Verbindungen und die Netzwerkknoten.

     Returns:
     - Kein Rückgabewert.
     ---------------------------------------------------------- */

  initialize() {

    if (!this.container) {
      console.error(
        "Network: Der Visualisierungscontainer fehlt."
      );

      return;
    }

    // Vorhandene SVG-Grafiken aus diesem Container
    // entfernen, um doppelte Netzwerke zu vermeiden.
    d3.select(this.container)
      .selectAll("svg.network-svg")
      .remove();

    // Eventuell vorhandenen Tooltip entfernen.
    d3.select(this.container)
      .selectAll(".network-tooltip")
      .remove();

    this.updateDimensions();

    this.createSvg();

    this.createTooltip();

    // Leere Netzwerke erhalten eine Hinweismeldung.
    if (this.nodes.length === 0) {
      this.showEmptyMessage();
      this.observeResize();
      return;
    }

    this.createSimulation();

    this.createLinks();

    this.createNodes();

    this.configureSimulation();

    this.observeResize();
  }


  /* ----------------------------------------------------------
     3. Abmessungen des Containers bestimmen

     Desc:
     Ermittelt die aktuelle Größe der Netzwerkfläche.

     Returns:
     - Kein Rückgabewert.
     ---------------------------------------------------------- */

  updateDimensions() {

    const bounds = this.container.getBoundingClientRect();

    this.width = Math.max(
      bounds.width || this.container.clientWidth || 800,
      320
    );

    this.height = Math.max(
      bounds.height || this.container.clientHeight || 650,
      300
    );
  }


  /* ----------------------------------------------------------
     4. SVG-Grafik erstellen

     Desc:
     Erstellt die SVG-Zeichenfläche und aktiviert
     Zoom sowie Verschieben des gesamten Netzwerks.

     Returns:
     - Kein Rückgabewert.
     ---------------------------------------------------------- */

  createSvg() {

    this.svg = d3.select(this.container)
      .append("svg")
      .attr("class", "network-svg")
      .attr("width", "100%")
      .attr("height", "100%")
      .attr(
        "viewBox",
        `0 0 ${this.width} ${this.height}`
      )
      .attr(
        "aria-label",
        "Interaktives Forschungsnetzwerk"
      );

    // Diese Gruppe enthält sämtliche Elemente,
    // die gemeinsam gezoomt und verschoben werden.
    this.graphGroup = this.svg
      .append("g")
      .attr("class", "network-graph-group");

    // Die Verbindungen werden unter den Knoten
    // gezeichnet, damit sie diese nicht verdecken.
    this.linkGroup = this.graphGroup
      .append("g")
      .attr("class", "network-links");

    this.nodeGroup = this.graphGroup
      .append("g")
      .attr("class", "network-nodes");

    // Zoomverhalten definieren.
    this.zoomBehavior = d3.zoom()
      .scaleExtent([0.2, 5])
      .on("zoom", event => {

        this.graphGroup.attr(
          "transform",
          event.transform
        );
      });

    // Zoom auf der SVG-Fläche aktivieren.
    this.svg.call(this.zoomBehavior);

    // Doppelklick soll nicht automatisch zoomen.
    // So bleibt die Interaktion mit Knoten einfacher.
    this.svg.on("dblclick.zoom", null);

    // Klick auf die freie Fläche hebt
    // eine bestehende Knotenauswahl auf.
    this.svg.on("click.network", event => {

      if (event.target === this.svg.node()) {
        this.clearSelection();
      }
    });
  }


  /* ----------------------------------------------------------
     5. Tooltip erstellen

     Desc:
     Erstellt ein HTML-Element für Informationen,
     die beim Überfahren eines Knotens erscheinen.

     Der Tooltip wird innerhalb des
     Netzwerkcontainers positioniert.

     Returns:
     - Kein Rückgabewert.
     ---------------------------------------------------------- */

  createTooltip() {

    this.tooltip = d3.select(this.container)
      .append("div")
      .attr("class", "network-tooltip")
      .attr("role", "tooltip")
      .style("position", "absolute")
      .style("display", "none")
      .style("pointer-events", "none")
      .style("z-index", "20")
      .style("max-width", "340px")
      .style("max-height", "320px")
      .style("overflow-y", "auto")
      .style("padding", "12px 14px")
      .style("border", "1px solid #cbd5e1")
      .style("border-radius", "9px")
      .style("background", "#ffffff")
      .style("box-shadow", "0 8px 24px rgba(15, 23, 42, 0.15)")
      .style("color", "#1e293b")
      .style("font-size", "13px")
      .style("line-height", "1.5");
  }


  /* ----------------------------------------------------------
     6. D3-Force-Simulation erstellen

     Desc:
     Positioniert Personen und Einrichtungen
     mithilfe physikalischer Kräfte.

     Die Verbindungen ziehen zugehörige Personen
     und Haupteinrichtungen zueinander.

     Returns:
     - Kein Rückgabewert.
     ---------------------------------------------------------- */

  createSimulation() {

    this.simulation = d3.forceSimulation(this.nodes)

      // Verbundene Knoten werden zusammengehalten.
      .force(
        "link",
        d3.forceLink(this.links)
          .id(node => node.id)
          .distance(link => {

            // Etwas größere Distanz zu Einrichtungen.
            return 115;
          })
          .strength(0.55)
      )

      // Knoten stoßen sich gegenseitig ab.
      .force(
        "charge",
        d3.forceManyBody()
          .strength(node => {

            return node.type === "facility"
              ? -650
              : -160;
          })
      )

      // Das Netzwerk bleibt ungefähr zentriert.
      .force(
        "center",
        d3.forceCenter(
          this.width / 2,
          this.height / 2
        )
      )

      // Kollisionen zwischen Knoten reduzieren.
      .force(
        "collision",
        d3.forceCollide()
          .radius(node => {

            return this.getNodeRadius(node) + 7;
          })
          .strength(0.8)
      );
  }


  /* ----------------------------------------------------------
     7. Verbindungen zeichnen

     Desc:
     Erstellt die Linien zwischen Personen
     und ihren Haupteinrichtungen.

     Returns:
     - Kein Rückgabewert.
     ---------------------------------------------------------- */

  createLinks() {

    this.linkSelection = this.linkGroup
      .selectAll("line")
      .data(this.links)
      .join("line")
      .attr("class", "network-link")
      .attr("stroke", "#aebdca")
      .attr("stroke-width", 1.5)
      .attr("stroke-opacity", 0.8);
  }


  /* ----------------------------------------------------------
     8. Netzwerkknoten zeichnen

     Desc:
     Erstellt SVG-Kreise für Personen
     und Haupteinrichtungen.

     Die Knoten reagieren auf:
     - Mausbewegung
     - Klick
     - Drag-and-Drop

     Returns:
     - Kein Rückgabewert.
     ---------------------------------------------------------- */

  createNodes() {

    this.nodeSelection = this.nodeGroup
      .selectAll("circle")
      .data(
        this.nodes,
        node => node.id
      )
      .join("circle")

      // Gemeinsame CSS-Klasse und Typklasse.
      .attr("class", node => {

        return node.type === "facility"
          ? "network-node network-node-facility"
          : "network-node network-node-person";
      })

      .attr("r", node => this.getNodeRadius(node))

      .attr("fill", node => this.getNodeColor(node))

      .attr("stroke", "#ffffff")

      .attr("stroke-width", 1.5)

      .attr("tabindex", 0)

      .attr("role", "button")

      .attr("aria-label", node => {

        const type = node.type === "facility"
          ? "Haupteinrichtung"
          : "Forschende Person";

        return `${type}: ${node.name}`;
      })

      .style("cursor", "pointer")

      // Tooltip beim Berühren anzeigen.
      .on("mouseenter", (event, node) => {

        this.showTooltip(event, node);
      })

      // Tooltipposition bei Mausbewegung aktualisieren.
      .on("mousemove", event => {

        this.moveTooltip(event);
      })

      // Tooltip beim Verlassen ausblenden.
      .on("mouseleave", () => {

        this.hideTooltip();
      })

      // Klick wählt einen Knoten aus.
      .on("click", (event, node) => {

        event.stopPropagation();

        this.selectNode(node);
      })

      // Tastaturbedienung ermöglichen.
      .on("keydown", (event, node) => {

        if (event.key === "Enter" ||
            event.key === " ") {

          event.preventDefault();

          this.selectNode(node);
        }
      })

      // Knoten mit der Maus verschieben.
      .call(this.createDragBehavior());
  }


  /* ----------------------------------------------------------
     9. D3-Simulation mit der Darstellung verbinden

     Desc:
     Aktualisiert bei jedem Simulationsschritt
     die Positionen der Knoten und Verbindungen.

     Returns:
     - Kein Rückgabewert.
     ---------------------------------------------------------- */

  configureSimulation() {

    this.simulation.on("tick", () => {

      // Verbindungen an den aktuellen
      // Positionen ihrer Endpunkte ausrichten.
      this.linkSelection
        .attr("x1", link => link.source.x)
        .attr("y1", link => link.source.y)
        .attr("x2", link => link.target.x)
        .attr("y2", link => link.target.y);

      // Kreise an den berechneten
      // Positionen platzieren.
      this.nodeSelection
        .attr("cx", node => node.x)
        .attr("cy", node => node.y);
    });
  }


  /* ----------------------------------------------------------
     10. Drag-and-Drop-Verhalten

     Desc:
     Einzelne Knoten können frei verschoben werden.

     Während des Ziehens wird die Simulation
     erneut aktiviert.

     Returns:
     - Konfiguriertes D3-Drag-Verhalten.
     ---------------------------------------------------------- */

  createDragBehavior() {

    return d3.drag()

      .on("start", (event, node) => {

        // Verhindert eine gleichzeitige
        // Verschiebung der gesamten SVG-Fläche.
        event.sourceEvent?.stopPropagation();

        if (!event.active && this.simulation) {

          this.simulation
            .alphaTarget(0.3)
            .restart();
        }

        // Aktuelle Position fixieren.
        node.fx = node.x;
        node.fy = node.y;

        this.hideTooltip();
      })

      .on("drag", (event, node) => {

        node.fx = event.x;
        node.fy = event.y;
      })

      .on("end", (event, node) => {

        if (!event.active && this.simulation) {

          this.simulation.alphaTarget(0);
        }

        // Fixierung wieder aufheben,
        // damit die Simulation weiterarbeiten kann.
        node.fx = null;
        node.fy = null;
      });
  }


  /* ----------------------------------------------------------
     11. Knotengröße bestimmen

     Desc:
     Haupteinrichtungen werden größer dargestellt
     als Personen.

     Parameters:
     - node: Netzwerkknoten

     Returns:
     - Radius in Pixeln.
     ---------------------------------------------------------- */

  getNodeRadius(node) {

    return node.type === "facility"
      ? this.facilityRadius
      : this.personRadius;
  }


  /* ----------------------------------------------------------
     12. Knotenfarbe bestimmen

     Desc:
     Unterscheidet Forschende und Haupteinrichtungen.

     Parameters:
     - node: Netzwerkknoten

     Returns:
     - CSS-Farbwert.
     ---------------------------------------------------------- */

  getNodeColor(node) {

    return node.type === "facility"
      ? this.facilityColor
      : this.personColor;
  }


  /* ----------------------------------------------------------
     13. Tooltip anzeigen

     Desc:
     Zeigt beim Hover die Informationen des Knotens.

     Personen:
     - Name
     - Titel
     - Einrichtungspfade

     Haupteinrichtungen:
     - Name
     - Vollständige Einrichtungshierarchie

     Parameters:
     - event: Mausereignis
     - node: betroffener Netzwerkknoten

     Returns:
     - Kein Rückgabewert.
     ---------------------------------------------------------- */

  showTooltip(event, node) {

    if (!this.tooltip) {
      return;
    }

    // Vorherige Tooltipinhalte entfernen.
    this.tooltip.html("");

    // Überschrift sicher als Text einsetzen.
    this.tooltip
      .append("div")
      .style("font-weight", "700")
      .style("font-size", "14px")
      .style("margin-bottom", "6px")
      .text(node.name || "Unbekannter Knoten");

    if (node.type === "person") {

      this.tooltip
        .append("div")
        .style("color", "#64748b")
        .style("margin-bottom", "8px")
        .text("Forschende Person");

      if (node.title) {

        this.tooltip
          .append("div")
          .style("margin-bottom", "6px")
          .text(node.title);
      }

      // Alle tatsächlichen Zugehörigkeitspfade
      // der Person anzeigen.
      this.renderPersonPaths(
        this.tooltip,
        node.facility_paths
      );

    } else if (node.type === "facility") {

      this.tooltip
        .append("div")
        .style("color", "#64748b")
        .style("margin-bottom", "8px")
        .text("Haupteinrichtung");

      // Die gesamte Untereinrichtungshierarchie
      // anzeigen.
      this.renderFacilityHierarchy(
        this.tooltip,
        node.hierarchy
      );
    }

    this.tooltip.style("display", "block");

    this.moveTooltip(event);
  }


  /* ----------------------------------------------------------
     14. Einrichtungspfade einer Person darstellen

     Desc:
     Zeigt für jede Rolle den vollständigen
     organisatorischen Pfad.

     Beispiel:
     Universität
       Fachbereich
         Institut

     Mehrere Zugehörigkeiten werden getrennt angezeigt.

     Parameters:
     - container: D3-Auswahl
     - paths: Array von Einrichtungspfaden

     Returns:
     - Kein Rückgabewert.
     ---------------------------------------------------------- */

  renderPersonPaths(container, paths) {

    if (!Array.isArray(paths) || paths.length === 0) {

      container
        .append("div")
        .text("Keine Einrichtung zugeordnet.");

      return;
    }

    container
      .append("div")
      .style("font-weight", "600")
      .style("margin", "8px 0 5px")
      .text("Institutionelle Zugehörigkeiten");

    paths.forEach((path, index) => {

      if (!Array.isArray(path) || path.length === 0) {
        return;
      }

      const pathContainer = container
        .append("div")
        .style("margin", "7px 0")
        .style("padding", "7px 9px")
        .style("background", "#f8fafc")
        .style("border-radius", "5px");

      if (paths.length > 1) {

        pathContainer
          .append("div")
          .style("font-weight", "600")
          .style("margin-bottom", "4px")
          .text(`Zugehörigkeit ${index + 1}`);
      }

      path.forEach((facility, depth) => {

        pathContainer
          .append("div")
          .style("margin-left", `${depth * 12}px`)
          .style("padding", "2px 0")
          .text(
            `${depth > 0 ? "↳ " : ""}${facility.name}`
          );
      });
    });
  }


  /* ----------------------------------------------------------
     15. Einrichtungshierarchie darstellen

     Desc:
     Stellt eine Haupteinrichtung und sämtliche
     Untereinrichtungen rekursiv dar.

     Parameters:
     - container: D3-Auswahl
     - hierarchy: Hierarchieobjekt
     - depth: aktuelle Hierarchieebene

     Returns:
     - Kein Rückgabewert.
     ---------------------------------------------------------- */

  renderFacilityHierarchy(
    container,
    hierarchy,
    depth = 0
  ) {

    if (!hierarchy) {

      if (depth === 0) {

        container
          .append("div")
          .text("Keine Hierarchiedaten vorhanden.");
      }

      return;
    }

    // Die Hierarchieebene bestimmt die Einrückung.
    container
      .append("div")
      .style("margin-left", `${depth * 12}px`)
      .style("padding", "3px 0")
      .style(
        "font-weight",
        depth === 0 ? "600" : "400"
      )
      .text(
        `${depth > 0 ? "↳ " : ""}${hierarchy.name}`
      );

    const children = Array.isArray(hierarchy.children)
      ? hierarchy.children
      : [];

    // Untereinrichtungen rekursiv ausgeben.
    children.forEach(child => {

      this.renderFacilityHierarchy(
        container,
        child,
        depth + 1
      );
    });
  }


  /* ----------------------------------------------------------
     16. Tooltip positionieren

     Desc:
     Positioniert den Tooltip in der Nähe
     des Mauszeigers.

     Dabei wird verhindert, dass der Tooltip
     über die Containergrenzen hinausragt.

     Parameters:
     - event: Mausereignis

     Returns:
     - Kein Rückgabewert.
     ---------------------------------------------------------- */

  moveTooltip(event) {

    if (!this.tooltip ||
        this.tooltip.style("display") === "none") {

      return;
    }

    const containerBounds =
      this.container.getBoundingClientRect();

    const tooltipElement = this.tooltip.node();

    if (!tooltipElement) {
      return;
    }

    const tooltipWidth = tooltipElement.offsetWidth;
    const tooltipHeight = tooltipElement.offsetHeight;

    // Mausposition relativ zum Container.
    const mouseX = event.clientX - containerBounds.left;
    const mouseY = event.clientY - containerBounds.top;

    // Abstand zum Mauszeiger.
    const offset = 14;

    let left = mouseX + offset;
    let top = mouseY + offset;

    // Tooltip bei Bedarf nach links verschieben.
    if (left + tooltipWidth > containerBounds.width) {

      left = mouseX - tooltipWidth - offset;
    }

    // Tooltip bei Bedarf nach oben verschieben.
    if (top + tooltipHeight > containerBounds.height) {

      top = mouseY - tooltipHeight - offset;
    }

    // Negative Positionen vermeiden.
    left = Math.max(4, left);
    top = Math.max(4, top);

    this.tooltip
      .style("left", `${left}px`)
      .style("top", `${top}px`);
  }


  /* ----------------------------------------------------------
     17. Tooltip ausblenden

     Desc:
     Entfernt den Tooltip aus der sichtbaren
     Darstellung.

     Returns:
     - Kein Rückgabewert.
     ---------------------------------------------------------- */

  hideTooltip() {

    if (this.tooltip) {

      this.tooltip.style("display", "none");
    }
  }


  /* ----------------------------------------------------------
     18. Knoten auswählen

     Desc:
     Markiert einen Knoten und hebt seine
     direkten Verbindungen hervor.

     Anschließend werden die Knotendaten
     an main.js übergeben.

     Parameters:
     - node: ausgewählter Netzwerkknoten

     Returns:
     - Kein Rückgabewert.
     ---------------------------------------------------------- */

  selectNode(node) {

    if (!node) {
      return;
    }

    this.selectedNode = node;

    this.hideTooltip();

    this.highlightSelection(node);

    // Die verbundenen Knoten ermitteln.
    const connectedNodes =
      this.getConnectedNodes(node);

    // Detailansicht aktualisieren.
    if (this.onNodeSelect) {

      this.onNodeSelect(
        node,
        connectedNodes
      );
    }
  }


  /* ----------------------------------------------------------
     19. Verbundene Knoten ermitteln

     Desc:
     Sucht alle Knoten, die über eine direkte
     Verbindung mit dem ausgewählten Knoten
     verbunden sind.

     Parameters:
     - node: ausgewählter Netzwerkknoten

     Returns:
     - Array verbundener Knoten.
     ---------------------------------------------------------- */

  getConnectedNodes(node) {

    const connectedIds = new Set();

    this.links.forEach(link => {

      // Nach Initialisierung der Simulation
      // enthalten source und target Knotenobjekte.
      const sourceId =
        typeof link.source === "object"
          ? link.source.id
          : link.source;

      const targetId =
        typeof link.target === "object"
          ? link.target.id
          : link.target;

      if (sourceId === node.id) {

        connectedIds.add(String(targetId));
      }

      if (targetId === node.id) {

        connectedIds.add(String(sourceId));
      }
    });

    return Array.from(connectedIds)
      .map(id => this.nodeById.get(id))
      .filter(Boolean)
      .sort((first, second) => {

        return String(first.name).localeCompare(
          String(second.name),
          "de"
        );
      });
  }


  /* ----------------------------------------------------------
     20. Knotenauswahl hervorheben

     Desc:
     Der ausgewählte Knoten und seine direkten
     Nachbarn bleiben vollständig sichtbar.

     Nicht verbundene Knoten und Kanten werden
     abgeschwächt.

     Parameters:
     - node: ausgewählter Knoten

     Returns:
     - Kein Rückgabewert.
     ---------------------------------------------------------- */

  highlightSelection(node) {

    const connectedIds = new Set(
      this.getConnectedNodes(node)
        .map(item => String(item.id))
    );

    connectedIds.add(String(node.id));

    this.nodeSelection
      .attr("opacity", item => {

        return connectedIds.has(String(item.id))
          ? 1
          : 0.18;
      })
      .attr("stroke", item => {

        return item.id === node.id
          ? "#0f172a"
          : "#ffffff";
      })
      .attr("stroke-width", item => {

        return item.id === node.id
          ? 3
          : 1.5;
      });

    this.linkSelection
      .attr("stroke-opacity", link => {

        const sourceId =
          typeof link.source === "object"
            ? link.source.id
            : link.source;

        const targetId =
          typeof link.target === "object"
            ? link.target.id
            : link.target;

        return sourceId === node.id ||
               targetId === node.id
          ? 1
          : 0.08;
      })
      .attr("stroke-width", link => {

        const sourceId =
          typeof link.source === "object"
            ? link.source.id
            : link.source;

        const targetId =
          typeof link.target === "object"
            ? link.target.id
            : link.target;

        return sourceId === node.id ||
               targetId === node.id
          ? 2.5
          : 1.5;
      });
  }


  /* ----------------------------------------------------------
     21. Auswahl zurücksetzen

     Desc:
     Entfernt die Hervorhebung und zeigt wieder
     alle Knoten und Verbindungen normal an.

     Returns:
     - Kein Rückgabewert.
     ---------------------------------------------------------- */

  clearSelection() {

    this.selectedNode = null;

    if (this.nodeSelection) {

      this.nodeSelection
        .attr("opacity", 1)
        .attr("stroke", "#ffffff")
        .attr("stroke-width", 1.5);
    }

    if (this.linkSelection) {

      this.linkSelection
        .attr("stroke-opacity", 0.8)
        .attr("stroke-width", 1.5);
    }

    // Der Informationsbereich wird bewusst
    // nicht geleert. Die zuletzt ausgewählten
    // Informationen bleiben dort lesbar.
  }


  /* ----------------------------------------------------------
     22. Leeres Netzwerk anzeigen

     Desc:
     Informiert darüber, dass keine passenden
     Netzwerkdaten vorhanden sind.

     Returns:
     - Kein Rückgabewert.
     ---------------------------------------------------------- */

  showEmptyMessage() {

    this.svg
      .append("text")
      .attr("class", "network-empty-message")
      .attr("x", this.width / 2)
      .attr("y", this.height / 2)
      .attr("text-anchor", "middle")
      .text(
        "Keine passenden Netzwerkdaten vorhanden."
      );
  }


  /* ----------------------------------------------------------
     23. Größenänderungen beobachten

     Desc:
     Reagiert auf Änderungen der Containergröße,
     beispielsweise beim Wechsel zwischen
     Desktop- und Tabletansicht.

     Returns:
     - Kein Rückgabewert.
     ---------------------------------------------------------- */

  observeResize() {

    if (typeof ResizeObserver === "undefined") {
      return;
    }

    this.resizeObserver = new ResizeObserver(() => {

      if (this.destroyed) {
        return;
      }

      this.resize();
    });

    this.resizeObserver.observe(this.container);
  }


  /* ----------------------------------------------------------
     24. Netzwerkgröße aktualisieren

     Desc:
     Passt die SVG-Zeichenfläche und den
     Mittelpunkt der Simulation an.

     Returns:
     - Kein Rückgabewert.
     ---------------------------------------------------------- */

  resize() {

    if (!this.container || !this.svg) {
      return;
    }

    const previousWidth = this.width;
    const previousHeight = this.height;

    this.updateDimensions();

    // Keine unnötigen Aktualisierungen ausführen.
    if (
      previousWidth === this.width &&
      previousHeight === this.height
    ) {
      return;
    }

    this.svg.attr(
      "viewBox",
      `0 0 ${this.width} ${this.height}`
    );

    if (this.simulation) {

      this.simulation.force(
        "center",
        d3.forceCenter(
          this.width / 2,
          this.height / 2
        )
      );

      this.simulation
        .alpha(0.3)
        .restart();
    }

    // Die Leermeldung ebenfalls neu zentrieren.
    this.svg
      .select(".network-empty-message")
      .attr("x", this.width / 2)
      .attr("y", this.height / 2);
  }


  /* ----------------------------------------------------------
     25. Zoom zurücksetzen

     Desc:
     Setzt die Darstellung auf die ursprüngliche
     Zoomstufe und Position zurück.

     Kann später mit einem HTML-Button
     verbunden werden.

     Returns:
     - Kein Rückgabewert.
     ---------------------------------------------------------- */

  resetZoom() {

    if (!this.svg || !this.zoomBehavior) {
      return;
    }

    this.svg
      .transition()
      .duration(350)
      .call(
        this.zoomBehavior.transform,
        d3.zoomIdentity
      );
  }


  /* ----------------------------------------------------------
     26. Netzwerk vollständig bereinigen

     Desc:
     Stoppt die Simulation und entfernt
     Beobachter, Ereignisse und HTML-Elemente.

     Besonders wichtig bei Rails Turbo,
     damit nicht mehrere Netzwerke gleichzeitig
     initialisiert werden.

     Returns:
     - Kein Rückgabewert.
     ---------------------------------------------------------- */

  destroy() {

    if (this.destroyed) {
      return;
    }

    this.destroyed = true;

    // Laufende Simulation beenden.
    if (this.simulation) {

      this.simulation.stop();

      this.simulation = null;
    }

    // ResizeObserver entfernen.
    if (this.resizeObserver) {

      this.resizeObserver.disconnect();

      this.resizeObserver = null;
    }

    // Tooltips entfernen.
    if (this.tooltip) {

      this.tooltip.remove();

      this.tooltip = null;
    }

    // SVG und registrierte Ereignisse entfernen.
    if (this.svg) {

      this.svg.on(".zoom", null);
      this.svg.on(".network", null);

      this.svg.remove();

      this.svg = null;
    }

    this.nodeSelection = null;
    this.linkSelection = null;
    this.graphGroup = null;
    this.nodeGroup = null;
    this.linkGroup = null;

    this.selectedNode = null;

    this.onNodeSelect = null;
  }
}
