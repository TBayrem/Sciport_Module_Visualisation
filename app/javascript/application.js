
// ============================================================
// Datei: application.js
//
// Desc:
// Zentraler Einstiegspunkt für das JavaScript
// der Rails-Anwendung.
//
// Lädt Rails Turbo, die vorhandenen Stimulus-Controller
// und die beiden Visualisierungen.
//
// Anwendungsfälle:
// - Navigation zwischen den Seiten ermöglichen
// - Forschungsnetzwerk initialisieren
// - Thematische Forschungslandschaft initialisieren
// ============================================================


// ------------------------------------------------------------
// 1. Rails Turbo
//
// Ermöglicht die Navigation innerhalb der Anwendung
// und unterstützt den Seitenwechsel zwischen
// Forschungsnetzwerk und Themenvisualisierung.
// ------------------------------------------------------------

import "@hotwired/turbo-rails";


// ------------------------------------------------------------
// 2. Rails Stimulus
//
// Lädt die vorhandenen Stimulus-Controller.
// Diese Konfiguration bleibt Bestandteil
// der Rails-Anwendung.
// ------------------------------------------------------------

import "controllers";


// ------------------------------------------------------------
// 3. Forschungsnetzwerk
//
// Der Einstiegspunkt network/main.js übernimmt
// die Initialisierung des D3-Netzwerks,
// die Einrichtungsfilter und die Detailinformationen.
//
// Die eigentliche Netzwerkdarstellung befindet
// sich in der Klasse Network.
// ------------------------------------------------------------

import "network/main";



