extends Control
## Status screen: the player's condition on the left, the bike's on the right.
## Purely a read-out — it reflects GameManager and never changes it. Shown from
## the pause menu's Status button, so it lives inside the paused tree.
##
## Player column: HP / Energy / Rizz meters plus cash, mortgage and the day's
## delivery progress. Bike column: rack load against bike_max_packages, plus
## the derived carrying stats.

const METER_W : float = 150.0
const METER_H : float = 12.0
const ROW_H   : float = 32.0
## A full performance bar = this multiple of the stock bike's value.
const FULL_BAR_RATIO : float = 1.5

@onready var player_meters : Control        = $Dim/StatusPanel/VBox/Columns/PlayerCol/Meters
@onready var player_rows   : VBoxContainer  = $Dim/StatusPanel/VBox/Columns/PlayerCol/Rows
@onready var bike_meters   : Control        = $Dim/StatusPanel/VBox/Columns/BikeCol/Meters
@onready var bike_rows     : VBoxContainer  = $Dim/StatusPanel/VBox/Columns/BikeCol/Rows
@onready var close_button  : Button         = $Dim/StatusPanel/VBox/CloseStatus
@onready var bike_heading  : Label          = $Dim/StatusPanel/VBox/Columns/BikeCol/Heading

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	close_button.pressed.connect(close)
	player_meters.draw.connect(_draw_player_meters)
	bike_meters.draw.connect(_draw_bike_meters)
	# Live-update while open, so eating an item or paying the mortgage shows up.
	for sig in [GameManager.hp_changed, GameManager.energy_changed, GameManager.rizz_changed]:
		sig.connect(func(_v: int) -> void: _refresh_if_open())
	GameManager.cash_changed.connect(func(_v: int) -> void: _refresh_if_open())
	GameManager.packages_changed.connect(func(_v: int) -> void: _refresh_if_open())
	GameManager.mortgage_changed.connect(func(_v: int) -> void: _refresh_if_open())
	GameManager.bike_stats_changed.connect(_refresh_if_open)

func open() -> void:
	visible = true
	refresh()

func close() -> void:
	visible = false

func _refresh_if_open() -> void:
	if visible:
		refresh()

## Rebuild both columns from current GameManager state.
func refresh() -> void:
	player_meters.queue_redraw()
	bike_meters.queue_redraw()
	_fill(player_rows, _player_stat_rows())
	_fill(bike_rows,   _bike_stat_rows())
	# The heading follows whichever vehicle the player currently rides.
	bike_heading.text = GameManager.vehicle_name()

# ── Row data ───────────────────────────────────────────────
func _player_stat_rows() -> Array:
	var rows : Array = [
		["Cash",       "$%d" % GameManager.cash],
		["Mortgage",   "$%d" % GameManager.mortgage if GameManager.mortgage > 0 else "Paid off"],
		["Home",       GameManager.home_id if GameManager.home_id != "" else "None yet"],
		["Day",        GameManager.date_label_short()],
	]
	# Delivery progress only means something once the day has targets.
	if GameManager.total_targets > 0:
		rows.append(["Deliveries",
				"%d / %d" % [GameManager.delivered_count, GameManager.total_targets]])
	rows.append(["Lifetime", "%d deliveries · $%d earned" \
			% [int(GameManager.stats.total_deliveries), int(GameManager.stats.total_earnings)]])
	return rows

func _bike_stat_rows() -> Array:
	var gm : Node = GameManager
	return [
		["Max packages",  "%d" % gm.bike_max_packages],
		["Carrying",      "%d / %d" % [gm.packages, gm.bike_max_packages]],
		["Max speed",     "%d px/s" % roundi(gm.bike_max_speed)],
		["Acceleration",  "%.1f" % gm.bike_accel],
		["Handling",      "%.1f rad/s" % gm.bike_handling],
		# Stored as speed kept; shown as the penalty, which reads more naturally.
		["Off-road",      "-%d%% on grass" % roundi((1.0 - gm.bike_off_road) * 100.0)],
	]

## Replace `container`'s children with one label row per [caption, value] pair.
func _fill(container: VBoxContainer, rows: Array) -> void:
	for c in container.get_children():
		c.queue_free()
	for r in rows:
		var row : HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var caption : Label = Label.new()
		caption.text = str(r[0])
		caption.custom_minimum_size = Vector2(110, 0)
		caption.add_theme_color_override("font_color", Color(0.66, 0.66, 0.74))
		row.add_child(caption)

		var value : Label = Label.new()
		value.text = str(r[1])
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
		value.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
		row.add_child(value)

		container.add_child(row)

# ── Meters ─────────────────────────────────────────────────
func _draw_player_meters() -> void:
	_meter(player_meters, 0, "Health", GameManager.hp,     GameManager.max_hp,
			Color(0.90, 0.20, 0.20))
	_meter(player_meters, 1, "Energy", GameManager.energy, GameManager.max_energy,
			Color(0.25, 0.80, 0.35))
	_meter(player_meters, 2, "Rizz",   GameManager.rizz,   GameManager.max_rizz,
			Color(0.95, 0.85, 0.20))

## Bike meters: the rack as discrete slots (so a capacity upgrade visibly adds
## a segment), then each performance stat as a share of the stock bike, where a
## full bar is 150% of baseline. Off-road is drawn as grip retained, so longer
## is better and matches the other bars.
func _draw_bike_meters() -> void:
	var gm : Node = GameManager
	_segments(bike_meters, 0, "Packages", gm.packages, gm.bike_max_packages,
			Color(0.85, 0.65, 0.25))
	_ratio(bike_meters, 1, "Max speed", gm.bike_max_speed, gm.BIKE_BASE_MAX_SPEED,
			"%d" % roundi(gm.bike_max_speed), Color(0.35, 0.70, 0.95))
	_ratio(bike_meters, 2, "Accel", gm.bike_accel, gm.BIKE_BASE_ACCEL,
			"%.1f" % gm.bike_accel, Color(0.55, 0.75, 0.40))
	_ratio(bike_meters, 3, "Handling", gm.bike_handling, gm.BIKE_BASE_HANDLING,
			"%.1f" % gm.bike_handling, Color(0.80, 0.55, 0.90))
	_ratio(bike_meters, 4, "Off-road", gm.bike_off_road, 1.0,
			"%d%%" % roundi(gm.bike_off_road * 100.0), Color(0.75, 0.60, 0.35))

## A bar showing `value` against `baseline`, where a full bar is FULL_BAR_RATIO
## times the baseline, so a stock stat sits partway along and upgrades grow it.
func _ratio(canvas: Control, index: int, label: String, value: float,
		baseline: float, readout: String, color: Color) -> void:
	var frac : float = 0.0
	if baseline > 0.0:
		frac = clampf(value / (baseline * FULL_BAR_RATIO), 0.0, 1.0)
	_bar(canvas, index, label, readout, frac, color)

## A continuous value/max bar with its caption above it.
func _meter(canvas: Control, index: int, label: String, value: int, maxv: int,
		color: Color) -> void:
	var frac : float = 0.0
	if maxv > 0:
		frac = clampf(float(value) / float(maxv), 0.0, 1.0)
	_bar(canvas, index, label, "%d/%d" % [value, maxv], frac, color)

## Shared bar drawing: caption left, readout right, filled to `frac`.
func _bar(canvas: Control, index: int, label: String, readout: String,
		frac: float, color: Color) -> void:
	var y    : float = float(index) * ROW_H
	var font : Font  = ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(0.0, y + 10.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.72, 0.72, 0.80))
	canvas.draw_string(font, Vector2(0.0, y + 10.0), readout,
			HORIZONTAL_ALIGNMENT_RIGHT, METER_W, 11, Color(0.88, 0.88, 0.94))
	var bar : Rect2 = Rect2(0.0, y + 14.0, METER_W, METER_H)
	canvas.draw_rect(bar, Color(0.14, 0.14, 0.17, 0.9))
	if frac > 0.0:
		canvas.draw_rect(Rect2(bar.position, Vector2(METER_W * frac, METER_H)), color)
	canvas.draw_rect(bar, Color(0, 0, 0, 0.45), false, 1.0)

## A discrete bar: one lit segment per unit, for small capacities like the rack.
func _segments(canvas: Control, index: int, label: String, value: int, maxv: int,
		color: Color) -> void:
	var y    : float = float(index) * ROW_H
	var font : Font  = ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(0.0, y + 10.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.72, 0.72, 0.80))
	canvas.draw_string(font, Vector2(0.0, y + 10.0), "%d/%d" % [value, maxv],
			HORIZONTAL_ALIGNMENT_RIGHT, METER_W, 11, Color(0.88, 0.88, 0.94))
	var gap  : float = 3.0
	var slot : float = (METER_W - gap * float(maxi(maxv - 1, 0))) / float(maxi(maxv, 1))
	for i in maxv:
		var r : Rect2 = Rect2(float(i) * (slot + gap), y + 14.0, slot, METER_H)
		canvas.draw_rect(r, color if i < value else Color(0.16, 0.16, 0.19, 0.85))
		canvas.draw_rect(r, Color(0, 0, 0, 0.45), false, 1.0)
