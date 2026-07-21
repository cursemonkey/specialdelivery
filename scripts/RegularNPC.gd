class_name RegularNPC
extends NPCBase
## Named villager with a weekly schedule (weekday + day phase → location) and
## dialogue. Its data comes from an NPCDefinition in NPCRegistry (configured by
## NPCManager at spawn). The player interacts with E when close; the NPC stops,
## turns to face the player, and the dialogue box opens.

var npc_name        : String                  = "Villager"
var home_position   : Vector2                 = Vector2.ZERO
var schedule        : Array[NPCScheduleEntry] = []
var dialogue_lines  : Array                   = []   # Array of DialogueLine
var conversation    : Resource                = null # future branching tree
var portrait        : Texture2D               = null # neutral portrait (fallback)
var definition      : NPCDefinition           = null # source data; resolves mood portraits
# Door node name -> resolved world position, filled in by NPCManager so the
# NPC can turn its schedule anchors into positions at retarget time.
var anchor_positions : Dictionary             = {}

func _ready() -> void:
	super._ready()
	add_to_group("interactable_npc")

## First schedule entry matching the current weekday + phase wins;
## no match means head home.
func _retarget() -> void:
	for entry in schedule:
		if entry.matches(TimeManager.weekday, TimeManager.phase):
			set_move_target(_resolve(entry.anchor, entry.offset))
			return
	set_move_target(home_position)

func _resolve(anchor: String, offset: Vector2) -> Vector2:
	var base : Vector2 = anchor_positions.get(anchor, home_position)
	return base + offset

## Called by Player just before opening the dialogue box. The tree pauses
## while dialogue is open; the short halt keeps the NPC standing politely
## for a beat after it closes.
func begin_interaction(player: Node2D) -> void:
	_halt_timer = maxf(_halt_timer, 1.0)
	velocity = Vector2.ZERO
	face_toward(player.global_position)

func get_dialogue() -> Array:
	if dialogue_lines.is_empty():
		return [DialogueLine.make("%s waves hello!" % npc_name)]
	return dialogue_lines

func get_portrait() -> Texture2D:
	return portrait

## Portrait for a mood (see DialogueLine mood constants), with fallback baked
## into NPCDefinition.portrait_texture().
func portrait_for_mood(mood: String) -> Texture2D:
	if definition != null:
		return definition.portrait_texture(mood)
	return portrait

## Build ready-to-display dialogue blocks: each line's text paired with the
## portrait for that line's emotion. Tolerates plain Strings as neutral lines.
func get_dialogue_blocks() -> Array:
	var blocks : Array = []
	for line in get_dialogue():
		if line is DialogueLine:
			blocks.append({"text": line.text, "portrait": portrait_for_mood(line.mood)})
		else:
			blocks.append({"text": str(line), "portrait": portrait_for_mood("")})
	return blocks
