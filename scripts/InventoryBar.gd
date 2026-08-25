extends Control
## Inventory strip: one box per slot, showing the item icon, its remaining
## portions, and the number key that eats from it. Empty slots stay visible so
## the player can see their carrying capacity at a glance.

const SLOT_W   : float = 34.0
const SLOT_H   : float = 34.0
const SLOT_GAP : float = 4.0

func _ready() -> void:
	GameManager.inventory_changed.connect(_redraw)
	queue_redraw()

func _redraw() -> void:
	queue_redraw()

func _draw() -> void:
	var font : Font = ThemeDB.fallback_font
	for i in GameManager.inventory.size():
		var x    : float   = float(i) * (SLOT_W + SLOT_GAP)
		var rect : Rect2   = Rect2(x, 0.0, SLOT_W, SLOT_H)
		var slot : Variant = GameManager.inventory[i]
		var filled : bool  = slot is Dictionary

		draw_rect(rect, Color(0.10, 0.10, 0.13, 0.80 if filled else 0.45))
		draw_rect(rect, Color(0.55, 0.60, 0.75, 0.9 if filled else 0.35), false, 1.0)

		# Slot number, top-left — this is the key that eats from it.
		draw_string(font, Vector2(x + 3.0, 10.0), str(i + 1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.65, 0.65, 0.72))

		if not filled:
			continue

		var id : String = str(slot.get("id", ""))
		draw_string(font, Vector2(x + 9.0, 25.0), ItemRegistry.icon(id),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1))

		# Stack size, bottom-right — only when more than one is held.
		var left : int = int(slot.get("portions", 0))
		if left > 1:
			draw_string(font, Vector2(x + SLOT_W - 12.0, SLOT_H - 3.0), str(left),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.92, 0.6))
