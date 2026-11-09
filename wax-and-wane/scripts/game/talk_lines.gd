class_name TalkLines
extends RefCounted
## Every line of the talking scenes (v2.7 dialogue stream, docs/streams/v27_dialogue.md). The scenes themselves are
## scripts/ui/talk.gd; the opening's panels are scripts/ui/opening.gd. All of it agrees with docs/design/STORY.md and
## Martha's diary (scripts/game/diary.gd): no old line was changed to make room for these.
##
## Who speaks: "me" (the candle being played: its own name, colours and face), "martha" (Martha Fenn as a memory,
## a sepia portrait) and each guardian by its kind (Enemy.DEFS: its name, its own frames).
## A line: {"who", "face", "text"}; "who" defaults to the guardian of the table entry, "face" to "open".
##   faces of the candle: open, brave, worried, teary (crying wax), happy, tired (sad), shout
##   faces of Martha: open, smile
## "{name}" in a line is the candle's name.
##
## The rules (checked by --talkcheck): a first meeting (MEET) is 2-4 lines, a fall (FALL) 1-2 lines, a later meeting
## (AGAIN) one short line; no line longer than LONGEST letters (three lines in the talk box on a 384 px screen).
## Voice: short sentences, plain words, warm, a little sad, one specific funny detail; the candle is brave but scared
## and a little funny; every guardian talks like the chore it is (the Organist in hymn-book phrases, the Weathercock
## like a weather report, the Gaoler in rules, the Stockpot in recipes...). Never villains: tired, faithful things
## that forgot how to stop. Every string is translatable: the extractor (tools/extract_strings.py) reads "text".

const LONGEST := 120

## The talking voices: [sound in assets/audio/sfx, pitch, level dB] per speaker; a blip every other letter
## (pitches: a list the blips walk through: the Choir sings in thirds, the Pendulum ticks and tocks).
## The guardians' portraits: "crop" = the top-left of the 24 x 24 part of their first idle frame that shows the face
## (drawn x2 in the 48 x 48 frame); "talk" = the frames they talk with ("sing" for the Choir and the Organist).
const SPEAKERS := {
	"me": {"voice": ["tick", [1.55], -15.0]},
	"martha": {"voice": ["ui_click", [0.92], -13.0]},
	"big_zombie": {"crop": [4, 6], "voice": ["step", [0.55], -11.0]},
	"wax_mother": {"crop": [8, 7], "voice": ["ui_back", [0.78], -12.0]},
	"furnace": {"crop": [8, 1], "voice": ["step", [0.72], -10.0]},
	"ogre": {"crop": [6, 8], "voice": ["ui_back", [0.6], -11.0]},
	"sexton": {"crop": [4, 5], "voice": ["step", [0.68], -11.0]},
	"ossuary": {"crop": [10, 5], "voice": ["ui_click", [0.62, 0.7, 0.58], -12.0]},
	"necro_boss": {"crop": [6, 1], "voice": ["ui_move", [0.62], -11.0]},
	"choir": {"crop": [12, 11], "voice": ["tick", [1.12, 1.4, 1.68], -16.0], "talk": "sing"},
	"organist": {"crop": [12, 12], "voice": ["tick", [0.8], -15.0], "talk": "sing"},
	"pendulum": {"crop": [4, 6], "voice": ["tick", [0.6, 0.52], -14.0]},
	"big_demon": {"crop": [5, 5], "voice": ["ui_back", [0.48], -11.0]},
	"weathercock": {"crop": [18, 2], "voice": ["ui_click", [1.3], -13.0]},
	"stockpot": {"crop": [10, 2], "voice": ["ui_back", [0.9], -12.0]},
	"librarian": {"crop": [4, 1], "voice": ["ui_move", [1.12], -14.0]},
	"dress_form": {"crop": [8, 1], "voice": ["ui_click", [1.1], -13.0]},
	"keeper": {"crop": [12, 6], "voice": ["tick", [0.45], -13.0]},
}

## The first time a save slot meets a guardian: a short exchange after its entrance, before the fight.
const MEET := {
	"big_zombie": [
		{"text": "Mmmf. Who's knocking? If it's about the rent, I'm out."},
		{"who": "me", "face": "worried", "text": "I'm not here about the rent! I'm only going upstairs."},
		{"text": "Upstairs is for chores. Down here is for sleeping. I've been very good at it for three hundred years."},
		{"who": "me", "face": "brave", "text": "Then I'll be quick, and you can get back to it."},
	],
	"wax_mother": [
		{"text": "Nine thousand and three, nine thousand and four... and you. Mother counts every drip, dear."},
		{"who": "me", "face": "worried", "text": "I'm not a drip. I'm a candle."},
		{"text": "Every candle in this house runs down to me in the end. You're just early. Come and melt. It's warm."},
		{"who": "me", "face": "teary", "text": "No thank you! ...It does look very warm, though."},
	],
	"furnace": [
		{"text": "Hrrm. Coal. Coal. Coal... is that wax? I haven't had wax since the winter of the long frost."},
		{"who": "me", "face": "shout", "text": "I'm not fuel! I'm... staff!"},
		{"text": "Everything's fuel, if you're hungry enough. And I've been hungry for a hundred winters."},
	],
	"ogre": [
		{"text": "Halt. The crypt is locked at twelve, by order of the Book of Rounds. Name and business."},
		{"who": "me", "face": "worried", "text": "Just passing through! I'm on my way upstairs."},
		{"text": "Nobody living goes in. Nobody dead comes out. And you, I'd say, are somewhere in between."},
		{"who": "me", "face": "brave", "text": "I'm a candle. We're allowed to be in between."},
	],
	"sexton": [
		{"text": "Hold still. Five inches... six with the flame. I'll put you down for a small one."},
		{"who": "me", "face": "teary", "text": "A small WHAT?"},
		{"text": "Just in case. I measure everyone who comes to dinner. Nobody ever stays for pudding."},
		{"who": "me", "face": "brave", "text": "Well, I'm not stopping for dinner either!"},
	],
	"ossuary": [
		{"text": "Order! Order. The stack has discussed you, and the stack has opinions."},
		{"who": "me", "face": "worried", "text": "Um. Good ones?"},
		{"text": "Mixed. The left femurs like you. The skulls say you're a draught and want you put outside."},
		{"who": "me", "face": "happy", "text": "Tell the left femurs thank you."},
	],
	"necro_boss": [
		{"text": "All's well... All's well... All's... Who goes there?"},
		{"who": "me", "face": "worried", "text": "Only me. A candle. Is anyone else here?"},
		{"text": "No one. No one for a hundred years. I watch the pews anyway. Watching is all that's left of me."},
		{"who": "me", "face": "tired", "text": "That sounds lonely."},
	],
	"choir": [
		{"text": "Ooh, a candle! Hold still, dear, we need the light for verse four hundred and twelve."},
		{"who": "me", "text": "How many verses are there?"},
		{"text": "Nobody knows! Mr. Pennock never told us where it ends, so we just keep going."},
		{"who": "me", "face": "worried", "text": "...Your faces are running."},
	],
	"organist": [
		{"text": "Please rise for hymn number four hundred and six."},
		{"who": "me", "face": "worried", "text": "There's nobody here to sing."},
		{"text": "The congregation is excused. The service is not. I have not missed one since Tuesday."},
		{"who": "me", "text": "...Which Tuesday?"},
	],
	"pendulum": [
		{"text": "Tick. That minute was yours. Tock. So was that one."},
		{"who": "me", "face": "teary", "text": "Stop taking them! I haven't got many."},
		{"text": "Nobody has many. That is why I take them one at a time. Tick."},
	],
	"big_demon": [
		{"text": "Ahh. A dawdler. I can smell every minute you've wasted tonight."},
		{"who": "me", "face": "worried", "text": "I was only looking at things!"},
		{"text": "Looking is my favourite. Every wasted minute is a crumb, and I want the whole loaf. I want TWO O'CLOCK."},
		{"who": "me", "face": "brave", "text": "Then I'd better not dawdle."},
	],
	"weathercock": [
		{"text": "Tonight: wind from the north-north-west, scattered candles, and a ninety per cent chance of you blowing out."},
		{"who": "me", "face": "worried", "text": "Is there any chance of... not that?"},
		{"text": "Outlook unsettled. Bring a coat. Hold on to your wick."},
	],
	"stockpot": [
		{"text": "Blub. Blub. Never off the boil. Cook's orders. Blub."},
		{"who": "me", "text": "I think Cook's been gone a long time."},
		{"text": "Then nobody's told me to stop. Season to taste. Add one small candle. Stir."},
		{"who": "me", "face": "shout", "text": "Do NOT add the candle!"},
	],
	"librarian": [
		{"text": "Shhh. No running in the reading room. No burning. And absolutely no crackling."},
		{"who": "me", "face": "worried", "text": "(Sorry.) I'll be very quiet."},
		{"text": "You are a flame in a room full of paper. You are the loudest thing I have ever seen."},
		{"who": "me", "face": "worried", "text": "..."},
	],
	"dress_form": [
		{"text": "Arms up. Hold still. The fitting is at eight, and the boat sails on Friday."},
		{"who": "me", "face": "worried", "text": "I don't think the dress is for me."},
		{"text": "Nonsense. Everyone fits something in the end. I have been waiting a very long time for Friday."},
		{"who": "me", "face": "tired", "text": "...Friday isn't coming, is it?"},
	],
	"keeper": [
		{"text": "You are early. No one has been early in three hundred years."},
		{"who": "me", "face": "brave", "text": "I came up to tell you something. You're allowed to stop."},
		{"text": "My orders say the clock must never run down. You keep time too. Let me wind you, and you will never go out."},
		{"who": "me", "face": "brave", "text": "That's the thing. Going out is my job."},
	],
}

## A guardian's first fall in a slot: its last words, or a memory of Martha (the house remembers her voice).
const FALL := {
	"big_zombie": [
		{"text": "Mmm. Wake me at twelve. Or don't. Either way."},
		{"who": "martha", "face": "smile", "text": "Old Rot moved in the week the house was built. Never paid a penny, and never once complained about the damp."},
	],
	"wax_mother": [
		{"text": "Go on, then. But you come home to Mother before you're all burnt down."},
		{"who": "martha", "text": "Mother means well. But if she ever cuddles you, you'll never get up again."},
	],
	"furnace": [
		{"text": "Banked... for the night... Somebody fetch... a scuttle..."},
		{"who": "me", "face": "tired", "text": "I'll tell someone you're hungry. Promise."},
	],
	"ogre": [
		{"text": "Keys... somebody take the keys... It's nearly lock-up..."},
		{"who": "martha", "face": "smile", "text": "I asked the Gaoler once why it locks a door nobody opens. It said, \"Because it's Tuesday.\" It was a Thursday."},
	],
	"sexton": [
		{"text": "I'll just... dig myself a little lie-down. Till twelve."},
	],
	"ossuary": [
		{"text": "Motion to... lie down... Seconded... Carried..."},
	],
	"necro_boss": [
		{"text": "All's... well..."},
		{"who": "martha", "text": "I used to leave a candle in the chapel for the Warden. I don't suppose it noticed. I liked to think it did."},
	],
	"choir": [
		{"text": "A-a-amen... Oh! Was that the end? How lovely."},
	],
	"organist": [
		{"text": "...The congregation... may be seated."},
		{"who": "martha", "face": "smile", "text": "Mr. Pennock always got the hymn numbers wrong. Miss Tibbet said it was the only thing about him she'd change."},
	],
	"pendulum": [
		{"text": "Tick... tock... ... ...tick."},
		{"who": "me", "face": "happy", "text": "There. Everyone can keep their own minutes now."},
	],
	"big_demon": [
		{"text": "No... not yet... It isn't even two..."},
		{"who": "martha", "face": "smile", "text": "Cook said the Hour Fiend is only the clockmaker's worrying, grown teeth. She said the cure for worry is a cup of tea."},
	],
	"weathercock": [
		{"text": "And now... the outlook... calm... calm... calm."},
		{"who": "me", "face": "happy", "text": "Calm sounds nice."},
	],
	"stockpot": [
		{"text": "Off... the boil... Cook will be... livid..."},
		{"who": "martha", "face": "smile", "text": "Cook said that pot was older than the house. She said the same about her knees."},
	],
	"librarian": [
		{"text": "Shh... shh... ...overdue..."},
		{"who": "me", "face": "happy", "text": "(Sleep well.)"},
	],
	"dress_form": [
		{"text": "Let out... the seams... I'll wait... for Friday..."},
		{"who": "martha", "text": "Miss Tibbet sewed every stitch of that dress herself. I never had the heart to take it off the form."},
	],
	"keeper": [
		{"text": "Twelve... I was told twelve... Nobody told me... what comes after..."},
		{"who": "me", "face": "teary", "text": "Morning comes after. You'll like it."},
	],
}

## A later meeting: one short line (Story scenes: First time), picked at random (never the same one twice running).
const AGAIN := {
	"big_zombie": [{"text": "You again. I'm still not paying."}, {"text": "Shh. I was dreaming about the foundations."},
		{"text": "Every night a candle. In my day it was just the damp."}],
	"wax_mother": [{"text": "There's my drip. Let Mother count you."}, {"text": "You've dripped since I last saw you. I can always tell."},
		{"text": "Look how tall you're getting. Come here, let me melt that."}],
	"furnace": [{"text": "Still not full. Never full."}, {"text": "Ahh. Afters."}, {"text": "Mind the door. It's hot. Everything's hot."}],
	"ogre": [{"text": "You again. Visiting hours are over. They always were."}, {"text": "Name? ...I know your name. I just like asking."},
		{"text": "Clink. That's the sound of the rules."}],
	"sexton": [{"text": "Still six inches? You've shrunk."}, {"text": "I kept your hole. Nobody else fits it."},
		{"text": "Dig, dig, dig. What else is a spade for?"}],
	"ossuary": [{"text": "The stack remembers you. In no particular order."}, {"text": "Is that the candle? The skulls still want it outside."},
		{"text": "Order! ...Oh. It's only you."}],
	"necro_boss": [{"text": "Who goes there? ...Ah. All's well."}, {"text": "I counted the pews. Still empty."},
		{"text": "Still watching. Still nobody. Still... you."}],
	"choir": [{"text": "Verse four hundred and thirteen! From the top!"}, {"text": "Hold that light still, dear, we've lost our place."},
		{"text": "La-a-a... oh, it's the little candle!"}],
	"organist": [{"text": "Hymn number nine hundred and nine. Please rise."}, {"text": "The collection will now be taken. In minutes."},
		{"text": "Late again. Please sit at the back."}],
	"pendulum": [{"text": "Tick. Welcome back. Tock. That cost you a minute."}, {"text": "Tock."},
		{"text": "Still counting. Tick. Still counting."}],
	"big_demon": [{"text": "Dawdle. Go on. Just a little longer."}, {"text": "I saved you a seat. Between the ticks."},
		{"text": "You're late. Delicious."}],
	"weathercock": [{"text": "Today: overcast, with spells of candle."}, {"text": "Wind's changing. It always does."},
		{"text": "Gale warning for small candles. That's you."}],
	"stockpot": [{"text": "Blub. Today's soup: you."}, {"text": "Simmer. Simmer. Never stop."}, {"text": "A pinch of salt, a pinch of candle. Blub."}],
	"librarian": [{"text": "Shhh."}, {"text": "Your light is overdue."}, {"text": "Still crackling, I hear."}],
	"dress_form": [{"text": "Arms up. It's nearly Friday."}, {"text": "Mind the pins. Some of them mind you."},
		{"text": "You've grown. Or shrunk. Hold still."}],
	"keeper": [{"text": "Early again. I have been thinking about that word."}, {"text": "Twelve. Wind. Twelve. Wind. ...Little candle."},
		{"text": "The ladder came down for you. It remembers you."}],
}


## The story's opening (scripts/ui/opening.gd): a slot's first run starts here. Each line belongs to a panel (the house
## at midnight, the great clock, Martha's kitchen, the cellar); narration has no "who"; Martha and Tallow speak a line
## each. It agrees with STORY.md: the house wakes when the Keeper winds the clock at twelve, Martha made Tallow so the
## house could rest, lit him every night for a year until the house learned the habit, and now it lights him itself.
const OPENING := [
	{"panel": "house", "text": "There is an old house that runs on a great clock."},
	{"panel": "house", "text": "Every night at twelve, the Keeper of Hours winds it, and the house gets up to do its chores."},
	{"panel": "dial", "text": "Anything done every night for long enough starts to do itself."},
	{"panel": "dial", "text": "The pot stirs itself. The organ plays itself. Nobody is left to tell them to stop."},
	{"panel": "kitchen", "text": "Martha Fenn kept this house for sixty-one years. She wanted it to rest."},
	{"panel": "kitchen", "text": "So she made a candle. A candle is the one thing that knows how to end."},
	{"panel": "kitchen", "who": "martha", "face": "smile", "text": "Good evening, Tallow."},
	{"panel": "kitchen", "text": "She lit him every night for a year, until the house learned to do it for her."},
	{"panel": "cellar", "text": "Now, at twelve, the match strikes itself, and Tallow wakes alone."},
	{"panel": "cellar", "who": "me", "face": "worried", "text": "...Martha?"},
	# v2.7 merge: the goal rides on the last line (the old 12:00 AM card no longer follows the opening)
	{"panel": "cellar", "text": "He's scared of the dark. He goes up anyway, to the clock in the belfry, before his wax runs out."},
]


## The endings' closing beat (scripts/ui/ending.gd): a few words between the candle and Martha's memory on one card
## (ENDING_CARD: the card they are said over), before the last card. The Housekeeper's is Tallow's own memory (she lit
## him), so only Tallow says it; the others suit any candle of the house.
const ENDINGS := {
	"true": [
		{"who": "me", "face": "tired", "text": "It's so quiet. Is everyone asleep?"},
		{"who": "martha", "face": "smile", "text": "Every last one, love. You can stop now too."},
		{"who": "me", "face": "happy", "text": "In a minute. I'd like to see the morning first."},
	],
	"housekeeper": [
		{"who": "me", "text": "It was you. Every night at twelve, it was you."},
		{"who": "martha", "face": "smile", "text": "Every night for a year. You cried wax at the match every single time."},
		{"who": "me", "face": "teary", "text": "I still do, a bit."},
	],
	"windows": [
		{"who": "me", "face": "happy", "text": "Every window's lit, Martha. Every room in the house."},
		{"who": "martha", "face": "smile", "text": "Then nobody comes home to a dark house tonight. That's all I ever wanted for them."},
		{"who": "me", "text": "There's one in the kitchen for you. There always was."},
	],
	"whole_story": [
		{"who": "me", "face": "tired", "text": "Martha? The diary's whole. Every page came home."},
		{"who": "martha", "face": "smile", "text": "Then the rounds are done, love. Sit down a minute. You've earned the good chair."},
		{"who": "me", "face": "happy", "text": "Goodnight, Martha."},
	],
}
const ENDING_CARD := {"true": 2, "housekeeper": 2, "windows": 3, "whole_story": 2}
const TALLOW_ONLY := ["housekeeper"]


## The first meeting's lines for a guardian ([] if it has none).
static func meet(kind: String) -> Array:
	return _with_who(MEET.get(kind, []), kind)


static func fall(kind: String) -> Array:
	return _with_who(FALL.get(kind, []), kind)


## One later-meeting line (not `last`, the one said last time, when there is a choice).
static func again(kind: String, last := "") -> Array:
	var opts: Array = AGAIN.get(kind, [])
	if opts.is_empty():
		return []
	var pick: Dictionary = opts[randi() % opts.size()]   # visual-only randomness: never the seeded RNGs
	if str(pick["text"]) == last and opts.size() > 1:
		pick = opts[(opts.find(pick) + 1) % opts.size()]
	return _with_who([pick], kind)


static func _with_who(lines: Array, kind: String) -> Array:
	var out: Array = []
	for l in lines:
		var d: Dictionary = (l as Dictionary).duplicate()
		if not d.has("who"):
			d["who"] = kind
		out.append(d)
	return out


## The speaker's name plate: the candle's name, MARTHA FENN, or the guardian's name.
static func speaker_name(who: String, candle: String) -> String:
	if who == "me":
		return L.t(str(Candles.def_of(candle)["name"])).to_upper()
	if who == "martha":
		return L.t("MARTHA FENN")
	return str(Enemy.DEFS.get(who, {}).get("name", who.to_upper()))


static func voice(who: String) -> Array:
	return SPEAKERS.get(who, SPEAKERS["me"]).get("voice", SPEAKERS["me"]["voice"])
