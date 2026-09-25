# Family Dashboard for openHAB (Tablet, Landscape)

Anonymized example. People here are named Lisa, Max, Tom, and Paul.

## What it can do

- **Overview:** Five "Appointments today" cards (three on top, two below), followed by weather, waste collection, and household chores side by side.
- **Calendar:** One tab per person with a weekly view as a classic calendar grid (today plus six days × hours, appointments as positioned blocks).
- **Household chores:** Popup for creating, editing, checking off, and deleting chores.
- **Weather:** Weather card with current values, tip of the day, and a four-day forecast.

## Files

| File | Location | Content |
|---|---|---|
| `dashboard-ui.yaml` | `$OPENHAB_CONF/yaml/` | Widgets and pages |
| `dashboard-kalender.yaml` | `$OPENHAB_CONF/yaml/` | Event filters + calendar items, NTP clock |
| `dashboard-aufgaben.yaml` | `$OPENHAB_CONF/yaml/` | Item for the task list |
| `wetter.items` | `$OPENHAB_CONF/items/` | Items for OpenWeatherMap (One Call) |
| `wetter.things`| `$OPENHAB_CONF/things/` | Things for OpeenWeatherMap (One Call) |
| `aufgaben.rb` | `$OPENHAB_CONF/automation/ruby/` | Rules for task management (JRuby) |

## Prerequisites

Bindings: **iCalendar**, **OpenWeatherMap**, **NTP**
Automation: **JRuby Scripting**

The following iCalendar bridges must exist:

`icalendar:calendar:Kalender_<Name>`

In this example:
- `Kalender_Lisa`
- `Kalender_Max`       <-- Private calendar of Max
- `Kalender_MaxArbeit` <-- Work calendar of Max
- `Kalender_Familie`
- `Kalender_Tom`
- `Kalender_Paul`

For the four-day forecast, an OpenWeatherMap One Call Thing is required (One Call 3.0, separate subscription with OpenWeatherMap; up to 1,000 calls/day are free).

Without this Thing, the forecast row remains empty. The current weather values continue to work.

The task rules require an existing structure:

- Group `AlleAufgaben`
- One group per task
- The following Items for each task:
  - `<id>_TageBis`
  - `<id>_Faellig`
  - `<id>_Intervall`
  - `<id>_Aktiv`
- The helper methods:
  - `create_aufgabe?`
  - `update_aufgabe?`
  - `delete_aufgabe?`

