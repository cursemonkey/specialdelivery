class_name DialogueLine
extends RefCounted
## One line of dialogue plus the speaker emotion that drives which portrait
## shows. `mood` is a lowercase string matching the portrait file suffix
## (assets/Portraits/<id>_<mood>.jpg); "" means the neutral base portrait.

const HAPPY     := "happy"
const MAD       := "mad"
const SURPRISED := "surprised"
const CALM      := "calm"
const SAD       := "sad"

## Friendship gating. `min_hearts` is the fewest hearts the player must have
## with this villager before the line can be said at all — 0 means "from the
## first hello". Lines don't disappear as friendship grows: once a newer tier
## unlocks, older lines stay in the pool at reduced weight (see
## RegularNPC.get_dialogue), so early chatter becomes uncommon rather than
## vanishing the moment a heart is earned.
var text       : String = ""
var mood       : String = ""
var min_hearts : int    = 0

static func make(line_text: String, line_mood: String = "", hearts: int = 0) -> DialogueLine:
	var line : DialogueLine = DialogueLine.new()
	line.text       = line_text
	line.mood       = line_mood
	line.min_hearts = hearts
	return line

## True when `hearts` is enough to hear this line.
func unlocked_at(hearts: int) -> bool:
	return hearts >= min_hearts
