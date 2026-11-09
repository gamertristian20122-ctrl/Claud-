class_name RoomTemplates
extends RefCounted
## Hand-made 15x9 room layouts. Legend:
##   .  floor            R rock (bombs)            Q soot rock (bombs; always drops a bomb)
##   U  urn (shots, 2)   C crate (shots, 3)        B furniture (shots, 4): barrel / coffin / pew / beam by floor
##   Z  skull pile (shots, 2)   O oil jar (1 shot or a blast: it explodes, chains to other jars)
##   G  hearth (blocks, burns on touch; 4 shots douse it, bombs smash it)
##   X  column (unbreakable)    P pit (blocks walkers, not shots or flyers)
##   S  spikes (hurt)    W cobweb (slows walkers; embers and blasts burn it)
##   e  enemy   h heavy enemy   f flyer   T chest (sometimes a mimic)   $ hidden chest (never a mimic)
## Rooms are randomly mirrored. Door cells and their neighbours are cleared automatically.
## Every layout must pass `validate()` (run `godot --headless --path . -- --checkrooms`): doors connect
## without breaking anything, every enemy can be reached, nothing is sealed in for good, and the
## centre cells (6..8, 4), where room-clear rewards drop, stay open.

const COLS := 15
const ROWS := 9
const DOORS := [Vector2i(7, 0), Vector2i(7, 8), Vector2i(0, 4), Vector2i(14, 4)]
const LANES := [Vector2i(7, 0), Vector2i(7, 1), Vector2i(6, 0), Vector2i(8, 0),
		Vector2i(7, 8), Vector2i(7, 7), Vector2i(6, 8), Vector2i(8, 8),
		Vector2i(0, 4), Vector2i(1, 4), Vector2i(0, 3), Vector2i(0, 5),
		Vector2i(14, 4), Vector2i(13, 4), Vector2i(14, 3), Vector2i(14, 5)]
## Everything a door lane is cleared of.
const LANE_CLEAR := ["R", "Q", "U", "C", "B", "Z", "O", "G", "X", "P", "S", "W"]
const LEGAL := ".RQUCBZOGXPSWehfT$"
## Passability used by the validator (must match Room.SOLID / Room.SHOT_SOLID).
const SOLID := ["R", "Q", "U", "C", "B", "Z", "O", "G", "g", "X", "P", "K"]
const SHOT_BREAK := ["U", "C", "B", "Z", "O"]
const BOMB_BREAK := ["R", "Q", "G", "g"]
const REWARD_CELLS := [Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4)]

## How much each floor likes a tag (multiplies a template's weight). 1 Cellar, 2 Crypt, 3 Chapel, 4 Belfry.
const FLOOR_LIKES := {
	1: {"webs": 2.0, "furniture": 1.6, "oil": 1.6, "fire": 1.2, "pits": 0.6, "bones": 0.5, "hard": 0.4},
	2: {"pits": 2.0, "bones": 2.6, "furniture": 1.3, "webs": 1.4, "oil": 0.7},
	3: {"furniture": 2.2, "fire": 1.8, "cover": 1.3, "bones": 0.7, "webs": 0.6},
	4: {"spikes": 1.8, "pits": 1.5, "hard": 1.6, "fire": 1.3, "choke": 1.4, "webs": 1.2},
	5: {"hard": 1.8, "open": 1.4, "cover": 1.5, "pits": 1.4, "furniture": 1.2, "webs": 0.3, "oil": 0.5, "bones": 0.4},   # Clock Tower
}

## id, tags, optional w (weight), min_floor, rows.
const NORMAL := [
	# ---------------------------------------------------------------- the v1 layouts (kept)
	{"id": "open_five", "tags": ["open"], "rows": [
		"...............",
		"...............",
		"...e.......e...",
		"...............",
		"......h........",
		"...............",
		"...e.......e...",
		"...............",
		"...............",
	]},
	{"id": "rock_corners", "tags": ["cover"], "rows": [
		"...............",
		"..RR.......RR..",
		"..R....e....R..",
		"...............",
		"....e.....e....",
		"...............",
		"..R....e....R..",
		"..RR.......RR..",
		"...............",
	]},
	{"id": "urn_box", "tags": ["cover"], "rows": [
		"...............",
		"...............",
		"....UUU.UUU....",
		"....U.e.e.U....",
		"...............",
		"....U.....U....",
		"....UUU.UUU....",
		"...............",
		"...............",
	]},
	{"id": "pit_blocks", "tags": ["pits"], "rows": [
		"...............",
		".e...........e.",
		"...PPP...PPP...",
		"...PPP...PPP...",
		"......h........",
		"...PPP...PPP...",
		"...PPP...PPP...",
		".e...........e.",
		"...............",
	]},
	{"id": "four_columns", "tags": ["open"], "rows": [
		"...............",
		"...X.......X...",
		"...............",
		"......eee......",
		"...............",
		"...............",
		"...X.......X...",
		"...............",
		"...............",
	]},
	{"id": "crate_brackets", "tags": ["cover", "flyers"], "rows": [
		"...............",
		"..f.........f..",
		"...............",
		"....CC...CC....",
		"....C.....C....",
		"....CC...CC....",
		"...............",
		"..e.........e..",
		"...............",
	]},
	{"id": "spike_bars", "tags": ["spikes"], "rows": [
		"...............",
		"...............",
		"..SSS.....SSS..",
		"...............",
		".....e.h.e.....",
		"...............",
		"..SSS.....SSS..",
		"...............",
		"...............",
	]},
	{"id": "rock_brackets", "tags": ["cover", "flyers"], "rows": [
		"...............",
		".RRR.......RRR.",
		".R...........R.",
		".R...f...f...R.",
		"...............",
		".R...........R.",
		".R....e.e....R.",
		".RRR.......RRR.",
		"...............",
	]},
	{"id": "pit_gate", "tags": ["pits", "choke"], "rows": [
		"...............",
		"...............",
		"...e..PPP..e...",
		"......PPP......",
		"...............",
		"......PPP......",
		"...e..PPP..e...",
		"...............",
		"...............",
	]},
	{"id": "column_diamond", "tags": ["cover"], "rows": [
		"...............",
		"..U.........U..",
		"...............",
		"....X.....X....",
		"......h.h......",
		"....X.....X....",
		"...............",
		"..U.........U..",
		"...............",
	]},
	{"id": "rock_halls", "tags": ["choke"], "rows": [
		"...............",
		"...............",
		"..RRRRR.RRRRR..",
		"...............",
		"..e....f....e..",
		"...............",
		"..RRRRR.RRRRR..",
		"...............",
		"...............",
	]},
	{"id": "chest_room", "tags": ["open", "reward"], "w": 0.6, "rows": [
		"...............",
		".e...........e.",
		"...............",
		"...............",
		"......T........",
		"...............",
		"...............",
		".e...........e.",
		"...............",
	]},
	{"id": "crate_urn_forts", "tags": ["cover"], "rows": [
		"...............",
		"...............",
		"...CUC...CUC...",
		"...U.......U...",
		"......hh.......",
		"...U.......U...",
		"...CUC...CUC...",
		"...............",
		"...............",
	]},
	{"id": "spike_ring", "tags": ["spikes", "flyers"], "rows": [
		"...............",
		"..f...........f",
		".....SSSSS.....",
		".....S...S.....",
		".....S.e.S.....",
		".....S...S.....",
		".....SSSSS.....",
		"f..............",
		"...............",
	]},
	{"id": "column_grid", "tags": ["cover"], "rows": [
		"...............",
		"...X...X...X...",
		"...............",
		"..e....h....e..",
		"...............",
		"...X...X...X...",
		"...............",
		"...e.......e...",
		"...............",
	]},
	{"id": "pit_brackets", "tags": ["pits"], "rows": [
		"...............",
		"..PPPP...PPPP..",
		"..P..........P.",
		"..P.e.....e..P.",
		"...............",
		"..P.e.....e..P.",
		"..P..........P.",
		"..PPPP...PPPP..",
		"...............",
	]},
	{"id": "rock_dots", "tags": ["cover"], "rows": [
		"...............",
		"...............",
		"....R..R..R....",
		"...............",
		"..h.........h..",
		"...............",
		"....R..R..R....",
		"...............",
		"...............",
	]},
	{"id": "urn_corners", "tags": ["open", "flyers"], "rows": [
		"...............",
		"..UU.......UU..",
		"..U....f....U..",
		"...............",
		"...e.......e...",
		"...............",
		"..U....f....U..",
		"..UU.......UU..",
		"...............",
	]},
	# ---------------------------------------------------------------- open arenas (chasers)
	{"id": "scatter", "tags": ["open"], "rows": [
		"...............",
		"....U.....U....",
		".U.....e.....U.",
		"...............",
		"..e....h....e..",
		"...............",
		".U.....e.....U.",
		"....U.....U....",
		"...............",
	]},
	{"id": "crossroads", "tags": ["open", "spikes"], "rows": [
		"...............",
		"...X.......X...",
		"..e.........e..",
		".....S...S.....",
		".......h.......",
		".....S...S.....",
		"..e.........e..",
		"...X.......X...",
		"...............",
	]},
	{"id": "ambush", "tags": ["open", "flyers"], "rows": [
		"...............",
		".CC.........CC.",
		".Ce.........eC.",
		"...............",
		"......f.f......",
		"...............",
		".Ce.........eC.",
		".CC.........CC.",
		"...............",
	]},
	# ---------------------------------------------------------------- cover from shooters
	{"id": "nave_columns", "tags": ["cover", "hard"], "min_floor": 2, "rows": [
		"...............",
		"..X...X.X...X..",
		"...............",
		".e...........e.",
		"....h.....h....",
		".e...........e.",
		"...............",
		"..X...X.X...X..",
		"...............",
	]},
	{"id": "bunkers", "tags": ["cover"], "rows": [
		"...............",
		".e.............",
		"...UUU...RRR...",
		"...U.......R...",
		".......h.......",
		"...R.......U...",
		"...RRR...UUU...",
		".............e.",
		"...............",
	]},
	{"id": "offset_cover", "tags": ["cover"], "rows": [
		"...............",
		"....R......e...",
		"..e...R........",
		".........R.....",
		"....R.....h....",
		".........R.....",
		"..e...R........",
		"....R......e...",
		"...............",
	]},
	{"id": "duel", "tags": ["cover"], "rows": [
		"...............",
		"...............",
		"...RR.....RR...",
		"...RRh...hRR...",
		"...............",
		"...RR.....RR...",
		"...............",
		".e...........e.",
		"...............",
	]},
	{"id": "ring_road", "tags": ["cover"], "rows": [
		"...............",
		"..RRRR...RRRR..",
		"..R.........R..",
		"..R..e...e..R..",
		".......h.......",
		"..R..e...e..R..",
		"..R.........R..",
		"..RRRR...RRRR..",
		"...............",
	]},
	{"id": "spiked_columns", "tags": ["cover", "spikes"], "rows": [
		"...............",
		"...............",
		"...SXS...SXS...",
		"...............",
		"..e...e.e...e..",
		"...............",
		"...SXS...SXS...",
		"...............",
		"...............",
	]},
	# ---------------------------------------------------------------- choke points and mazes
	{"id": "switchback", "tags": ["choke", "flyers"], "rows": [
		"...............",
		"..f............",
		"RRRRRRRRRRR....",
		".e.........e...",
		"...............",
		"...e.......e...",
		"....RRRRRRRRRRR",
		"............f..",
		"...............",
	]},
	{"id": "four_rooms", "tags": ["choke"], "rows": [
		"...............",
		"...............",
		".......R.......",
		"..e....R....e..",
		"..RRRR...RRRR..",
		"..e....R....e..",
		".......R.......",
		"...............",
		"...............",
	]},
	{"id": "lanes", "tags": ["choke"], "rows": [
		"...............",
		"....R.....R....",
		"....R..e..R....",
		"..e.R.....R.e..",
		"...............",
		"..e.R.....R.e..",
		"....R..e..R....",
		"....R.....R....",
		"...............",
	]},
	{"id": "hourglass", "tags": ["choke", "hard"], "min_floor": 2, "rows": [
		"...............",
		".RRRRR...RRRRR.",
		"..RRR.....RRR..",
		"...R..e.e..R...",
		".......h.......",
		"...R..e.e..R...",
		"..RRR.....RRR..",
		".RRRRR...RRRRR.",
		"...............",
	]},
	{"id": "diagonal", "tags": ["choke"], "rows": [
		"...............",
		"..R............",
		"...R.......e...",
		"....R..........",
		"..e..R.....h...",
		"......R........",
		".......R.......",
		"........R...e..",
		"...............",
	]},
	# ---------------------------------------------------------------- pits that split the room
	{"id": "moat", "tags": ["pits", "choke", "flyers"], "rows": [
		"...............",
		"..f.........f..",
		"PPPPPP...PPPPPP",
		"...e.......e...",
		"...............",
		"...e.......e...",
		"PPPPPP...PPPPPP",
		"...............",
		"...............",
	]},
	{"id": "pit_cross", "tags": ["pits"], "rows": [
		"...............",
		"...PP.....PP...",
		"...PP..e..PP...",
		"...............",
		"..e....h....e..",
		"...............",
		"...PP..e..PP...",
		"...PP.....PP...",
		"...............",
	]},
	{"id": "twin_holes", "tags": ["pits", "flyers"], "rows": [
		"...............",
		".e....f.f....e.",
		"...PPPPPPPPP...",
		"...PPPPPPPPP...",
		"...............",
		"...PPPPPPPPP...",
		"...PPPPPPPPP...",
		".e...........e.",
		"...............",
	]},
	{"id": "pit_dots", "tags": ["pits", "hard"], "min_floor": 2, "rows": [
		"...............",
		"..P.P.P.P.P.P..",
		"...............",
		"..P.P.P.P.P.P..",
		"...e...h...e...",
		"..P.P.P.P.P.P..",
		"...............",
		"..P.P.P.P.P.P..",
		"...............",
	]},
	{"id": "pit_bridges", "tags": ["pits", "choke"], "rows": [
		"....P.....P....",
		".e..P.....P....",
		"....P..e..P....",
		"....P.....P....",
		"...............",
		"....P.....P....",
		"....P..h..P....",
		"....P.....P..e.",
		"....P.....P....",
	]},
	{"id": "moat_chest", "tags": ["pits", "reward"], "w": 0.6, "rows": [
		"...............",
		".e...........e.",
		".....PPPPP.....",
		".....P...P.....",
		".......T.......",
		".....P...P.....",
		".....PPPPP.....",
		".e...........e.",
		"...............",
	]},
	{"id": "bell_shafts", "tags": ["pits", "flyers"], "rows": [
		"...............",
		"..e.........e..",
		"..PPP.....PPP..",
		"..PXP..h..PXP..",
		"..PPP.....PPP..",
		"...............",
		"..f.........f..",
		"...............",
		"...............",
	]},
	# ---------------------------------------------------------------- spike corridors
	{"id": "spike_crossing", "tags": ["spikes", "choke", "flyers"], "rows": [
		"...............",
		".e...........e.",
		"RRRRR..f..RRRRR",
		"....SSSSSSS....",
		"....SS...SS....",
		"....SSSSSSS....",
		"RRRRR.....RRRRR",
		".e...........e.",
		"...............",
	]},
	{"id": "spike_gates", "tags": ["spikes", "choke", "flyers", "hard"], "min_floor": 2, "rows": [
		"...f...........",
		"...............",
		"RRRSRRRRRRRSRRR",
		"...............",
		"..e...e.e...e..",
		"...............",
		"RRRSRRRRRRRSRRR",
		"...............",
		"...........f...",
	]},
	{"id": "spike_moat", "tags": ["spikes"], "rows": [
		"...............",
		".SS.........SS.",
		".SS...e.e...SS.",
		".....SSSSS.....",
		".....S...S.....",
		".....SSSSS.....",
		".SS...e.e...SS.",
		".SS.........SS.",
		"...............",
	]},
	{"id": "gauntlet", "tags": ["spikes", "pits", "hard"], "min_floor": 3, "rows": [
		"...............",
		".PP.........PP.",
		".PP..S...S..PP.",
		".....S.e.S.....",
		"..e..S...S..e..",
		".....S.h.S.....",
		".PP..S...S..PP.",
		".PP.........PP.",
		"...............",
	]},
	# ---------------------------------------------------------------- furniture (barrels, coffins, pews, beams)
	{"id": "storeroom", "tags": ["furniture"], "rows": [
		"...............",
		".BB..B...B..BB.",
		".B...........B.",
		".......e.......",
		"..e.........e..",
		".......e.......",
		".B...........B.",
		".BB..B...B..BB.",
		"...............",
	]},
	{"id": "pew_rows", "tags": ["furniture", "cover"], "rows": [
		"...............",
		"...............",
		"..BBBB...BBBB..",
		"...e.......e...",
		"..BBBB...BBBB..",
		".......h.......",
		"..BBBB...BBBB..",
		"...............",
		"...............",
	]},
	{"id": "aisle", "tags": ["furniture"], "rows": [
		"...............",
		".BBBBB...BBBBB.",
		"..e.........e..",
		".BBBBB...BBBBB.",
		"...............",
		".BBBBB...BBBBB.",
		"..e.........e..",
		".BBBBB...BBBBB.",
		"...............",
	]},
	{"id": "long_pews", "tags": ["furniture", "choke"], "rows": [
		"...............",
		"...e.......e...",
		".BBBBB...BBBBB.",
		"...............",
		".......h.......",
		"...............",
		".BBBBB...BBBBB.",
		"...e.......e...",
		"...............",
	]},
	{"id": "barrel_ring", "tags": ["furniture"], "rows": [
		"...............",
		"..BBB.....BBB..",
		"..B.........B..",
		"..B..e...e..B..",
		"...............",
		"..B..e...e..B..",
		"..B.........B..",
		"..BBB.....BBB..",
		"...............",
	]},
	{"id": "coffin_rows", "tags": ["furniture"], "rows": [
		"...............",
		"..B..B...B..B..",
		"..B..B...B..B..",
		"...............",
		"..e...e.e...e..",
		"...............",
		"..B..B...B..B..",
		"..B..B...B..B..",
		"...............",
	]},
	{"id": "web_store", "tags": ["furniture", "webs"], "rows": [
		"...............",
		".BBB.WWWWW.BBB.",
		"...............",
		"...W..e.e..W...",
		"...W...h...W...",
		"...W.......W...",
		"...............",
		".BBB.WWWWW.BBB.",
		"...............",
	]},
	# ---------------------------------------------------------------- hearths (fire)
	{"id": "hearth_hall", "tags": ["fire"], "rows": [
		"...............",
		"...U.......U...",
		".......e.......",
		".....G...G.....",
		"..e.........e..",
		"...............",
		".......h.......",
		"...U.......U...",
		"...............",
	]},
	{"id": "hearth_ring", "tags": ["fire", "open"], "rows": [
		"...............",
		"...e.......e...",
		".......G.......",
		".....U...U.....",
		"...............",
		".....U...U.....",
		".......G.......",
		"...e.......e...",
		"...............",
	]},
	{"id": "braziers", "tags": ["fire", "cover"], "rows": [
		"...............",
		"...G.......G...",
		"...............",
		"...RR.....RR...",
		"..e....h....e..",
		"...RR.....RR...",
		"...............",
		"...e.......e...",
		"...............",
	]},
	{"id": "fireplaces", "tags": ["fire"], "rows": [
		"...G.......G...",
		"...............",
		"..U..e...e..U..",
		"...............",
		".......h.......",
		"...............",
		"..U.........U..",
		"...............",
		"...............",
	]},
	{"id": "kitchen", "tags": ["fire", "cover"], "rows": [
		"...............",
		".G.........U.U.",
		"...............",
		"...CC.....e....",
		"..eCC..........",
		".........CC....",
		"....e....CC.e..",
		".U.U.........G.",
		"...............",
	]},
	# ---------------------------------------------------------------- oil jars (shoot them near foes)
	{"id": "oil_cellar", "tags": ["oil"], "rows": [
		"...............",
		"..C.O.....O.C..",
		"..C.........C..",
		".....e...e.....",
		"...............",
		".....e...e.....",
		"..C.........C..",
		"..C.O.....O.C..",
		"...............",
	]},
	{"id": "oil_alley", "tags": ["oil", "cover"], "rows": [
		"...............",
		".e...........e.",
		"...CCOC.COCC...",
		"...............",
		".......h.......",
		"...............",
		"...CCOC.COCC...",
		".e...........e.",
		"...............",
	]},
	{"id": "oil_ring", "tags": ["oil"], "rows": [
		"...............",
		"...e.......e...",
		"...............",
		"......OOO......",
		".....O.h.O.....",
		"......OOO......",
		"...............",
		"...e.......e...",
		"...............",
	]},
	{"id": "powder_store", "tags": ["oil", "cover"], "rows": [
		"...............",
		".OCC.......CCO.",
		".C...........C.",
		".......e.......",
		"...e...h...e...",
		".......e.......",
		".C...........C.",
		".OCC.......CCO.",
		"...............",
	]},
	# ---------------------------------------------------------------- cobwebs (slow)
	{"id": "web_corners", "tags": ["webs", "open"], "rows": [
		"WWW.........WWW",
		"WW...........WW",
		"W.....e.e.....W",
		"...............",
		".......h.......",
		"...............",
		"W.....e.e.....W",
		"WW...........WW",
		"WWW.........WWW",
	]},
	{"id": "web_cover", "tags": ["webs", "cover"], "rows": [
		"...............",
		"..R.........R..",
		"..RWW.....WWR..",
		"...WW..e..WW...",
		".......h.......",
		"...WW..e..WW...",
		"..RWW.....WWR..",
		"..R.........R..",
		"...............",
	]},
	{"id": "nest", "tags": ["webs", "flyers"], "rows": [
		".WW.........WW.",
		"W.............W",
		"..f.........f..",
		".......W.......",
		"....f..W..f....",
		".......W.......",
		"..e.........e..",
		"W.............W",
		".WW.........WW.",
	]},
	{"id": "web_tunnel", "tags": ["webs", "choke"], "rows": [
		"...............",
		"..RRRR...RRRR..",
		"...............",
		"..WWWWWWWWWWW..",
		"..We.......eW..",
		"..WWWWWWWWWWW..",
		"...............",
		"..RRRR...RRRR..",
		"...............",
	]},
	# ---------------------------------------------------------------- bones (skull piles)
	{"id": "ossuary", "tags": ["bones"], "rows": [
		"...............",
		"..Z..e......Z..",
		"...............",
		"....Z..Z..Z....",
		"..e.........e..",
		"....Z..Z..Z....",
		"...............",
		"..Z......e..Z..",
		"...............",
	]},
	{"id": "skull_rows", "tags": ["bones", "cover"], "rows": [
		"...............",
		"..ZZ..Z.Z..ZZ..",
		"...............",
		"..e....h....e..",
		"...............",
		"..e.........e..",
		"...............",
		"..ZZ..Z.Z..ZZ..",
		"...............",
	]},
	{"id": "bone_yard", "tags": ["bones", "pits"], "rows": [
		"...............",
		".ZZ.........ZZ.",
		".Z..PP...PP..Z.",
		"....PP.e.PP....",
		"..e.........e..",
		"....PP.e.PP....",
		".Z..PP...PP..Z.",
		".ZZ.........ZZ.",
		"...............",
	]},
	# ---------------------------------------------------------------- hidden rewards
	{"id": "soot_vaults", "tags": ["reward", "cover"], "w": 0.5, "rows": [
		"...............",
		"...e.......e...",
		"..RQR.....RRR..",
		"..R$R.....R$R..",
		"..RRR..h..RRR..",
		"...............",
		"...e.......e...",
		"...............",
		"...............",
	]},
	{"id": "corner_vault", "tags": ["reward"], "w": 0.5, "rows": [
		"...............",
		".RRR.......e...",
		".R$Q...........",
		".RRR...........",
		".......h.......",
		"...........e...",
		"...............",
		"..e.......e....",
		"...............",
	]},
	{"id": "crate_fort", "tags": ["reward", "open"], "w": 0.5, "rows": [
		"...............",
		".e...........e.",
		"...............",
		"......CCC......",
		"......C$C......",
		"......CCC......",
		"...............",
		".e...........e.",
		"...............",
	]},
]

const START := [
	"...............",
	"...............",
	"...............",
	"...............",
	"...............",
	"...............",
	"...............",
	"...............",
	"...............",
]

const TREASURE := [
	"...............",
	"...............",
	"....U.....U....",
	"...............",
	"...............",
	"...............",
	"....U.....U....",
	"...............",
	"...............",
]

const BOSS := [
	"...............",
	"...............",
	"..X.........X..",
	"...............",
	"...............",
	"...............",
	"..X.........X..",
	"...............",
	"...............",
]


## `night` (FloorGen.generate, world.gen_night): a longer night's floor gates the hard layouts by its depth and
## takes its area's likes (Areas.def(id)["likes"]); empty = floor_num of the 4-floor house.
static func weight_of(t: Dictionary, floor_num: int, dist: int, night := {}) -> float:
	if float(t.get("min_floor", 1)) > float(night.get("depth", floor_num)):
		return 0.0
	var tags: Array = t.get("tags", [])
	if "hard" in tags and dist < 2:
		return 0.0
	var w: float = float(t.get("w", 1.0))
	var likes: Dictionary = night.get("likes", FLOOR_LIKES.get(floor_num, {}))
	for tag in tags:
		w *= float(likes.get(tag, 1.0))
	return w


## Weighted, seeded pick for a normal room (randomly mirrored, with small per-floor touches).
static func pick_normal(rng: RandomNumberGenerator, floor_num := 1, dist := 99, night := {}) -> Array:
	var total := 0.0
	for t in NORMAL:
		total += weight_of(t, floor_num, dist, night)
	var roll := rng.randf() * total
	var chosen: Dictionary = NORMAL[0]
	for t in NORMAL:
		roll -= weight_of(t, floor_num, dist, night)
		if roll <= 0.0 and weight_of(t, floor_num, dist, night) > 0.0:
			chosen = t
			break
	var rows: Array = (chosen["rows"] as Array).duplicate()
	if rng.randf() < 0.5:
		for i in rows.size():
			rows[i] = (rows[i] as String).reverse()
	if rng.randf() < 0.5:
		rows.reverse()
	# one rock in a bigger rock group may be a soot rock (bomb it to get the bomb back)
	var rocks: Array[Vector2i] = []
	for y in rows.size():
		var r: String = rows[y]
		for x in r.length():
			if r[x] == "R":
				rocks.append(Vector2i(x, y))
	if rocks.size() >= 4 and not "Q" in "".join(rows) and rng.randf() < 0.3:
		var c: Vector2i = rocks[rng.randi() % rocks.size()]
		var s: String = rows[c.y]
		rows[c.y] = s.substr(0, c.x) + "Q" + s.substr(c.x + 1)
	# the crypt keeps its dead: some urns are skull piles
	if str(night.get("area", "crypt" if floor_num == 2 else "")) == "crypt":
		for y in rows.size():
			var s2: String = rows[y]
			for x in s2.length():
				if s2[x] == "U" and rng.randf() < 0.35:
					s2 = s2.substr(0, x) + "Z" + s2.substr(x + 1)
			rows[y] = s2
	return rows


## Parse rows -> Array[Array[String]] grid [y][x], with door lanes cleared.
static func to_grid(rows: Array) -> Array:
	var g := []
	for y in ROWS:
		var row := []
		var s: String = rows[y] if y < rows.size() else "..............."
		for x in COLS:
			row.append(s[x] if x < s.length() else ".")
		g.append(row)
	for c in LANES:
		var ch: String = g[c.y][c.x]
		if ch in LANE_CLEAR:
			g[c.y][c.x] = "."
	return g


# ---------------------------------------------------------------- validator

static func _reach(g: Array, from: Vector2i, pass_chars: Array) -> Dictionary:
	var seen := {from: true}
	var q: Array[Vector2i] = [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= COLS or n.y >= ROWS or seen.has(n):
				continue
			var ch: String = g[n.y][n.x]
			if ch in SOLID and not ch in pass_chars:
				continue
			seen[n] = true
			q.append(n)
	return seen


## Returns a list of problems with one layout (all four mirrorings, candelabras placed).
static func check_layout(id: String, rows: Array, normal := true, boss := false) -> Array[String]:
	var errs: Array[String] = []
	if rows.size() != ROWS:
		errs.append("%s: %d rows" % [id, rows.size()])
		return errs
	for y in ROWS:
		var r: String = rows[y]
		if r.length() != COLS:
			errs.append("%s: row %d has %d chars" % [id, y, r.length()])
			return errs
		for ch in r:
			if not ch in LEGAL:
				errs.append("%s: illegal char '%s' in row %d" % [id, ch, y])
	var hearths := "".join(rows).count("G")
	if hearths > 2:
		errs.append("%s: %d hearths (max 2: wall-light budget)" % [id, hearths])
	var foes := 0
	for ch in "".join(rows):
		if ch in "ehf":
			foes += 1
	if normal and (foes < 1 or foes > 8):
		errs.append("%s: %d enemies" % [id, foes])
	for v in 4:
		var rr: Array = rows.duplicate()
		if v & 1:
			for i in rr.size():
				rr[i] = (rr[i] as String).reverse()
		if v & 2:
			rr.reverse()
		var g := to_grid(rr)
		var spots := [Vector2i(0, 0), Vector2i(14, 0)]
		if boss:
			spots += [Vector2i(0, 8), Vector2i(14, 8)]
		for sp in spots:
			if g[sp.y][sp.x] == ".":
				g[sp.y][sp.x] = "K"
		var tag := "%s[%s%s]" % [id, "h" if v & 1 else "", "v" if v & 2 else ""]
		for c in LANES:
			if g[c.y][c.x] in ["e", "h", "f", "T", "$"]:
				errs.append("%s: spawn in a door lane at %s" % [tag, c])
		var walk := _reach(g, DOORS[2], [])
		var shot := _reach(g, DOORS[2], SHOT_BREAK)
		var bomb := _reach(g, DOORS[2], SHOT_BREAK + BOMB_BREAK)
		for d in DOORS:
			if not walk.has(d):
				errs.append("%s: door %s cut off from the left door" % [tag, d])
		for c in REWARD_CELLS:
			var ch: String = g[c.y][c.x]
			if not shot.has(c) or ch in ["S", "P"] or (ch in SOLID and not ch in SHOT_BREAK):
				errs.append("%s: reward cell %s blocked ('%s')" % [tag, c, ch])
		for y in ROWS:
			for x in COLS:
				var c2 := Vector2i(x, y)
				var ch2: String = g[y][x]
				if ch2 in SOLID:
					continue
				if not bomb.has(c2):
					errs.append("%s: floor %s sealed for good" % [tag, c2])
				elif ch2 in ["e", "h", "T"] and not shot.has(c2):
					errs.append("%s: '%s' at %s needs a bomb to reach" % [tag, ch2, c2])
	return errs


## Validate every layout; prints a report and returns the number of problems.
static func validate() -> int:
	var errs: Array[String] = []
	var ids := {}
	for t in NORMAL:
		var id: String = t["id"]
		if ids.has(id):
			errs.append("duplicate id " + id)
		ids[id] = true
		errs.append_array(check_layout(id, t["rows"]))
	errs.append_array(check_layout("START", START, false))
	errs.append_array(check_layout("TREASURE", TREASURE, false))
	errs.append_array(check_layout("BOSS", BOSS, false, true))
	for e in errs:
		print("[checkrooms] ", e)
	for f in [1, 2, 3, 4]:
		var n := 0
		var top := []
		for t in NORMAL:
			if weight_of(t, f, 9) > 0.0:
				n += 1
			if weight_of(t, f, 9) >= 1.6:
				top.append(t["id"])
		print("[checkrooms] floor %d: %d layouts, favourites: %s" % [f, n, ", ".join(top)])
	print("[checkrooms] %d normal layouts, %d problems" % [NORMAL.size(), errs.size()])
	return errs.size()
