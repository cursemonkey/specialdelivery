extends Node

const DAY_NAMES := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]


func day_name() -> String:
	return DAY_NAMES[(day - 1) % DAY_NAMES.size()]

func weekday_abbrev() -> String:    # "Mon"
	return DAY_NAMES[(day - 1) % DAY_NAMES.size()].substr(0, 3)

# ── Calendar (derived from the absolute `day` counter) ─────
func calendar_date() -> Dictionary:
	return Calendar.date_for_day(day)

func season() -> int:
	return Calendar.date_for_day(day).season

func date_label() -> String:        # "Year 1, Fall 9"
	return Calendar.format_long(day)

func date_label_short() -> String:  # "Fall 9 · Yr 1"
	return Calendar.format_short(day)

func date_label_hud() -> String:    # "Mon, Winter 12"
	var d : Dictionary = Calendar.date_for_day(day)
	return "%s, %s %d" % [weekday_abbrev(), Calendar.SEASON_NAMES[d.season], d.day]

# Global game state
var cash: int = 0
var packages: int = 0
var day: int = 1
var day_cash: int = 0   # earnings this day only (used for end-of-day bonus)
var total_targets: int = 0
var delivered_count: int = 0
var home_id: String = ""
var mortgage: int = 0
signal mortgage_changed(amount: int)

## Pay `amount` off the mortgage, capped at what's owed and what's affordable.
## Returns the amount actually paid (0 if nothing could be paid).
func pay_mortgage(amount: int) -> int:
	var paid : int = mini(mini(amount, mortgage), cash)
	if paid <= 0:
		return 0
	cash     -= paid
	mortgage -= paid
	cash_changed.emit(cash)
	mortgage_changed.emit(mortgage)
	return paid

## The most the player could put down right now.
func max_mortgage_payment() -> int:
	return mini(cash, mortgage)
var easy_bike             : bool = false
var snap_to_direction     : bool = true
## Global multiplier applied to the player and every NPC sprite, so the whole
## cast can be tuned to one size while art is still being swapped in.
var sprite_scale          : float = 1.0
signal sprite_scale_changed(value: float)

func set_sprite_scale(value: float) -> void:
	sprite_scale = clampf(value, 0.5, 1.0)
	sprite_scale_changed.emit(sprite_scale)
var max_drops_per_day     : int  = 4
var max_packages_per_drop : int  = 3

# ── Vehicle stats ─────────────────────────────────
## The bicycle's characteristics, shown on the status screen and read by
## Player for movement. These are progression (upgradeable), so they live in
## the save rather than in settings.
##
## Baselines match the values Player used as constants before these existed, so
## a fresh bike rides exactly as it always did.
const BIKE_BASE_MAX_PACKAGES : int   = 4      # packages on the rack at once
const BIKE_BASE_MAX_SPEED    : float = 148.0  # px/sec flat-out
const BIKE_BASE_ACCEL        : float = 5.0    # px/sec² build-up
const BIKE_BASE_HANDLING     : float = 2.8    # rad/sec turn rate
const BIKE_BASE_OFF_ROAD     : float = 0.8    # speed kept on grass (1.0 = no penalty)

var bike_max_packages : int   = BIKE_BASE_MAX_PACKAGES
var bike_max_speed    : float = BIKE_BASE_MAX_SPEED
var bike_accel        : float = BIKE_BASE_ACCEL
var bike_handling     : float = BIKE_BASE_HANDLING
## Fraction of top speed retained off-road. Higher is better: 1.0 would mean
## grass costs nothing, the 0.8 baseline means a 20% penalty.
var bike_off_road     : float = BIKE_BASE_OFF_ROAD

## The scooter, bought from Aidan. Carries one more package than the bike and is
## quicker on the road, but its small wheels cope worse with grass. Riding it
## still uses the bike sprite for now.
const SCOOTER_MAX_PACKAGES : int   = BIKE_BASE_MAX_PACKAGES + 1
const SCOOTER_MAX_SPEED    : float = 205.0   # noticeably quicker than the bike's 148
const SCOOTER_ACCEL        : float = 7.0
const SCOOTER_HANDLING     : float = 2.5     # a touch heavier to turn
const SCOOTER_OFF_ROAD     : float = 0.7     # worse on grass than the bike's 0.8

## Which vehicle the player rides. The scooter replaces the bike once bought.
enum Vehicle { BIKE, SCOOTER }
var vehicle : int = Vehicle.BIKE

## Rack slots added by storage upgrades, applied to whichever vehicle is ridden.
var storage_upgrades : int = 0
const STORAGE_UPGRADE_SLOTS : int = 2   # packages gained per upgrade bought

signal bike_stats_changed()

func has_scooter() -> bool:
	return vehicle == Vehicle.SCOOTER

func vehicle_name() -> String:
	return "Scooter" if has_scooter() else "Bicycle"

## Swap to the scooter. Capacity/speed come from its profile from here on.
func grant_scooter() -> void:
	if has_scooter():
		return
	vehicle        = Vehicle.SCOOTER
	bike_max_speed = SCOOTER_MAX_SPEED
	bike_accel     = SCOOTER_ACCEL
	bike_handling  = SCOOTER_HANDLING
	bike_off_road  = SCOOTER_OFF_ROAD
	_apply_capacity()

## Buy one more crate for the rack.
func add_storage_upgrade() -> void:
	storage_upgrades += 1
	_apply_capacity()

## Base capacity for the current vehicle, before upgrades.
func base_capacity() -> int:
	return SCOOTER_MAX_PACKAGES if has_scooter() else BIKE_BASE_MAX_PACKAGES

## Recompute the rack from the vehicle plus everything bolted to it.
func _apply_capacity() -> void:
	set_bike_max_packages(base_capacity() + storage_upgrades * STORAGE_UPGRADE_SLOTS)

## Room left on the rack right now.
func package_space() -> int:
	return maxi(bike_max_packages - packages, 0)

## True when the rack is full, so drop pads know to leave the rest behind.
func bike_is_full() -> bool:
	return package_space() <= 0

func set_bike_max_packages(value: int) -> void:
	bike_max_packages = maxi(value, 1)
	# Shedding capacity can't leave us over-loaded.
	if packages > bike_max_packages:
		set_packages(bike_max_packages)
	bike_stats_changed.emit()

## Percentage a stat sits at against its baseline, for the status screen's bars
## (100% = stock bike). Upgrades push these past 100.
func bike_stat_percent(value: float, baseline: float) -> float:
	if baseline <= 0.0:
		return 0.0
	return (value / baseline) * 100.0

# ── Player day-stats (0..max, reset each day) ──────────────
var max_hp     : int = 20
var max_energy : int = 20
var max_rizz   : int = 20
var hp     : int = 20   # full each day; spinouts cost 1; 0 ends the day
var energy : int = 20   # full each day; moving drains it; 0 = half speed
var rizz   : int = 0    # starts at 0; each point adds 1% delivery tip

## Sub-point damage carried between hits (see damage_hp). Kept separate so `hp`
## stays an int: the HP bar draws one segment per whole point, so a segment only
## vanishes once accumulated fractions add up to a full point.
var _hp_debt : float = 0.0

signal hp_changed(v: int)
signal energy_changed(v: int)
signal rizz_changed(v: int)
signal out_of_health()

func add_hp(delta: int) -> void:
	var was : int = hp
	hp = clampi(hp + delta, 0, max_hp)
	hp_changed.emit(hp)
	if was > 0 and hp == 0:
		out_of_health.emit()

## Fractional damage, e.g. 0.5 for a pothole or 0.25 for a puddle. Fractions
## accumulate in `_hp_debt` and only bite into `hp` once they total a whole
## point — so four puddle hits cost one HP segment, not four.
func damage_hp(amount: float) -> void:
	if amount <= 0.0:
		return
	_hp_debt += amount
	var whole : int = int(floor(_hp_debt))
	if whole <= 0:
		return
	_hp_debt -= float(whole)
	add_hp(-whole)

func add_energy(delta: int) -> void:
	energy = clampi(energy + delta, 0, max_energy)
	energy_changed.emit(energy)

func add_rizz(delta: int) -> void:
	rizz = clampi(rizz + delta, 0, max_rizz)
	rizz_changed.emit(rizz)

## Reset the per-day stats: full health & energy, zero rizz. The ledger is NOT
## cleared here — it spans a calendar day and is cleared by clear_ledger() on
## the date rollover, so a same-day nap keeps the morning's deliveries.
func reset_day_stats() -> void:
	hp       = max_hp
	energy   = max_energy
	rizz     = 0
	_hp_debt = 0.0
	hp_changed.emit(hp)
	energy_changed.emit(energy)
	rizz_changed.emit(rizz)

## Partial rest: restore a fraction of max HP and energy (0.0–1.0+). Rizz is a
## reputation built during the day, so sleeping does not touch it. Rounds up so
## a single hour always returns something visible on the segmented bars.
func recover_by_fraction(fraction: float) -> void:
	if fraction <= 0.0:
		return
	var hp_gain : int = int(ceil(float(max_hp)     * fraction))
	var en_gain : int = int(ceil(float(max_energy) * fraction))
	hp       = clampi(hp + hp_gain,         0, max_hp)
	energy   = clampi(energy + en_gain,     0, max_energy)
	_hp_debt = 0.0   # a rest clears any part-point of pending damage
	hp_changed.emit(hp)
	energy_changed.emit(energy)

func rizz_over_half() -> bool:
	return float(rizz) / float(max_rizz) > 0.5

# ── Delivery ledger ────────────────────────────────────────
# One entry per delivery: {name, value, rizz_tip, speed_tip, tip}.
#   value     = flat base pay for the drop
#   rizz_tip  = the customer's tip for style (+1% of base per Rizz point)
#   speed_tip = the customer's tip for promptness (up to +100% of base)
#   tip       = rizz_tip + speed_tip (kept for convenience / older readers)
# The ledger now covers a calendar day (0:00–23:59:59), so it survives naps and
# is only cleared when the date actually rolls over — see clear_ledger().
var _ledger : Array = []

func get_ledger() -> Array:
	return _ledger

## Clear the day's ledger. Called only on a true calendar-day rollover, NOT on
## every sleep — a same-day nap must keep the morning's deliveries visible.
func clear_ledger() -> void:
	_ledger.clear()

## Rebuild the ledger from a save. JSON has no ints, so every number comes
## back as a float and is coerced; a save written before the ledger was
## persisted simply starts empty.
func _ledger_from_save(raw: Variant) -> void:
	_ledger.clear()
	if not raw is Array:
		return
	for e in raw:
		if not e is Dictionary:
			continue
		var rizz_tip  : int = int(e.get("rizz_tip",  0))
		var speed_tip : int = int(e.get("speed_tip", 0))
		_ledger.append({
			"name":      str(e.get("name", "Delivery")),
			"value":     int(e.get("value", 0)),
			"rizz_tip":  rizz_tip,
			"speed_tip": speed_tip,
			"tip":       rizz_tip + speed_tip,
		})

## A tip has two independent halves, so each can be zero on its own:
##   • Rizz  — style, +1% of base per Rizz point (0 at zero Rizz)
##   • Speed — promptness, scaled from the delivery time (0 at/after SLOW_TIME)
## A very slow delivery by a player with no Rizz therefore tips exactly $0.
func rizz_tip_for(base_earned: int) -> int:
	return int(round(float(base_earned) * float(rizz) * 0.01))

func speed_tip_for(base_earned: int, landing_time: float) -> int:
	return int(round(float(base_earned) * speed_tip_frac(landing_time)))

## 0.0 … (DELIVERY_MAX_MULT - 1.0): the speed half of the tip as a fraction of
## base. Full value up to FAST_TIME, decaying to nothing by SLOW_TIME.
func speed_tip_frac(landing_time: float) -> float:
	return _delivery_mult(landing_time) - DELIVERY_MIN_MULT

## Record a delivery, splitting base pay from the two tip halves, add the total
## to cash, and return that total.
func register_delivery(base_earned: int, landing_time: float, target_name: String) -> int:
	var value     : int = base_earned
	var rizz_tip  : int = rizz_tip_for(base_earned)
	var speed_tip : int = speed_tip_for(base_earned, landing_time)
	var total     : int = value + rizz_tip + speed_tip
	_ledger.append({
		"name":      target_name,
		"value":     value,
		"rizz_tip":  rizz_tip,
		"speed_tip": speed_tip,
		"tip":       rizz_tip + speed_tip,
	})
	on_delivery_complete(total)
	return total

# ── Inventory ──────────────────────────────────────────────
## A fixed row of slots, each either empty (null) or holding one item type with
## a remaining-portion count: {"id": String, "portions": int}. Items of the same
## kind stack: a purchase tops up an existing stack of that item before taking a
## fresh slot, up to STACK_LIMIT portions per slot.
const INVENTORY_SLOTS : int = 6

## Most portions one slot can hold, whatever the item.
const STACK_LIMIT : int = 99

var inventory : Array = []

signal inventory_changed()

func _init() -> void:
	_clear_inventory()

func _clear_inventory() -> void:
	inventory = []
	for i in INVENTORY_SLOTS:
		inventory.append(null)

## First slot index holding `id` with portions left, or -1.
func find_item_slot(id: String) -> int:
	for i in inventory.size():
		var s : Variant = inventory[i]
		if s is Dictionary and str(s.get("id", "")) == id and int(s.get("portions", 0)) > 0:
			return i
	return -1

## Portions of `id` this slot could still take (0 if it holds something else).
func _slot_headroom(slot: int, id: String) -> int:
	var s : Variant = inventory[slot]
	if s == null:
		return STACK_LIMIT
	if not (s is Dictionary) or str(s.get("id", "")) != id:
		return 0
	return maxi(STACK_LIMIT - int(s.get("portions", 0)), 0)

## Total portions of `id` the bag could still take across every slot — partial
## stacks of that item first, then empty slots.
func room_for(id: String) -> int:
	var room : int = 0
	for i in inventory.size():
		room += _slot_headroom(i, id)
	return room

## How many portions of `id` the bag is holding right now.
func count_of(id: String) -> int:
	var n : int = 0
	for s in inventory:
		if s is Dictionary and str(s.get("id", "")) == id:
			n += int(s.get("portions", 0))
	return n

func first_empty_slot() -> int:
	for i in inventory.size():
		if inventory[i] == null:
			return i
	return -1

func has_free_slot() -> bool:
	return first_empty_slot() != -1

## Put one purchase of `id` into the bag, topping up existing stacks of that
## item before opening a fresh slot. A purchase is all-or-nothing: if the whole
## amount won't fit, nothing is added and this returns false, so the shop never
## charges for a partial delivery.
func add_item(id: String) -> bool:
	if not ItemRegistry.has(id):
		return false
	return add_portions(id, ItemRegistry.portions(id))

## Add `amount` portions of `id`, spilling across slots as needed. All-or-
## nothing: returns false and changes nothing when there isn't room for all of
## it. Partial stacks of the same item fill first so the bag stays tidy.
func add_portions(id: String, amount: int) -> bool:
	if not ItemRegistry.has(id) or amount <= 0:
		return false
	if room_for(id) < amount:
		return false
	var left : int = amount
	# Top up existing stacks of this item first …
	for i in inventory.size():
		if left <= 0:
			break
		var s : Variant = inventory[i]
		if not (s is Dictionary) or str(s.get("id", "")) != id:
			continue
		var take : int = mini(_slot_headroom(i, id), left)
		if take <= 0:
			continue
		s["portions"] = int(s.get("portions", 0)) + take
		inventory[i]  = s
		left -= take
	# … then open fresh slots for whatever is still left.
	for i in inventory.size():
		if left <= 0:
			break
		if inventory[i] != null:
			continue
		var take2 : int = mini(STACK_LIMIT, left)
		inventory[i] = {"id": id, "portions": take2}
		left -= take2
	inventory_changed.emit()
	return true

## Eat one portion from `slot`, restoring that item's energy. The slot empties
## when its last portion is gone. Returns false if the slot has nothing to eat.
func consume_slot(slot: int) -> bool:
	if slot < 0 or slot >= inventory.size():
		return false
	var s : Variant = inventory[slot]
	if not (s is Dictionary):
		return false
	var id    : String = str(s.get("id", ""))
	var left  : int    = int(s.get("portions", 0))
	if left <= 0 or not ItemRegistry.has(id):
		return false
	# Refuse when it would be wasted: energy is already full, so the portion
	# would be spent for nothing.
	if energy >= max_energy:
		return false
	add_energy(ItemRegistry.energy(id))
	left -= 1
	if left <= 0:
		inventory[slot] = null
	else:
		s["portions"] = left
		inventory[slot] = s
	inventory_changed.emit()
	return true

## Slots as save-friendly plain data (and back). Nulls are preserved so slot
## positions survive a round-trip.
func _inventory_to_save() -> Array:
	var out : Array = []
	for s in inventory:
		if s is Dictionary:
			out.append({"id": str(s.get("id", "")), "portions": int(s.get("portions", 0))})
		else:
			out.append(null)
	return out

func _inventory_from_save(data: Variant) -> void:
	_clear_inventory()
	if not (data is Array):
		return
	for i in mini(data.size(), INVENTORY_SLOTS):
		var s : Variant = data[i]
		if not (s is Dictionary):
			continue
		var id : String = str(s.get("id", ""))
		var n  : int    = int(s.get("portions", 0))
		# Drop anything the catalogue no longer knows about, so removing an item
		# from ITEMS can't corrupt an existing save.
		if ItemRegistry.has(id) and n > 0:
			# Clamp to the stack limit in case it was lowered since the save.
			inventory[i] = {"id": id, "portions": mini(n, STACK_LIMIT)}
	inventory_changed.emit()

# ── Lifetime statistics ────────────────────────────────────
## Records built from each closed-out calendar day. Saves written before this
## existed simply start empty, so an in-progress game begins accumulating from
## the next day-end onward rather than back-filling history it never recorded.
var stats : Dictionary = {
	"days_recorded":     0,
	"total_earnings":    0,
	"total_tips":        0,
	"total_deliveries":  0,
	"best_earnings":     0,   "best_earnings_day":     0,
	"best_tips":         0,   "best_tips_day":         0,
	"best_deliveries":   0,   "best_deliveries_day":   0,
}

## Fold one finished calendar day into the lifetime records. `net` is what the
## player actually banked (gross minus any dock).
func record_day_stats(day_number: int, net: int, tips: int, deliveries: int) -> void:
	stats.days_recorded    = int(stats.days_recorded)    + 1
	stats.total_earnings   = int(stats.total_earnings)   + net
	stats.total_tips       = int(stats.total_tips)       + tips
	stats.total_deliveries = int(stats.total_deliveries) + deliveries
	if net > int(stats.best_earnings):
		stats.best_earnings     = net
		stats.best_earnings_day = day_number
	if tips > int(stats.best_tips):
		stats.best_tips     = tips
		stats.best_tips_day = day_number
	if deliveries > int(stats.best_deliveries):
		stats.best_deliveries     = deliveries
		stats.best_deliveries_day = day_number

const SAVE_SLOT_COUNT : int = 5
var current_slot      : int = -1   # which slot autosaves write to; -1 = none chosen yet
# Clock time read from the last loaded save, applied by Main when resuming.
var loaded_hour       : float = TimeManager.DAY_START_HOUR

# Monotonic in-game seconds, advanced by Main only during active play (frozen
# while paused). Used to time deliveries from pad-landing to drop-off.
var play_clock : float = 0.0

# Delivery speed bonus: a package delivered within FAST seconds of landing pays
# the full MAX multiplier; by SLOW seconds it decays to MIN (never below base).
const DELIVERY_FAST_TIME : float = 25.0
const DELIVERY_SLOW_TIME : float = 120.0
const DELIVERY_MAX_MULT  : float = 2.0
const DELIVERY_MIN_MULT  : float = 1.0

## Base pay plus both halves of the tip (speed and Rizz).
func delivery_payout(base_earned: int, landing_time: float) -> int:
	return base_earned \
		+ speed_tip_for(base_earned, landing_time) \
		+ rizz_tip_for(base_earned)

## Short flavour tag for the delivery message, based on speed.
func delivery_speed_tag(landing_time: float) -> String:
	var mult : float = _delivery_mult(landing_time)
	if mult >= DELIVERY_MAX_MULT - 0.01:
		return " ⚡ Speedy bonus!"
	if mult > DELIVERY_MIN_MULT + 0.01:
		return " ⏱ Quick!"
	return ""

func _delivery_mult(landing_time: float) -> float:
	var elapsed : float = maxf(play_clock - landing_time, 0.0)
	var t       : float = clampf(
		(elapsed - DELIVERY_FAST_TIME) / (DELIVERY_SLOW_TIME - DELIVERY_FAST_TIME),
		0.0, 1.0)
	return lerpf(DELIVERY_MAX_MULT, DELIVERY_MIN_MULT, t)

signal cash_changed(new_cash: int)
signal packages_changed(new_packages: int)
signal day_changed(new_day: int)
signal delivery_made(cash_earned: int)
signal all_delivered()
signal message_requested(text: String, duration: float)

func show_message(text: String, duration: float = 2.5) -> void:
	message_requested.emit(text, duration)

func add_cash(amount: int) -> void:
	cash += amount
	day_cash += amount
	cash_changed.emit(cash)

## Spending (shop purchases). Deliberately does NOT touch `day_cash`, which
## tracks the day's *earnings* — it drives the all-delivered bonus, so buying
## groceries must not shrink that.
func spend_cash(amount: int) -> bool:
	if amount <= 0 or cash < amount:
		return false
	cash -= amount
	cash_changed.emit(cash)
	return true

## Undo a spend_cash (e.g. a purchase that couldn't be completed). Mirrors
## spend_cash so `day_cash` stays untouched in both directions.
func refund_cash(amount: int) -> void:
	if amount <= 0:
		return
	cash += amount
	cash_changed.emit(cash)

func use_package() -> bool:
	if packages <= 0:
		return false
	packages -= 1
	packages_changed.emit(packages)
	return true

func set_packages(count: int) -> void:
	packages = clampi(count, 0, bike_max_packages)
	packages_changed.emit(packages)

func on_delivery_complete(earned: int) -> void:
	delivered_count += 1
	add_cash(earned)
	delivery_made.emit(earned)
	if total_targets > 0 and delivered_count >= total_targets:
		all_delivered.emit()

func start_new_day(target_count: int) -> void:
	day += 1
	day_cash = 0
	delivered_count = 0
	total_targets = target_count
	set_packages(target_count)
	day_changed.emit(day)

## Load packages onto the bike, up to its rack capacity. Returns how many were
## actually taken, so the caller can tell the player what was left behind.
func add_packages(count: int) -> int:
	var taken : int = mini(count, package_space())
	if taken <= 0:
		return 0
	packages += taken
	packages_changed.emit(packages)
	return taken

func add_targets(count: int) -> void:
	total_targets += count

# Door markers were renumbered in the map; saves written before that still hold
# the old names. Translate them on load so an existing home keeps working (this
# is what drives the home-door spawn, the bed, and the map's home icon).
const HOME_ID_MIGRATIONS : Dictionary = {
	"Townhouse3": "Townhouse15",
	"Townhouse2": "Townhouse10",
	"House28":    "House84",
	"House19":    "House96",
}

func migrate_home_id(id: String) -> String:
	return HOME_ID_MIGRATIONS.get(id, id)

func _slot_path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot

## Reads a slot without loading it into live game state — used by the save
## slot picker UI to show "Slot N — Day X · $Y · <timestamp>" or "Empty".
func get_slot_info(slot: int) -> Dictionary:
	var path : String = _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {"exists": false}
	var file : FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"exists": false}
	var parsed : Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {"exists": false}
	return {
		"exists":    true,
		"slot_name": str(parsed.get("slot_name", "Slot %d" % slot)),
		"day":       int(parsed.get("day",       1)),
		"cash":      int(parsed.get("cash",      0)),
		"timestamp": int(parsed.get("timestamp", 0)),
	}

## Writes to `slot` (or current_slot if omitted) and remembers it so later
## autosaves (e.g. day rollover) keep landing in the same slot.
func save_game(slot: int = -1) -> void:
	if slot == -1:
		slot = current_slot
	if slot == -1:
		return
	current_slot = slot
	var existing   : Dictionary = get_slot_info(slot)
	var slot_name  : String     = str(existing.get("slot_name", "Slot %d" % slot)) \
			if existing.get("exists", false) else "Slot %d" % slot
	var data : Dictionary = {
		"slot_name": slot_name,
		"timestamp": Time.get_unix_time_from_system(),
		"cash":      cash,
		"day":       day,
		"home_id":   home_id,
		"mortgage":  mortgage,
		"bike_max_packages": bike_max_packages,
		"bike_max_speed":    bike_max_speed,
		"bike_accel":        bike_accel,
		"bike_handling":     bike_handling,
		"bike_off_road":     bike_off_road,
		"vehicle":          vehicle,
		"storage_upgrades": storage_upgrades,
		"hour":      TimeManager.hour,   # resume the in-game clock where we left off
		# The day in progress. Saved so a mid-day save/reload keeps the
		# calendar day's takings intact and the midnight ledger still reports
		# the whole 24 hours, not just what happened after loading.
		"ledger":          _ledger,
		"day_cash":        day_cash,
		"delivered_count": delivered_count,
		"total_targets":   total_targets,
		"stats":     stats,
		"inventory": _inventory_to_save(),
	}
	var file : FileAccess = FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()

func load_game(slot: int) -> bool:
	var path : String = _slot_path(slot)
	if not FileAccess.file_exists(path):
		return false
	var file : FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed : Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return false
	current_slot = slot
	cash     = int(parsed.get("cash",     0))
	day      = int(parsed.get("day",      1))
	home_id  = migrate_home_id(str(parsed.get("home_id",  "")))
	mortgage = int(parsed.get("mortgage", 0))
	# Saves predating vehicle stats get a stock bike.
	bike_max_packages = maxi(int(parsed.get("bike_max_packages", BIKE_BASE_MAX_PACKAGES)), 1)
	bike_max_speed    = float(parsed.get("bike_max_speed", BIKE_BASE_MAX_SPEED))
	bike_accel        = float(parsed.get("bike_accel",     BIKE_BASE_ACCEL))
	bike_handling     = float(parsed.get("bike_handling",  BIKE_BASE_HANDLING))
	bike_off_road     = float(parsed.get("bike_off_road",  BIKE_BASE_OFF_ROAD))
	vehicle          = int(parsed.get("vehicle",          Vehicle.BIKE))
	storage_upgrades = maxi(int(parsed.get("storage_upgrades", 0)), 0)
	# Older saves have no clock — fall back to the normal 6am start.
	loaded_hour = float(parsed.get("hour", TimeManager.DAY_START_HOUR))
	# Restore the calendar day already in progress, so the midnight ledger
	# still covers the full 24 hours across a save/reload.
	_ledger_from_save(parsed.get("ledger", null))
	day_cash        = int(parsed.get("day_cash",        0))
	delivered_count = int(parsed.get("delivered_count", 0))
	total_targets   = int(parsed.get("total_targets",   0))
	# Saves written before lifetime stats existed just keep the zeroed defaults,
	# so those games start recording from their next day-end. Merge key-by-key
	# (rather than assigning wholesale) because JSON returns every number as a
	# float and may omit keys added in later versions.
	var loaded_stats : Variant = parsed.get("stats", null)
	if loaded_stats is Dictionary:
		for k in stats.keys():
			if loaded_stats.has(k):
				stats[k] = int(loaded_stats[k])
	# Saves predating the inventory simply load an empty one.
	_inventory_from_save(parsed.get("inventory", null))
	cash_changed.emit(cash)
	day_changed.emit(day)
	return true

## Settings (control scheme, drop tuning) are global user prefs, independent
## of any save slot, so they live in their own file.
func save_settings() -> void:
	var data : Dictionary = {
		"easy_bike":             easy_bike,
		"snap_to_direction":     snap_to_direction,
		"max_drops_per_day":     max_drops_per_day,
		"max_packages_per_drop": max_packages_per_drop,
		"sprite_scale":          sprite_scale,
	}
	var file : FileAccess = FileAccess.open("user://settings.json", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()

func load_settings() -> void:
	if not FileAccess.file_exists("user://settings.json"):
		return
	var file : FileAccess = FileAccess.open("user://settings.json", FileAccess.READ)
	if file == null:
		return
	var parsed : Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	easy_bike             = bool(parsed.get("easy_bike",            false))
	snap_to_direction     = bool(parsed.get("snap_to_direction",    true))
	max_drops_per_day     = int(parsed.get("max_drops_per_day",     4))
	max_packages_per_drop = int(parsed.get("max_packages_per_drop", 3))
	sprite_scale          = clampf(float(parsed.get("sprite_scale", 1.0)), 0.5, 1.0)

func reset() -> void:
	cash = 0
	packages = 0
	day = 1
	day_cash = 0
	total_targets = 0
	delivered_count = 0
	home_id  = ""
	mortgage = 0
	bike_max_packages = BIKE_BASE_MAX_PACKAGES
	bike_max_speed    = BIKE_BASE_MAX_SPEED
	bike_accel        = BIKE_BASE_ACCEL
	bike_handling     = BIKE_BASE_HANDLING
	bike_off_road     = BIKE_BASE_OFF_ROAD
	vehicle           = Vehicle.BIKE
	storage_upgrades  = 0
	current_slot = -1
	_ledger.clear()
	_clear_inventory()
	for k in stats.keys():
		stats[k] = 0
