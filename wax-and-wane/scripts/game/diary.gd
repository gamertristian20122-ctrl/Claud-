class_name Diary
extends Node
## Martha Fenn's diary (v2.5 story stream; the story: docs/design/STORY.md, the stream: docs/streams/v25_story.md).
## 24 torn pages in story order (PAGES), where each can turn up (`from`), which ones this save slot has found,
## the reading card's queue and the endings they open.
##
## Where pages turn up (the `from` keys). Every roll comes from the diary's own generators, seeded from the run's
## seed and the floor ("<seed>:diary:<floor>"), never from world.rng or the floor RNG: a seed builds the same house
## and the same loot with or without pages, and the same pages for every slot that has found the same ones.
##   hollow          a hollow (secret room) may hold a loose page (HOLLOW_CHANCE, rolled per floor)
##   marked          the floor's first marked foe snuffed may drop one (MARKED_CHANCE)
##   champion        a house champion (mini-boss) may drop one (CHAMPION_CHANCE)
##   study           the Study's desk (STUDY_CHANCE)
##   guardian        a guardian's first fall in this slot (since the diary): its area's page if that is missing
##                   ("guardian:<area>"), else a loose one; a guardian that gave its page gives no other
##   area:<area>     the Kitchen, the Library and the Attic each keep their page in one seeded room: it lies there
##                   once that room is cleared
##   tower           the Clock Tower's first room, by the top of the ladder
## Never a page this slot has found, nor one already lying somewhere on this floor. Loose pages come roughly in
## story order (one of the first WINDOW missing ones, seeded); a slot's first page is always page 1.
##
## Hooks (one line each): world._start_floor -> on_floor_start, world._stock_hollow -> on_hollow,
## Specials._stock("study") -> on_study, world.on_enemy_killed -> on_kill, world._clear_room -> on_clear,
## Pickup._collect("page") -> collect, world.on_back -> on_back, world._victory -> win_ending,
## Tower.true_end -> keeper_ending, Records.end_run -> on_end_run, results.gd -> on_results; the Journal's
## Diary tab reads PAGES, is_found() and where_text(). Records (per save slot, Game.records): "diary" (page id ->
## the run it was found on), "diary_guardians" (guardian kind -> 1 once it gave its page), "endings_seen"
## (ending id -> times); the Journal's gold dot is Records' "d:<id>".

const TOTAL := 24
## The Housekeeper's ending wants this many pages (and a won night).
const HALF := 12
## A night this long (or longer) won plays A Candle in Every Window.
const LONG_NIGHT := 7
## Loose pages: one of the first WINDOW missing ones in story order (seeded), so the diary reads like a life.
const WINDOW := 3
const HOLLOW_CHANCE := 0.45
const MARKED_CHANCE := 0.1
const CHAMPION_CHANCE := 0.3
const STUDY_CHANCE := 0.6
## Seconds the room must stay calm (no foe alive, no guardian, cleared) before a reading card opens.
const CALM := 0.6
## Where a loose page can turn up.
const LOOSE := ["hollow", "marked", "champion", "study", "guardian"]
const FIRST := "first_night"

## The diary in story order: id, title, the page (2-5 short sentences, Martha's voice) and where it can turn up.
const PAGES := [
	{"id": "first_night", "title": "My first night", "from": LOOSE,
		"text": "Martha Fenn, aged fourteen: one good dress and a cold. That was me, my first night in this house. At twelve the clock struck and the whole house got up. Cook said staring was rude and handed me a broom."},
	{"id": "rounds", "title": "The Book of Rounds", "from": LOOSE,
		"text": "Every chore in this house is written in the Book of Rounds: wind the clock at twelve, bank the furnace, lock the crypt, ring the bell at one. The first line is in the clockmaker's own hand, and the ink is three hundred years old."},
	{"id": "the_rule", "title": "The house's one rule", "from": LOOSE,
		"text": "In this house, anything done every night for long enough starts to do itself. The organ plays itself. The pot stirs itself. Mind your habits here. They will outlive you."},
	{"id": "under_stairs", "title": "Under the stairs", "from": ["guardian:cellar"],
		"text": "The clockmaker let the room under the cellar stairs to pay for his clock. The lodger never left, and never paid. Every candle end this house ever burnt has run down there into one warm pink pool. We call her Mother. She counts every drip."},
	{"id": "cook", "title": "Cook's one law", "from": ["area:kitchen", "guardian:kitchen"],
		"text": "Cook's one law: the stockpot never goes off the boil. It was boiling before her, she said, and it would be boiling after her. She was right. Mind the stove tops. They light themselves now."},
	{"id": "crypt_keys", "title": "Down in the crypt", "from": ["guardian:crypt"],
		"text": "The Gaoler locks the crypt every night, though nobody living goes in. The Sexton measures everyone who comes to dinner, just in case. When the crypt ran out of room, the old bones were stacked in a corner. The stack has opinions now."},
	{"id": "merchant", "title": "The merchant", "from": LOOSE,
		"text": "A merchant comes up through the cellar floor at twelve and sets up shop in whatever room is empty. He sold my mother her first candle, and he has not aged a day. I asked his name once. He said that was extra."},
	{"id": "pennock", "title": "Mr. Pennock", "from": ["guardian:chapel"],
		"text": "We buried Mr. Pennock, the organist, on a Tuesday. That night the organ played the whole service by itself and got the hymn numbers wrong, just like he did. It has not missed a service since. The choir sing along. Their faces have run a bit."},
	{"id": "silence", "title": "Silence", "from": ["area:library", "guardian:library"],
		"text": "The Head Librarian has shushed this house for two hundred years. Nobody saw her come in, and nobody dares ask her to leave. She once shushed Cook for laughing in the kitchen, two floors down. Cook did her laughing in the garden after that."},
	{"id": "tibbet", "title": "Miss Tibbet's dress", "from": ["area:attic", "guardian:attic"],
		"text": "Miss Tibbet, the dressmaker, was sewing her own wedding dress. Mr. Pennock had booked the boat for Friday. He died on the Tuesday. She left the dress pinned on its form and her trunk packed, and went home to her sister's."},
	{"id": "great_bell", "title": "The great bell", "from": ["guardian:belfry"],
		"text": "Big Walter rang the great bell by hand for forty years. When his arms gave out, the bell went on ringing anyway. The weathercock on the roof turns to watch it. Behind the bell something huge swings to and fro, and the whole tower counts along."},
	{"id": "below_stairs", "title": "Below stairs", "from": LOOSE,
		"text": "When I came there were nine of us below stairs. One by one they married, or left, or were buried, the way people do. The house never noticed. It just went on doing their chores without them."},
	{"id": "family", "title": "The family", "from": LOOSE,
		"text": "The family went to the seaside in my third summer and never came back. They sent letters, then money, then nothing. We kept the house for them anyway. That is what keeping a house means, I suppose."},
	{"id": "seance", "title": "The seance", "from": LOOSE,
		"text": "The maids held a seance in the back parlour to ask the house what it wanted. Every lodger in the house answered at once. It took a week to get the soot out of the curtains. We did not ask again."},
	{"id": "wilf", "title": "Wilf", "from": LOOSE,
		"text": "Wilf, the boot boy, slept in the coal bin because it was the warmest bed in the house. He slept there so long the house forgot he was a boy. Snuffing a lodger only puts it to bed until twelve. Be gentle with Wilf anyway. He hated the dark."},
	{"id": "clockmaker", "title": "The clockmaker", "from": LOOSE,
		"text": "The man who built this house made clocks, and he was afraid of one thing: a wasted minute. So he built a clock to keep every minute in the house, and a brass keeper to wind it. He never told it when to stop."},
	{"id": "borrowed", "title": "Borrowed time", "from": LOOSE,
		"text": "A clock that keeps every minute has to get them from somewhere. Each swing of the pendulum takes one from someone in the house. That is why candles here burn so fast. It is why we all grew old so quickly."},
	{"id": "between_ticks", "title": "Between the ticks", "from": LOOSE,
		"text": "Something lives in the gaps between the ticks. Cook called it the Hour Fiend. It eats the minutes you waste, and it wants the clock to strike two. At two the rounds end, and anything still burning goes out."},
	{"id": "keeper", "title": "The Keeper of Hours", "from": ["tower"],
		"text": "Above the bells lives the Keeper of Hours: brass all through, with a dial for a face. It has wound the clock every night for three hundred years, and nobody ever told it that it could stop. It keeps its ladder pulled up. It only lets it down for someone early."},
	{"id": "hammer", "title": "The hammer", "from": LOOSE,
		"text": "At nineteen I took a hammer up to stop the clock myself. I got as far as the Chapel before two struck, and woke in my own bed with the hammer back in its drawer. At two the house puts everything back. Not always where it was."},
	{"id": "candle_knows", "title": "What a candle knows", "from": LOOSE,
		"text": "Everything in this house has forgotten how to stop: the organ, the pot, the bell, the Keeper. A candle never forgets. It burns, it gives its light, and then it goes out, and that is its whole job. I am going to make a candle."},
	{"id": "good_tallow", "title": "Good tallow", "from": LOOSE,
		"text": "I took the wax from the cellar while Mother slept, only the clean top, and an old wick from the chapel. He came out stubby and lopsided, and cried wax when I struck the match. I have named him Tallow. Mother will want him back. She can't have him."},
	{"id": "every_night", "title": "Every night at twelve", "from": LOOSE,
		"text": "Every night at twelve I light Tallow, say good evening and blow him out again. A year of that and he will light himself, like everything else here. I have chalked the cellar floor for him and hidden what I can in the walls, sealed with wax so he knows where to knock."},
	{"id": "for_tallow", "title": "For Tallow", "from": ["guardian:tower"],
		"text": "Tallow, my knees won't do the stairs any more, so the climb is yours. Go up past the bells and tell them all they can stop. Don't cry, you'll only drip. You are the bravest thing in this house. Love, Martha."},
]

## The endings (scripts/ui/ending.gd plays their cards): the name on the credits and the results screen, and
## the results screen's line under DONE BY.
const ENDINGS := {
	"true": {"name": "True ending"},
	"housekeeper": {"name": "The Housekeeper", "line": "The kitchen light is on. You can finally rest."},
	"windows": {"name": "A Candle in Every Window", "line": "Every window in the house is lit. You can finally rest."},
	"whole_story": {"name": "The Whole Story", "line": "Every page is home. The house can rest."},
}
const ENDING_ACH := {"housekeeper": "end_housekeeper", "windows": "end_windows", "whole_story": "end_story"}

var world: Node
var floor_n := 0
var plan := {}                       # source -> true while this floor still keeps a page there
var area_cell := Vector2i(-99, -99)  # the room that keeps this area's page (the new areas)
var queue: Array = []                # found and not read yet (the reading card opens when the room is calm)
var found_now: Array = []            # found this run (the results screen)
var ending := ""                     # the ending this run played ("" = the results screen only)
var card: Control                    # the reading card on screen
var _out := {}                       # page id -> true: lying on this floor, not picked up yet
var _pick := RandomNumberGenerator.new()
var _calm := 0.0


static func of(w: Node) -> Diary:
	var d = w.get_meta("diary") if w.has_meta("diary") else null
	if d != null and is_instance_valid(d):
		return d
	var nd := Diary.new()
	nd.world = w
	nd.name = "Diary"
	w.set_meta("diary", nd)
	w.add_child(nd)
	return nd


# ================================================================ the slot's diary

static func _rec(key: String) -> Dictionary:
	var d: Variant = Game.records.get(key, {})
	if not (d is Dictionary):
		d = {}
	Game.records[key] = d
	return d


static func found() -> Dictionary:
	return _rec("diary")


static func is_found(id: String) -> bool:
	return found().has(id)


static func count() -> int:
	var n := 0
	for pg in PAGES:
		if is_found(str(pg["id"])):
			n += 1
	return n


static func page(id: String) -> Dictionary:
	for pg in PAGES:
		if pg["id"] == id:
			return pg
	return {}


## 1-based place in the story.
static func number(id: String) -> int:
	for i in PAGES.size():
		if PAGES[i]["id"] == id:
			return i + 1
	return 0


static func is_loose(pg: Dictionary) -> bool:
	return "hollow" in (pg["from"] as Array)


## The page an area's guardians give at their first fall ("" if none).
static func place_page(area: String) -> String:
	return _page_from("guardian:" + area)


## The page one of an area's rooms keeps (the Kitchen, the Library, the Attic).
static func room_page(area: String) -> String:
	return _page_from("area:" + area)


static func tower_page() -> String:
	return _page_from("tower")


static func _page_from(key: String) -> String:
	for pg in PAGES:
		if key in (pg["from"] as Array):
			return str(pg["id"])
	return ""


## A page is found: kept in the slot's records (a gold dot in the Journal), the diary achievements.
static func mark_found(id: String) -> void:
	var d := found()
	if d.has(id) or page(id).is_empty():
		return
	d[id] = int(Game.records.get("runs", 0))
	Records.mark_new("d:" + id)
	var n := count()
	Achievements.unlock("diary_first")
	if n >= HALF:
		Achievements.unlock("diary_half")
	if n >= TOTAL:
		Achievements.unlock("diary_all")
	Game.save()


static func ending_seen(id: String) -> int:
	return int(_rec("endings_seen").get(id, 0))


## The Journal: where a page can turn up, in a few words.
static func where_text(id: String) -> String:
	var from: Array = page(id).get("from", [])
	if "hollow" in from:
		return L.t("Somewhere in the house: a hollow, a marked foe, a house champion, the Study, or a guardian's first fall.")
	for k in from:
		var s := str(k)
		if s == "tower":
			return L.t("Waits at the top of the ladder of light.")
		if s == "guardian:tower":
			return L.t("The Keeper of Hours keeps it.")
		if s.begins_with("area:"):
			var a := s.substr(5)
			return L.t("Somewhere in {area} (a night of {n} floors or more).", {"area": str(Areas.def(a).get("name", a)), "n": first_night(a)})
	for k in from:
		var s := str(k)
		if s.begins_with("guardian:"):
			var a := s.substr(9)
			return L.t("Kept by the guardians of {area}: snuff one for the first time.", {"area": str(Areas.def(a).get("name", a))})
	return ""


## The shortest night an area is part of (the Kitchen 5, the Library 6, the Attic 7).
static func first_night(area: String) -> int:
	for n in range(Areas.MIN_FLOORS, Areas.MAX_FLOORS + 1):
		if area in Areas.sequence(n) or area in Areas._raw_sequence(n):
			return n
	return Areas.MAX_FLOORS


static func area_of(w: Node) -> String:
	return str(w.fdef().get("area", "")) if w.has_method("fdef") else ""


# ================================================================ the floor's pages

## world._start_floor: roll where this floor keeps its pages (the diary's own seeded generator) and, in the
## Clock Tower, leave the Keeper's page by the top of the ladder.
static func on_floor_start(w: Node) -> void:
	of(w)._plan_floor()


func _plan_floor() -> void:
	var w := world
	floor_n = int(w.floor_num)
	_out.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:diary:%d" % [int(w.run_seed), floor_n])
	_pick.seed = hash("%d:diarypick:%d" % [int(w.run_seed), floor_n])
	plan = {"hollow": rng.randf() < HOLLOW_CHANCE, "marked": rng.randf() < MARKED_CHANCE,
		"champion": rng.randf() < CHAMPION_CHANCE, "study": rng.randf() < STUDY_CHANCE}
	area_cell = Vector2i(-99, -99)
	var area := area_of(w)
	if room_page(area) != "":
		var cells: Array = []
		for c in w.layout["cells"].keys():
			var d: Dictionary = w.layout["cells"][c]
			if d["type"] == "normal" and int(d.get("dist", 0)) >= 1 and not d.has("mini"):
				cells.append(c)
		cells.sort()
		if not cells.is_empty():
			area_cell = cells[rng.randi() % cells.size()]
	if area == "tower" and w.room and w.room.data["type"] == "start":
		var id := pick("tower")
		if id != "":
			_drop(id, w.room.center() + Vector2(26, -14))


## The page a source gives now ("" = none): never one this slot has found, nor one lying on this floor.
func pick(source: String, area := "") -> String:
	var fresh := count() == 0
	match source:
		"area":
			return _free(room_page(area))
		"tower":
			return _free(tower_page())
		"guardian":
			if not (fresh and _free(FIRST) != ""):
				var own := _free(place_page(area))
				if own != "":
					return own
	var cands: Array = []
	for pg in PAGES:
		if is_loose(pg) and _free(str(pg["id"])) != "":
			cands.append(str(pg["id"]))
			if cands.size() >= WINDOW:
				break
	if cands.is_empty():
		return ""
	if fresh:
		return cands[0]   # a slot's first page is page 1 (the first loose page)
	return cands[_pick.randi() % cands.size()]


func _free(id: String) -> String:
	return id if id != "" and not is_found(id) and not _out.has(id) else ""


func _drop(id: String, pos: Vector2, pop := Vector2.ZERO, src := "") -> Pickup:
	var p: Pickup = world.add_pickup("page", world.free_spot_near(pos, 5.0), id, 0, pop)   # never inside an urn or a wall
	if src != "":
		p.record["src"] = src
	_out[id] = true
	Audio.play("page_flip", -8.0, 0.05, 1.25)
	if world.main and world.main.autotest:
		print("[diary] page %d (%s) lies on floor %d (%s)" % [number(id), id, int(world.floor_num), src if src != "" else world.room.data["type"]])
	return p


## world._stock_hollow: a hollow may keep a page (someone hid it from the dark).
static func on_hollow(w: Node, c: Vector2) -> void:
	var d := of(w)
	if d.plan.get("hollow", false):
		d.plan["hollow"] = false
		var id := d.pick("hollow")
		if id != "":
			d._drop(id, c + Vector2(30, -18))


## Specials._stock("study"): a page on the floor by the lectern (never one of the three that crumble).
static func on_study(w: Node, c: Vector2) -> void:
	var d := of(w)
	if d.plan.get("study", false):
		d.plan["study"] = false
		var id := d.pick("study")
		if id != "":
			d._drop(id, c + Vector2(-24, 2))


## world.on_enemy_killed: a guardian's first fall, a house champion, the floor's first marked foe.
static func on_kill(w: Node, e: Node) -> void:
	of(w)._killed(e)


func _killed(e: Node) -> void:
	if bool(e.get("boss")):
		var kind := str(e.get("kind"))
		if _rec("diary_guardians").has(kind):
			return
		var id := pick("guardian", area_of(world))
		if id == "":
			_rec("diary_guardians")[kind] = 1   # nothing left for it to give
			return
		var c: Vector2 = world.room.center()
		_drop(id, world.free_spot_near(c + Vector2(0, -22), 8.0), Vector2.ZERO, "g:" + kind)
		return
	var src := ""
	if e.has_meta("mini"):
		src = "champion"
	elif str(e.get("champ")) != "":
		src = "marked"
	if src == "" or not plan.get(src, false):
		return
	plan[src] = false
	var id2 := pick(src)
	if id2 != "":
		_drop(id2, (e as Node2D).global_position, Vector2.from_angle(randf() * TAU) * 30.0)


## world._clear_room: the new areas' page lies in its room once that room is cleared.
static func on_clear(w: Node) -> void:
	var d := of(w)
	if w.cur_cell != d.area_cell or d.area_cell == Vector2i(-99, -99):
		return
	d.area_cell = Vector2i(-99, -99)
	var id := d.pick("area", area_of(w))
	if id != "":
		d._drop(id, w.free_spot_near(w.room.center() + Vector2(-22, -18), 8.0))


# ================================================================ picking it up and reading it

## Pickup._collect ("page"): the page is found (saved at once); its reading card waits for a calm room.
static func collect(w: Node, id: String, pos: Vector2, rec := {}) -> void:
	of(w)._collect(id, pos, rec, false)


func _collect(id: String, pos: Vector2, rec: Dictionary, quiet: bool) -> void:
	_out.erase(id)
	var src := str(rec.get("src", ""))
	if src.begins_with("g:"):
		_rec("diary_guardians")[src.substr(2)] = 1
	if is_found(id) or page(id).is_empty():
		Game.save()
		return
	mark_found(id)
	found_now.append(id)
	queue.append(id)
	if world.main and world.main.autotest:
		print("[diary] found page %d (%s), %d / %d" % [number(id), id, count(), TOTAL])
	if quiet:
		return
	Audio.play("page_flip", 0.0, 0.04, 1.0)
	world.fx_text(pos + Vector2(0, -18), L.t("A diary page  {n} / {total}", {"n": count(), "total": TOTAL}), UI.CREAM)


## The run is ending (a won night, the Keeper stilled): pages still lying in the room are gathered up.
func _gather() -> void:
	var r: Node = world.room
	if r == null or not is_instance_valid(r):
		return
	for o in r.objects.get_children():
		if o is Pickup and o.kind == "page" and not o.taken:
			o.taken = true
			world.forget_pickup(o.record)
			_collect(o.item, o.global_position, o.record if o.record else {}, true)
			o.queue_free()


func _process(dt: float) -> void:
	if queue.is_empty() or world == null or (card != null and is_instance_valid(card)):
		return
	if not _calm_now():
		_calm = 0.0
		return
	_calm += dt
	if _calm >= CALM:
		_calm = 0.0
		_open_card(str(queue.pop_front()))


## Never during a fight: the room is cleared, no foe or guardian is alive, nothing holds the world.
func _calm_now() -> bool:
	var w := world
	if w.finished or w.paused or w.transitioning or w.player == null or w.player.dead or get_tree().paused:
		return false
	if w.room == null or not is_instance_valid(w.room) or not w.room.data.get("cleared", false):
		return false
	if w.room.data.get("rung", false) and not w.room.data.get("seance_done", false):
		return false   # a Seance between two waves
	if w.count_enemies() > 0 or Juice.holding(w):
		return false
	var b: Variant = w.boss
	return b == null or not is_instance_valid(b) or not b.alive


func _open_card(id: String) -> void:
	var w := world
	w.hud.release_sticks()
	w.paused = true
	get_tree().paused = true
	card = PageCard.open(w.hud.root, id, _card_closed)
	if w.main and w.main.autotest:
		print("[diary] reading card: page %d (%s), room %s" % [number(id), id, w.room.data["type"]])
		if not w.main.autotest.args.has("diary"):   # play-tests read it for a moment (the tour keeps it open)
			(card as PageCard).auto_close = 0.4


func _card_closed() -> void:
	card = null
	_calm = 0.0
	if world and not world.finished and not world.hud.pause_layer:
		world.paused = false
		get_tree().paused = false


## world.on_back (Back / Esc): closes the reading card first.
static func on_back(w: Node) -> bool:
	var d := of(w)
	if d.card != null and is_instance_valid(d.card):
		(d.card as PageCard).close()
		return true
	return false


# ================================================================ endings

## Which ending a won night plays ("" = the results screen only): a night of LONG_NIGHT floors or more ->
## A Candle in Every Window; HALF pages or more -> The Housekeeper. When both fit, the one not seen yet in this
## slot (else the long night's).
static func ending_for_win(floors: int, pages: int, seen := {}) -> String:
	var cands: Array = []
	if floors >= LONG_NIGHT:
		cands.append("windows")
	if pages >= HALF:
		cands.append("housekeeper")
	for c in cands:
		if int(seen.get(c, 0)) <= 0:
			return c
	return str(cands[0]) if not cands.is_empty() else ""


## world._victory: a won night plays its ending (cards and credits, scripts/ui/ending.gd), then `done` (the
## results). Pages still lying in the guardian's room are gathered first, so the twelfth can count.
static func win_ending(w: Node, done: Callable) -> void:
	var d := of(w)
	d._gather()
	var id := ending_for_win(int(w.get("night_floors")) if w.get("night_floors") != null else 4, count(), _rec("endings_seen"))
	if id == "":
		done.call()
		return
	d._start_ending(id)
	var e := Ending.new()
	e.ending = id
	e.setup(float(w.clock_minutes()), str(w.candle_id), done)
	w.add_child(e)


## Tower.true_end: the Keeper is stilled. With every page it is The Whole Story, else the true ending.
static func keeper_ending(w: Node) -> String:
	var d := of(w)
	d._gather()
	var id := "whole_story" if count() >= TOTAL else "true"
	d._start_ending(id)
	return id


func _start_ending(id: String) -> void:
	ending = id
	var seen := _rec("endings_seen")
	seen[id] = int(seen.get(id, 0)) + 1
	if ENDING_ACH.has(id):
		Achievements.unlock(ENDING_ACH[id])
	if world.main and world.main.autotest:
		print("[diary] ending: %s (%d pages)" % [id, count()])
	Game.save()


static func ending_name(id: String) -> String:
	return L.t(str(ENDINGS.get(id, {}).get("name", "")))


# ================================================================ results

## Records.end_run: the run's pages and ending for the results screen.
static func on_end_run(w: Node, _won: bool, params: Dictionary) -> void:
	var d := of(w)
	params["ending"] = d.ending
	params["diary_new"] = d.found_now.duplicate()
	params["diary_unread"] = d.queue.duplicate()


## results.gd: the ending's name and line, the pages found tonight, and the reading cards of the pages that
## were found as the run ended (or during a fight that never ended), one after another.
static func on_results(res: Control, v: Container, params: Dictionary) -> void:
	var id := str(params.get("ending", ""))
	var labels: Array = []
	Tower._labels(v, labels)
	if id == "whole_story":
		for l in labels:
			if l.text == "TRUE ENDING":
				l.text = ending_name(id).to_upper()
	elif ENDINGS.has(id) and ENDINGS[id].has("line"):
		for l in labels:
			if l.text.begins_with("The house is quiet"):
				l.text = L.t(str(ENDINGS[id]["line"]))
	var news: Array = params.get("diary_new", [])
	if not news.is_empty():
		var names: Array = []
		for p in news.slice(0, 2):
			names.append("\"%s\"" % L.t(str(page(p).get("title", ""))))
		var line := L.t("Diary: {pages} ({n} / {total})", {"pages": ", ".join(names) + (" +%d" % (news.size() - 2) if news.size() > 2 else ""), "n": count(), "total": TOTAL})
		var dl := UI.label(line, 8, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size = Vector2(300, 0)
		v.add_child(dl)
		v.move_child(dl, mini(2, v.get_child_count() - 1))
	var unread: Array = (params.get("diary_unread", []) as Array).duplicate()
	if not unread.is_empty():
		res.get_tree().create_timer(0.9).timeout.connect(func(): _read_on(res, unread))


static func _read_on(res: Control, ids: Array) -> void:
	if ids.is_empty() or not is_instance_valid(res) or not res.is_inside_tree():
		return
	var id := str(ids.pop_front())
	var c := PageCard.open(res, id, func(): _read_on(res, ids))
	var main: Node = res.get_parent()
	if main and main.get("autotest") != null and main.autotest and not main.autotest.args.has("diary"):
		c.auto_close = 0.4
