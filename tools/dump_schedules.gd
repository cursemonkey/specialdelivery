extends SceneTree
## Prints every NPC's weekly schedule as a readable grid, so you can confirm at
## a glance where each character is at any hour without reading the registry.
##
##   "C:\Program Files\Godot_v4.6.1-stable\Godot_v4.6.1-stable_win64_console.exe" \
##       --headless --script tools/dump_schedules.gd
##
## Legend:  (in) = inside the building   ·   (out) = standing outside it

const HOURS : Array = [0, 3, 6, 8, 9, 11, 13, 15, 17, 19, 21, 23]

func _initialize() -> void:
	# Autoloads aren't available to a --script run, so build the registry by hand.
	var reg = load("res://scripts/NPCRegistry.gd").new()
	reg._register_all()

	var day_names : Array = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
	print("Legend: 4-letter building code + i = INSIDE (walk in to meet them)")
	print("                                 + o = OUTSIDE (visible on the street)")
	print("Alternating-week NPCs (Elsie, Spider) shown on their EVEN week.")
	var defs : Array = reg.all_definitions()
	defs.sort_custom(func(a, b): return a.display_name < b.display_name)

	for def in defs:
		print("\n=== %s  (id: %s, home: %s)" % [def.display_name, def.id, def.home_anchor])
		if def.away_season_from >= 0:
			print("    away: %s %d  →  %s %d" % [
				Calendar.SEASON_NAMES[def.away_season_from], def.away_day_from,
				Calendar.SEASON_NAMES[def.away_season_to],   def.away_day_to])
		var header : String = "    hour |"
		for h in HOURS:
			header += " %5s" % ("%02d" % h)
		print(header)
		for wd in range(day_names.size()):
			var row : String = "    %-4s |" % day_names[wd]
			for h in HOURS:
				row += " %5s" % _where(def, wd, float(h))
			print(row)
	quit()

## First matching entry wins, mirroring RegularNPC._retarget().
func _where(def, weekday: int, hour: float) -> String:
	var phase : int = _phase_for(hour)
	for e in def.schedule:
		# Week parity varies; report the even-week routine and note alternates.
		if e.matches(weekday, phase, 0, hour, Calendar.Season.FALL):
			return _short(e.anchor) + ("i" if e.interior else "o")
	return _short(def.home_anchor) + "i"

func _phase_for(h: float) -> int:
	if h >= 21.0 or h < 6.0:
		return 2   # NIGHT
	if h >= 19.0:
		return 1   # SUNSET
	return 0       # DAY

func _short(anchor: String) -> String:
	if anchor.is_empty():
		return "?"
	var a : String = anchor.replace("Building_", "")
	return a.substr(0, 4)
