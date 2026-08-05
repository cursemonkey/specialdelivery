class_name Pickup

extends Area2D
## A permanent street feature. Three kinds:
##   • RAMP    — wedge ramp: speed boost + a small jump
##   • PUDDLE  — blue oval: spin-out
##   • POTHOLE — black circle: slowdown only
##
## These are scenery, not collectables: they stay put after being hit and only
## disappear when the world redistributes them (see WorldGenerator._scatter_pickups).

enum Kind { RAMP, PUDDLE, POTHOLE }

## Seconds before the same body can set this off again. Without it the effect
## would re-fire every frame the player overlaps the shape.
const RETRIGGER_DELAY := 1.2

var kind     : Kind  = Kind.RAMP
var _pulse   : float = 0.0
var _angle   : float = 0.0   # RAMP only — direction the wedge points
var _cooldown: float = 0.0

@onready var _sprite : Node2D = $PickupSprite

func setup(k: Kind, angle: float = 0.0) -> void:
	kind   = k
	_angle = angle
	queue_redraw()

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	_pulse = fmod(_pulse + delta * 3.5, TAU)
	_sprite.queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if _cooldown > 0.0:
		return
	if not body is CharacterBody2D:
		return
	if not body.has_method("apply_boost"):
		return
	_cooldown = RETRIGGER_DELAY
	match kind:
		Kind.RAMP:
			body.apply_ramp()
		Kind.PUDDLE:
			body.apply_puddle()
		Kind.POTHOLE:
			body.apply_slow()

# ── PickupSprite child draws itself ────────────────────────
# (handled in PickupSprite.gd)
func get_pulse() -> float:
	return _pulse

func get_kind() -> Kind:
	return kind

func get_angle() -> float:
	return _angle
