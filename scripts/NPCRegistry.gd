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
	_register_jimmy_henderson()
	_register_doctor_carrington()
	_register_elsie_carrington()
	_register_spider()
	_register_flower_campbell()
	_register_kali()
	_register_darin()
	_register_nayra()
	_register_marco()
	_register_aidan()
	_register_elias_thorne()
	_register_silas_thorne()
	_register_junia_thorne()

## Aidan — the mechanic. Works the shop 11am to 8pm on weekdays and a short
## Saturday shift, drinks at the pub after closing on Friday and Saturday, and
## is at church on Sunday mornings. Lives in a small house on the west side, a
## short walk up the road. Grew up around his father's junk yard, which is where
## he picked up the trade — he mentions the old man often. Plain-spoken and
## unbothered.
## TODO: his father is referenced in dialogue but not yet in the cast; when the
## junk yard NPC is added, link them (shared surname / schedule visits).
func _register_aidan() -> void:
	# Mon(1) Tue(2) Wed(3) Thu(4) Fri(5) — Saturday runs shorter hours, closed Sunday.
	const SUN : int = 0
	const FRI : int = 5
	const SAT : int = 6
	var work_days : Array[int] = [1, 2, 3, 4, 5]
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "aidan"
	def.display_name = "Aidan"
	def.home_anchor  = "House4"           # west side, up the road from the shop
	def.shirt_color  = Color("#4a6b8a")   # oil-stained blue coveralls
	def.pants_color  = Color("#3b4450")
	def.hair_color   = Color("#4a3527")
	def.skin_color   = Color("#d9a077")
	# First match wins, so the pub and church entries come before the shop and
	# home entries that would otherwise cover those hours.
	# Entries are matched against the *current* weekday, so a night out that runs
	# past midnight is written as two entries: the evening on the night itself,
	# and the small hours on the following day.
	var sched : Array[NPCScheduleEntry] = [
		# Friday: straight from the shop to the pub at 8pm…
		NPCScheduleEntry.make_hours([FRI], 20.0, 24.0, "Pub", Vector2(0, 40), -1, true),
		# Saturday: …until 3am, then a short shift 12–4pm, then the pub again.
		NPCScheduleEntry.make_hours([SAT],  0.0,  3.0, "Pub",      Vector2(0, 40), -1, true),
		NPCScheduleEntry.make_hours([SAT], 12.0, 16.0, "Mechanic", Vector2(0, 40), -1, true),
		NPCScheduleEntry.make_hours([SAT], 16.0, 24.0, "Pub",      Vector2(0, 40), -1, true),
		# Sunday: home from the pub at 3am, then church from 10am to noon.
		NPCScheduleEntry.make_hours([SUN],  0.0,  3.0, "Pub",    Vector2(0, 40), -1, true),
		NPCScheduleEntry.make_hours([SUN], 10.0, 12.0, "Church", Vector2(0, 40), -1, true),
		# Weekdays: in the mechanic shop from 11am until he shuts at 8pm.
		NPCScheduleEntry.make_hours(work_days, 11.0, 20.0, "Mechanic", Vector2(0, 40), -1, true),
		# Everything else: home on the west side.
		NPCScheduleEntry.make_hours([], 0.0, 24.0, "House4", Vector2(0, 20), -1, true),
	]
	def.schedule = sched
	def.random_dialogue = true
	# Friendship tiers. He starts brusque and transactional, warms into shop
	# talk, then into the junk yard and his father — the thing he actually
	# cares about. Old lines stay in the pool at falling odds (see
	# RegularNPC.get_dialogue), so early gruffness never fully disappears.
	def.dialogue_lines = [
		# Stranger — polite, brief, all business.
		DialogueLine.make("Shop's open. Something rattling?", DialogueLine.CALM, 0),
		DialogueLine.make("Bring it in if it's rattling. Rattles turn into walks home.", DialogueLine.CALM, 0),
		DialogueLine.make("Nothing's really broke. Just parts that haven't been put right yet.", DialogueLine.CALM, 0),
		# Acquaintance — starts doing small favours, notices your bike.
		DialogueLine.make("That chain could use oiling. No charge — takes me a second.", DialogueLine.HAPPY, 2),
		DialogueLine.make("Whole shop smells like grease and I stopped noticing years ago.", DialogueLine.HAPPY, 2),
		DialogueLine.make("You ride harder than most. I can tell from the brake pads.", DialogueLine.CALM, 2),
		# Friend — opens up about where the trade came from.
		DialogueLine.make("My old man works the junk yard, that's where I learned how to fix crap up.", DialogueLine.CALM, 5),
		DialogueLine.make("Dad could name a part by the sound it made falling off. Still can't do that.", DialogueLine.HAPPY, 5),
		DialogueLine.make("Half this shop came out of that yard. Don't tell anyone I said so.", DialogueLine.CALM, 5),
		# Close friend — quieter, more honest, says the warm thing outright.
		DialogueLine.make("Keep your spare key here if you want. Shop's never locked to you.", DialogueLine.HAPPY, 8),
		DialogueLine.make("Ought to visit the old man more. Keep meaning to. You know how it goes.", DialogueLine.SAD, 8),
		DialogueLine.make("Fixed a lot of bikes. Yours is the one I actually look forward to.", DialogueLine.HAPPY, 8),
	]
	# Gifts: Junk-yard raised: give him something to work with. Milk he leaves to curdle in the shop fridge.
	def.loved_gifts = ["scrap"]
	def.liked_gifts = ["bolts", "bread"]
	def.disliked_gifts = ["milk"]
	_add(def)

## Marco — the baker. Opens the cafe Tuesday to Saturday, starting his day at
## 4am to get the ovens on and heading home when he closes up at 5pm. Warm and
## chatty; greets everyone like an old friend.
func _register_marco() -> void:
	# Tue(2) Wed(3) Thu(4) Fri(5) Sat(6)
	var work_days : Array[int] = [2, 3, 4, 5, 6]
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "marco"
	def.display_name = "Marco"
	def.home_anchor  = "House98"          # just up the road from the cafe
	def.shirt_color  = Color("#f2e4cf")   # flour-dusted baker's whites
	def.pants_color  = Color("#8a5a3c")
	def.hair_color   = Color("#241a12")
	def.skin_color   = Color("#c98f63")
	var sched : Array[NPCScheduleEntry] = [
		# Working days: at the cafe from 4am until he closes at 5pm.
		NPCScheduleEntry.make_hours(work_days, 4.0, 17.0, "Cafe", Vector2(0, 40), -1, true),
		# Everything else (evenings, and all day Sunday and Monday): home.
		NPCScheduleEntry.make_hours([], 0.0, 24.0, "House98", Vector2(0, 20), -1, true),
	]
	def.schedule = sched
	def.random_dialogue = true
	def.dialogue_lines = [
		DialogueLine.make("Heyyy, there they are! Good to see you, friend.", DialogueLine.HAPPY),
		DialogueLine.make("Fresh out of the oven — you can smell it, yes? Come in, come in!", DialogueLine.HAPPY),
		DialogueLine.make("You work too hard. Sit, eat something. On me!", DialogueLine.HAPPY),
		DialogueLine.make("Up since four, and still smiling. That is the secret!", DialogueLine.CALM),
		DialogueLine.make("Any friend on a bicycle is a friend of mine.", DialogueLine.HAPPY),
	]
	# Gifts: A baker's holy trinity. Grease and metal near his kitchen, less so.
	def.loved_gifts = ["butter"]
	def.liked_gifts = ["bread", "milk"]
	def.disliked_gifts = ["scrap"]
	_add(def)

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
	# Gifts: She restocks the dairy case herself and has opinions about it.
	def.loved_gifts = ["milk"]
	def.liked_gifts = ["bread"]
	def.disliked_gifts = ["scrap"]
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
	# Gifts: Night shifts run on sandwiches. Scrap metal reads as evidence to her.
	def.loved_gifts = ["bread"]
	def.liked_gifts = ["milk", "butter"]
	def.disliked_gifts = ["scrap"]
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
	# Gifts: Old-school: butters everything. A bag of bolts is a bag of trouble.
	def.loved_gifts = ["butter"]
	def.liked_gifts = ["bread"]
	def.disliked_gifts = ["bolts"]
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
	# Gifts: Fence posts and gate hinges always need fixing. Her farm makes its own butter.
	def.loved_gifts = ["bolts"]
	def.liked_gifts = ["scrap", "milk"]
	def.disliked_gifts = ["butter"]
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
	# spider.png is 736x68: 8 frames of 92x68, one row (facing down). Height is
	# normalised automatically, so no manual scale is needed here.
	def.frame_size    = Vector2i(92, 68)
	def.frame_count   = 8
	def.sprite_offset = Vector2(0, -2)
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
	# Friendship tiers. Road-worn and laconic: starts on autopilot with the
	# stock musician patter, then lets the tiredness show, then the doubt, and
	# finally admits the touring is the part he'd give up. Elsie is his anchor
	# throughout — see _register_elsie_carrington.
	def.dialogue_lines = [
		# Stranger — stage patter he could say in his sleep.
		DialogueLine.make("Hey there. Catch us play sometime, yeah?", DialogueLine.HAPPY, 0),
		DialogueLine.make("Long night. Long tour. Same difference.", DialogueLine.CALM, 0),
		DialogueLine.make("Load in, play, load out. That's the whole job.", DialogueLine.CALM, 0),
		# Acquaintance — drops the patter, talks about the actual nights.
		DialogueLine.make("Pub crowd's small, but they listen. That's rarer than you'd think.", DialogueLine.CALM, 2),
		DialogueLine.make("Slept in the van again. Elsie pretends not to notice.", DialogueLine.HAPPY, 2),
		DialogueLine.make("You're up as late as I am. Respect.", DialogueLine.HAPPY, 2),
		# Friend — the cost of it starts showing.
		DialogueLine.make("Every town looks the same from a stage. This one doesn't. Don't know why.", DialogueLine.CALM, 5),
		DialogueLine.make("Wrote something on the road. Haven't played it for anyone yet.", DialogueLine.SAD, 5),
		DialogueLine.make("Mum worries when I'm away. Says she doesn't. She does.", DialogueLine.SAD, 5),
		# Close friend — says the quiet thing out loud.
		DialogueLine.make("Played that new one at soundcheck. Empty room. Thought of you, oddly.", DialogueLine.HAPPY, 8),
		DialogueLine.make("Tour ends and I'm relieved. Took me years to admit that bit.", DialogueLine.SAD, 8),
		DialogueLine.make("Come by the pub Saturday. I'll play you the one nobody's heard.", DialogueLine.HAPPY, 8),
	]
	# Gifts: Rattling hardware sounds like percussion to him. Milk before a gig, never.
	def.loved_gifts = ["bolts"]
	def.liked_gifts = ["bread", "scrap"]
	def.disliked_gifts = ["milk"]
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
		# Mondays off — grocery at 10am, the cafe at 1pm, home from 4pm.
		NPCScheduleEntry.make_hours([MON], 10.0, 13.0, "Grocery", Vector2(0, 40), -1, true),
		NPCScheduleEntry.make_hours([MON], 13.0, 16.0, "Cafe",    Vector2(0, 40), -1, true),
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
	# Gifts: A nurse's late-shift tea needs milk. Sharp metal she sees enough of at work.
	def.loved_gifts = ["milk"]
	def.liked_gifts = ["bread", "butter"]
	def.disliked_gifts = ["scrap"]
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
	# Gifts: Wholesome and sensible; she'll lecture you gently about the butter.
	def.loved_gifts = ["bread"]
	def.liked_gifts = ["milk"]
	def.disliked_gifts = ["butter"]
	_add(def)

## Jimmy Henderson — the Mayor's husband. Same routine as her for now (they
## travel together); at City Hall he also handles mortgage payments.
func _register_jimmy_henderson() -> void:
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "jimmy_henderson"
	def.display_name = "Jimmy Henderson"
	def.home_anchor  = "House96"          # shares the Mayor's home
	def.shirt_color  = Color("#4a7a5a")
	def.pants_color  = Color("#333f36")
	def.hair_color   = Color("#6a5a4a")
	# Identical to Mayor Henderson's schedule; both are interior, so the pair are
	# found inside City Hall by day and inside their home at night.
	var sched : Array[NPCScheduleEntry] = [
		NPCScheduleEntry.make([], Phase.DAY,    "Building_TownHall", Vector2(0, 40), -1, true),
		# Sunset counts as home time too — without this the phase falls through to
		# the plain home fallback, which parks them OUTSIDE the house for 7–9pm.
		NPCScheduleEntry.make([], Phase.SUNSET, "House96",           Vector2(0, 20), -1, true),
		NPCScheduleEntry.make([], Phase.NIGHT,  "House96",           Vector2(0, 20), -1, true),
	]
	def.schedule = sched
	def.random_dialogue = true
	def.dialogue_lines = [
		DialogueLine.make("Lovely day for it, isn't it?", DialogueLine.HAPPY),
		DialogueLine.make("The wife's busy running the town. I keep the books.", DialogueLine.CALM),
		DialogueLine.make("Mind how you go on that bicycle!", DialogueLine.CALM),
	]
	# Gifts: Banker's lunch. Scrap metal doesn't fit the City Hall aesthetic.
	def.loved_gifts = ["bread"]
	def.liked_gifts = ["butter", "milk"]
	def.disliked_gifts = ["scrap"]
	_add(def)

func _register_mayor_henderson() -> void:
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "mayor_henderson"
	def.display_name = "Mayor Henderson"
	def.home_anchor  = "House96"          # a home just south of City Hall
	def.shirt_color  = Color("#6a4a8a")   # mayoral purple
	def.pants_color  = Color("#33333f")
	def.hair_color   = Color("#9a9aa0")
	# The public face of the town: out front of City Hall greeting people through
	# the morning, then inside at her desk for the afternoon, home in the evening.
	# The last entry covers the whole day so no hour can fall through.
	var sched : Array[NPCScheduleEntry] = [
		NPCScheduleEntry.make_hours([],  8.0, 11.0, "Building_TownHall", Vector2(84, 42), -1, false),
		NPCScheduleEntry.make_hours([], 11.0, 17.0, "Building_TownHall", Vector2(0, 40),  -1, true),
		NPCScheduleEntry.make_hours([],  0.0, 24.0, "House96",           Vector2(0, 20),  -1, true),
	]
	def.schedule = sched
	def.dialogue_lines = [
		DialogueLine.make("Hi, how's the delivery business?", DialogueLine.SURPRISED),
	]
	# Gifts: Fond of the finer spread at civic receptions.
	def.loved_gifts = ["butter"]
	def.liked_gifts = ["bread"]
	def.disliked_gifts = ["bolts"]
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
	# Gifts: Tea and trivia night. Bolts she has no earthly use for.
	def.loved_gifts = ["milk"]
	def.liked_gifts = ["bread", "butter"]
	def.disliked_gifts = ["bolts"]
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
	# Gifts: Pub staple; he tinkers, and milk is not what he drinks.
	def.loved_gifts = ["bread"]
	def.liked_gifts = ["scrap", "bolts"]
	def.disliked_gifts = ["milk"]
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
	# Gifts: A kid's idea of a treat. Sharp scrap is not a toy.
	def.loved_gifts = ["butter"]
	def.liked_gifts = ["bread", "milk"]
	def.disliked_gifts = ["scrap"]
	_add(def)

# ── The Thorne family ──────────────────────────────
# Reverend Elias Thorne and his two children share the parsonage (House138),
# the house beside the church. Elias and his son Silas are not on easy terms:
# Silas took the grocery job instead of helping at the church, and neither of
# them says so directly. Junia is caught in the middle and stays out of it.
const THORNE_HOME : String = "House138"

## Silas's day off rotates through the working week (Mon–Sat) rather than being
## fixed, so the grocery isn't reliably staffed by him on any one weekday. It's
## derived from the week number so it feels random but stays stable: the same
## day all week, and a save/reload can't shuffle it mid-week.
## Sunday (0) is never returned — he's at church that morning regardless.
func silas_day_off(week_number: int) -> int:
	# 1..6, stepping by 5 each week so consecutive weeks aren't adjacent days.
	return 1 + ((week_number * 5) % 6)

## True when Silas is on shift at the grocery on `weekday` of the given week.
func silas_works_on(week_number: int, weekday: int) -> bool:
	if weekday == 0:
		return false
	return weekday != silas_day_off(week_number)

## Reverend Elias Thorne — the minister. Long Sunday service (7am–1:30pm) and
## weekday hours at the church Monday to Thursday (7am–3:30pm). Friday and
## Saturday are his days off, and he spends a few hours of each visiting either
## the farm or City Hall, alternating week by week via week_parity.
func _register_elias_thorne() -> void:
	const SUN : int = 0
	const FRI : int = 5
	const SAT : int = 6
	var church_days : Array[int] = [1, 2, 3, 4]   # Mon–Thu
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "elias_thorne"
	def.display_name = "Reverend Elias Thorne"
	def.home_anchor  = THORNE_HOME
	def.shirt_color  = Color("#2f3238")   # black clerical shirt
	def.pants_color  = Color("#26282d")
	def.hair_color   = Color("#8e8b86")   # grey, thinning
	def.skin_color   = Color("#e0bd97")
	# First match wins, so the day-off visits come before the home fallback.
	var sched : Array[NPCScheduleEntry] = [
		# Sunday: the service, then out on the church steps to see people off.
		NPCScheduleEntry.make_hours([SUN], 7.0, 13.5, "Church", Vector2(0, 40), -1, true),
		NPCScheduleEntry.make_hours([SUN], 13.5, 15.0, "Church", Vector2(70, 55), -1, false),
		# Monday–Thursday: at the church through the working day.
		NPCScheduleEntry.make_hours(church_days, 7.0, 15.5, "Church", Vector2(0, 40), -1, true),
		# Days off (Fri/Sat): the farm on even weeks, City Hall on odd ones.
		NPCScheduleEntry.make_hours([FRI, SAT], 10.0, 14.0, "Farm", Vector2(0, 30), 0, true),
		NPCScheduleEntry.make_hours([FRI, SAT], 10.0, 14.0, "Building_TownHall", Vector2(0, 40), 1, true),
		# Everything else: home at the parsonage next door.
		NPCScheduleEntry.make_hours([], 0.0, 24.0, THORNE_HOME, Vector2(0, 20), -1, true),
	]
	def.schedule = sched
	def.random_dialogue = true
	def.dialogue_lines = [
		DialogueLine.make("The door's open all week, not just Sundays. Worth remembering.", DialogueLine.CALM),
		DialogueLine.make("You've met my daughter, I'm sure. Junia. She's the bright one.", DialogueLine.HAPPY),
		DialogueLine.make("My son works the grocery now. It's steady work. Steady is fine.", DialogueLine.SAD),
		DialogueLine.make("I asked Silas for one morning a week. One. He had his reasons.", DialogueLine.MAD),
		DialogueLine.make("Mind the hill on that bicycle. I've buried more sensible men.", DialogueLine.CALM),
	]
	# Gifts: Communion bread above all; scrap is clutter in a tidy vestry.
	def.loved_gifts = ["bread"]
	def.liked_gifts = ["butter", "milk"]
	def.disliked_gifts = ["scrap"]
	_add(def)

## Silas Thorne — the minister's son. At church for the Sunday morning service
## (7am–noon) but leaves before his father is finished, then works the grocery
## the rest of the week with one rotating day off, which he spends at home.
func _register_silas_thorne() -> void:
	const SUN : int = 0
	var work_days : Array[int] = [1, 2, 3, 4, 5, 6]
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "silas_thorne"
	def.display_name = "Silas Thorne"
	def.home_anchor  = THORNE_HOME
	def.shirt_color  = Color("#7c6a9c")   # muted purple
	def.pants_color  = Color("#3d4457")
	def.hair_color   = Color("#4a3b2c")
	def.skin_color   = Color("#e0bd97")
	# His day off rotates week to week, which a fixed weekday list can't express,
	# so one stay-home entry is emitted per week parity in front of the grocery
	# shift. Parity only gives two distinct weeks, so the rotation repeats every
	# fortnight — widen this if week_parity ever grows more states.
	var sched : Array[NPCScheduleEntry] = []
	for w in 2:
		var off_days : Array[int] = [silas_day_off(w)]
		sched.append(NPCScheduleEntry.make_hours(off_days, 0.0, 24.0, THORNE_HOME, Vector2(0, 20), w, true))
	sched.append_array([
		# Sunday: the service, but only the first half of it.
		NPCScheduleEntry.make_hours([SUN], 7.0, 12.0, "Church", Vector2(40, 40), -1, true),
		# Otherwise: behind the counter at the grocery.
		NPCScheduleEntry.make_hours(work_days, 8.0, 18.0, "Grocery", Vector2(0, 40), -1, true),
		# Everything else: home.
		NPCScheduleEntry.make_hours([], 0.0, 24.0, THORNE_HOME, Vector2(0, 20), -1, true),
	])
	def.schedule = sched
	def.random_dialogue = true
	def.dialogue_lines = [
		DialogueLine.make("Deliveries go round the back. I'll sign for it.", DialogueLine.CALM),
		DialogueLine.make("I like the shop. Nobody here expects anything of me by noon.", DialogueLine.CALM),
		DialogueLine.make("Yeah, that's my father. We manage.", DialogueLine.SAD),
		DialogueLine.make("I go to the service. I just don't stay for the whole thing.", DialogueLine.MAD),
		DialogueLine.make("Junia says I should talk to him. Junia says a lot of things.", DialogueLine.CALM),
	]
	# Gifts: anything that isn't stock he shelves all week; bread is a busman's holiday.
	def.loved_gifts = ["butter"]
	def.liked_gifts = ["scrap", "bolts"]
	def.disliked_gifts = ["bread"]
	_add(def)

## Junia Thorne — the minister's daughter. Church on Sunday mornings, school
## Monday to Friday. Saturdays she either goes along with her father on his
## visits or takes herself off to the field beside the school, alternating week
## by week in step with whichever visit her father is making.
func _register_junia_thorne() -> void:
	const SUN : int = 0
	const SAT : int = 6
	var school_days : Array[int] = [1, 2, 3, 4, 5]   # Mon–Fri
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "junia_thorne"
	def.display_name = "Junia Thorne"
	def.home_anchor  = THORNE_HOME
	def.shirt_color  = Color("#e6b8c8")   # pale rose
	def.pants_color  = Color("#5a6b8c")
	def.hair_color   = Color("#6b4a2c")
	def.skin_color   = Color("#e0bd97")
	var sched : Array[NPCScheduleEntry] = [
		# Sunday: the full service, sat alongside her father.
		NPCScheduleEntry.make_hours([SUN], 7.0, 13.5, "Church", Vector2(-40, 40), -1, true),
		# Saturday: even weeks she tags along to the farm with her father; odd weeks
		# she's out in the field beside the school instead.
		NPCScheduleEntry.make_hours([SAT], 10.0, 14.0, "Farm", Vector2(-40, 30), 0, true),
		NPCScheduleEntry.make_hours([SAT], 10.0, 15.0, "School", Vector2(0, 90), 1, false).wandering(120.0),
		# Monday–Friday: school.
		NPCScheduleEntry.make_hours(school_days, 9.0, 15.5, "School", Vector2(0, 40), -1, true),
		# Everything else: home.
		NPCScheduleEntry.make_hours([], 0.0, 24.0, THORNE_HOME, Vector2(0, 20), -1, true),
	]
	def.schedule = sched
	def.random_dialogue = true
	def.dialogue_lines = [
		DialogueLine.make("There's a field past the school where nobody looks for me.", DialogueLine.HAPPY),
		DialogueLine.make("Papa and Silas are being ridiculous. Both of them. Equally.", DialogueLine.MAD),
		DialogueLine.make("I get the whole sermon and Silas gets half. He thinks I don't notice.", DialogueLine.CALM),
		DialogueLine.make("Do you ever deliver anywhere far? Properly far?", DialogueLine.SURPRISED),
		DialogueLine.make("If you see Silas, tell him I said to come for supper.", DialogueLine.CALM),
	]
	# Gifts: a kid's sweet tooth; scrap metal is her brother's kind of present.
	def.loved_gifts = ["milk"]
	def.liked_gifts = ["butter", "bread"]
	def.disliked_gifts = ["scrap"]
	_add(def)
