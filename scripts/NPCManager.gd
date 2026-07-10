extends Node2D
## NPCManager — spawns and configures all villagers. Created from Main._ready().
## Schedule locations are anchored to the named doors under Main's "Doors"
## node so they stay correct if the map shifts; tweak the offsets/casts below
## to add or move villagers.

const BackgroundNPCScene := preload("res://scenes/BackgroundNPC.tscn")
const RegularNPCScene    := preload("res://scenes/RegularNPC.tscn")

var _player : CharacterBody2D = null
var _doors  : Node            = null

func setup(player: CharacterBody2D, doors_root: Node) -> void:
	_player = player
	_doors  = doors_root

func spawn_all() -> void:
	_spawn_background_npcs()
	_spawn_regular_npcs()

# ── Background cast (ambient, non-interactable) ────────────
func _spawn_background_npcs() -> void:
	var pub  : Vector2 = _door_pos("Pub",        Vector2(2000, 1500))
	var apts : Vector2 = _door_pos("Apartments", Vector2(1600, 1800))
	var b1   : Vector2 = _door_pos("Building1",  Vector2(2200, 1700))

	# Each route: [day, sunset, night] wander-to spots.
	var routes : Array = [
		[apts + Vector2(-40, 40), pub + Vector2(30, 40),  apts + Vector2(0, 30)],
		[b1   + Vector2(20, 40),  b1  + Vector2(-90, 60), pub  + Vector2(-30, 30)],
		[pub  + Vector2(70, 30),  apts + Vector2(50, 60), b1   + Vector2(0, 40)],
	]
	var shirts : Array = [Color("#7aa05a"), Color("#a06a9a"), Color("#c4a04a")]

	for i in routes.size():
		var npc : BackgroundNPC = BackgroundNPCScene.instantiate()
		add_child(npc)
		var route : Array = routes[i]
		npc.global_position = route[0]
		var typed_route : Array[Vector2] = []
		for p in route:
			typed_route.append(p)
		npc.route_points = typed_route
		var sprite : NPCSprite = npc.get_node("NPCSprite")
		sprite.shirt_color = shirts[i]
		npc._retarget()

# ── Regular cast (schedules + dialogue) ────────────────────
func _spawn_regular_npcs() -> void:
	var pub     : Vector2 = _door_pos("Pub",        Vector2(2000, 1500))
	var apts    : Vector2 = _door_pos("Apartments", Vector2(1600, 1800))
	var b1      : Vector2 = _door_pos("Building1",  Vector2(2200, 1700))
	var house28 : Vector2 = _door_pos("House28",    Vector2(2400, 2000))
	var house10 : Vector2 = _door_pos("House10",    Vector2(1400, 2100))

	# Mabel — works at Building1 early in the week, market runs late-week,
	# pub on sunset mid-week, always home at night.
	_spawn_regular(
		"Mabel", apts,
		[
			NPCScheduleEntry.make([1, 2, 3],       TimeManager.Phase.DAY,    b1 + Vector2(-30, 40)),
			NPCScheduleEntry.make([4, 5],          TimeManager.Phase.DAY,    house28 + Vector2(30, 30)),
			NPCScheduleEntry.make([2, 3],          TimeManager.Phase.SUNSET, pub + Vector2(20, 30)),
			NPCScheduleEntry.make([],              TimeManager.Phase.NIGHT,  apts + Vector2(0, 20)),
		],
		[
			"Oh, hello dear! Busy day of deliveries?",
			"I'm off to the pub later — Wednesdays are trivia night!",
		],
		Color("#d46a6a"), Color("#e0d8c8")
	)

	# Gus — pub regular. Tends Building1 on weekends (Sun), naps at home
	# on sunset, at the pub every night.
	_spawn_regular(
		"Gus", house28,
		[
			NPCScheduleEntry.make([0],             TimeManager.Phase.DAY,    b1 + Vector2(30, 40)),
			NPCScheduleEntry.make([1, 2, 3, 4, 5], TimeManager.Phase.DAY,    pub + Vector2(-40, 40)),
			NPCScheduleEntry.make([],              TimeManager.Phase.NIGHT,  pub + Vector2(0, 30)),
		],
		[
			"Watch where you're pedaling, kid!",
			"...Ah, I'm only teasing. Fine weather for it.",
		],
		Color("#5a7aa0"), Color("#7a6a4a")
	)

	# Poppy — school-age: out by House10 on weekdays, roams near the
	# apartments Sunday, home at sunset and night.
	_spawn_regular(
		"Poppy", house10,
		[
			NPCScheduleEntry.make([1, 2, 3, 4, 5], TimeManager.Phase.DAY,    house10 + Vector2(50, 40)),
			NPCScheduleEntry.make([0],             TimeManager.Phase.DAY,    apts + Vector2(-60, 50)),
			NPCScheduleEntry.make([],              TimeManager.Phase.SUNSET, house10 + Vector2(0, 25)),
		],
		[
			"Wow, you deliver packages?! That's so cool!",
			"When I grow up I want a bike just like yours.",
		],
		Color("#e0a040"), Color("#4a3020")
	)

func _spawn_regular(
	npc_name: String,
	home: Vector2,
	entries: Array,
	lines: Array,
	shirt: Color,
	hair: Color
) -> void:
	var npc : RegularNPC = RegularNPCScene.instantiate()
	add_child(npc)
	npc.npc_name        = npc_name
	npc.home_position   = home + Vector2(0, 20)
	npc.global_position = npc.home_position
	var typed_entries : Array[NPCScheduleEntry] = []
	for e in entries:
		typed_entries.append(e)
	npc.schedule       = typed_entries
	npc.dialogue_lines = lines
	var sprite : NPCSprite = npc.get_node("NPCSprite")
	sprite.shirt_color = shirt
	sprite.hair_color  = hair
	npc._retarget()

# ── Helpers ────────────────────────────────────────────────
func _door_pos(door_name: String, fallback: Vector2) -> Vector2:
	if _doors != null:
		var door : Node2D = _doors.get_node_or_null(door_name)
		if door != null:
			return door.global_position
	return fallback
