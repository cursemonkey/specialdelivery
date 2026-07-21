class_name DialogueLine
extends RefCounted
## One line of dialogue plus the speaker emotion that drives which portrait
## shows. `mood` is a lowercase string matching the portrait file suffix
## (assets/Portraits/<id>_<mood>.jpg); "" means the neutral base portrait.

const HAPPY     := "happy"
const MAD       := "mad"
const SURPRISED := "surprised"
const CALM      := "calm"

var text : String = ""
var mood : String = ""

static func make(line_text: String, line_mood: String = "") -> DialogueLine:
	var line : DialogueLine = DialogueLine.new()
	line.text = line_text
	line.mood = line_mood
	return line
