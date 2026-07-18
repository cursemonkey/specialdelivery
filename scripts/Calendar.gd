class_name Calendar
extends RefCounted
## Pure date math for the game calendar. The whole game runs on one absolute,
## 1-based day counter (GameManager.day); this maps it to a (year, season,
## day-of-season) date. Absolute day 1 == Year 1, Fall, day 1.
##
## Season order within a year is Fall → Winter → Spring → Summer, so a fresh
## game (day 1) opens in Fall and the year rolls over after Summer.

enum Season { FALL, WINTER, SPRING, SUMMER }

const SEASON_NAMES   : Array[String] = ["Fall", "Winter", "Spring", "Summer"]
const SEASON_LENGTHS : Array[int]    = [20, 20, 20, 22]   # index matches Season
const DAYS_PER_YEAR  : int           = 82                 # == sum(SEASON_LENGTHS)

## Map an absolute 1-based day to {year:int, season:int, day:int}. `day` is
## 1-based within its season.
static func date_for_day(absolute_day: int) -> Dictionary:
	var idx         : int = maxi(absolute_day, 1) - 1
	var year        : int = idx / DAYS_PER_YEAR + 1
	var day_of_year : int = idx % DAYS_PER_YEAR
	var season      : int = Season.SUMMER
	for i in SEASON_LENGTHS.size():
		if day_of_year < SEASON_LENGTHS[i]:
			season = i
			break
		day_of_year -= SEASON_LENGTHS[i]
	return { "year": year, "season": season, "day": day_of_year + 1 }

static func season_name(season: int) -> String:
	return SEASON_NAMES[season]

## "Year 1, Fall 9"
static func format_long(absolute_day: int) -> String:
	var d : Dictionary = date_for_day(absolute_day)
	return "Year %d, %s %d" % [d.year, SEASON_NAMES[d.season], d.day]

## "Fall 9 · Yr 1"  (compact, for the HUD)
static func format_short(absolute_day: int) -> String:
	var d : Dictionary = date_for_day(absolute_day)
	return "%s %d · Yr %d" % [SEASON_NAMES[d.season], d.day, d.year]
