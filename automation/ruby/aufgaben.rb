require "securerandom"
require "json"

def aufgaben_liste_aktualisieren
  liste = AlleAufgaben.members
                      .select { |m| m.is_a?(OpenHAB::Core::Items::GroupItem) }
                      .map { |g| { id: g.name, label: g.label.to_s } }
                      .sort_by { |a| a[:label].downcase }
  AufgabenManager_Liste.update(liste.to_json)
end

def faelligkeit_setzen(id, tage)
  tage_bis    = items["#{id}_TageBis"]
  faelligkeit = items["#{id}_Faellig"]
  return logger.warn("Faelligkeit: Aufgabe '#{id}' nicht gefunden") unless tage_bis && faelligkeit

  tage = [tage, 0].max
  tage_bis.update(tage)
  # Bewusst update statt Befehl: ein OFF-BEFEHL wuerde die Regel
  # "Aufgabe erledigt" ausloesen und TageBis wieder aufs Intervall setzen.
  faelligkeit.update(tage.positive? ? OFF : ON)
  logger.info("Faelligkeit von '#{id}' auf #{tage} Tag(e) gesetzt")
end

rule "Aufgaben: Fälligkeit runterzählen" do
  every :day, at: "8:00"
  changed AufgabenDebug
  run do
    AlleAufgaben.members
                .select { |m| m.is_a?(OpenHAB::Core::Items::GroupItem) }
                .each do |aufgabe|
      tage_bis      = items["#{aufgabe.name}_TageBis"]
      faelligkeit   = items["#{aufgabe.name}_Faellig"]
      aufgabe_aktiv = items["#{aufgabe.name}_Aktiv"]

      next unless tage_bis && faelligkeit && aufgabe_aktiv
      next if aufgabe_aktiv.off? || faelligkeit.on?

      differenz = tage_bis.state.to_i - 1
      tage_bis << differenz

      next if differenz.positive?

      faelligkeit << ON
      nachricht = "🔧 Aufgabe '#{aufgabe.label}' ist seit heute fällig."
      logger.info(nachricht)      
    end
  end
end

rule "Aufgaben: Aufgabe erledigt" do
  # changed AlleAufgaben_Faelligkeit.members, to: OFF
  received_command AlleAufgaben_Faelligkeit.members, command: OFF
  run do |event|
    # Ruecksetzen der Tageszaehler
    aufgabe = items[event.item.name.sub("_Faellig", "")]
    intervall = items["#{aufgabe.name}_Intervall"]
    tage_bis = items["#{aufgabe.name}_TageBis"]
    tage_bis << intervall.state.to_i
  end
end

# aufgaben_manager.rb
# Legt ein Steuerungs-Item an (persistent) und verarbeitet CRUD-Befehle.
# Format der Befehle (JSON-String an AufgabenManager_Befehl senden):
#
# CREATE: {"cmd":"create","name":"Testaufgabe_D","label":"Testaufgabe D","intervall":7,"dependency":""}
# UPDATE: {"cmd":"update","name":"Testaufgabe_D","label":"Neue Bezeichnung","intervall":14,"dependency":"Testaufgabe_A"}
# DELETE: {"cmd":"delete","name":"Testaufgabe_D"}

require "json"

# ---------------------------------------------------------------------------
# Steuerungs-Items persistent anlegen (einmalig, idempotent durch update:true)
# ---------------------------------------------------------------------------
items.build(:persistent) do
  # Übergeordnete Gruppe aller Aufgaben
  group_item "AlleAufgaben", "Alle Aufgaben"
  group_item "AlleAufgaben_Faelligkeit", "Fälligkeit aller Aufgaben"

  # Steuerungs-Item: Über MainUI oder REST einen JSON-Befehl senden
  string_item "AufgabenManager_Befehl", "Aufgaben Manager Befehl"
end

# ---------------------------------------------------------------------------
# Hilfsmethoden
# ---------------------------------------------------------------------------

def aufgabe_exists?(name)
  items.key?(name)
end

def generate_aufgaben_id
  "aufg_#{SecureRandom.hex(5)}"
end

# CREATE: name wird vom System generiert, nicht vom Nutzer
def create_aufgabe?(label, intervall)
  id = generate_aufgaben_id # z.B. "aufg_402ba383f2"

  items.build(:persistent) do
    group_item id, label, groups: ["AlleAufgaben"]
    number_item "#{id}_TageBis",  "#{label} – Tage bis fällig", groups: [id], state: intervall
    number_item "#{id}_Intervall", "#{label} – Aufgabenintervall", groups: [id], state: intervall
    switch_item "#{id}_Faellig",  "#{label} – fällig",          groups: [id, "AlleAufgaben_Faelligkeit"], state: OFF
    switch_item "#{id}_Aktiv",    "#{label} – aktiv",           groups: [id], state: ON
  end

  logger.info("Aufgabe '#{label}' angelegt als '#{id}'")
  id # ID zurückgeben, damit der Nutzer sie kennt
end

# UPDATE: nur label und intervall änderbar, id bleibt fix
def update_aufgabe?(id, label, intervall)
  aufgabe = items[id]
  unless aufgabe
    logger.warn("Aufgabe '#{id}' nicht gefunden.")
    return false
  end

  items.build(:persistent) do
    group_item id, label || aufgabe.label, groups: ["AlleAufgaben"]
    number_item "#{id}_TageBis", "#{label || aufgabe.label} – Tage bis fällig", groups: [id]
    number_item "#{id}_Intervall", "#{label || aufgabe.label} – Aufgabenintervall", groups: [id], state: intervall
    switch_item "#{id}_Faellig",  "#{label || aufgabe.label} – fällig",
                groups: [id, "AlleAufgaben_Faelligkeit"], state: OFF
    switch_item "#{id}_Aktiv",    "#{label || aufgabe.label} – aktiv", groups: [id], state: ON
  end

  logger.info("Aufgabe '#{id}' aktualisiert.")
  true
end

def delete_aufgabe?(name)
  unless aufgabe_exists?(name)
    logger.warn("Aufgabe '#{name}' nicht gefunden.")
    return false
  end

  # Unteritems zuerst löschen
  ["#{name}_TageBis", "#{name}_Faellig", "#{name}_Aktiv", "#{name}_Intervall"].each do |item_name|
    items.remove(items[item_name]) if aufgabe_exists?(item_name)
  end

  # Gruppe löschen
  items.remove(items[name])

  logger.info("Aufgabe '#{name}' gelöscht.")
  true
end

# ---------------------------------------------------------------------------
# Regel: Auf Befehle am Steuerungs-Item reagieren
# ---------------------------------------------------------------------------
rule "Aufgaben CRUD verarbeiten" do
  received_command AufgabenManager_Befehl
  run do |event|
    raw = event.command.to_s.strip
    next if raw.empty? || raw == "NULL"

    begin
      cmd = JSON.parse(raw)
    rescue JSON::ParserError => e
      logger.error("Ungültiger JSON-Befehl: #{e.message}")
      next
    end

    operation = cmd["cmd"].to_s.downcase
    label     = cmd["label"].to_s
    intervall = cmd["intervall"].to_i
    id        = cmd["name"].to_s

    case operation
    when "create"
      create_aufgabe?(label, intervall)
    when "update"
      update_aufgabe?(id, label, intervall)
      faelligkeit_setzen(id, cmd["tagebis"].to_i) if cmd.key?("tagebis")
    when "delete"
      delete_aufgabe?(id)
    else
      logger.warn("Unbekannter Befehl: #{operation}")
    end

    aufgaben_liste_aktualisieren

    # Befehl zurücksetzen
    AufgabenManager_Befehl.update(NULL)
  end
end

rule "Aufgaben: Liste für Dashboard aufbauen" do
  on_load
  run { aufgaben_liste_aktualisieren }
end

logger.info("Aufgaben Manager geladen. ")
