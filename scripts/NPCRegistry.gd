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
	# Deferred: InteriorRegistry, which knows the reserved rooms, is the next
	# autoload and isn't ready yet.
	_check_player_homes.call_deferred()

## The player's home is reserved (InteriorRegistry.is_reserved_room): nobody
## else lives in the house, or in flat 301 if it's the apartments, so whichever
## one is bought is the player's alone. The rest of the apartment block — the
## lobby and the other flats — is shared, and villagers can live there.
## Nothing enforces that in the data, so this shouts during development if a
## villager is given a reserved room as a home or is scheduled to go inside
## one — far easier to catch here than to notice a flatmate months later.
func _check_player_homes() -> void:
	for def in _defs.values():
		if InteriorRegistry.is_reserved_room(def.home_anchor):
			push_warning("NPCRegistry: '%s' lives in %s, which is reserved for the player."
				% [def.id, def.home_anchor])
		for entry in def.schedule:
			if entry.interior and InteriorRegistry.is_reserved_room(entry.anchor):
				push_warning("NPCRegistry: '%s' is scheduled inside %s, which is reserved for the player."
					% [def.id, entry.anchor])

func get_definition(id: String) -> NPCDefinition:
	return _defs.get(id)

func all_definitions() -> Array:
	return _defs.values()

func has(id: String) -> bool:
	return _defs.has(id)

func _add(def: NPCDefinition) -> void:
	def.load_sheet_layout()
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
	_register_cast()
	_apply_fruitcake_tastes()

## Fruitcake is sold at the farm every winter and almost nobody wants it. Rather
## than repeat that in every villager's gift lists, it's settled here once the
## whole cast exists: everyone dislikes it unless listed below.
const FRUITCAKE_LOVERS  : Array[String] = [
	"jimmy_henderson",   # the one man in town who buys it on purpose
]
const FRUITCAKE_NEUTRAL : Array[String] = [
	"marsha_campbell",   # she sells it; she's not going to insult the stock
]
const FRUITCAKE_HATERS  : Array[String] = [
	"mayor_henderson",   # thirty Christmases of Jimmy's fruitcake
	"marco",             # takes it personally, as a baker
	"spider",
	"teri_sanders",
	"noah", "poppy", "apple_campbell", "junia_thorne",   # the kids
]

func _apply_fruitcake_tastes() -> void:
	for def in _defs.values():
		if FRUITCAKE_NEUTRAL.has(def.id):
			continue
		if FRUITCAKE_LOVERS.has(def.id):
			def.loved_gifts.append("fruitcake")
		elif FRUITCAKE_HATERS.has(def.id):
			def.hated_gifts.append("fruitcake")
		else:
			def.disliked_gifts.append("fruitcake")

func _register_cast() -> void:
	_register_mayor_henderson()
	_register_jimmy_henderson()
	_register_doctor_carrington()
	_register_elsie_carrington()
	_register_spider()
	_register_flower_campbell()
	_register_marsha_campbell()
	_register_apple_campbell()
	_register_kali()
	_register_darin()
	_register_cole()
	_register_james()
	_register_nicolle()
	_register_noah()
	_register_nayra()
	_register_marco()
	_register_aidan()
	_register_bill()
	_register_wendell_price()
	_register_olivia_price()
	_register_elias_thorne()
	_register_silas_thorne()
	_register_junia_thorne()
	_register_teri_sanders()
	_register_declan_murphy()
	_register_rosie_finch()

# ── The pub ────────────────────────────────────────────────
## Declan Murphy and Rosie Finch run the pub together and live in House50, right
## next door. They got engaged last spring and are planning the wedding between
## shifts: Declan keeps the bar and the cellar, Rosie runs the kitchen and the
## books. The pub opens at 11am and closes at 1am every day, so the two of them
## are behind the bar most waking hours and each takes one weekday afternoon off.
## Teri Sanders works for them Wednesday to Sunday nights.
const PUB_HOME : String = "House50"

## Declan Murphy — the landlord. Big, warm, and sentimental about the place; he
## proposed to Rosie in the pub after closing. Tuesdays he takes the afternoon to
## buy produce at the farm, then goes home and leaves Rosie to open the evening.
func _register_declan_murphy() -> void:
	const TUE : int = 2
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "declan_murphy"
	def.display_name = "Declan Murphy"
	def.home_anchor  = PUB_HOME
	def.shirt_color  = Color("#2f5a3a")   # bottle-green shirt
	def.pants_color  = Color("#3a3028")
	def.hair_color   = Color("#a0472a")   # ginger
	def.skin_color   = Color("#f0c8a0")
	# First match wins, so the Tuesday errand comes before the bar shift.
	var sched : Array[NPCScheduleEntry] = [
		# Tuesday afternoon: the farm for the week's produce, then home.
		NPCScheduleEntry.make_hours([TUE], 12.0, 15.0, "Farm", Vector2(30, 30), -1, true),
		NPCScheduleEntry.make_hours([TUE], 15.0, 24.0, PUB_HOME, Vector2(0, 20), -1, true),
		# Every other day: behind the bar from opening at 11am…
		NPCScheduleEntry.make_hours([], 11.0, 24.0, "Pub", Vector2(20, 20), -1, true),
		# …until close at 1am.
		NPCScheduleEntry.make_hours([], 0.0, 1.0, "Pub", Vector2(20, 20), -1, true),
		# Everything else: home next door.
		NPCScheduleEntry.make_hours([], 0.0, 24.0, PUB_HOME, Vector2(0, 20), -1, true),
	]
	def.schedule = sched
	def.random_dialogue = true
	# Friendship tiers: publican patter, then the pub's history, then how much
	# he can't believe Rosie said yes.
	def.dialogue_lines = [
		# Stranger — the landlord's welcome.
		DialogueLine.make("Welcome in! Declan. I pour, Rosie cooks, and nobody argues with either of us.", DialogueLine.HAPPY, 0),
		DialogueLine.make("Delivery for the pub? Round the side, mind the kegs.", DialogueLine.CALM, 0),
		DialogueLine.make("You look like a soup-of-the-day sort of person. Rosie's is the best in town.", DialogueLine.HAPPY, 0),
		# Acquaintance — the regulars and the wedding.
		DialogueLine.make("Gus has had the same stool for twenty years. We'll bury him in it.", DialogueLine.HAPPY, 2),
		DialogueLine.make("Rosie and I are getting married. You'll hear about it. Everyone hears about it.", DialogueLine.HAPPY, 2),
		DialogueLine.make("Wedding budget, pub budget. Same budget. Don't tell Rosie I said that.", DialogueLine.CALM, 2),
		# Friend — what the place means to him.
		DialogueLine.make("My dad ran this pub before me. I still hear him every time the cellar door creaks.", DialogueLine.CALM, 5),
		DialogueLine.make("Asked Spider to play the wedding. He said yes before I finished asking.", DialogueLine.HAPPY, 5),
		DialogueLine.make("Rosie wants the reception somewhere fancy. I want it here. Guess who'll win.", DialogueLine.MAD, 5),
		# Close friend — the soft centre.
		DialogueLine.make("I proposed right there behind the bar, after close. Dropped the ring in the sink first.", DialogueLine.HAPPY, 8),
		DialogueLine.make("Some nights I watch her laughing with the regulars and think, how did I get this lucky.", DialogueLine.CALM, 8),
		DialogueLine.make("Keep a seat free on the big day. Front row. You've earned it.", DialogueLine.HAPPY, 8),
	]
	# Gifts: a meat pie is a proper pub supper; milk has no place behind his bar.
	def.loved_gifts = ["meat_pie"]
	def.liked_gifts = ["bread", "onions"]
	def.disliked_gifts = ["milk"]
	_add(def)

## Rosie Finch — the landlady. Sharp, organised and funny; she runs the kitchen,
## the books, and very firmly the wedding. Monday afternoons she meets Reverend
## Thorne at the church to plan the ceremony, then has the evening off at home.
func _register_rosie_finch() -> void:
	const MON : int = 1
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "rosie_finch"
	def.display_name = "Rosie Finch"
	def.home_anchor  = PUB_HOME
	def.shirt_color  = Color("#c8584a")   # brick red
	def.pants_color  = Color("#3d3a4a")
	def.hair_color   = Color("#3a2418")   # dark brown
	def.skin_color   = Color("#d9a57c")
	# First match wins, so the Monday church visit comes before the bar shift.
	var sched : Array[NPCScheduleEntry] = [
		# Monday afternoon: wedding planning with the Reverend, then home.
		NPCScheduleEntry.make_hours([MON], 13.0, 15.0, "Church", Vector2(30, 40), -1, true),
		NPCScheduleEntry.make_hours([MON], 15.0, 24.0, PUB_HOME, Vector2(20, 20), -1, true),
		# Every other day: in the kitchen and behind the bar from 11am…
		NPCScheduleEntry.make_hours([], 11.0, 24.0, "Pub", Vector2(-20, 20), -1, true),
		# …until close at 1am.
		NPCScheduleEntry.make_hours([], 0.0, 1.0, "Pub", Vector2(-20, 20), -1, true),
		# Everything else: home next door.
		NPCScheduleEntry.make_hours([], 0.0, 24.0, PUB_HOME, Vector2(20, 20), -1, true),
	]
	def.schedule = sched
	def.random_dialogue = true
	# Friendship tiers: brisk landlady, then the wedding planner, then the nerves.
	def.dialogue_lines = [
		# Stranger — brisk and friendly.
		DialogueLine.make("Hi love, Rosie. Kitchen's open till nine — after that it's crisps or nothing.", DialogueLine.HAPPY, 0),
		DialogueLine.make("If Declan offers you a 'house special', it's whatever he forgot to order.", DialogueLine.HAPPY, 0),
		DialogueLine.make("Wipe your feet. I've just done the floor and I will know.", DialogueLine.MAD, 0),
		# Acquaintance — the ring and the plans.
		DialogueLine.make("Did you see the ring? Look. No, properly look.", DialogueLine.HAPPY, 2),
		DialogueLine.make("Mondays I see the Reverend about the ceremony. He's very patient. I am not.", DialogueLine.CALM, 2),
		DialogueLine.make("Teri's covering more nights so we can plan. That girl's a saint in eyeliner.", DialogueLine.HAPPY, 2),
		# Friend — the business behind the bar.
		DialogueLine.make("Declan's brilliant with people and hopeless with numbers. That's what I'm for.", DialogueLine.CALM, 5),
		DialogueLine.make("He wants the reception here. Honestly? I do too. I'm just making him sweat.", DialogueLine.HAPPY, 5),
		DialogueLine.make("Seating plan's a nightmare. Half this town isn't speaking to the other half.", DialogueLine.MAD, 5),
		# Close friend — the nerves.
		DialogueLine.make("My mum never thought I'd settle. Running a pub, marrying the landlord. Bit of a cliché.", DialogueLine.SAD, 8),
		DialogueLine.make("Sometimes I wonder if I'm ready. Then he does something daft and I know I am.", DialogueLine.CALM, 8),
		DialogueLine.make("You're on the guest list. In pen. Do you know how rare pen is?", DialogueLine.HAPPY, 8),
	]
	# Gifts: a baker's pie tempts the cook; scrap is clutter in her kitchen.
	def.loved_gifts = ["blueberry_pie"]
	def.liked_gifts = ["butter", "flour", "strawberries"]
	def.disliked_gifts = ["scrap"]
	_add(def)

## Wendell Price — runs the hardware store, which he's been quietly turning
## into an electronics shop: the nails and paint are still at the front, but
## the back is all the new stock he can't stop talking about. Open Monday to
## Saturday, 9am–6pm; Sunday afternoons he volunteers at the library, keeping
## its old computers alive — the library his wife Olivia runs (see
## _register_olivia_price). They live together in Townhouse25. Earnest, a bit
## of a gadget evangelist, and the town's go-to for anything with a plug.
## (House3 is nearer the store but is left free: it's the likely real home for
## Aidan and Bill — see AIDAN_HOME.)
const WENDELL_HOME : String = "Townhouse25"

func _register_wendell_price() -> void:
	const SUN : int = 0
	var open_days : Array[int] = [1, 2, 3, 4, 5, 6]
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "wendell_price"
	def.display_name = "Wendell Price"
	def.home_anchor  = WENDELL_HOME
	def.shirt_color  = Color("#c0392b")   # red store apron
	def.pants_color  = Color("#3a4a5a")   # navy chinos
	def.hair_color   = Color("#2b2522")   # near-black, neatly parted
	def.skin_color   = Color("#c68a5e")
	# First match wins, so the store and library come before the home fallback.
	var sched : Array[NPCScheduleEntry] = [
		NPCScheduleEntry.make_hours(open_days, 9.0, 18.0, "Hardware", Vector2(0, 40), -1, true),
		NPCScheduleEntry.make_hours([SUN], 13.0, 16.0, "Library", Vector2(0, 40), -1, true),
		NPCScheduleEntry.make_hours([], 0.0, 24.0, WENDELL_HOME, Vector2(0, 20), -1, true),
	]
	def.schedule = sched
	def.random_dialogue = true
	# Friendship tiers: the sales pitch, then the shop's reinvention, then why
	# he really cares about it.
	def.dialogue_lines = [
		# Stranger — the pitch, never quite switched off.
		DialogueLine.make("Welcome to Price's! Hammers at the front, the future at the back.", DialogueLine.HAPPY, 0),
		DialogueLine.make("Only one computer in stock right now. One's all this town needs to get started.", DialogueLine.HAPPY, 0),
		DialogueLine.make("If it plugs in, I sell it. If it doesn't, I probably still sell it.", DialogueLine.CALM, 0),
		# Acquaintance — the shop he's turning it into.
		DialogueLine.make("Dad sold nails here for forty years. I'm keeping the nails. Mostly.", DialogueLine.CALM, 2),
		DialogueLine.make("Ordered a television for the window. The whole street's going to stop and stare.", DialogueLine.HAPPY, 2),
		DialogueLine.make("Bill at the yard brings me dead radios. Half of them only need a fuse.", DialogueLine.HAPPY, 2),
		# Friend — the library and the town.
		DialogueLine.make("Sundays I fix the library computers. They're older than Junia Thorne.", DialogueLine.HAPPY, 5),
		DialogueLine.make("Olivia runs the library. I sell the future, she guards the past. It works.", DialogueLine.HAPPY, 5),
		DialogueLine.make("Some folk think a computer's a waste of money in a town this size. Some folk.", DialogueLine.MAD, 5),
		DialogueLine.make("A delivery business with a computer? You'd have routes planned before breakfast.", DialogueLine.CALM, 5),
		# Close friend — what it's actually about.
		DialogueLine.make("I just don't want this town to get left behind. Is that silly?", DialogueLine.SAD, 8),
		DialogueLine.make("You're the only one who lets me finish explaining a gadget. Besides Olivia. Thank you.", DialogueLine.HAPPY, 8),
		DialogueLine.make("If you ever need anything wired up, you come to me first. Not a question.", DialogueLine.CALM, 8),
	]
	# Gifts: a bag of bolts is never wasted in a hardware store; jam on the
	# keyboard is how computers die.
	def.loved_gifts = ["bolts"]
	def.liked_gifts = ["scrap", "bread", "milk"]
	def.disliked_gifts = ["jam"]
	_add(def)

## Olivia Price — Wendell's wife, the town librarian. Runs the library Monday to
## Friday, 10am–8pm, and doesn't set foot in it at weekends: that's when Wendell
## takes his screwdrivers to its computers, and she'd rather not watch. Weekends
## she's at home. Precise, dry and warmer than she lets on; she fondly tolerates
## Wendell's gadgets and lends out books like she's matchmaking.
func _register_olivia_price() -> void:
	var open_days : Array[int] = [1, 2, 3, 4, 5]
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "olivia_price"
	def.display_name = "Olivia Price"
	def.home_anchor  = WENDELL_HOME
	def.shirt_color  = Color("#5b6e8c")   # slate cardigan
	def.pants_color  = Color("#3a3340")   # charcoal skirt
	def.hair_color   = Color("#8a5a3a")   # auburn, pinned up
	def.skin_color   = Color("#e3b48c")
	var sched : Array[NPCScheduleEntry] = [
		# Weekdays: the library, opening to close.
		NPCScheduleEntry.make_hours(open_days, 10.0, 20.0, "Library", Vector2(-40, 40), -1, true),
		# Everything else, weekends included: home with Wendell.
		NPCScheduleEntry.make_hours([], 0.0, 24.0, WENDELL_HOME, Vector2(20, 20), -1, true),
	]
	def.schedule = sched
	def.random_dialogue = true
	# Friendship tiers: the stern librarian, then the books and Wendell, then
	# what the library means to her.
	def.dialogue_lines = [
		# Stranger — quiet voice, firm rules.
		DialogueLine.make("Welcome to the library. Indoor voices, please. Yes, that one too.", DialogueLine.CALM, 0),
		DialogueLine.make("Open ten till eight, Monday to Friday. Weekends the books get their rest.", DialogueLine.CALM, 0),
		DialogueLine.make("You'll want a library card. Everyone wants a library card eventually.", DialogueLine.HAPPY, 0),
		# Acquaintance — books, and the man she married.
		DialogueLine.make("I've a book for you. I don't know which yet. Come back Thursday.", DialogueLine.HAPPY, 2),
		DialogueLine.make("Wendell's selling computers now. I married a man who thinks paper is a phase.", DialogueLine.CALM, 2),
		DialogueLine.make("Someone returned a cookbook with jam on every page. I have suspicions.", DialogueLine.MAD, 2),
		# Friend — the regulars and the cat.
		DialogueLine.make("Dewey sleeps in the history section. He's read nothing, but he's very well informed.", DialogueLine.HAPPY, 5),
		DialogueLine.make("Junia Thorne reads three books a week. I keep a shelf back just for her.", DialogueLine.HAPPY, 5),
		DialogueLine.make("Wendell fixes our computers on Sundays. I stay home. Marriage is knowing when.", DialogueLine.CALM, 5),
		# Close friend — why she does it.
		DialogueLine.make("A town that keeps its library keeps its memory. I take that seriously.", DialogueLine.CALM, 8),
		DialogueLine.make("Wendell worries the town's being left behind. I worry it'll forget what it was.", DialogueLine.SAD, 8),
		DialogueLine.make("I'd lend you any book in the building. Even the ones I don't lend.", DialogueLine.HAPPY, 8),
	]
	# Gifts: tea and toast between shelves; nothing sticky near the books, and
	# scrap metal is Wendell's department.
	def.loved_gifts = ["milk"]
	def.liked_gifts = ["bread", "blueberry_pie", "strawberries"]
	def.disliked_gifts = ["jam", "scrap"]
	_add(def)

## Teri Sanders — serves at the pub five nights a week (Wednesday to Sunday,
## 5pm to 1am) while she saves up and chases modelling work. Outgoing and quick
## with a line: she knows every regular by name and treats the bar like a stage.
## Monday and Tuesday are her nights off; Tuesday afternoons she takes her
## portfolio to the cafe. Lives in House55, a short walk down from the pub.
const TERI_HOME : String = "House55"

func _register_teri_sanders() -> void:
	const MON : int = 1
	const TUE : int = 2
	# Wed(3) Thu(4) Fri(5) Sat(6) Sun(0). The shift runs past midnight, and
	# entries match the *current* weekday, so the last hour of each shift is
	# written against the following day (Thu–Mon), as with Aidan's nights out.
	var shift_nights : Array[int] = [3, 4, 5, 6, 0]
	var shift_tails  : Array[int] = [4, 5, 6, 0, 1]
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "teri_sanders"
	def.display_name = "Teri Sanders"
	def.home_anchor  = TERI_HOME
	def.shirt_color  = Color("#1f1c24")   # black bar-staff top
	def.pants_color  = Color("#8a2f4a")   # plum
	def.hair_color   = Color("#e8c46a")   # honey blonde
	def.skin_color   = Color("#f0c8a0")
	# First match wins, so the pub and cafe entries come before the home fallback.
	var sched : Array[NPCScheduleEntry] = [
		# Working nights: behind the bar from 5pm…
		NPCScheduleEntry.make_hours(shift_nights, 17.0, 24.0, "Pub", Vector2(50, 20), -1, true),
		# …until close at 1am the next morning.
		NPCScheduleEntry.make_hours(shift_tails, 0.0, 1.0, "Pub", Vector2(50, 20), -1, true),
		# Tuesday afternoon: portfolio and a latte at the cafe.
		NPCScheduleEntry.make_hours([TUE], 13.0, 16.0, "Cafe", Vector2(-40, 40), -1, true),
		# Everything else (sleeping in after late shifts, and Monday off): home.
		NPCScheduleEntry.make_hours([], 0.0, 24.0, TERI_HOME, Vector2(0, 20), -1, true),
	]
	def.schedule = sched
	def.random_dialogue = true
	# Friendship tiers. Loud and friendly from the first hello — she is the
	# pub's welcome committee — then the modelling ambitions, then the doubt she
	# keeps under the smile. Old lines stay in the pool at falling odds.
	def.dialogue_lines = [
		# Stranger — bar patter, and she means every word.
		DialogueLine.make("Hiya! You're new. I'm Teri — I never forget a face, so don't make me.", DialogueLine.HAPPY, 0),
		DialogueLine.make("Pub opens at five. First one's on me if you tell me a good story.", DialogueLine.HAPPY, 0),
		DialogueLine.make("Love the bike. Very 'windswept courier.' It's working for you.", DialogueLine.HAPPY, 0),
		# Acquaintance — the other job.
		DialogueLine.make("Serving's the day job. Well, night job. I'm a model. Aspiring. Same thing!", DialogueLine.HAPPY, 2),
		DialogueLine.make("Had a casting call in the city Monday. They said 'we'll be in touch.' Classic.", DialogueLine.CALM, 2),
		DialogueLine.make("Five nights a week on my feet. Honestly, it's basically runway training.", DialogueLine.HAPPY, 2),
		# Friend — what it actually takes.
		DialogueLine.make("Tuesdays I sit in the cafe redoing my portfolio. Marco says I'm his best decor.", DialogueLine.HAPPY, 5),
		DialogueLine.make("Forty rejections this year. I count them. Is that weird? It's probably weird.", DialogueLine.SAD, 5),
		DialogueLine.make("Some bloke told me I'd never make it out of a small-town pub. Watch me.", DialogueLine.MAD, 5),
		# Close friend — the quiet version of her.
		DialogueLine.make("If I ever do make it, I'm going to miss this place more than I let on.", DialogueLine.CALM, 8),
		DialogueLine.make("You're the only one who asks how the castings went and actually waits for the answer.", DialogueLine.HAPPY, 8),
		DialogueLine.make("Got a callback! A real one! You're the first person I've told.", DialogueLine.SURPRISED, 8),
	]
	# Gifts: runs on lattes between castings; butter is off the menu before a shoot.
	def.loved_gifts = ["milk"]
	def.liked_gifts = ["bread"]
	def.disliked_gifts = ["butter"]
	_add(def)

## Cole — the firefighter. Works out of the Firehouse on alternating weeks, days
## one week and nights the next, on the same week_parity pattern as Doctor
## Carrington's hospital shifts. Young, loud and relentlessly cheerful: the sort
## who tips his helmet at everyone and means it. Lives in Townhouse30, the
## nearest free house to the Firehouse — the Apartments is reserved for the
## player (see GameManager.PLAYER_HOME_IDS).
const COLE_HOME : String = "Townhouse30"

func _register_cole() -> void:
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "cole"
	def.display_name = "Cole"
	def.home_anchor  = COLE_HOME
	def.shirt_color  = Color("#d8b440")   # yellow turnout coat
	def.pants_color  = Color("#b89a5a")   # tan turnout trousers
	def.hair_color   = Color("#7a4ab8")   # purple
	def.skin_color   = Color("#f0c8a0")
	# The portrait file is "Cole.jpg", capitalised, where the id-based lookup
	# would ask for "cole.jpg". That happens to work on Windows, whose disk
	# ignores case, but an exported build is case-sensitive and would show no
	# portrait. Naming the exact file sidesteps it.
	def.portrait_path = "res://assets/Portraits/Cole.jpg"
	# Mirrors Doctor Carrington: week_parity 0 = even weeks, 1 = odd weeks. All
	# interior, so he's found by going inside.
	var sched : Array[NPCScheduleEntry] = [
		# Even weeks — day shift: at the Firehouse through the day and evening,
		# home overnight.
		NPCScheduleEntry.make([], Phase.DAY,    "Firehouse", Vector2(0, 40), 0, true),
		NPCScheduleEntry.make([], Phase.SUNSET, "Firehouse", Vector2(0, 40), 0, true),
		NPCScheduleEntry.make([], Phase.NIGHT,  COLE_HOME,   Vector2(0, 20), 0, true),
		# Odd weeks — night shift: sleeps through the day, on at sunset, stays
		# the night.
		NPCScheduleEntry.make([], Phase.DAY,    COLE_HOME,   Vector2(0, 20), 1, true),
		NPCScheduleEntry.make([], Phase.SUNSET, "Firehouse", Vector2(0, 40), 1, true),
		NPCScheduleEntry.make([], Phase.NIGHT,  "Firehouse", Vector2(0, 40), 1, true),
	]
	def.schedule = sched
	# Friendship tiers, as with the mayor and Aidan: all enthusiasm at first,
	# then the job, then the part of it he doesn't joke about. Older lines stay
	# in the pool at falling odds (see RegularNPC.get_dialogue).
	def.random_dialogue = true
	def.dialogue_lines = [
		# Stranger — the cheerful public face.
		DialogueLine.make("Heya! Cole, Fire Department. Stay safe out there!", DialogueLine.HAPPY, 0),
		DialogueLine.make("Smoke alarm working? Test it tonight. Promise me.", DialogueLine.CALM, 0),
		DialogueLine.make("Nice bike! Wear a helmet, though. I'm a big helmet guy.", DialogueLine.HAPPY, 0),
		# Acquaintance — station life.
		DialogueLine.make("Station's quiet today. Quiet's good. Quiet means nobody's having a bad day.", DialogueLine.CALM, 2),
		DialogueLine.make("I'm on cooking duty this week. Pray for the crew.", DialogueLine.HAPPY, 2),
		DialogueLine.make("Night shifts mess with my head. I had breakfast at 7pm yesterday.", DialogueLine.CALM, 2),
		# Friend — why he does it.
		DialogueLine.make("Most of the job's rescuing cats and checking alarms. Honestly? I love it.", DialogueLine.HAPPY, 5),
		DialogueLine.make("Got into this after a fire on my street as a kid. Firefighters were so calm.", DialogueLine.CALM, 5),
		DialogueLine.make("You're out on those roads more than anyone. You see smoke, you call me. Deal?", DialogueLine.CALM, 5),
		# Close friend — the part he doesn't joke about.
		DialogueLine.make("Some calls stay with you. I don't talk about those much. Thanks for not asking.", DialogueLine.SAD, 8),
		DialogueLine.make("After a rough shift, running into you kind of fixes the day.", DialogueLine.HAPPY, 8),
		DialogueLine.make("If anything ever happens to your place, I'm there first. Not even a question.", DialogueLine.CALM, 8),
	]
	# Gifts: station cooking runs on bread; bolts are just clutter in the truck.
	def.loved_gifts = ["bread"]
	def.liked_gifts = ["milk", "butter"]
	def.disliked_gifts = ["bolts"]
	_add(def)

# ── The Brookes ────────────────────────────────────────────
## James (fire marshal), his wife Nicolle (teacher at the school) and their son
## Noah. They share a house a short walk from the school, which is where two of
## the three go every weekday.
##
## James runs the opposite shift rota to Cole: where Cole is on days, James is
## on nights. They overlap at sunset both weeks, which reads as the handover.
const BROOKE_HOME : String = "House130"

## Family skin tones, kept together so they stay consistent if they are retuned.
const BROOKE_SKIN_ADULT : Color = Color("#5e3c28")
const BROOKE_SKIN_CHILD : Color = Color("#6b4630")

## James — the fire marshal. Not front-line like Cole: he runs inspections and
## works out what started things, so he is the one telling you your extinguisher
## is out of date. Dry, precise, and fonder of people than he lets on.
func _register_james() -> void:
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "james"
	def.display_name = "James"
	def.home_anchor  = BROOKE_HOME
	def.shirt_color  = Color("#e4e6ee")   # white marshal's dress shirt
	def.pants_color  = Color("#2a2f3d")   # navy
	def.hair_color   = Color("#1b1310")
	def.skin_color   = BROOKE_SKIN_ADULT
	# The mirror image of Cole's rota (see _register_cole): parity 0 = even
	# weeks, 1 = odd. Where Cole works days, James works nights. Both are at the
	# station at sunset, which is the shift handover.
	var sched : Array[NPCScheduleEntry] = [
		# Even weeks — night shift.
		NPCScheduleEntry.make([], Phase.DAY,    BROOKE_HOME, Vector2(-25, 20), 0, true),
		NPCScheduleEntry.make([], Phase.SUNSET, "Firehouse",  Vector2(-25, 40), 0, true),
		NPCScheduleEntry.make([], Phase.NIGHT,  "Firehouse",  Vector2(-25, 40), 0, true),
		# Odd weeks — day shift.
		NPCScheduleEntry.make([], Phase.DAY,    "Firehouse",  Vector2(-25, 40), 1, true),
		NPCScheduleEntry.make([], Phase.SUNSET, "Firehouse",  Vector2(-25, 40), 1, true),
		NPCScheduleEntry.make([], Phase.NIGHT,  BROOKE_HOME, Vector2(-25, 20), 1, true),
	]
	def.schedule = sched
	def.random_dialogue = true
	def.dialogue_lines = [
		# Stranger — the clipboard.
		DialogueLine.make("Fire Marshal Brooke. When did you last check that extinguisher?", DialogueLine.CALM, 0),
		DialogueLine.make("Most fires I look into were preventable. That is the part that gets me.", DialogueLine.CALM, 0),
		DialogueLine.make("Keep those delivery boxes clear of the stairwells, would you.", DialogueLine.CALM, 0),
		# Acquaintance — the job behind the clipboard.
		DialogueLine.make("Cole thinks I am all paperwork. Somebody has to read the paperwork.", DialogueLine.HAPPY, 2),
		DialogueLine.make("Opposite rota to Cole, so we mostly wave at each other at sunset.", DialogueLine.CALM, 2),
		DialogueLine.make("Nicolle marks books, I file reports. Romantic household, ours.", DialogueLine.HAPPY, 2),
		# Friend — why the rules matter to him.
		DialogueLine.make("I do inspections so nobody has to do rescues. That is the whole job.", DialogueLine.CALM, 5),
		DialogueLine.make("Noah wants to ride the engine. He is seven. I said we would discuss it at thirty.", DialogueLine.HAPPY, 5),
		# Close friend.
		DialogueLine.make("Night weeks are hard. I look in on Noah asleep before I go. Every time.", DialogueLine.SAD, 8),
		DialogueLine.make("You are out on those streets at all hours. I would rather you were careful than quick.", DialogueLine.CALM, 8),
	]
	# Gifts: a thermos-and-sandwich man on a night rota.
	def.loved_gifts = ["butter"]
	def.liked_gifts = ["bread", "milk"]
	def.disliked_gifts = ["scrap"]
	_add(def)

## Nicolle — teaches at the school, nine to five on weekdays. Weekend afternoons
## she is out of the house: the grocery on Saturday, the cafe on Sunday.
func _register_nicolle() -> void:
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "nicolle"
	def.display_name = "Nicolle"
	def.home_anchor  = BROOKE_HOME
	def.shirt_color  = Color("#7a9ec4")   # chalk-dust blue
	def.pants_color  = Color("#3a3550")
	def.hair_color   = Color("#241a16")
	def.skin_color   = BROOKE_SKIN_ADULT
	# First match wins, so the weekday and weekend entries come before the
	# catch-all that keeps her at home the rest of the time.
	var sched : Array[NPCScheduleEntry] = [
		# Mon-Fri: at the school, 9 to 5.
		NPCScheduleEntry.make_hours([1, 2, 3, 4, 5], 9.0, 17.0, "School", Vector2(0, 40), -1, true),
		# Weekend afternoons out: Saturday the grocery, Sunday the cafe.
		NPCScheduleEntry.make_hours([6], 13.0, 17.0, "Grocery", Vector2(0, 40), -1, true),
		NPCScheduleEntry.make_hours([0], 13.0, 17.0, "Cafe",    Vector2(0, 40), -1, true),
		# Everything else: home.
		NPCScheduleEntry.make_hours([], 0.0, 24.0, BROOKE_HOME, Vector2(0, 20), -1, true),
	]
	def.schedule = sched
	def.random_dialogue = true
	def.dialogue_lines = [
		# Stranger.
		DialogueLine.make("Morning! Sorry — teacher voice. I cannot switch it off.", DialogueLine.HAPPY, 0),
		DialogueLine.make("Thirty seven-year-olds and one me. Outnumbered, but winning.", DialogueLine.HAPPY, 0),
		DialogueLine.make("If a parcel comes for the school, the office door is the green one.", DialogueLine.CALM, 0),
		# Acquaintance.
		DialogueLine.make("Noah is in my class this year. He has opinions about that.", DialogueLine.HAPPY, 2),
		DialogueLine.make("James is on nights this week, so it is me and the small one.", DialogueLine.CALM, 2),
		DialogueLine.make("Saturday is the shop, Sunday is the cafe. That is my whole weekend and I love it.", DialogueLine.HAPPY, 2),
		# Friend.
		DialogueLine.make("Twelve years teaching. Still cannot sleep the night before term starts.", DialogueLine.CALM, 5),
		DialogueLine.make("One kid who thought they were not clever finds out they are. That is the job.", DialogueLine.HAPPY, 5),
		# Close friend.
		DialogueLine.make("Marking done, house quiet, James at the station. Glad of the company.", DialogueLine.CALM, 8),
		DialogueLine.make("Noah talks about you at dinner, you know. You have got a small fan.", DialogueLine.HAPPY, 8),
	]
	# Gifts: staffroom tea and a decent loaf.
	def.loved_gifts = ["milk"]
	def.liked_gifts = ["bread", "butter"]
	def.disliked_gifts = ["bolts"]
	_add(def)

## Noah Brooke — James and Nicolle's son, seven. He shadows his mother: in her
## class on weekdays, trailing her round the shop and the cafe at weekends.
func _register_noah() -> void:
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "noah"
	def.display_name = "Noah"
	def.home_anchor  = BROOKE_HOME
	def.shirt_color  = Color("#e0703c")   # bright orange t-shirt
	def.pants_color  = Color("#3f4a63")
	def.hair_color   = Color("#191110")
	def.skin_color   = BROOKE_SKIN_CHILD
	def.sprite_scale = 0.8                # a head shorter than the grown-ups
	# Nicolle's schedule with a small offset, so he stands beside her rather
	# than inside her. Keep the two in step if hers is ever changed.
	var sched : Array[NPCScheduleEntry] = [
		NPCScheduleEntry.make_hours([1, 2, 3, 4, 5], 9.0, 17.0, "School", Vector2(34, 44), -1, true),
		NPCScheduleEntry.make_hours([6], 13.0, 17.0, "Grocery", Vector2(34, 44), -1, true),
		NPCScheduleEntry.make_hours([0], 13.0, 17.0, "Cafe",    Vector2(34, 44), -1, true),
		NPCScheduleEntry.make_hours([], 0.0, 24.0, BROOKE_HOME, Vector2(28, 24), -1, true),
	]
	def.schedule = sched
	def.random_dialogue = true
	def.dialogue_lines = [
		DialogueLine.make("Are you the package person?! Mum said you are the package person!", DialogueLine.SURPRISED, 0),
		DialogueLine.make("My dad is a FIRE MARSHAL. That is the boss of fires.", DialogueLine.HAPPY, 0),
		DialogueLine.make("I am not allowed on the fire engine yet. It is a whole thing.", DialogueLine.SAD, 0),
		DialogueLine.make("Mum is my teacher AND my mum. So unfair, she knows everything.", DialogueLine.MAD, 2),
		DialogueLine.make("Can I hold a package? I will be really careful. I am good at careful.", DialogueLine.HAPPY, 2),
		DialogueLine.make("When I am big I am going to have a bike like yours and go SO fast.", DialogueLine.HAPPY, 5),
		DialogueLine.make("Dad works nights sometimes. I leave the hall light on for him.", DialogueLine.CALM, 8),
	]
	# Gifts: seven years old. Butter is not a treat, whatever the grown-ups think.
	def.loved_gifts = ["milk"]
	def.liked_gifts = ["bread"]
	def.disliked_gifts = ["butter"]
	_add(def)

## Aidan — the mechanic. Works the shop 11am to 8pm on weekdays and a short
## Saturday shift, drinks at the pub after closing on Friday and Saturday, and
## is at church on Sunday mornings. Lives in a small house on the west side, a
## short walk up the road. Grew up around his father's junk yard, which is where
## he picked up the trade — he mentions the old man often. Plain-spoken and
## unbothered. Lives with his dad, Bill (see _register_bill).
##
## AIDAN_HOME is shared by father and son. NOTE: "House4" has no matching node
## under Main's "Doors" (the map has House3 and House40), so it resolves to the
## world origin — change it here once the right house is picked and both move.
const AIDAN_HOME : String = "House4"

func _register_aidan() -> void:
	# Mon(1) Tue(2) Wed(3) Thu(4) Fri(5) — Saturday runs shorter hours, closed Sunday.
	const SUN : int = 0
	const FRI : int = 5
	const SAT : int = 6
	var work_days : Array[int] = [1, 2, 3, 4, 5]
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "aidan"
	def.display_name = "Aidan"
	def.home_anchor  = AIDAN_HOME         # west side, up the road from the shop
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
		NPCScheduleEntry.make_hours([], 0.0, 24.0, AIDAN_HOME, Vector2(0, 20), -1, true),
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

## Bill — Aidan's dad, who runs the junk yard. Out in the yard every day: 8am to
## 6pm through the week, 11am to 4pm at weekends. The yard has no buildings yet,
## so he wanders anywhere on its grass. Talk to him while he's there to trade:
## he has one thing he's dug up for sale each day, and he's the only one in
## town who'll buy anything back (ShopPanel.JUNKYARD). Lives with Aidan.
## Gruff, slow-talking, and quietly very proud of his son.
const BILL_YARD_ZONES    : Array[String] = ["JunkyardGrass", "JunkyardGrass2"]
const BILL_WEEKDAY_HOURS : Vector2 = Vector2(8.0, 18.0)
const BILL_WEEKEND_HOURS : Vector2 = Vector2(11.0, 16.0)

## True while Bill is scheduled to be working the yard — when his counter opens.
func bill_at_yard_now() -> bool:
	var weekend : bool    = TimeManager.weekday == 0 or TimeManager.weekday == 6
	var hours   : Vector2 = BILL_WEEKEND_HOURS if weekend else BILL_WEEKDAY_HOURS
	return TimeManager.hour >= hours.x and TimeManager.hour < hours.y

func _register_bill() -> void:
	var weekdays : Array[int] = [1, 2, 3, 4, 5]
	var weekends : Array[int] = [6, 0]
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "bill"
	def.display_name = "Bill"
	def.home_anchor  = AIDAN_HOME
	def.shirt_color  = Color("#7a6a3a")   # faded olive work shirt
	def.pants_color  = Color("#4a4038")   # dirt-brown work trousers
	def.hair_color   = Color("#b8b4ac")   # grey
	def.skin_color   = Color("#d9a077")   # Aidan's colouring
	# First match wins: the yard first, home the rest of the time. The yard
	# entries are outdoors and wander its grass; the "Mechanic" anchor is just a
	# real door for the route there, since the zones pick where he stands.
	var sched : Array[NPCScheduleEntry] = [
		NPCScheduleEntry.make_hours(weekdays, BILL_WEEKDAY_HOURS.x, BILL_WEEKDAY_HOURS.y, "Mechanic") \
				.wandering_in(BILL_YARD_ZONES),
		NPCScheduleEntry.make_hours(weekends, BILL_WEEKEND_HOURS.x, BILL_WEEKEND_HOURS.y, "Mechanic") \
				.wandering_in(BILL_YARD_ZONES),
		NPCScheduleEntry.make_hours([], 0.0, 24.0, AIDAN_HOME, Vector2(20, 20), -1, true),
	]
	def.schedule = sched
	def.random_dialogue = true
	# Friendship tiers: the haggler, then the yard and what's in it, then Aidan.
	def.dialogue_lines = [
		# Stranger — terse, already pricing you up.
		DialogueLine.make("Name's Bill. Everything's for sale. Including the dog, some days.", DialogueLine.CALM, 0),
		DialogueLine.make("Got something to sell? I'll give you a fair price. Fair-ish.", DialogueLine.HAPPY, 0),
		DialogueLine.make("Mind the rusty bits. That's most of the bits.", DialogueLine.CALM, 0),
		# Acquaintance — the yard.
		DialogueLine.make("Folk throw out things that only needed a bolt. I'm the bolt.", DialogueLine.HAPPY, 2),
		DialogueLine.make("Found a whole pie in a skip once. Still warm. Didn't ask.", DialogueLine.SURPRISED, 2),
		DialogueLine.make("Weekends I keep short hours. Man's got to rest his back.", DialogueLine.CALM, 2),
		# Friend — the boy.
		DialogueLine.make("You know my lad, Aidan? Runs the garage. Learned it all out here.", DialogueLine.HAPPY, 5),
		DialogueLine.make("He fixes things proper. I just fix them till they stop complaining.", DialogueLine.CALM, 5),
		DialogueLine.make("Boy works too hard. Gets that from his mother, God rest her.", DialogueLine.SAD, 5),
		# Close friend — the soft part he keeps buried.
		DialogueLine.make("Never told him I'm proud of him. Reckon he knows. You think he knows?", DialogueLine.SAD, 8),
		DialogueLine.make("When I'm gone, the yard's his. Hope he sells it. Hope he doesn't.", DialogueLine.CALM, 8),
		DialogueLine.make("You've got an eye for what's worth keeping. Rare, that.", DialogueLine.HAPPY, 8),
	]
	# Gifts: a bag of bolts is the finest present going; greens are rabbit food.
	def.loved_gifts = ["bolts"]
	def.liked_gifts = ["scrap", "meat_pie", "jam"]
	def.disliked_gifts = ["fiddleheads"]
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
	def.home_anchor  = "House200"        # moved out of Apartments: player home
	def.shirt_color  = Color("#8fbf8a")   # grocer's green apron
	def.pants_color  = Color("#57506b")
	def.hair_color   = Color("#2b1f1a")
	def.skin_color   = Color("#c98f63")
	# Empty weekday list = every day. The shift wraps past midnight (7 → 1), and
	# the flat covers the gap; both are interior, so she's found by going inside.
	var sched : Array[NPCScheduleEntry] = [
		NPCScheduleEntry.make_hours([], 7.0, 1.0, "Grocery",    Vector2(0, 40), -1, true),
		NPCScheduleEntry.make_hours([], 1.0, 7.0, "House200", Vector2(0, 20), -1, true),
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

## Flower Campbell — lives and works on the farm. Out in the fields from 6am to
## 2pm in spring and summer, indoors the rest of the day, church on Sundays and
## the grocery on Thursday afternoons.
##
## Old enough to remember her father walking out when Marsha fell pregnant with
## Apple, and still bitter about it. She doesn't talk about him; she works, and
## a lot of the farm now runs on her. See "The Campbells" below.
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
	# flower_campbell.png + flower_campbell.json: 80x80 cells, 8 walk frames and
	# a 4-frame breathing idle; rows come from the JSON. She fills ~46px of each
	# cell, so draw the sheet 1:1 (matching Spider) rather than normalising the
	# 80px cell down to 68, and drop the ~17px of empty space below her feet.
	def.sprite_scale  = 80.0 / NPCDefinition.TARGET_FRAME_HEIGHT
	def.sprite_offset = Vector2(0, 5)
	var spring_summer : Array[int] = [Calendar.Season.SPRING, Calendar.Season.SUMMER]
	var sched : Array[NPCScheduleEntry] = [
		# Sundays: church during the day.
		NPCScheduleEntry.make_hours([SUN], 9.0, 13.0, "Church", Vector2(0, 40), -1, true),
		# Thursday afternoons: the grocery store.
		NPCScheduleEntry.make_hours([THU], 13.0, 17.0, "Grocery", Vector2(0, 40), -1, true),
		# Spring & summer, 6am–2pm: farm rounds across the fields either side of
		# the farm road (Grass5 west, Grass6 east). Church and the Thursday
		# grocery run are listed first, so they cut the rounds short on those days.
		NPCScheduleEntry.make_hours([], 6.0, 14.0, "Farm", Vector2(0, 60), -1, false) \
				.in_seasons(spring_summer).wandering_in(["Grass5", "Grass6"]),
		# Everything else: inside the farmhouse.
		NPCScheduleEntry.make_hours([], 0.0, 24.0, "Farm", Vector2(0, 30), -1, true),
	]
	def.schedule = sched
	def.random_dialogue = true
	def.dialogue_lines = [
		# Stranger — friendly, busy, nothing personal.
		DialogueLine.make("Mornin'! The fields are lookin' good this year.", DialogueLine.HAPPY, 0),
		DialogueLine.make("Nothin' beats a quiet morning out here.", DialogueLine.CALM, 0),
		DialogueLine.make("Can't stop long — those fences won't mend themselves.", DialogueLine.CALM, 0),
		# Acquaintance — the family, and how much she carries.
		DialogueLine.make("Mum sells the eggs, I do most of the rest. Apple does her best, bless her.", DialogueLine.HAPPY, 2),
		DialogueLine.make("Up before the hens most days. Somebody's got to be.", DialogueLine.CALM, 2),
		DialogueLine.make("Apple follows me round the fields on Saturdays. Slows me right down. I don't mind.", DialogueLine.HAPPY, 2),
		# Friend — the father, briefly and sharply.
		DialogueLine.make("It's just the three of us. Has been since Apple was on the way.", DialogueLine.CALM, 5),
		DialogueLine.make("Dad left when he found out about Apple. Packed a bag. That was that.", DialogueLine.MAD, 5),
		DialogueLine.make("Apple doesn't remember him. Honestly? She's lucky.", DialogueLine.SAD, 5),
		# Close friend — what's under the anger.
		DialogueLine.make("I'm not working this hard for him. I'm doing it so Mum never has to worry again.", DialogueLine.CALM, 8),
		DialogueLine.make("Sometimes I think I'm still waiting for him to come up the lane. Stupid, eh.", DialogueLine.SAD, 8),
		DialogueLine.make("Mum's the strongest person I know. Don't tell her I said that.", DialogueLine.HAPPY, 8),
	]
	# Gifts: Fence posts and gate hinges always need fixing. Her farm makes its own butter.
	def.loved_gifts = ["bolts"]
	def.liked_gifts = ["scrap", "milk"]
	def.disliked_gifts = ["butter"]
	_add(def)

# ── The Campbells ──────────────────────────────────────────
## Flower's mother Marsha and her little sister Apple share the farmhouse with
## her. The girls' father left when he found out Marsha was pregnant with Apple,
## and Marsha has run the farm alone since, with Flower increasingly doing the
## heavy lifting. Flower remembers him and is bitter about it; Apple has no
## memory of him at all and pitches in anyway. Marsha sells the farm's eggs
## from a desk inside the farmhouse.
const CAMPBELL_HOME : String = "Farm"

## Marsha's selling hours at her desk: Wednesday to Saturday, 7am to 5pm.
const MARSHA_DESK_DAYS  : Array[int] = [3, 4, 5, 6]
const MARSHA_DESK_OPEN  : float = 7.0
const MARSHA_DESK_CLOSE : float = 17.0

## True while Marsha's desk is open. Player checks this before opening the farm
## counter, so talking to her outside those hours is just a chat.
func marsha_selling_now() -> bool:
	return MARSHA_DESK_DAYS.has(TimeManager.weekday) \
			and TimeManager.hour >= MARSHA_DESK_OPEN and TimeManager.hour < MARSHA_DESK_CLOSE

## Marsha Campbell — Flower and Apple's mum. Sells eggs from her desk in the
## farmhouse Wednesday to Saturday, 7am–5pm; takes the girls to church on
## Sunday mornings; otherwise about the farmhouse. Brisk, warm, and fond of
## calling everyone "love". Her husband walked out when she was pregnant with
## Apple; she doesn't dwell on it, but she worries it has hardened Flower.
func _register_marsha_campbell() -> void:
	const SUN : int = 0
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "marsha_campbell"
	def.display_name = "Marsha Campbell"
	def.home_anchor  = CAMPBELL_HOME
	def.shirt_color  = Color("#e8d8a8")   # cream blouse
	def.pants_color  = Color("#6b4f3a")   # brown work skirt
	def.hair_color   = Color("#a3502a")   # auburn — where Flower gets it
	def.skin_color   = Color("#f0c8a0")
	# First match wins: the desk and church come before the farmhouse fallback.
	var sched : Array[NPCScheduleEntry] = [
		NPCScheduleEntry.make_hours(MARSHA_DESK_DAYS, MARSHA_DESK_OPEN, MARSHA_DESK_CLOSE,
				CAMPBELL_HOME, Vector2(-40, 30), -1, true),
		NPCScheduleEntry.make_hours([SUN], 9.0, 13.0, "Church", Vector2(-40, 40), -1, true),
		NPCScheduleEntry.make_hours([], 0.0, 24.0, CAMPBELL_HOME, Vector2(-40, 30), -1, true),
	]
	def.schedule = sched
	def.random_dialogue = true
	def.dialogue_lines = [
		# Stranger — the farm stand.
		DialogueLine.make("Eggs, love? Wednesday to Saturday, seven till five. Laid this morning.", DialogueLine.HAPPY, 0),
		DialogueLine.make("Wipe your feet. Not you — the bike. Well, both.", DialogueLine.CALM, 0),
		DialogueLine.make("You'll have met Flower out in the fields. She works harder than I did at her age.", DialogueLine.HAPPY, 0),
		# Acquaintance — family.
		DialogueLine.make("Apple's named every hen. I daren't tell her where the eggs go.", DialogueLine.HAPPY, 2),
		DialogueLine.make("I bake the fruitcake for Jimmy Henderson, mostly. He's the only one who buys it.", DialogueLine.HAPPY, 2),
		DialogueLine.make("Ran this farm on my own since before Apple was born. We manage fine.", DialogueLine.CALM, 2),
		DialogueLine.make("If Apple asks you for a ride on that bike, the answer's no.", DialogueLine.MAD, 2),
		# Friend — the man who left, told plainly.
		DialogueLine.make("Their father left the week I told him Apple was coming. Didn't even take his boots.", DialogueLine.CALM, 5),
		DialogueLine.make("Flower'll take this place on one day. I just hope she wants to, and isn't doing it for me.", DialogueLine.CALM, 5),
		DialogueLine.make("Sit down a minute, love. Kettle's always on in this house.", DialogueLine.HAPPY, 5),
		# Close friend — what she worries about.
		DialogueLine.make("Flower's still angry at him. I wish she'd put it down. It's heavy, and it's not hers.", DialogueLine.SAD, 8),
		DialogueLine.make("Apple's never known him and never asked. Some nights that breaks my heart more than him going did.", DialogueLine.SAD, 8),
		DialogueLine.make("Some winters I didn't know how we'd get through. We did. We always do.", DialogueLine.CALM, 8),
		DialogueLine.make("You're practically family now. That means you're not getting paid for chores.", DialogueLine.HAPPY, 8),
	]
	# Gifts: a baker's loaf is a treat when you keep hens; scrap is one more
	# thing for the yard.
	def.loved_gifts = ["bread"]
	def.liked_gifts = ["milk", "bolts"]
	def.disliked_gifts = ["scrap"]
	_add(def)

## Apple Campbell — Flower's little sister, about eight. Has no memory of her
## father (he left before she was born) and doesn't miss what she never had;
## she just likes helping. School Monday to Friday, church with the family on
## Sunday. On Saturdays in spring and summer she follows Flower round the farm
## rounds, 6am–2pm; otherwise she's in the farmhouse, "helping" at Mum's desk.
func _register_apple_campbell() -> void:
	const SUN : int = 0
	const SAT : int = 6
	var school_days   : Array[int] = [1, 2, 3, 4, 5]
	var spring_summer : Array[int] = [Calendar.Season.SPRING, Calendar.Season.SUMMER]
	var def : NPCDefinition = NPCDefinition.new()
	def.id           = "apple_campbell"
	def.display_name = "Apple Campbell"
	def.home_anchor  = CAMPBELL_HOME
	def.shirt_color  = Color("#d94a4a")   # apple red, naturally
	def.pants_color  = Color("#4a8a4a")   # green dungarees
	def.hair_color   = Color("#c1440e")   # red hair, like Flower
	def.skin_color   = Color("#f0c8a0")
	def.sprite_scale = 0.8                # a head shorter than the grown-ups
	var sched : Array[NPCScheduleEntry] = [
		NPCScheduleEntry.make_hours([SUN], 9.0, 13.0, "Church", Vector2(40, 40), -1, true),
		NPCScheduleEntry.make_hours(school_days, 9.0, 15.5, "School", Vector2(40, 40), -1, true),
		# Saturdays in the growing season: on Flower's rounds with her, same
		# hours and fields (keep in step with _register_flower_campbell). She
		# trails Flower; if Flower isn't out yet, she potters about the fields.
		NPCScheduleEntry.make_hours([SAT], 6.0, 14.0, CAMPBELL_HOME, Vector2(30, 60), -1, false) \
				.in_seasons(spring_summer).wandering_in(["Grass5", "Grass6"]).following("flower_campbell"),
		NPCScheduleEntry.make_hours([], 0.0, 24.0, CAMPBELL_HOME, Vector2(40, 30), -1, true),
	]
	def.schedule = sched
	def.random_dialogue = true
	def.dialogue_lines = [
		DialogueLine.make("I'm Apple! Like the fruit. Flower's named after a flower. Mum likes plants.", DialogueLine.HAPPY, 0),
		DialogueLine.make("That hen is Duchess. She's the boss. Don't look her in the eye.", DialogueLine.SURPRISED, 0),
		DialogueLine.make("I help Mum at the desk. I count the eggs. Sometimes I count them twice.", DialogueLine.HAPPY, 0),
		DialogueLine.make("Flower won't let me drive the tractor. I'm EIGHT.", DialogueLine.MAD, 2),
		DialogueLine.make("Can I ride on your bike? Mum said no but she's not here. Oh. She is here.", DialogueLine.SAD, 2),
		DialogueLine.make("When I grow up I'm going to have a hundred hens and you can deliver them.", DialogueLine.HAPPY, 5),
		DialogueLine.make("Saturdays I do the rounds with Flower. I carry the bucket. It's a very important bucket.", DialogueLine.HAPPY, 2),
		DialogueLine.make("I don't have a dad. I've got Mum and Flower, so that's two, which is more than one.", DialogueLine.CALM, 5),
		DialogueLine.make("Flower goes quiet if anyone says about our dad. So I don't.", DialogueLine.SAD, 5),
		DialogueLine.make("Mum works really hard. I'm going to make her breakfast one day. With eggs.", DialogueLine.CALM, 8),
		DialogueLine.make("When I'm big I'm going to do ALL the jobs so Flower can have a lie-in.", DialogueLine.HAPPY, 8),
	]
	# Gifts: a kid's treat; she names the hens, so eggs are not a present.
	def.loved_gifts = ["butter"]
	def.liked_gifts = ["milk", "bread"]
	def.disliked_gifts = ["eggs"]
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
		DialogueLine.make("Marsha does a fruitcake at the farm come winter. Nobody appreciates it like I do.", DialogueLine.HAPPY),
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
	def.random_dialogue = true
	# Friendship tiers. She starts in full public-office voice — warm, but the
	# warmth is part of the job — and loosens into the actual woman underneath:
	# the paperwork, the town she worries about, and finally Jimmy and the plain
	# admission that she counts on you. Old lines stay in the pool at falling
	# odds (see RegularNPC.get_dialogue), so the civic greeting never fully goes.
	def.dialogue_lines = [
		# Stranger — the campaign handshake. Pleasant, practised, a little rehearsed.
		DialogueLine.make("Hi, how's the delivery business?", DialogueLine.HAPPY, 0),
		DialogueLine.make("Welcome, welcome. City Hall is open to everyone — do come in sometime.", DialogueLine.HAPPY, 0),
		DialogueLine.make("A growing town needs good roads and good people. We're fortunate in both.", DialogueLine.CALM, 0),
		DialogueLine.make("If you've a concern, bring it to my desk. That's what the desk is for.", DialogueLine.CALM, 0),
		# Acquaintance — she's noticed you specifically, and the polish slips a little.
		DialogueLine.make("You again! I'm starting to think you keep this town running more than I do.", DialogueLine.HAPPY, 2),
		DialogueLine.make("Between us, I signed forty-one forms before lunch. Forty-one.", DialogueLine.CALM, 2),
		DialogueLine.make("Mind the cobbles on the east lane. It's on the list. Everything's on the list.", DialogueLine.CALM, 2),
		DialogueLine.make("If Jimmy offers you fruitcake, you say you've just eaten. Trust me.", DialogueLine.MAD, 2),
		DialogueLine.make("People think the mayor's job is ribbon-cutting. It is mostly drainage.", DialogueLine.HAPPY, 2),
		# Friend — the office door stays open, and she says what she actually thinks.
		DialogueLine.make("Shut the door behind you, would you? Ten minutes where nobody wants anything.", DialogueLine.CALM, 5),
		DialogueLine.make("I've lived here my whole life. Every pothole I approve is one I grew up tripping over.", DialogueLine.HAPPY, 5),
		DialogueLine.make("Some days the council makes me want to move to the coast and raise geese.", DialogueLine.MAD, 5),
		DialogueLine.make("Jimmy says I bring the office home with me. Jimmy is unfortunately correct.", DialogueLine.CALM, 5),
		# Close friend — quieter, and she stops performing entirely.
		DialogueLine.make("When I'm tired of being Mayor Henderson, I'm just glad someone still knocks.", DialogueLine.CALM, 8),
		DialogueLine.make("Jimmy and I married young and nobody thought it would take. Thirty years next spring.", DialogueLine.HAPPY, 8),
		DialogueLine.make("I'll not run forever. I'd like to leave the place tidier than I found it, that's all.", DialogueLine.CALM, 8),
		DialogueLine.make("You've done more for this town on that bicycle than half my council has in office.", DialogueLine.HAPPY, 8),
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
	def.home_anchor  = "House134"        # moved out of Apartments: player home
	def.shirt_color  = Color("#d46a6a")
	def.hair_color   = Color("#e0d8c8")
	var sched : Array[NPCScheduleEntry] = [
		NPCScheduleEntry.make([1, 2, 3], Phase.DAY,    "Building1", Vector2(-30, 40)),
		NPCScheduleEntry.make([4, 5],    Phase.DAY,    "House80",   Vector2(30, 30)),
		NPCScheduleEntry.make([2, 3],    Phase.SUNSET, "Pub",       Vector2(20, 30)),
		NPCScheduleEntry.make([],        Phase.NIGHT,  "House134", Vector2(0, 20)),
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
	def.home_anchor  = "House80"         # moved out of House84: player home
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
	def.home_anchor  = "House12"         # moved out of House10: player home
	def.shirt_color  = Color("#e0a040")
	def.hair_color   = Color("#4a3020")
	var sched : Array[NPCScheduleEntry] = [
		NPCScheduleEntry.make([1, 2, 3, 4, 5], Phase.DAY,    "House12",  Vector2(50, 40)),
		NPCScheduleEntry.make([0],             Phase.DAY,    "House134", Vector2(-60, 50)),
		NPCScheduleEntry.make([],              Phase.SUNSET, "House12",  Vector2(0, 25)),
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
