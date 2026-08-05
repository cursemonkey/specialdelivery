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
	_register_doctor_carrington()
	_register_elsie_carrington()

## Elsie Carrington — Doctor Carrington's mother, a nurse at the hospital.
## Alternating shift weeks, Saturdays at the pub, Mondays running errands.
func _register_elsie_carrington() -> void:
	const SAT : int = 6
	const MON : int = 1
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "elsie_carrington"
	def.display_name = "Elsie Carrington"
	def.home_anchor  = "House60"
	def.shirt_color  = Color("#bfe4f5")   # nurse blues
	def.pants_color  = Color("#4a6b82")
	def.hair_color   = Color("#d8d2cc")   # greying
	# week_parity 0 = day-shift weeks, 1 = night-shift weeks. Day-off entries come
	# first so they override the shift for that weekday.
	var sched : Array[NPCScheduleEntry] = [
		# Saturdays off — pub from 6pm to 2am.
		NPCScheduleEntry.make_hours([SAT], 18.0, 2.0, "Pub", Vector2(0, 40), -1, true),
		NPCScheduleEntry.make_hours([SAT], 2.0, 18.0, "House60", Vector2(0, 20), -1, true),
		# Mondays off — grocery at 10am, bakery/cafe at 1pm, home from 4pm.
		NPCScheduleEntry.make_hours([MON], 10.0, 13.0, "Grocery", Vector2(0, 40), -1, true),
		NPCScheduleEntry.make_hours([MON], 13.0, 16.0, "Bakery",  Vector2(0, 40), -1, true),
		NPCScheduleEntry.make_hours([MON], 16.0, 10.0, "House60", Vector2(0, 20), -1, true),
		# Day-shift weeks: hospital 8am–6pm, otherwise home.
		NPCScheduleEntry.make_hours([], 8.0, 18.0, "Hospital", Vector2(0, 40), 0, true),
		NPCScheduleEntry.make_hours([], 18.0, 8.0, "House60",  Vector2(0, 20), 0, true),
		# Night-shift weeks: hospital 6pm–4am, otherwise home.
		NPCScheduleEntry.make_hours([], 18.0, 4.0, "Hospital", Vector2(0, 40), 1, true),
		NPCScheduleEntry.make_hours([], 4.0, 18.0, "House60",  Vector2(0, 20), 1, true),
	]
	def.schedule = sched
	def.random_dialogue = true
	def.dialogue_lines = [
		DialogueLine.make("Lovin' life, guy?", DialogueLine.HAPPY),
		DialogueLine.make("My daughter doesn't always get along with me.", DialogueLine.SAD),
		DialogueLine.make("My daughter complains I live too hard.", DialogueLine.MAD),
		DialogueLine.make("How's it goin', guy?", DialogueLine.CALM),
	]
	_add(def)
	_register_mabel()
	_register_gus()
	_register_poppy()

func _register_doctor_carrington() -> void:
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "doctor_carrington"
	def.display_name = "Doctor Carrington"
	def.home_anchor  = "Townhouse10"
	def.shirt_color  = Color("#a8ecc8")   # mint clothing
	def.pants_color  = Color("#5fc9a3")   # deeper mint
	def.hair_color   = Color("#f49ac2")   # pink hair
	# First match wins, so the day/day-of-week overrides come before the base
	# alternating-week routine. week_parity: 0 = even weeks, 1 = odd weeks. Every
	# entry is interior (true) — she's inside these buildings, found by going in.
	var sched : Array[NPCScheduleEntry] = [
		# Sundays: church during the day, then out front on the steps at sunset
		# (outdoors, so she can be met on the street).
		NPCScheduleEntry.make([0], Phase.DAY,    "Church",  Vector2(0, 40), -1, true),
		NPCScheduleEntry.make([0], Phase.SUNSET, "Church",  Vector2(70, 55), -1, false),
		# Wednesdays: outside the grocery by day, inside it in the afternoon.
		NPCScheduleEntry.make([3], Phase.DAY,    "Grocery", Vector2(60, 55), -1, false),
		NPCScheduleEntry.make([3], Phase.SUNSET, "Grocery", Vector2(0, 40), -1, true),
		# Even weeks: at the hospital early, home at night.
		NPCScheduleEntry.make([], Phase.DAY,    "Hospital",   Vector2(0, 40), 0, true),
		NPCScheduleEntry.make([], Phase.SUNSET, "Hospital",   Vector2(0, 40), 0, true),
		NPCScheduleEntry.make([], Phase.NIGHT,  "Townhouse10", Vector2(0, 20), 0, true),
		# Odd weeks: home by day, to the hospital at sunset, stays overnight.
		NPCScheduleEntry.make([], Phase.DAY,    "Townhouse10", Vector2(0, 20), 1, true),
		NPCScheduleEntry.make([], Phase.SUNSET, "Hospital",   Vector2(0, 40), 1, true),
		NPCScheduleEntry.make([], Phase.NIGHT,  "Hospital",   Vector2(0, 40), 1, true),
	]
	def.schedule = sched
	# One of these is picked at random each time the player talks to her; the
	# mood on each line selects the matching portrait.
	def.random_dialogue = true
	def.dialogue_lines = [
		DialogueLine.make("Please take care of your health.", DialogueLine.CALM),
		DialogueLine.make("Well now, you're looking well! Keep that up.", DialogueLine.HAPPY),
		DialogueLine.make("Another crash? Honestly, slow down out there!", DialogueLine.MAD),
		DialogueLine.make("Rest when you need it — the packages will keep.", DialogueLine.CALM),
	]
	_add(def)

func _register_mayor_henderson() -> void:
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "mayor_henderson"
	def.display_name = "Mayor Henderson"
	def.home_anchor  = "House96"          # a home just south of City Hall
	def.shirt_color  = Color("#6a4a8a")   # mayoral purple
	def.pants_color  = Color("#33333f")
	def.hair_color   = Color("#9a9aa0")
	# Every day: at City Hall through the daytime, home again by sunset/night
	# (the home_anchor fallback covers any phase with no matching entry).
	var sched : Array[NPCScheduleEntry] = [
		# Beside the City Hall entrance (not on the door) so the player can enter.
		NPCScheduleEntry.make([], Phase.DAY,   "Building_TownHall", Vector2(84, 42)),
		NPCScheduleEntry.make([], Phase.NIGHT, "House96",           Vector2(0, 20)),
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
		NPCScheduleEntry.make([4, 5],    Phase.DAY,    "House84",   Vector2(30, 30)),
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
	def.home_anchor  = "House84"
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
