# Familien-Dashboard für openHAB (Tablet, Querformat)

Anonymisiertes Beispiel. Personen heißen hier Lisa, Max, Tom und Paul.

## Was es kann

- **Übersicht:** fünf Karten „Termine heute“ (drei oben, zwei unten), darunter Wetter,
  Müllabfuhr und Haushaltsaufgaben nebeneinander
- **Pro Person ein Tab** mit Wochenansicht als klassisches Kalender-Grid
  (heute plus sechs Tage x Stunden, Termine als positionierte Blöcke)
- **Haushaltsaufgaben** mit Popup zum Anlegen, Bearbeiten, Abhaken und Löschen
- **Wetterkarte** mit aktuellen Werten, Tipp des Tages und Vier-Tage-Vorschau

## Dateien

| Datei | Ablage | Inhalt |
|---|---|---|
| `dashboard-ui.yaml` | `$OPENHAB_CONF/yaml/` | Widgets und Seiten |
| `dashboard-kalender.yaml` | `$OPENHAB_CONF/yaml/` | Eventfilter + Items der Kalender, NTP-Uhr |
| `dashboard-aufgaben.yaml` | `$OPENHAB_CONF/yaml/` | Item für die Aufgabenliste |
| `wetter.items` | `$OPENHAB_CONF/items/` | Items für OpenWeatherMap (One Call) |
| `aufgaben.rb` | `$OPENHAB_CONF/automation/ruby/` | Regeln für die Aufgabenverwaltung (JRuby) |

## Voraussetzungen

- Bindings: **iCalendar**, **OpenWeatherMap**, **NTP**
- Kalender-Bridges `icalendar:calendar:Kalender_<Name>` müssen vorhanden sein
  (hier: `Kalender_Lisa`, `Kalender_Max`, `Kalender_MaxArbeit`, `Kalender_Familie`,
  `Kalender_Tom`, `Kalender_Paul`)
- Für die Vier-Tage-Vorschau ein `onecall`-Thing (One Call 3.0, eigenes Abo bei
  OpenWeatherMap; bis 1.000 Abrufe/Tag kostenlos). Ohne das Thing bleibt die
  Vorschauzeile leer, die aktuellen Werte funktionieren trotzdem.
- Die Aufgaben-Regeln setzen eine bestehende Struktur voraus: Gruppe `AlleAufgaben`
  mit je einer Gruppe pro Aufgabe und den Items `<id>_TageBis`, `<id>_Faellig`,
  `<id>_Intervall`, `<id>_Aktiv` sowie die Hilfsmethoden `create_aufgabe?`,
  `update_aufgabe?` und `delete_aufgabe?`.

## Hinweise, die beim Bauen Zeit gekostet haben

- **Ausdrücke sind Ausdrücke:** `const`, `return` oder `{ … }`-Blöcke funktionieren in
  Widget-Ausdrücken nicht. Statt dessen Pfeilfunktionen, Ternaries und
  sofort aufgerufene Funktionen mit Parametern als Ersatz für Variablen verwenden.
- **Nur wenige globale Objekte:** `Math`, `Number`, `JSON`, `dayjs`. `String(x)` gibt es
  nicht, stattdessen `('' + x)`.
- **Layout-Seiten haben eine feste Hierarchie:** `oh-block` > `oh-grid-row` >
  `oh-grid-col`. Eine Spalte rendert nur EIN Kind; alles Weitere gehört in einen
  Container darin. Für echte Abstände zwischen Karten ist ein eigenes CSS-Grid
  einfacher als das Framework7-Raster.
- **Zeit ist kein Auslöser:** Ausdrücke werden nur neu berechnet, wenn sich ein
  referenziertes Item ändert. Ein DateTime-Item vom NTP-Binding, das minütlich
  aktualisiert wird und in den zeitabhängigen Ausdrücken mitgelesen wird, sorgt für
  den Tageswechsel.
- **`0` als Standardwert:** `props.startHour || 7` macht aus 0 Uhr wieder 7 Uhr.
- **`oh-repeater` mit `itemsInGroup`** lädt die Mitglieder nur einmal. Für Listen, die
  sich zur Laufzeit ändern (Aufgaben), ist ein String-Item mit JSON praktischer.
