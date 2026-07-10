class_name RegularNPC
extends NPCBase
## Named villager with a weekly schedule (weekday + day phase → location)
## and dialogue. The player interacts with E when close; the NPC stops,
## turns to face the player, and the dialogue box opens (Player.gd drives
## this via the "interactable_npc" group).

var npc_name       : String                  = "Villager"
var home_position  : Vector2                 = Vector2.ZERO
var schedule       : Array[NPCScheduleEntry] = []
var dialogue_lines : Array                   = []   # Array of Strings

func _ready() -> void:
	super._ready()
	add_to_group("interactable_npc")

## First schedule entry matching the current weekday + phase wins;
## no match means head home.
func _retarget() -> void:
	for entry in schedule:
		if entry.matches(TimeManager.weekday, TimeManager.phase):
			set_move_target(entry.target)
			return
	set_move_target(home_position)

## Called by Player just before opening the dialogue box. The tree pauses
## while dialogue is open; the short halt keeps the NPC standing politely
## for a beat after it closes.
func begin_interaction(player: Node2D) -> void:
	_halt_timer = maxf(_halt_timer, 1.0)
	velocity = Vector2.ZERO
	face_toward(player.global_position)

func get_dialogue() -> Array:
	if dialogue_lines.is_empty():
		return ["%s waves hello!" % npc_name]
	return dialogue_lines
