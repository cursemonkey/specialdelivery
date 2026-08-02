extends Control
## Three Mega-Man-style segmented meters — Health (red), Energy (green), Rizz
## (yellow) — drawn as vertical stacks of slivers that fill from the bottom.
## Reads GameManager stats and redraws on their change signals.

const SEG_W   : float = 16.0
const SEG_H   : float = 4.0
const SEG_GAP : float = 1.5
const BAR_GAP : float = 26.0
const TOP     : float = 15.0

func _ready() -> void:
	GameManager.hp_changed.connect(_redraw)
	GameManager.energy_changed.connect(_redraw)
	GameManager.rizz_changed.connect(_redraw)
	queue_redraw()

func _redraw(_v: int = 0) -> void:
	queue_redraw()

func _draw() -> void:
	_draw_bar(0, "HP", GameManager.hp,     GameManager.max_hp,     Color(0.90, 0.20, 0.20))
	_draw_bar(1, "EN", GameManager.energy, GameManager.max_energy, Color(0.25, 0.80, 0.35))
	_draw_bar(2, "RZ", GameManager.rizz,   GameManager.max_rizz,   Color(0.95, 0.85, 0.20))

func _draw_bar(index: int, label: String, value: int, maxv: int, color: Color) -> void:
	var x    : float = float(index) * BAR_GAP
	var font : Font  = ThemeDB.fallback_font
	draw_string(font, Vector2(x - 1.0, 11.0), label, HORIZONTAL_ALIGNMENT_LEFT, SEG_W + 2.0, 10,
			Color(0.92, 0.92, 0.92))
	for i in maxv:
		var y   : float = TOP + float(maxv - 1 - i) * (SEG_H + SEG_GAP)
		var col : Color = color if i < value else Color(0.16, 0.16, 0.18, 0.65)
		draw_rect(Rect2(x, y, SEG_W, SEG_H), col)
		draw_rect(Rect2(x, y, SEG_W, SEG_H), Color(0, 0, 0, 0.4), false, 1.0)
