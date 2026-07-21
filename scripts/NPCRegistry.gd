extends Node
## NPCRegistry (autoload) — the central table of every named villager, keyed by
## a stable string id. This is where you flesh individual NPCs out as the game
## grows: routines, appearance, and (later) conversation trees all live on the
## NPCDefinition. Other systems look an NPC up with get_definition(id):
##
##     var mabel := NPCRegistry.get_definition("mabel")
##
## Ids are stable, so save data, quest flags, and dialogue state can reference
## an NPC without caring where it currently is in the world.

const Phase := TimeManager.Phase

var _defs : Dictionary = {}   # id -> NPCDefinition

func _ready() -> void:
	_register_all()

func get_definition(id: String) -> NPCDefinition:
	return _defs.get(id)

func all_definitions() -> Array:
	return _defs.values()

func has(id: String) -> bool:
	return _defs.has(id)

func _add(def: NPCDefinition) -> void:
	_defs[def.id] = def

# ── The cast ───────────────────────────────────────────────
# Add a villager by writing a _register_* function and calling it here.
func _register_all() -> void:
	_register_mayor_henderson()
	_register_mabel()
	_register_gus()
	_register_poppy()

func _register_mayor_henderson() -> void:
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "mayor_henderson"
	def.display_name = "Mayor Henderson"
	def.home_anchor  = "House19"          # a home just south of City Hall
	def.shirt_color  = Color("#6a4a8a")   # mayoral purple
	def.pants_color  = Color("#33333f")
	def.hair_color   = Color("#9a9aa0")
	# Every day: at City Hall through the daytime, home again by sunset/night
	# (the home_anchor fallback covers any phase with no matching entry).
	var sched : Array[NPCScheduleEntry] = [
		NPCScheduleEntry.make([], Phase.DAY,   "Building_TownHall", Vector2(0, 40)),
		NPCScheduleEntry.make([], Phase.NIGHT, "House19",           Vector2(0, 20)),
	]
	def.schedule = sched
	def.dialogue_lines = [
		DialogueLine.make("Hi, how's the delivery business?", DialogueLine.SURPRISED),
	]
	_add(def)

func _register_mabel() -> void:
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "mabel"
	def.display_name = "Mabel"
	def.home_anchor  = "Apartments"
	def.shirt_color  = Color("#d46a6a")
	def.hair_color   = Color("#e0d8c8")
	var sched : Array[NPCScheduleEntry] = [
		NPCScheduleEntry.make([1, 2, 3], Phase.DAY,    "Building1", Vector2(-30, 40)),
		NPCScheduleEntry.make([4, 5],    Phase.DAY,    "House28",   Vector2(30, 30)),
		NPCScheduleEntry.make([2, 3],    Phase.SUNSET, "Pub",       Vector2(20, 30)),
		NPCScheduleEntry.make([],        Phase.NIGHT,  "Apartments", Vector2(0, 20)),
	]
	def.schedule = sched
	def.dialogue_lines = [
		DialogueLine.make("Oh, hello dear! Busy day of deliveries?", DialogueLine.HAPPY),
		DialogueLine.make("I'm off to the pub later — Wednesdays are trivia night!", DialogueLine.HAPPY),
	]
	_add(def)

func _register_gus() -> void:
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "gus"
	def.display_name = "Gus"
	def.home_anchor  = "House28"
	def.shirt_color  = Color("#5a7aa0")
	def.hair_color   = Color("#7a6a4a")
	var sched : Array[NPCScheduleEntry] = [
		NPCScheduleEntry.make([0],             Phase.DAY,   "Building1", Vector2(30, 40)),
		NPCScheduleEntry.make([1, 2, 3, 4, 5], Phase.DAY,   "Pub",       Vector2(-40, 40)),
		NPCScheduleEntry.make([],              Phase.NIGHT, "Pub",       Vector2(0, 30)),
	]
	def.schedule = sched
	def.dialogue_lines = [
		DialogueLine.make("Watch where you're pedaling, kid!", DialogueLine.MAD),
		DialogueLine.make("...Ah, I'm only teasing. Fine weather for it.", DialogueLine.CALM),
	]
	_add(def)

func _register_poppy() -> void:
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "poppy"
	def.display_name = "Poppy"
	def.home_anchor  = "House10"
	def.shirt_color  = Color("#e0a040")
	def.hair_color   = Color("#4a3020")
	var sched : Array[NPCScheduleEntry] = [
		NPCScheduleEntry.make([1, 2, 3, 4, 5], Phase.DAY,    "House10",    Vector2(50, 40)),
		NPCScheduleEntry.make([0],             Phase.DAY,    "Apartments", Vector2(-60, 50)),
		NPCScheduleEntry.make([],              Phase.SUNSET, "House10",    Vector2(0, 25)),
	]
	def.schedule = sched
	def.dialogue_lines = [
		DialogueLine.make("Wow, you deliver packages?! That's so cool!", DialogueLine.SURPRISED),
		DialogueLine.make("When I grow up I want a bike just like yours.", DialogueLine.HAPPY),
	]
	_add(def)
