class_name Pickup

extends Area2D
## A street pickup: either a "trick" (blue square = speed boost)
## or a "trap" (red circle = slowdown).

enum Kind { TRICK, TRAP }

var kind : Kind = Kind.TRICK
var _active := true
var _pulse  := 0.0

@onready var _sprite : Node2D = $PickupSprite

func setup(k: Kind) -> void:
	kind = k
	queue_redraw()

func _process(delta: float) -> void:
	if not _active:
		return
	_pulse = fmod(_pulse + delta * 3.5, TAU)
	$PickupSprite.queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if not _active:
		return
	if not body is CharacterBody2D:
		return
	if not body.has_method("apply_boost"):
		return
	_active = false
	visible = false
	if kind == Kind.TRICK:
		body.apply_boost()
	else:
		body.apply_slow()

# ── PickupSprite child draws itself ────────────────────────
# (handled in PickupSprite.gd)
func get_pulse() -> float:
	return _pulse

func get_kind() -> Kind:
	return kind
