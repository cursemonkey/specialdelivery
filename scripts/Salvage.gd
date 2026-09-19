class_name Salvage

extends Area2D
## A free collectable lying in the street — a piece of scrap metal or a bag of
## bolts. Unlike Pickup (which is permanent road furniture), salvage is
## temporary: SalvageManager spawns it, and it expires on its own timer.
##
## Life cycle: the piece sits for `lifetime` seconds, spends the last
## FLICKER_LEAD seconds blinking to warn it is about to go, then frees itself.
## Riding over it puts it in the bag — silently, with no toast or dialogue,
## but with a short upward pop (see COLLECT_*) so the pickup is unmistakable.

signal collected(item_id: String)
signal expired()

## Real seconds of blinking before despawn. The clock runs at 2 in-game hours
## per real minute, so this is a little under an in-game hour of warning.
const FLICKER_LEAD : float = 25.0

## Blinks per second while flickering out.
const FLICKER_RATE : float = 6.0

# ── Collect pop ────────────────────────────────────────────
## How long the piece flies up for after being collected, in real seconds.
const COLLECT_TIME  : float = 0.42
## Pixels it climbs over that time.
const COLLECT_RISE  : float = 34.0
## How much bigger it swells at the top of the arc.
const COLLECT_SCALE : float = 1.5
## Spin over the flight, in turns — a little tumble as it goes.
const COLLECT_SPIN  : float = 0.55

## Item id from ItemRegistry — "scrap" or "bolts".
var item_id  : String = "scrap"
## Total real seconds this piece survives before despawning.
var lifetime : float  = 360.0

var _age       : float = 0.0
var _bob       : float = 0.0
var _taken     : bool  = false
# Collect-pop state. While _collecting, the piece is already out of the bag's
# way (counted, uncollidable) and is only playing its flight out.
var _collecting : bool  = false
var _pop        : float = 0.0   # 0 → 1 across COLLECT_TIME
var _origin     : Vector2 = Vector2.ZERO

@onready var _sprite : Node2D = $SalvageSprite

func setup(id: String, life: float) -> void:
	item_id  = id
	lifetime = maxf(life, FLICKER_LEAD + 1.0)
	# Start the bob at a random point so a cluster of pieces doesn't pulse in
	# lockstep.
	_bob = randf() * TAU

func _process(delta: float) -> void:
	if _collecting:
		_advance_pop(delta)
		return
	_age += delta
	if _age >= lifetime:
		_despawn()
		return
	_bob = fmod(_bob + delta * 2.2, TAU)
	_sprite.queue_redraw()

## Fly up, swell, spin and fade, then free. Eased so it leaves quickly and
## slows as it fades, which reads as "collected" rather than "fell upward".
func _advance_pop(delta: float) -> void:
	_pop = minf(_pop + delta / COLLECT_TIME, 1.0)
	var eased : float = 1.0 - pow(1.0 - _pop, 3.0)   # ease-out cubic
	global_position = _origin + Vector2(0.0, -COLLECT_RISE * eased)
	# Swell early, then shrink away to nothing as it fades out.
	var swell : float = lerpf(1.0, COLLECT_SCALE, sin(_pop * PI))
	_sprite.scale    = Vector2(swell, swell)
	_sprite.rotation = TAU * COLLECT_SPIN * eased
	_sprite.queue_redraw()
	if _pop >= 1.0:
		queue_free()

## True once this piece is in its final flickering seconds.
func is_flickering() -> bool:
	return _age >= lifetime - FLICKER_LEAD

## Draw alpha for the sprite: solid most of the piece's life, blinking at the
## end. The blink deepens as the piece gets closer to going, so the last second
## is unmistakable.
func draw_alpha() -> float:
	if _collecting:
		# Hold full strength for the first half of the flight, then fade out.
		return clampf(1.0 - maxf(_pop - 0.45, 0.0) / 0.55, 0.0, 1.0)
	if not is_flickering():
		return 1.0
	var remaining : float = maxf(lifetime - _age, 0.0)
	# 0 at the start of the flicker, 1 at the moment of despawn.
	var urgency   : float = 1.0 - (remaining / FLICKER_LEAD)
	var blink     : float = 0.5 + 0.5 * sin(_age * TAU * FLICKER_RATE)
	# Deeper troughs as urgency rises: barely a shimmer at first, hard blink at the end.
	return lerpf(1.0, blink, clampf(urgency, 0.0, 1.0))

## True while the collect pop is playing.
func is_collecting() -> bool:
	return _collecting

func get_bob() -> float:
	return _bob

func get_item_id() -> String:
	return item_id

func _on_body_entered(body: Node2D) -> void:
	if _taken:
		return
	# Only the player collects; NPCs and vehicles ride straight over it.
	# Same duck-typed test Pickup uses to recognise the rider.
	if not body is CharacterBody2D:
		return
	if not body.has_method("apply_boost"):
		return
	if not GameManager.add_portions(item_id, 1):
		# Bag is full — leave the piece where it is so it can be picked up
		# after something is eaten or sold.
		return
	_taken = true
	collected.emit(item_id)
	_begin_pop()

## Start the upward flight. The piece stops colliding immediately so it can't
## be collected twice, and stops bobbing so the pop starts from a settled pose.
func _begin_pop() -> void:
	_collecting = true
	_pop        = 0.0
	_origin     = global_position
	_bob        = 0.0
	# Deferred: we are inside this Area2D's own body_entered signal.
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	# Draw above anything it flies over during the pop.
	z_index = 10

func _despawn() -> void:
	if _taken:
		return
	_taken = true
	expired.emit()
	queue_free()
