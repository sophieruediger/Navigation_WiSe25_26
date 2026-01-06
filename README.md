# Open Source basierte Navigation - Modul Navigation Abgabe

## Übersicht
Diese Applikation wurde im Rahmen des Moduls "Navigation" entwickelt. Sie stellt ein Routing-System für Berlin bereit, welches auf OpenStreetMap (OSM) Daten basiert. Die Anwendung berechnet die kürzeste Route zwischen zwei Punkten (Start und Ziel) unter Verwendung des Dijkstra-Algorithmus.

## Architektur
Die Anwendung ist als Microservice-Architektur mit Docker Containern aufgebaut:

1.  **Datenbank (db)**:
    *   PostgreSQL mit **PostGIS** (für Geodaten) und **pgRouting** (für Routing-Algorithmen).
    *   Speichert die OSM-Daten in einem routingfähigen Format (Topologie).

2.  **API (postgrest)**:
    *   Verwendet **PostgREST**, um die Datenbankfunktionen direkt als REST-API bereitzustellen.
    *   Dient als Schnittstelle zwischen Frontend und Datenbank.

3.  **Frontend**:
    *   Eine Webanwendung basierend auf **OpenLayers**.
    *   Ermöglicht die Interaktion auf einer Karte (Start/Ziel setzen) und visualisiert die berechnete Route.

4.  **Import**:
    *   Ein temporärer Container, der beim Start die OSM-Rohdaten (`.pbf`) verarbeitet.
    *   Nutzt `osm2pgrouting`, um die Daten in die Datenbank zu importieren und die Topologie zu erstellen.

## Technische Implementierung der Navigation

### 1. Datenaufbereitung
Die Rohdaten liegen als OSM PBF Datei (`berlin.osm.pbf`) vor. Der Import-Prozess (`import/entrypoint.sh`) führt folgende Schritte aus:
*   Konvertierung von PBF zu XML (falls nötig).
*   Verwendung von `osm2pgrouting` mit einer `mapconfig.xml`, um relevante Straßen und Wege zu filtern und in Knoten (Nodes) und Kanten (Edges) zu zerlegen. Dabei wird die Topologie des Straßennetzes aufgebaut, die für das Routing essenziell ist.

### 2. Routing-Algorithmus
Das Kernstück der Navigation ist eine PL/pgSQL Funktion `route` in der Datenbank (`import/init.sql`). Diese Funktion kapselt die Komplexität des Routings:

*   **Eingabe**: Start- und Zielkoordinaten (Längengrad, Breitengrad).
*   **Map Matching / Projektion**: Da ein Klick auf der Karte selten exakt einen Knoten des Graphen trifft, sucht die Funktion zunächst die nächstgelegenen Kanten (`ways`) für Start- und Endpunkt.
*   **Teilstrecken-Berechnung**:
    *   Vom Startpunkt wird eine Linie zum projizierten Punkt auf der Start-Kante gezogen.
    *   Vom projizierten Punkt wird der Weg zum nächsten Knoten des Graphen berechnet.
*   **Dijkstra**: Für den Weg zwischen dem Start-Knoten und dem End-Knoten im Graphen wird `pgr_dijkstra` verwendet. Dieser Algorithmus findet den kürzesten Pfad basierend auf den Kosten (hier: Länge in Metern).
*   **Zusammenfügen**: Die Geometrien der Teilstrecken (Start -> Graph, Graph-Pfad, Graph -> Ziel) werden als GeoJSON zurückgegeben.

### 3. API Schnittstelle
Das Frontend ruft diese Funktion über PostgREST auf:
`POST /rpc/route` mit den Parametern `x1, y1, x2, y2`.

## Installation und Start

Voraussetzungen: Docker und Docker Compose.

1.  Stellen Sie sicher, dass die Datei `data/berlin.osm.pbf` vorhanden ist.
2.  Starten Sie die Anwendung:
    ```bash
    docker-compose up --build
    ```
3.  Warten Sie, bis der Import-Container (`sophie_import`) fertig ist ("Import finished"). Dies kann beim ersten Mal einige Minuten dauern.
4.  Öffnen Sie das Frontend im Browser: [http://localhost:8080](http://localhost:8080)

## Verwendung
*   **Start/Ziel setzen**: Klicken Sie auf die Karte. Es werden nacheinander Start oder Zielkoordinate festgelegt.
*   **Route berechnen**: Klicken Sie auf "Calculate Route". Die Route wird als blaue Linie auf der Karte dargestellt.

