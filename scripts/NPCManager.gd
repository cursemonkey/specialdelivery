extends Node2D
## NPCManager — spawns and configures all villagers. Created from Main._ready().
##
## Regular (named, interactable) NPCs are data-driven: their definitions live in
## NPCRegistry keyed by id, and this manager just resolves each definition's
## door anchors into world positions and instances a RegularNPC. To add or edit
## a regular villager, edit NPCRegistry — not this file.
##
## Background (ambient, non-interactable) NPCs are configured inline below since
## they're simple phase-only wanderers; they wear greys and blank "NPC-meme"
## faces to read as background at a glance.

const BackgroundNPCScene := preload("res://scenes/BackgroundNPC.tscn")
const RegularNPCScene    := preload("res://scenes/RegularNPC.tscn")

# Fallback door positions, used only if the named door node can't be found.
const ANCHOR_FALLBACKS := {
	"Pub":              Vector2(2000, 1500),
	"Apartments":       Vector2(1600, 1800),
	"Building1":        Vector2(2200, 1700),
	"House28":          Vector2(2069, 2997),
	"House10":          Vector2(1207, 2026),
	"House19":          Vector2(3019, 2573),
	"Building_TownHall": Vector2(2898, 2070),
}

var _player : CharacterBody2D = null
var _doors  : Node            = null

func setup(player: CharacterBody2D, doors_root: Node) -> void:
	_player = player
	_doors  = doors_root

func spawn_all() -> void:
	_spawn_background_npcs()
	_spawn_regular_npcs()

# ── Regular cast (from NPCRegistry) ────────────────────────
func _spawn_regular_npcs() -> void:
	for def in NPCRegistry.all_definitions():
		_spawn_from_definition(def)

func _spawn_from_definition(def: NPCDefinition) -> void:
	var npc : RegularNPC = RegularNPCScene.instantiate()
	add_child(npc)
	npc.definition       = def
	npc.id               = def.id
	npc.npc_name         = def.display_name
	npc.schedule         = def.schedule
	npc.dialogue_lines   = def.dialogue_lines
	npc.conversation     = def.conversation
	npc.portrait         = def.portrait_texture()
	npc.anchor_positions = _resolve_anchors(def)
	npc.home_position    = npc.anchor_positions.get(def.home_anchor, Vector2.ZERO) + def.home_offset
	npc.global_position  = npc.home_position

	var sprite : NPCSprite = npc.get_node("NPCSprite")
	sprite.shirt_color = def.shirt_color
	sprite.pants_color = def.pants_color
	sprite.hair_color  = def.hair_color
	npc._retarget()

## Resolve every door anchor a definition references into world positions.
func _resolve_anchors(def: NPCDefinition) -> Dictionary:
	var names : Array = [def.home_anchor]
	for entry in def.schedule:
		if not names.has(entry.anchor):
			names.append(entry.anchor)
	var result : Dictionary = {}
	for anchor_name in names:
		result[anchor_name] = _door_pos(anchor_name)
	return result

# ── Background cast (ambient, greyed-out "NPC-meme" villagers) ──
func _spawn_background_npcs() -> void:
	var pub  : Vector2 = _door_pos("Pub")
	var apts : Vector2 = _door_pos("Apartments")
	var b1   : Vector2 = _door_pos("Building1")

	# Each route: [day, sunset, night] wander-to spots.
	var routes : Array = [
		[apts + Vector2(-40, 40), pub + Vector2(30, 40),  apts + Vector2(0, 30)],
		[b1   + Vector2(20, 40),  b1  + Vector2(-90, 60), pub  + Vector2(-30, 30)],
		[pub  + Vector2(70, 30),  apts + Vector2(50, 60), b1   + Vector2(0, 40)],
	]
	# Muted greys so the background cast reads as scenery, not characters.
	var shirts : Array = [Color("#8f8f8f"), Color("#6f6f74"), Color("#a2a2a2")]

	for i in routes.size():
		var npc : BackgroundNPC = BackgroundNPCScene.instantiate()
		add_child(npc)
		npc.id = "bg_%d" % i
		var route : Array = routes[i]
		npc.global_position = route[0]
		var typed_route : Array[Vector2] = []
		for p in route:
			typed_route.append(p)
		npc.route_points = typed_route
		var sprite : NPCSprite = npc.get_node("NPCSprite")
		sprite.meme_style  = true
		sprite.shirt_color = shirts[i]
		sprite.pants_color = Color("#565659")
		sprite.hair_color  = Color("#777777")
		sprite.skin_color  = Color("#a8a8a8")   # classic grey NPC-meme skin
		npc._retarget()

# ── Helpers ────────────────────────────────────────────────
func _door_pos(door_name: String) -> Vector2:
	if _doors != null:
		var door : Node2D = _doors.get_node_or_null(door_name)
		if door != null:
			return door.global_position
	return ANCHOR_FALLBACKS.get(door_name, Vector2.ZERO)
