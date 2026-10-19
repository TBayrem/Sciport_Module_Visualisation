
import * as d3 from "d3";

// ============================================================
// Klasse: Network
//
// Desc:
// Erstellt und verwaltet ein interaktives Forschungsnetzwerk
// mithilfe der D3-Bibliothek.
//
// Die Klasse stellt Forschende und wissenschaftliche
// Einrichtungen als Knoten sowie ihre institutionellen
// Zugehörigkeiten als Verbindungen dar.
//
// Anwendungsfälle:
// - Forschungsnetzwerk visualisieren
// - Forschende und Einrichtungen unterscheiden
// - Netzwerk zoomen und verschieben
// - Netzwerkknoten interaktiv bewegen
// - Verbindungen ausgewählter Knoten hervorheben
// - Informationen zu ausgewählten Knoten bereitstellen
// ============================================================

export default class Network {

  // ----------------------------------------------------------
  // 1. Konstruktor und Initialisierung
  //
  // Der Konstruktor übernimmt das HTML-Element,
  // die Netzwerkdaten und eine optionale Callback-Funktion
  // für die Anzeige von Detailinformationen.
  // ----------------------------------------------------------

  /**
   * Title: constructor
   *
   * Desc:
   * Initialisiert die Netzwerkvisualisierung und
   * erstellt die erforderlichen D3-Elemente.
   *
   * Parameters:
   * - container: HTML-Element für das Netzwerk
   * - data: Objekt mit nodes und links
   * - onNodeSelect: optionale Callback-Funktion
   *
   * Returns:
   * - Neue Instanz der Klasse Network.
   */
  constructor(container, data, onNodeSelect = null) {
    this.container = container;

    this.nodes = (data.nodes || []).map(node => ({ ...node }));
    this.links = (data.links || []).map(link => ({ ...link }));

    this.onNodeSelect = onNodeSelect;

    this.selectedNode = null;
    this.simulation = null;

    this.width = container.clientWidth || 800;
    this.height = container.clientHeight || 600;

    this.initialize();
  }


  // ----------------------------------------------------------
  // 2. Aufbau der SVG-Visualisierung
  // ----------------------------------------------------------

  /**
   * Title: initialize
   *
   * Desc:
   * Erstellt das SVG-Element, richtet Zoom und
   * Verschiebung ein und startet die Darstellung
   * des Forschungsnetzwerks.
   *
   * Parameters:
   * - Keine.
   *
   * Returns:
   * - Kein Rückgabewert.
   */
  initialize() {
    d3.select(this.container).selectAll("*").remove();

    this.svg = d3
      .select(this.container)
      .append("svg")
      .attr("class", "network-svg")
      .attr("width", "100%")
      .attr("height", "100%")
      .attr("viewBox", [
        0,
        0,
        this.width,
        this.height
      ]);

    this.graphGroup = this.svg
      .append("g")
      .attr("class", "network-graph-group");

    this.linkGroup = this.graphGroup
      .append("g")
      .attr("class", "network-links");

    this.nodeGroup = this.graphGroup
      .append("g")
      .attr("class", "network-nodes");

    this.setupZoom();
    this.render();
  }


  // ----------------------------------------------------------
  // 3. Zoom und Verschiebung
  // ----------------------------------------------------------

  /**
   * Title: setupZoom
   *
   * Desc:
   * Ermöglicht das Zoomen und Verschieben
   * des gesamten Forschungsnetzwerks.
   *
   * Parameters:
   * - Keine.
   *
   * Returns:
   * - Kein Rückgabewert.
   */
  setupZoom() {
    this.zoom = d3
      .zoom()
      .scaleExtent([0.2, 5])
      .on("zoom", event => {
        this.graphGroup.attr(
          "transform",
          event.transform
        );
      });

    this.svg.call(this.zoom);
  }


  // ----------------------------------------------------------
  // 4. Darstellung der Netzwerkkanten
  // ----------------------------------------------------------

  /**
   * Title: renderLinks
   *
   * Desc:
   * Zeichnet die institutionellen Verbindungen
   * zwischen Forschenden und Einrichtungen.
   *
   * Parameters:
   * - Keine.
   *
   * Returns:
   * - D3-Selektion der Netzwerkkanten.
   */
  renderLinks() {
    this.linkElements = this.linkGroup
      .selectAll("line")
      .data(this.links)
      .join("line")
      .attr("class", "network-link")
      .attr("stroke", "#aebdca")
      .attr("stroke-width", 1.5);

    return this.linkElements;
  }


  // ----------------------------------------------------------
  // 5. Darstellung der Netzwerkknoten
  // ----------------------------------------------------------

  /**
   * Title: renderNodes
   *
   * Desc:
   * Zeichnet Forschende und Einrichtungen
   * als unterschiedlich eingefärbte Knoten.
   *
   * Forschende werden blau dargestellt,
   * Einrichtungen orange.
   *
   * Parameters:
   * - Keine.
   *
   * Returns:
   * - D3-Selektion der Netzwerkknoten.
   */
  renderNodes() {
    this.nodeElements = this.nodeGroup
      .selectAll("circle")
      .data(this.nodes, node => node.id)
      .join("circle")
      .attr("class", node =>
        `network-node network-node-${node.type}`
      )
      .attr("r", node =>
        node.type === "facility" ? 11 : 7
      )
      .attr("fill", node =>
        node.type === "facility" ? "#e58b32" : "#2563eb"
      )
      .attr("stroke", "#ffffff")
      .attr("stroke-width", 1.5)
      .style("cursor", "pointer")
      .on("click", (event, node) => {
        event.stopPropagation();
        this.selectNode(node);
      });

    this.nodeElements
      .append("title")
      .text(node => node.name || "Unbekannt");

    return this.nodeElements;
  }


  // ----------------------------------------------------------
  // 6. Force-Simulation
  // ----------------------------------------------------------

  /**
   * Title: setupSimulation
   *
   * Desc:
   * Erstellt die D3-Force-Simulation.
   *
   * Die Simulation verteilt die Knoten im Raum
   * und hält verbundene Knoten durch Kräfte
   * in einer gemeinsamen Netzwerkstruktur.
   *
   * Parameters:
   * - Keine.
   *
   * Returns:
   * - Kein Rückgabewert.
   */
  setupSimulation() {
    this.simulation = d3
      .forceSimulation(this.nodes)
      .force(
        "link",
        d3.forceLink(this.links)
          .id(node => node.id)
          .distance(85)
      )
      .force(
        "charge",
        d3.forceManyBody().strength(-160)
      )
      .force(
        "center",
        d3.forceCenter(
          this.width / 2,
          this.height / 2
        )
      )
      .force(
        "collision",
        d3.forceCollide().radius(18)
      )
      .on("tick", () => {
        this.updatePositions();
      });
  }


  // ----------------------------------------------------------
  // 7. Aktualisierung der Knotenpositionen
  // ----------------------------------------------------------

  /**
   * Title: updatePositions
   *
   * Desc:
   * Aktualisiert bei jedem Simulationsschritt
   * die Positionen der Knoten und Verbindungen.
   *
   * Parameters:
   * - Keine.
   *
   * Returns:
   * - Kein Rückgabewert.
   */
  updatePositions() {
    this.linkElements
      .attr("x1", link => link.source.x)
      .attr("y1", link => link.source.y)
      .attr("x2", link => link.target.x)
      .attr("y2", link => link.target.y);

    this.nodeElements
      .attr("cx", node => node.x)
      .attr("cy", node => node.y);
  }


  // ----------------------------------------------------------
  // 8. Interaktives Verschieben der Knoten
  // ----------------------------------------------------------

  /**
   * Title: setupDragging
   *
   * Desc:
   * Ermöglicht das Verschieben einzelner Knoten.
   *
   * Die Force-Simulation reagiert während des
   * Verschiebens auf die neue Knotenposition.
   *
   * Parameters:
   * - Keine.
   *
   * Returns:
   * - Kein Rückgabewert.
   */
  setupDragging() {
    const drag = d3
      .drag()
      .on("start", (event, node) => {
        if (!event.active) {
          this.simulation.alphaTarget(0.3).restart();
        }

        node.fx = node.x;
        node.fy = node.y;
      })
      .on("drag", (event, node) => {
        node.fx = event.x;
        node.fy = event.y;
      })
      .on("end", (event, node) => {
        if (!event.active) {
          this.simulation.alphaTarget(0);
        }

        node.fx = null;
        node.fy = null;
      });

    this.nodeElements.call(drag);
  }


  // ----------------------------------------------------------
  // 9. Auswahl und Hervorhebung eines Knotens
  // ----------------------------------------------------------

  /**
   * Title: selectNode
   *
   * Desc:
   * Markiert einen ausgewählten Knoten und
   * hebt dessen direkte Verbindungen hervor.
   *
   * Die ausgewählte Person oder Einrichtung
   * wird zusätzlich an die Detailansicht gemeldet.
   *
   * Parameters:
   * - node: ausgewählter Netzwerkknoten
   *
   * Returns:
   * - Kein Rückgabewert.
   */
  selectNode(node) {
    this.selectedNode = node;

    const connectedIds = new Set([node.id]);

    this.links.forEach(link => {
      const sourceId =
        typeof link.source === "object"
          ? link.source.id
          : link.source;

      const targetId =
        typeof link.target === "object"
          ? link.target.id
          : link.target;

      if (sourceId === node.id) {
        connectedIds.add(targetId);
      }

      if (targetId === node.id) {
        connectedIds.add(sourceId);
      }
    });

    this.nodeElements
      .attr("opacity", currentNode =>
        connectedIds.has(currentNode.id) ? 1 : 0.2
      )
      .attr("stroke-width", currentNode =>
        currentNode.id === node.id ? 3 : 1.5
      );

    this.linkElements
      .attr("opacity", link => {
        const sourceId = link.source.id;
        const targetId = link.target.id;

        return sourceId === node.id ||
               targetId === node.id
          ? 1
          : 0.1;
      })
      .attr("stroke-width", link => {
        return link.source.id === node.id ||
               link.target.id === node.id
          ? 2.5
          : 1.5;
      });

    if (typeof this.onNodeSelect === "function") {
      this.onNodeSelect(node, this.getConnectedNodes(node));
    }
  }


  // ----------------------------------------------------------
  // 10. Ermittlung benachbarter Knoten
  // ----------------------------------------------------------

  /**
   * Title: getConnectedNodes
   *
   * Desc:
   * Ermittelt alle direkt verbundenen Knoten
   * einer ausgewählten Person oder Einrichtung.
   *
   * Die Informationen werden für die Detailansicht
   * des Forschungsnetzwerks benötigt.
   *
   * Parameters:
   * - node: ausgewählter Netzwerkknoten
   *
   * Returns:
   * - Array mit direkt verbundenen Knoten.
   */
  getConnectedNodes(node) {
    const connectedIds = new Set();

    this.links.forEach(link => {
      const sourceId = link.source.id;
      const targetId = link.target.id;

      if (sourceId === node.id) {
        connectedIds.add(targetId);
      }

      if (targetId === node.id) {
        connectedIds.add(sourceId);
      }
    });

    return this.nodes.filter(currentNode =>
      connectedIds.has(currentNode.id)
    );
  }


  // ----------------------------------------------------------
  // 11. Zurücksetzen der Knotenauswahl
  // ----------------------------------------------------------

  /**
   * Title: resetSelection
   *
   * Desc:
   * Entfernt die Hervorhebung eines Knotens
   * und zeigt das gesamte Netzwerk wieder
   * mit normaler Deckkraft an.
   *
   * Parameters:
   * - Keine.
   *
   * Returns:
   * - Kein Rückgabewert.
   */
  resetSelection() {
    this.selectedNode = null;

    this.nodeElements
      .attr("opacity", 1)
      .attr("stroke-width", 1.5);

    this.linkElements
      .attr("opacity", 1)
      .attr("stroke-width", 1.5);

    if (typeof this.onNodeSelect === "function") {
      this.onNodeSelect(null, []);
    }
  }


  // ----------------------------------------------------------
  // 12. Darstellung des gesamten Netzwerks
  // ----------------------------------------------------------

  /**
   * Title: render
   *
   * Desc:
   * Zeichnet die Netzwerkknoten und Verbindungen,
   * startet die Force-Simulation und aktiviert
   * die Interaktion mit den Knoten.
   *
   * Parameters:
   * - Keine.
   *
   * Returns:
   * - Kein Rückgabewert.
   */
  render() {
    if (this.nodes.length === 0) {
      this.graphGroup
        .append("text")
        .attr("x", this.width / 2)
        .attr("y", this.height / 2)
        .attr("text-anchor", "middle")
        .attr("class", "network-empty-message")
        .text("Keine Netzwerkdaten vorhanden.");

      return;
    }

    this.renderLinks();
    this.renderNodes();
    this.setupSimulation();
    this.setupDragging();

    this.svg.on("click", () => {
      this.resetSelection();
    });
  }


  // ----------------------------------------------------------
  // 13. Freigabe der Netzwerkressourcen
  // ----------------------------------------------------------

  /**
   * Title: destroy
   *
   * Desc:
   * Beendet die Force-Simulation und entfernt
   * die SVG-Darstellung.
   *
   * Die Methode wird benötigt, wenn Turbo
   * die Seite verlässt oder neu lädt.
   *
   * Parameters:
   * - Keine.
   *
   * Returns:
   * - Kein Rückgabewert.
   */
  destroy() {
    if (this.simulation) {
      this.simulation.stop();
    }

    d3.select(this.container).selectAll("*").remove();
  }

}
