extends CharacterBody2D

# ── Constants ──────────────────────────────────────────────
const TILE_SIZE       := 16
const FOOT_SPEED      := 80.0
const BIKE_FRICTION   := 0.90
## Bike performance now lives on GameManager (see its Vehicle stats block)
## so it can be upgraded and shown on the status screen. These read it per
## use; the baselines there match the constants this replaced.
const STRAIGHTEN_DELAY     := 0.1         # seconds without steering before easing starts
const STRAIGHTEN_SPEED     := 4.0         # lerp_angle weight/sec once easing starts
const BOOST_MULT      := 1.8
const SLOW_MULT       := 0.4
const BOOST_DURATION  := 1.5
const SLOW_DURATION   := 1.0
const THROW_RANGE      := 6 * TILE_SIZE   # pixel range for toss (5 tiles + 20%)
const BIKE_MOUNT_RANGE := 3 * TILE_SIZE   # how close player must be to mount
const DOOR_INTERACT_RANGE := 4 * TILE_SIZE   # how close player must be to talk at a door
const NPC_INTERACT_RANGE  := 2.25 * TILE_SIZE # how close player must be to talk to an NPC
const TRAIL_STEP       := 12.0            # px between recorded trail positions
const NPC_RUNOVER_SPEED := 40.0           # min bike speed for a spin-out crash
const SPIN_DURATION     := 0.8            # seconds of lost control after hitting an NPC
const SPIN_VISUAL_SPEED := 2.0 * TAU / 0.8   # two full sprite rotations per spin-out
const EASY_TURN_SPEED    := 6.0           # rad/sec the easy-mode bike can re-aim itself
const RAMP_HOP_HEIGHT    := 14.0          # px of air gained off a speed ramp
const POTHOLE_HP_COST    := 0.5           # fractional HP lost to a pothole
const PUDDLE_HP_COST     := 0.25          # fractional HP lost to a puddle
const SHOPKEEPER_ID      := "nayra"       # talking to them opens the grocery counter
const BANKER_ID          := "jimmy_henderson"   # handles mortgage payments at City Hall
const CITY_HALL_ID       := "Building_TownHall"
const GROCERY_ID         := "Grocery"      # Nayra only sells from behind this counter
const MECHANIC_ID        := "Mechanic"     # Aidan only sells from behind this one
const MECHANIC_ID_NPC    := "aidan"        # runs the garage counter

# 8-direction bike textures ordered E, SE, S, SW, W, NW, N, NE
# (index = int(fposmod(deg + 22.5, 360) / 45))
const BIKE_TEXTURES : Array = [
	preload("res://assets/Hero/Hero_Bike_E.png"),
	preload("res://assets/Hero/Hero_bike_SE.png"),
	preload("res://assets/Hero/Hero_Bike_S.png"),
	preload("res://assets/Hero/Hero_Bike_SW.png"),
	preload("res://assets/Hero/Hero_Bike_W.png"),
	preload("res://assets/Hero/hero_bike_NW.png"),
	preload("res://assets/Hero/Hero_Bike_N.png"),
	preload("res://assets/Hero/Hero_Bike_NE.png"),
]

# ── State ──────────────────────────────────────────────────
var on_bike       := false
var bike_speed    := 0.0
var bike_angle    := -PI / 2.0   # facing up
var bike_frame    := 0
var bike_timer    := 0.0
var _bike_dir_index    := -1
var _visual_bike_angle := -PI / 2.0   # for sprite selection only, turns at full speed
var _straighten_timer  := 0.0   # time spent near a cardinal heading without steering
var snap_to_direction  := true
var _easy_bike_angle   := -PI / 2.0   # current facing used only by easy-mode bike movement


var _hopping      := false

var boost_timer   := 0.0
var slow_timer    := 0.0
var _spin_timer   := 0.0   # > 0 while spun out after running into an NPC

var facing        := Vector2.DOWN
var walk_frame    := 0
var walk_timer    := 0.0

# ── References ─────────────────────────────────────────────
@onready var foot_sprite  : Sprite2D = $FootSprite
#@onready var bike_sprite  : Node2D = $BikeSprite
@onready var bike_sprite  : Sprite2D = $BikeSprite2

@onready var anim_player  : AnimationPlayer = $AnimationPlayer
@onready var boost_aura   : Node2D = $BoostAura
@onready var slow_aura    : Node2D = $SlowAura
@onready var throw_marker : Node2D = $ThrowMarker

# References set from Main
var delivery_targets : Array = []
var world_bike       : Node2D = null
var pause_menu       : Node   = null
var dialogue_box     : Node   = null
var shop_panel       : Node   = null
var mortgage_panel   : Node   = null
var choice_panel     : Node   = null
var doors            : Array  = []
var road_regions      : Array[NavigationRegion2D] = []
var dirt_road_regions : Array[NavigationRegion2D] = []
var grass_regions     : Array[NavigationRegion2D] = []
var drop_pad_manager : Node               = null
var home_door_node   : Node2D             = null
var input_locked     : bool               = false
var interior_manager : Node               = null
var in_interior      : bool               = false

# Path trail for bird following
var path_trail       : Array[Vector2] = []
var _last_trail_pos  : Vector2 = Vector2.ZERO

# ── Signals ────────────────────────────────────────────────
signal mounted_bike()
signal dismounted_bike()
signal home_door_activated()

# ───────────────────────────────────────────────────────────
## The player's art is normalised the same way NPC sheets are: its frame height
## is scaled to NPCDefinition.TARGET_FRAME_HEIGHT so everyone matches on screen,
## and the Sprite Scale setting then multiplies that. FOOT_FRAME_H is the height
## of the slice taken in _process_foot().
const FOOT_FRAME_H : float = 60.0
const BIKE_FRAME_H : float = 68.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_mode(false)
	boost_aura.visible = false
	slow_aura.visible  = false
	GameManager.sprite_scale_changed.connect(_on_sprite_scale_changed)
	_on_sprite_scale_changed(GameManager.sprite_scale)

func _on_sprite_scale_changed(value: float) -> void:
	var target : float = NPCDefinition.TARGET_FRAME_HEIGHT
	var foot   : float = (target / FOOT_FRAME_H) * value
	var bike   : float = (target / BIKE_FRAME_H) * value
	foot_sprite.scale = Vector2(foot, foot)
	bike_sprite.scale = Vector2(bike, bike)

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	_tick_effects(delta)
	if on_bike:
		_process_bike(delta)
	else:
		_process_foot(delta)
	move_and_slide()
	_handle_npc_collisions()
	_record_trail()

func _record_trail() -> void:
	if global_position.distance_to(_last_trail_pos) >= TRAIL_STEP:
		path_trail.append(global_position)
		_last_trail_pos = global_position

func reset_trail() -> void:
	path_trail.clear()
	_last_trail_pos = global_position

func _input(event: InputEvent) -> void:
	if input_locked:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		_toggle_pause()
		return
	# E (talk to a nearby NPC / advance dialogue) works inside and outside.
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_try_dialogue()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if dialogue_box != null and dialogue_box.visible:
			dialogue_box.advance()
			return
	# Number keys take one portion out of the matching slot and hold it. What
	# happens next is up to E: eaten on the spot, or offered to a villager.
	if event is InputEventKey and event.pressed \
			and event.keycode >= KEY_1 and event.keycode < KEY_1 + GameManager.INVENTORY_SLOTS:
		if not (dialogue_box != null and dialogue_box.visible) and not get_tree().paused:
			_hold_slot(event.keycode - KEY_1)
			return
	# Q puts the held portion back in the bag.
	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		if not (dialogue_box != null and dialogue_box.visible) and not get_tree().paused:
			_stow_held()
			return
	if dialogue_box != null and dialogue_box.visible:
		if event.is_action_pressed("mount_bike") or event.is_action_pressed("throw_package"):
			dialogue_box.close()
		return
	# Inside a building: movement still polls in _physics_process, but bike /
	# throw / hop are suppressed. The Interior handles E at the bed (sleep).
	if in_interior:
		return
	if get_tree().paused:
		return
	if event.is_action_pressed("mount_bike"):
		_toggle_bike()
	if event.is_action_pressed("throw_package"):
		_try_throw()
	if event is InputEventKey and event.pressed and event.keycode == KEY_M:
		_hop()

func _toggle_pause() -> void:
	if pause_menu == null:
		return
	if get_tree().paused:
		pause_menu._on_close_button_pressed()
	else:
		pause_menu._on_pause_button_pressed()

func _try_dialogue() -> void:
	if dialogue_box == null:
		return
	if dialogue_box.visible:
		dialogue_box.advance()
		return
	if get_tree().paused:
		return
	# Talking to a nearby villager takes priority over entering a building.
	var nearest_npc : RegularNPC = null
	var nearest_d   : float      = NPC_INTERACT_RANGE
	var npcs        : Array      = get_tree().get_nodes_in_group("interactable_npc")
	for npc in npcs:
		var d : float = global_position.distance_to(npc.global_position)
		if d <= nearest_d:
			nearest_d   = d
			nearest_npc = npc
	if nearest_npc != null:
		nearest_npc.begin_interaction(self)
		# Holding something? Talking to a villager offers it to them, and that
		# replaces the usual chat (and any shop counter) for this interaction.
		if GameManager.is_holding():
			_offer_gift(nearest_npc)
			return
		# Jimmy at City Hall offers a choice of business or small talk; elsewhere
		# he just chats like anyone else.
		if nearest_npc.id == BANKER_ID and _at_city_hall() and choice_panel != null and mortgage_panel != null:
			_open_banker_choice(nearest_npc)
			return
		# Shopkeepers open their counter once the greeting finishes — but only
		# behind it. Nayra's schedule is all interior, so catching her outside
		# means she's walking to or from work: she chats, she doesn't sell.
		var after : Callable = Callable()
		if shop_panel != null and nearest_npc.id == SHOPKEEPER_ID and _at_grocery():
			after = func() -> void: shop_panel.open(shop_panel.GROCERY)
		# Aidan sells parts and vehicle upgrades, but only at the garage.
		elif shop_panel != null and nearest_npc.id == MECHANIC_ID_NPC and _at_mechanic():
			after = func() -> void: shop_panel.open(shop_panel.GARAGE)
		dialogue_box.open_blocks(nearest_npc.get_dialogue_blocks(), after)
		return
	# Otherwise, enter the building whose door we're standing at — but only on
	# foot. On the bike, prompt the player to dismount first.
	if interior_manager != null:
		if on_bike:
			if interior_manager.has_door_near(global_position):
				GameManager.show_message("🚲 Hop off your bike to go inside!")
				return
		elif interior_manager.try_enter_nearest(global_position):
			return
	# Nobody to talk to and no door to open: E eats what's in hand.
	if GameManager.is_holding():
		_eat_held()

## Hand the held portion to `npc`. Their reaction comes from the gift tables on
## their NPCDefinition (see NPCRegistry): loved and liked add friendship,
## disliked takes some away, and anything unlisted is accepted politely for
## nothing. Either way the item is gone — giving is final.
func _offer_gift(npc: RegularNPC) -> void:
	var item_id : String = GameManager.held_item
	if item_id.is_empty() or npc == null:
		return
	var def : NPCDefinition = npc.definition
	# An NPC with no definition (or no tables yet) still accepts the gift; it
	# simply earns nothing, rather than blocking the interaction.
	var reaction : int = def.gift_reaction(item_id) if def != null else 0
	var gained   : int = GameManager.add_friendship(npc.id, reaction)
	GameManager.take_held()

	var item_name : String = ItemRegistry.display_name(item_id)
	var who       : String = npc.display_label()
	var mood      : String = DialogueLine.CALM
	var line      : String = ""
	if reaction >= GameManager.GIFT_LOVE:
		mood = DialogueLine.HAPPY
		line = "%s? Oh, I love these — thank you!" % item_name
	elif reaction > 0:
		mood = DialogueLine.HAPPY
		line = "The %s? That's kind of you, thanks." % item_name
	elif reaction < 0:
		mood = DialogueLine.MAD
		line = "%s… no thank you. Not for me." % item_name
	else:
		line = "Oh — the %s? That's thoughtful, thanks." % item_name

	# Only report a friendship change that actually happened: at 0 or 100 the
	# meter can't move, and claiming otherwise would be a lie.
	if gained != 0:
		var arrow : String = "♥ +%d" % gained if gained > 0 else "♡ %d" % gained
		GameManager.show_message("%s %s — %s" % [arrow, who, _hearts_readout(npc.id)])

	dialogue_box.open(line, Callable(), npc.portrait_for_mood(mood), who)

## "3/10 hearts" for the on-screen gift confirmation.
func _hearts_readout(npc_id: String) -> String:
	return "%d/%d ♥" % [GameManager.friendship_hearts(npc_id), GameManager.FRIENDSHIP_HEARTS]

## Take one portion out of an inventory slot and hold it, ready to eat with E
## or hand to a villager. Pressing the same slot again puts it back.
func _hold_slot(slot: int) -> void:
	var s : Variant = GameManager.inventory[slot] if slot < GameManager.inventory.size() else null
	if not (s is Dictionary):
		return
	var id      : String = str(s.get("id", ""))
	var was_out : String = GameManager.held_item
	if not GameManager.hold_from_slot(slot):
		# The only ordinary failure is a full bag blocking the swap.
		if GameManager.is_holding():
			GameManager.show_message("🎒 No room to put away the %s first." \
					% ItemRegistry.display_name(GameManager.held_item))
		return
	if not GameManager.is_holding():
		# Pressing the held item's own slot stowed it instead.
		GameManager.show_message("🎒 Put the %s away." % ItemRegistry.display_name(was_out))
		return
	GameManager.show_message("%s Holding %s — E to use, talk to someone to give it, Q to put it back." \
			% [ItemRegistry.icon(id), ItemRegistry.display_name(id)])

## Put the held portion back in the bag.
func _stow_held() -> void:
	if not GameManager.is_holding():
		return
	var id : String = GameManager.held_item
	if GameManager.stow_held():
		GameManager.show_message("🎒 Put the %s away." % ItemRegistry.display_name(id))
	else:
		GameManager.show_message("🎒 Your bag is too full to put that back.")

## Eat what's in hand. Refuses (keeping the item in hand) when it isn't food or
## the energy would be wasted, so a portion is never lost for nothing.
func _eat_held() -> void:
	var id : String = GameManager.held_item
	if id.is_empty():
		return
	# Workshop materials can be carried and gifted, but not eaten.
	if ItemRegistry.is_material(id):
		GameManager.show_message("🔧 %s isn't edible — it's for repairs." % ItemRegistry.display_name(id))
		return
	if GameManager.energy >= GameManager.max_energy:
		GameManager.show_message("😋 You're too full to eat that right now.")
		return
	GameManager.take_held()
	GameManager.add_energy(ItemRegistry.energy(id))
	GameManager.show_message("%s Ate %s. +%d energy" \
			% [ItemRegistry.icon(id), ItemRegistry.display_name(id), ItemRegistry.energy(id)])


## True when the player is inside City Hall.
func _at_city_hall() -> bool:
	return in_interior and interior_manager != null and interior_manager.current_building_id == CITY_HALL_ID

## True while the player is standing inside the grocery store, where the
## shop counter is open for business.
func _at_grocery() -> bool:
	return in_interior and interior_manager != null and interior_manager.current_building_id == GROCERY_ID

## True while the player is standing inside the mechanic shop, where
## Aidan's counter is open for business.
func _at_mechanic() -> bool:
	return in_interior and interior_manager != null and interior_manager.current_building_id == MECHANIC_ID

## Jimmy's City Hall greeting, then a menu: pay the mortgage, or just chat.
func _open_banker_choice(npc: RegularNPC) -> void:
	var portrait : Texture2D = npc.portrait_for_mood(DialogueLine.HAPPY)
	dialogue_box.open("Hiya neighbour! How can I help you today?", func() -> void:
		var opts : Array = []
		if GameManager.mortgage > 0:
			opts.append({"text": "Make a payment on my mortgage", "id": "pay"})
		opts.append({"text": "Just chat", "id": "chat"})
		choice_panel.open("Jimmy Henderson", opts)
	, portrait, npc.display_label())

## Routed here by Main when a choice comes back from the panel.
func on_banker_choice(id: String, npc: RegularNPC) -> void:
	if id == "pay":
		mortgage_panel.open()
	elif id == "chat" and npc != null:
		dialogue_box.open_blocks(npc.get_dialogue_blocks())

func _hop() -> void:
	if on_bike or _hopping:
		return
	_hopping = true
	var tween := create_tween()
	tween.tween_property(foot_sprite, "position:y", -18.0, 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_property(foot_sprite, "position:y",   0.0, 0.20).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): _hopping = false)

# ── Mode switching ─────────────────────────────────────────
func _toggle_bike() -> void:
	if on_bike:
		_dismount()
	else:
		_try_mount()

func _try_mount() -> void:
	if world_bike == null or not world_bike.visible:
		GameManager.show_message("No bike nearby!")
		return
	if global_position.distance_to(world_bike.global_position) > BIKE_MOUNT_RANGE:
		GameManager.show_message("🚲 Get closer to the bike first!")
		return
	on_bike = true
	bike_speed = 0.0
	bike_angle = velocity.angle() if velocity.length() > 10 else -PI / 2.0
	_visual_bike_angle = bike_angle
	_easy_bike_angle   = bike_angle
	_straighten_timer = 0.0
	world_bike.visible = false
	_set_mode(true)
	mounted_bike.emit()
	GameManager.show_message("🚲 Hopped on the bicycle!")

func _dismount() -> void:
	on_bike = false
	bike_speed = 0.0
	if world_bike != null:
		world_bike.global_position = global_position + Vector2(TILE_SIZE, 0)
		world_bike.visible = true
	_set_mode(false)
	dismounted_bike.emit()
	GameManager.show_message("🚶 Back on foot!")

func force_dismount() -> void:
	if on_bike:
		on_bike = false
		bike_speed = 0.0
		_set_mode(false)

func _set_mode(biking: bool) -> void:
	foot_sprite.visible = !biking
	bike_sprite.visible =  biking

# ── Foot movement ──────────────────────────────────────────
func _process_foot(delta: float) -> void:
	var dir := _get_dir()
	var spd := FOOT_SPEED * _speed_mult(false)
	velocity = dir * spd

	if dir != Vector2.ZERO:
		facing = dir.normalized()
		walk_timer += delta
		if walk_timer >= 0.15:
			walk_timer = 0.0
			walk_frame = (walk_frame + 1) % 6
	else:
		walk_timer = 0.0
		walk_frame = 0

	foot_sprite.flip_h = facing.x < 0
	foot_sprite.region_rect = Rect2(walk_frame * 68, 0, 68, 60) 
	#width?, height start, width, height

# ── Bike movement ──────────────────────────────────────────
func _process_bike(delta: float) -> void:
	if GameManager.easy_bike:
		_process_bike_easy(delta)
		return
	# Spin-out: controls dead, speed bleeds off fast, sprite whirls.
	var spinning := _spin_timer > 0.0
	if spinning:
		_spin_timer -= delta
		bike_speed *= 0.92

	var turn_input := 0.0
	if not spinning:
		if Input.is_action_pressed("move_left"):  turn_input = -1.0
		if Input.is_action_pressed("move_right"): turn_input =  1.0

	var accel   := not spinning and Input.is_action_pressed("move_up")
	var braking := not spinning and Input.is_action_pressed("move_down")
	var mult   := _speed_mult()

	if accel:
		bike_speed = move_toward(bike_speed, _bike_max_speed() * mult, _bike_accel() * mult)
	elif braking:
		if bike_speed > 1.0:
			bike_speed = move_toward(bike_speed, 0.0, _bike_accel() * 2.0)
		else:
			bike_speed = move_toward(bike_speed, -_bike_max_speed() * 0.35, _bike_accel())
	else:
		bike_speed *= BIKE_FRICTION
		if abs(bike_speed) < 0.5:
			bike_speed = 0.0
			
	if bike_speed > 2.0:
		var turn_factor: float = clamp(bike_speed / _bike_max_speed(), 0.3, 1.0)
		bike_angle += turn_input * _bike_turn_speed() * turn_factor * delta

	# Auto-straighten: when riding without steering input, hold briefly then
	# ease the heading onto the nearest of the 8 directions. No tolerance gate:
	# the nearest octant is at most 22.5° away, so snapping always engages.
	if snap_to_direction and turn_input == 0.0 and abs(bike_speed) > 2.0:
		_straighten_timer += delta
		if _straighten_timer >= STRAIGHTEN_DELAY:
			var nearest_octant: float = round(bike_angle / (PI / 4.0)) * (PI / 4.0)
			bike_angle = lerp_angle(bike_angle, nearest_octant, STRAIGHTEN_SPEED * delta)
	else:
		_straighten_timer = 0.0

	velocity = Vector2(cos(bike_angle), sin(bike_angle)) * bike_speed

	# Visual angle turns at full _bike_turn_speed() on input so the sprite reacts immediately,
	# independent of the physics turn_factor. Snaps back to bike_angle when not turning.
	if spinning:
		_visual_bike_angle += SPIN_VISUAL_SPEED * delta
	elif turn_input != 0.0 and bike_speed > 0.0:
		_visual_bike_angle += turn_input * _bike_turn_speed() * delta
	else:
		_visual_bike_angle = bike_angle

	# Direction: 8-way lookup. Angle 0=East, clockwise. Offset +22.5 centres each 45° sector.
	var dir_index := int(fposmod(rad_to_deg(_visual_bike_angle) + 22.5, 360.0) / 45.0)
	if dir_index != _bike_dir_index:
		_bike_dir_index = dir_index
		bike_sprite.texture = BIKE_TEXTURES[dir_index]

	# Frame animation — runs in reverse when backing up
	if bike_speed != 0.0:
		bike_timer += delta
		if bike_timer >= 0.15:
			bike_timer = 0.0
			bike_frame = (bike_frame + 5 + int(sign(bike_speed))) % 5
	else:
		bike_timer = 0.0
		bike_frame = 0
	bike_sprite.frame = bike_frame



# ── NPC collisions ─────────────────────────────────────────
## After move_and_slide(): on foot we gently shove the NPC along in our
## direction of travel (herding); on the bike at speed the NPC is knocked
## toward whichever side of the bike it's on and the player spins out.
func _handle_npc_collisions() -> void:
	for i in get_slide_collision_count():
		var collider : Object = get_slide_collision(i).get_collider()
		if collider is NPCBase:
			var npc        : NPCBase = collider
			var cur_speed  : float   = velocity.length() if GameManager.easy_bike else absf(bike_speed)
			var travel     : Vector2 = velocity.normalized() if GameManager.easy_bike else Vector2(cos(bike_angle), sin(bike_angle)) * signf(bike_speed)
			if on_bike and cur_speed > NPC_RUNOVER_SPEED:
				var side : float = signf(travel.cross(npc.global_position - global_position))
				if side == 0.0:
					side = 1.0
				npc.knock_back((travel.orthogonal() * side + travel * 0.3).normalized())
				_spin_out()
			elif not on_bike:
				npc.push(velocity)
		elif collider is Vehicle:
			# Riding into a parked vehicle: costs health and rizz, and spins out.
			var cur_speed : float = velocity.length() if GameManager.easy_bike else absf(bike_speed)
			if on_bike and cur_speed > NPC_RUNOVER_SPEED:
				_hit_vehicle(collider)

func _hit_vehicle(vehicle: Vehicle) -> void:
	if _spin_timer > 0.0:
		return   # already spinning from this crash
	var msg : String = vehicle.on_hit_by_player()
	_spin_timer = SPIN_DURATION
	GameManager.show_message(msg)

func _spin_out() -> void:
	if _spin_timer > 0.0:
		return
	_spin_timer = SPIN_DURATION
	GameManager.add_hp(-1)      # spinouts cost health …
	GameManager.add_rizz(-1)    # … and a point of rizz
	GameManager.show_message("💫 Crash! You spun out!")

func _process_bike_easy(delta: float) -> void:
	var spinning := _spin_timer > 0.0
	if spinning:
		_spin_timer -= delta
		velocity   *= 0.85
		_visual_bike_angle += SPIN_VISUAL_SPEED * delta
		var dir_index := int(fposmod(rad_to_deg(_visual_bike_angle) + 22.5, 360.0) / 45.0)
		if dir_index != _bike_dir_index:
			_bike_dir_index = dir_index
			bike_sprite.texture = BIKE_TEXTURES[dir_index]
		bike_timer += delta
		if bike_timer >= 0.15:
			bike_timer = 0.0
			bike_frame = (bike_frame + 1) % 5
		bike_sprite.frame = bike_frame
		return

	var dir  := _get_dir()
	var mult := _speed_mult()

	if dir != Vector2.ZERO:
		# Turn the bike's facing toward the pressed direction at a fixed rate
		# instead of snapping instantly — a 180° reversal takes twice as long
		# to come about as a 90° turn.
		var target_angle : float = dir.angle()
		_easy_bike_angle = rotate_toward(_easy_bike_angle, target_angle, EASY_TURN_SPEED * delta)
		velocity = Vector2(cos(_easy_bike_angle), sin(_easy_bike_angle)) * _bike_max_speed() * mult

		var dir_index := int(fposmod(rad_to_deg(_easy_bike_angle) + 22.5, 360.0) / 45.0)
		if dir_index != _bike_dir_index:
			_bike_dir_index = dir_index
			bike_sprite.texture = BIKE_TEXTURES[dir_index]
		bike_timer += delta
		if bike_timer >= 0.15:
			bike_timer = 0.0
			bike_frame = (bike_frame + 1) % 5
	else:
		velocity   = Vector2.ZERO
		bike_timer = 0.0
		bike_frame = 0
	bike_sprite.frame = bike_frame

# ── Throwing ───────────────────────────────────────────────
func _try_throw() -> void:
	if GameManager.packages <= 0:
		GameManager.show_message("No packages left!")
		return

	var best_target  = null
	var best_dist    := THROW_RANGE

	for target in delivery_targets:
		if target.is_delivered:
			continue
		var d := global_position.distance_to(target.door_position)
		if d < best_dist:
			best_dist   = d
			best_target = target

	if best_target == null:
		GameManager.show_message("No delivery nearby! Get closer.")
		return

	if GameManager.use_package():
		# Toss the parcel in an arc; it delivers itself when it lands.
		var world : Node = get_parent().get_node_or_null("WorldGenerator")
		if world != null and world.has_method("spawn_package"):
			world.spawn_package(global_position, best_target.door_position, best_target)
		else:
			best_target.receive_package(global_position)

# ── Effects ────────────────────────────────────────────────
func apply_boost() -> void:
	boost_timer = BOOST_DURATION
	boost_aura.visible = true
	GameManager.add_rizz(1)     # grabbing a speed-up looks cool: +1 rizz
	GameManager.show_message("💨 Speed Boost!")

## Hitting a wedge ramp: speed boost plus a short air-time hop.
func apply_ramp() -> void:
	boost_timer = BOOST_DURATION
	boost_aura.visible = true
	GameManager.add_rizz(1)     # catching air looks cool: +1 rizz
	GameManager.show_message("🛹 Ramp! Nice air!")
	_air_hop()

## Hitting a puddle: lose control and spin out. Cheaper than an NPC crash —
## a quarter point of health rather than a full one.
func apply_puddle() -> void:
	if _spin_timer > 0.0:
		return
	_spin_timer = SPIN_DURATION
	GameManager.add_rizz(-1)
	GameManager.damage_hp(PUDDLE_HP_COST)
	GameManager.show_message("💦 Splash! You hydroplaned!")

func apply_slow() -> void:
	slow_timer = SLOW_DURATION
	slow_aura.visible = true
	GameManager.add_rizz(-1)    # a slowdown is a bad look: -1 rizz
	GameManager.damage_hp(POTHOLE_HP_COST)
	GameManager.show_message("🕳️ Pothole! Slowed down!")

## Small jump arc on whichever sprite is currently showing. Purely visual —
## movement carries on underneath, so it can't strand the player mid-air.
func _air_hop() -> void:
	if _hopping:
		return
	var spr : Node2D = bike_sprite if on_bike else foot_sprite
	var base : float = 0.0 if not on_bike else spr.position.y
	_hopping = true
	var tween := create_tween()
	tween.tween_property(spr, "position:y", base - RAMP_HOP_HEIGHT, 0.16).set_ease(Tween.EASE_OUT)
	tween.tween_property(spr, "position:y", base, 0.22).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): _hopping = false)

func _tick_effects(delta: float) -> void:
	# On the bike the spin timer is driven by the bike movement handlers (which
	# also whirl the sprite). On foot nothing else drains it, so do it here —
	# otherwise a puddle hit while walking would leave the timer stuck.
	if not on_bike and _spin_timer > 0.0:
		_spin_timer -= delta
	if boost_timer > 0.0:
		boost_timer -= delta
		if boost_timer <= 0.0:
			boost_aura.visible = false
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_aura.visible = false

func _is_in_region(region: NavigationRegion2D) -> bool:
	if region == null:
		return false
	var nav_poly := region.navigation_polygon
	if nav_poly == null:
		return false
	var local_pos := region.to_local(global_position)
	for i in nav_poly.get_outline_count():
		if Geometry2D.is_point_in_polygon(local_pos, nav_poly.get_outline(i)):
			return true
	return false

func _is_in_any_region(regions: Array[NavigationRegion2D]) -> bool:
	for region in regions:
		if _is_in_region(region):
			return true
	return false

## Surface zones can overlap on the map (e.g. a grass patch under a road).
## Resolution is best-surface-wins, checked in this fixed priority order:
## Road (fastest) > Dirt Road (neutral) > Grass (slowest).
func _speed_mult(apply_surface: bool = true) -> float:
	var m := 1.0
	if boost_timer > 0.0:
		m = BOOST_MULT
	elif slow_timer > 0.0:
		m = SLOW_MULT
	elif apply_surface:
		if _is_in_any_region(road_regions):        m = 1.2
		elif _is_in_any_region(dirt_road_regions): m = 1.0
		# Grass is the off-road case: the bike's off_road stat is the fraction
		# of speed it keeps there, so a better bike loses less. On foot the
		# bike's tyres are irrelevant, so the stock penalty applies.
		elif _is_in_any_region(grass_regions):
			m = GameManager.bike_off_road if on_bike else GameManager.BIKE_BASE_OFF_ROAD
	# Out of energy: move at 70% speed.
	if GameManager.energy <= 0:
		m *= 0.7
	return m

# ── Bike performance ───────────────────────────────
func _bike_max_speed() -> float:
	return GameManager.bike_max_speed

func _bike_accel() -> float:
	return GameManager.bike_accel

func _bike_turn_speed() -> float:
	return GameManager.bike_handling

# ── Helpers ────────────────────────────────────────────────
func _get_dir() -> Vector2:
	var d := Vector2.ZERO
	if Input.is_action_pressed("move_up"):    d.y -= 1
	if Input.is_action_pressed("move_down"):  d.y += 1
	if Input.is_action_pressed("move_left"):  d.x -= 1
	if Input.is_action_pressed("move_right"): d.x += 1
	return d.normalized()
