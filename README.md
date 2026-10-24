# SciPort Visualization

**Interaktive Visualisierung von Forschungsnetzwerken und thematischen Forschungsstrukturen**

Dieses Repository enthält eine Webanwendung zur interaktiven Exploration und Visualisierung von Forschungsdaten aus dem SciPort-Kontext. Die Anwendung entsteht im Rahmen einer Masterarbeit und verwendet Ruby on Rails, PostgreSQL und D3.js.

## 1. Projektziel

Ziel des Projekts ist die Entwicklung einer webbasierten Visualisierungsumgebung, die Beziehungen zwischen Personen und Forschungseinrichtungen sowie thematische Zusammenhänge innerhalb der Forschungslandschaft zugänglich macht.

Die Anwendung verfolgt zwei Visualisierungsansätze:

- **Forschungsnetzwerk:** Darstellung von Personen, Einrichtungen und ihren Beziehungen als interaktives Netzwerk.
- **Thematische Forschungslandschaft:** Visualisierung thematischer Strukturen und Cluster.

Die Visualisierungen sollen die explorative Analyse komplexer Forschungsdaten unterstützen.

## 2. Technologie-Stack

| Komponente | Technologie |
|---|---|
| Backend | Ruby on Rails 8 |
| Programmiersprache | Ruby 4 |
| Datenbank | PostgreSQL 17 |
| Visualisierung | D3.js 7 |
| Frontend | JavaScript, HTML, CSS |
| JavaScript-Einbindung | Rails Importmap |
| Navigation | Hotwire Turbo |
| Entwicklungsumgebung | Visual Studio Code, Windows PowerShell |
| Versionsverwaltung | Git |
| Primäres Entwicklungsrepository | GitLab |

Die Versionsangaben beschreiben die aktuell verwendete lokale Entwicklungsumgebung.

## 3. Projektstruktur

```text
app/
  controllers/
    visualizations_controller.rb
  javascript/
    application.js
    network/
      Network.js
      main.js
  views/
    visualizations/
      network.html.erb
  assets/
    stylesheets/
      network.css

config/
  database.yml
  importmap.rb
  routes.rb
```

Die tatsächliche Verzeichnisstruktur kann im Laufe der Entwicklung erweitert werden.

## 4. Voraussetzungen

Für die lokale Entwicklung werden benötigt:

- Ruby und Bundler
- PostgreSQL
- Git
- Ein kompatibler Webbrowser
- Zugriff auf die benötigte SciPort-Datenbank beziehungsweise eine geeignete Entwicklungsdatenbank

## 5. Lokale Installation

Repository klonen:

```powershell
git clone <GITLAB-REPOSITORY-URL>
cd sciport_visualization
```

Ruby-Abhängigkeiten installieren:

```powershell
bundle install
```

Die PostgreSQL-Datenbank muss vor dem Start verfügbar sein.

**Hinweis:** Die Anwendung setzt gegebenenfalls vorhandene Forschungsdaten und Datenbankstrukturen voraus. Eine neue, leere Datenbank ersetzt diese Daten nicht.

## 6. PostgreSQL-Konfiguration

Die Datenbankverbindung wird in `config/database.yml` konfiguriert.

Für die lokale Entwicklungsumgebung werden folgende Parameter verwendet:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  host: 127.0.0.1
  port: 5432
  username: postgres
  password: <%= ENV["POSTGRES_PASSWORD"] %>

development:
  <<: *default
  database: sciport_visualization_development

test:
  <<: *default
  database: sciport_visualization_test
```

Die bestehende Produktionskonfiguration wird separat beibehalten.

### Passwort sicher bereitstellen

Das PostgreSQL-Passwort wird nicht im Quellcode gespeichert, sondern über die Umgebungsvariable `POSTGRES_PASSWORD` bereitgestellt.

Unter Windows PowerShell:

```powershell
$securePassword = Read-Host "PostgreSQL-Passwort eingeben" -AsSecureString
$env:POSTGRES_PASSWORD = [System.Net.NetworkCredential]::new("", $securePassword).Password
```

Das Passwort wird bei der Eingabe verdeckt. Die Umgebungsvariable gilt für die aktuelle PowerShell-Sitzung und Prozesse, die daraus gestartet werden.

**Sicherheitshinweise:**

- Keine Passwörter in Git committen.
- Keine Zugangsdaten in README-Dateien oder Screenshots veröffentlichen.
- Keine produktiven Zugangsdaten für lokale Tests verwenden, sofern getrennte Konten verfügbar sind.
- Lokale Geheimnisse nicht in öffentlich zugänglichen Dateien speichern.

### Datenbankverbindung überprüfen

```powershell
ruby bin/rails runner "puts ActiveRecord::Base.connection.select_value('SELECT current_database()')"
```

Bei erfolgreicher Verbindung mit der konfigurierten Entwicklungsdatenbank erscheint:

```text
sciport_visualization_development
```

**Achtung:** Befehle wie `db:drop`, `db:reset` oder `db:setup` dürfen nicht unüberlegt auf Datenbanken mit vorhandenen Forschungsdaten angewendet werden.

## 7. Anwendung starten

In einer PowerShell-Sitzung, in der `POSTGRES_PASSWORD` gesetzt ist:

```powershell
ruby bin/rails server
```

Die Anwendung ist standardmäßig unter folgenden Adressen erreichbar:

- http://localhost:3000
- http://localhost:3000/network

## 8. Forschungsnetzwerk

Die Netzwerkvisualisierung wird über den Controller `VisualizationsController` bereitgestellt.

Zentrale Bestandteile:

- `Network.js`: D3-basierte Netzwerkdarstellung
- `main.js`: Initialisierung und Benutzerinteraktionen
- `network.html.erb`: HTML-Ansicht
- `network.css`: Darstellung und Layout

Die Visualisierung berücksichtigt Personen und Forschungseinrichtungen. Die Darstellung hierarchischer Einrichtungsstrukturen und die zugehörigen Interaktionen sind Teil der weiteren Entwicklung und Überprüfung.

## 9. Entwicklungsstand

**Aktueller Stand: Oktober 2026**

- Rails-Anwendung startet lokal.
- PostgreSQL-Verbindung zur Entwicklungsdatenbank wurde erfolgreich getestet.
- Die Netzwerkroute `/network` ist eingerichtet.
- Die JavaScript-Einstiegspunkte und Importmap-Konfiguration wurden überprüft.
- Die sichtbare Darstellung des Forschungsnetzwerks ist noch Gegenstand der Fehlersuche.
- Weitere Visualisierungs- und Evaluationsschritte folgen.

Dieser Abschnitt wird mit dem Projektfortschritt aktualisiert.

## 10. Versionsverwaltung

Das Projekt wird mit Git versioniert. Für die weitere Entwicklung wird **GitLab als primäres Arbeitsrepository** verwendet.

GitHub kann als zusätzlicher Repository-Standort bestehen bleiben. Änderungen werden nicht automatisch zwischen beiden Plattformen synchronisiert.

Vor einem Push werden der aktuelle Branch, das Ziel-Remote und die zu übertragenden Dateien überprüft.

## 11. Wissenschaftlicher Kontext

Die Anwendung wird im Rahmen einer Masterarbeit entwickelt. Architekturentscheidungen, Visualisierungskonzepte, Implementierungsschritte und Evaluation werden in der schriftlichen Arbeit dokumentiert.

## 12. Datenschutz und Forschungsdaten

Forschungsdaten, Zugangsdaten und gegebenenfalls personenbezogene Informationen sind entsprechend den geltenden organisatorischen und datenschutzrechtlichen Anforderungen zu behandeln.

Die Veröffentlichung des Quellcodes bedeutet nicht automatisch, dass zugrunde liegende Forschungsdaten veröffentlicht werden dürfen.

## 13. Lizenz

Die Lizenzierung und mögliche Veröffentlichung des Projekts sind vor einer öffentlichen Freigabe mit den zuständigen Stellen zu klären.
