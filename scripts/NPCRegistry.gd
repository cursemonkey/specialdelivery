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

## Stable placeholder name for an NPC with no name of its own: the first such
## NPC is "NPC 1", the next "NPC 2", and so on. Keyed by id so a given NPC keeps
## the same number for the whole session.
var _fallback_names : Dictionary = {}

func fallback_name_for(id: String) -> String:
	if id.is_empty():
		return "NPC"
	if not _fallback_names.has(id):
		_fallback_names[id] = "NPC %d" % (_fallback_names.size() + 1)
	return _fallback_names[id]

# ── The cast ───────────────────────────────────────────────
# Add a villager by writing a _register_* function and calling it here.
func _register_all() -> void:
	_register_mayor_henderson()
	_register_doctor_carrington()
	_register_elsie_carrington()
	_register_spider()
	_register_flower_campbell()
	_register_kali()
	_register_darin()
	_register_nayra()

## Nayra — the grocer. Works the shop 7am–1am every day of the week, and only
## goes back to her flat in the Apartments for the small hours between shifts.
## Polite and shy: she apologises for things that aren't her fault and tends to
## trail off mid-sentence.
func _register_nayra() -> void:
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "nayra"
	def.display_name = "Nayra"
	def.home_anchor  = "Apartments"
	def.shirt_color  = Color("#8fbf8a")   # grocer's green apron
	def.pants_color  = Color("#57506b")
	def.hair_color   = Color("#2b1f1a")
	def.skin_color   = Color("#c98f63")
	# Empty weekday list = every day. The shift wraps past midnight (7 → 1), and
	# the flat covers the gap; both are interior, so she's found by going inside.
	var sched : Array[NPCScheduleEntry] = [
		NPCScheduleEntry.make_hours([], 7.0, 1.0, "Grocery",    Vector2(0, 40), -1, true),
		NPCScheduleEntry.make_hours([], 1.0, 7.0, "Apartments", Vector2(0, 20), -1, true),
	]
	def.schedule = sched
	def.random_dialogue = true
	def.dialogue_lines = [
		DialogueLine.make("Oh — hello. Sorry, I didn't hear you come in…", DialogueLine.SURPRISED),
		DialogueLine.make("Everything's fresh today. I checked twice. Um… just in case.", DialogueLine.CALM),
		DialogueLine.make("Take your time. I don't mind waiting, really.", DialogueLine.CALM),
		DialogueLine.make("You must get so tired, all that cycling. You should eat something.", DialogueLine.HAPPY),
		DialogueLine.make("Sorry — was I in your way?", DialogueLine.SAD),
	]
	_add(def)

## Kali — police officer, 7am–7pm, off Tuesdays and Saturdays.
func _register_kali() -> void:
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "kali"
	def.display_name = "Officer Kali"
	def.home_anchor  = "House70"
	def.shirt_color  = Color("#2f4a7a")   # police blues
	def.pants_color  = Color("#26324a")
	def.hair_color   = Color("#2b2118")
	def.schedule     = _police_schedule("House70", [2, 6])   # off Tue(2) & Sat(6)
	def.random_dialogue = true
	def.dialogue_lines = [
		DialogueLine.make("Keep it slow through town, alright?", DialogueLine.CALM),
		DialogueLine.make("Nice riding out there. Stay safe!", DialogueLine.HAPPY),
	]
	_add(def)

## Darin — senior police officer, 7am–7pm, off Sundays and Mondays.
func _register_darin() -> void:
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "darin"
	def.display_name = "Sergeant Darin"
	def.home_anchor  = "House72"
	def.shirt_color  = Color("#1e3560")   # darker blues — senior officer
	def.pants_color  = Color("#1b2436")
	def.hair_color   = Color("#6a6259")   # greying
	def.schedule     = _police_schedule("House72", [0, 1])   # off Sun(0) & Mon(1)
	def.random_dialogue = true
	def.dialogue_lines = [
		DialogueLine.make("Thirty years on this beat. Seen it all.", DialogueLine.CALM),
		DialogueLine.make("Slow down, kid. Packages aren't worth a crash.", DialogueLine.MAD),
	]
	_add(def)

## Shared officer routine: on shift at the station 7am–7pm on working days,
## home otherwise. On days they're assigned a roadblock, PoliceManager overrides
## the daytime posting and sends them out to the scene instead.
func _police_schedule(home: String, days_off: Array[int]) -> Array[NPCScheduleEntry]:
	var work_days : Array[int] = []
	for d in range(GameManager.DAY_NAMES.size()):
		if not days_off.has(d):
			work_days.append(d)
	var sched : Array[NPCScheduleEntry] = [
		NPCScheduleEntry.make_hours(work_days, 7.0, 19.0, "Police", Vector2(0, 40), -1, true),
		NPCScheduleEntry.make_hours([], 0.0, 24.0, home, Vector2(0, 20), -1, true),
	]
	return sched

## True if this officer is on shift right now (used by PoliceManager).
func officer_works_today(id: String, weekday: int) -> bool:
	var off : Dictionary = {"kali": [2, 6], "darin": [0, 1]}
	if not off.has(id):
		return false
	return not off[id].has(weekday)

## Flower Campbell — lives and works on the farm. Out in the fields on spring and
## summer mornings, indoors the rest of the day, church on Sundays and the
## grocery on Thursday afternoons.
func _register_flower_campbell() -> void:
	const SUN : int = 0
	const THU : int = 4
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "flower_campbell"
	def.display_name = "Flower Campbell"
	def.home_anchor  = "Farm"
	def.shirt_color  = Color("#c0392b")   # red shirt
	def.pants_color  = Color("#33509c")   # blue pants
	def.hair_color   = Color("#c1440e")   # red hair
	var spring_summer : Array[int] = [Calendar.Season.SPRING, Calendar.Season.SUMMER]
	var sched : Array[NPCScheduleEntry] = [
		# Sundays: church during the day.
		NPCScheduleEntry.make_hours([SUN], 9.0, 13.0, "Church", Vector2(0, 40), -1, true),
		# Thursday afternoons: the grocery store.
		NPCScheduleEntry.make_hours([THU], 13.0, 17.0, "Grocery", Vector2(0, 40), -1, true),
		# Spring & summer mornings: wandering the fields outside the farmhouse.
		NPCScheduleEntry.make_hours([], 6.0, 12.0, "Farm", Vector2(0, 60), -1, false) \
				.in_seasons(spring_summer).wandering(110.0),
		# Everything else: inside the farmhouse.
		NPCScheduleEntry.make_hours([], 0.0, 24.0, "Farm", Vector2(0, 30), -1, true),
	]
	def.schedule = sched
	def.random_dialogue = true
	def.dialogue_lines = [
		DialogueLine.make("Mornin'! The fields are lookin' good this year.", DialogueLine.HAPPY),
		DialogueLine.make("Nothin' beats a quiet morning out here.", DialogueLine.CALM),
	]
	_add(def)

## Spider — lives with Elsie Carrington, plays in a band. Out at the pub most
## nights, but stays in with Elsie on her days off (Saturday and Monday), and
## leaves town on tour from Spring 10 to Fall 20.
func _register_spider() -> void:
	const SAT : int = 6   # Elsie's days off
	const MON : int = 1
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "spider"
	def.display_name = "Spider"
	def.home_anchor  = "House60"          # same house as Elsie
	def.shirt_color  = Color("#b3352f")   # red shirt
	def.pants_color  = Color("#43301f")   # dark brown pants
	def.skin_color   = Color("#e8c8a0")   # caucasian
	def.bald         = true
	# spider.png is a single 736x92 strip: 8 frames of 92x92, one row (down).
	# Scaled down to sit alongside the ~30px-tall procedural villagers.
	def.frame_size    = Vector2i(92, 92)
	def.frame_count   = 8
	def.sprite_scale  = 0.42
	def.sprite_offset = Vector2(0, -6)
	# Placeholder: no separate idle art yet, so idle replays the walk frames at a
	# slower pace. Drop in assets/NPCs/spider_idle.png later to use real idle art.
	def.idle_reuses_walk = true
	def.idle_frame_time  = 0.30
	# On tour: away from town Spring 10 → Fall 20 (wraps past the year end).
	def.set_away(Calendar.Season.SPRING, 10, Calendar.Season.FALL, 20)
	var sched : Array[NPCScheduleEntry] = [
		# Elsie's days off — he stays home with her instead of going out.
		NPCScheduleEntry.make_hours([SAT, MON], 0.0, 24.0, "House60", Vector2(0, 20), -1, true),
		# Every other night: pub from 8pm to 5am, home the rest of the day.
		NPCScheduleEntry.make_hours([], 20.0, 5.0, "Pub",     Vector2(0, 40), -1, true),
		NPCScheduleEntry.make_hours([], 5.0, 20.0, "House60", Vector2(0, 20), -1, true),
	]
	def.schedule = sched
	def.random_dialogue = true
	def.dialogue_lines = [
		DialogueLine.make("Hey there. Catch us play sometime, yeah?", DialogueLine.HAPPY),
		DialogueLine.make("Long night. Long tour. Same difference.", DialogueLine.CALM),
	]
	_add(def)

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
