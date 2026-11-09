extends RefCounted
## Screenshot tour and checks of the save slots (v2.1), never in play:
##   -- --autotest --tour --slots --shots=DIR [--fit]
## Give it its own profile. On a profile that holds a 2.0 save (save.cfg with records, run.cfg) it
## first checks the move into Slot 1, record by record. Then it drives the real screens: the title,
## the Slots screen (touch and gamepad focus, Back), New candle -> the level picker -> a level 3 run
## (its pause menu and results), Level (picker with NOW, the confirm), Delete (both confirms), Play over
## a saved run (the confirm), Continue (the run keeps its own level) and the Journal's run record.
## Prints "[slots] PASS / FAIL ..." per check and "[slots] DONE fails=N".

static var fails := 0


static func _ok(cond: bool, what: String) -> void:
	print("[slots] %s  %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		fails += 1


static func _slots_screen(title: Node) -> Slots:
	for c in (title.root as Control).get_children():
		if c is Slots and not c.is_queued_for_deletion():
			return c
	return null


static func _top_modal(title: Node) -> Control:
	var r: Control = title.root
	for i in range(r.get_child_count() - 1, -1, -1):
		var c := r.get_child(i)
		if c.get_meta("modal", false) and not c.is_queued_for_deletion():
			return c
	return null


## A button by its text, or by the text of a label on it (two-line buttons).
static func _button(root: Node, text: String) -> Button:
	if root == null:
		return null
	for c in root.get_children():
		if c is Button:
			if (c as Button).text == text:
				return c
			for l in c.get_children():
				if l is Label and (l as Label).text == text:
					return c
		var deep := _button(c, text)
		if deep:
			return deep
	return null


static func _press(root: Node, text: String) -> bool:
	var b := _button(root, text)
	if b == null:
		print("[slots] no button '%s'" % text)
		return false
	b.pressed.emit()
	return true


static func _wait_game(at: Node) -> Node:
	var main: Node = at.main
	var t := 0.0
	while t < 10.0 and not (main.current and main.current.name == "Game" and main.current.get("player") != null and not main._busy):
		await at._wait(0.1)
		t += 0.1
	await at._wait(0.6)
	return main.current


static func _wait_screen(at: Node, nm: String) -> Node:
	var main: Node = at.main
	var t := 0.0
	while t < 10.0 and not (main.current and main.current.name == nm and not main._busy):
		await at._wait(0.1)
		t += 0.1
	return main.current


static func tour(at: Node) -> void:
	var main: Node = at.main
	var tag: String = at._vs()
	fails = 0
	Controls.set_device(Controls.TOUCH)
	# ---- 1. a 2.0 save moved into Slot 1 (Game.load_save did it at start-up)
	var old := ConfigFile.new()
	if old.load(Game.OLD_SAVE) == OK and old.has_section("records"):
		var mism := 0
		var keys := old.get_section_keys("records")
		for k in keys:
			if str(old.get_value("records", k)) != str(Game.records.get(k)):
				mism += 1
				print("[slots] MISMATCH %s: %s -> %s" % [k, old.get_value("records", k), Game.records.get(k)])
		var want_lv := 1 if bool(old.get_value("settings", "gentle", false)) else 2
		_ok(mism == 0 and Game.slot == 1 and Game.slot_live and Game.level == want_lv,
			"2.0 save -> Slot 1: %d records, %d mismatches, level %d (Gentle burn was %s), runs %d, wins %d, achievements %d, relics seen %d" % [
			keys.size(), mism, Game.level, old.get_value("settings", "gentle", false), int(Game.records["runs"]), int(Game.records["wins"]),
			(Game.records["achievements"] as Dictionary).size(), (Game.records["seen_relics"] as Dictionary).size()])
		var cf := ConfigFile.new()
		_ok(cf.load(Game.SAVE_PATH) == OK and not cf.has_section("records") and not cf.has_section_key("settings", "gentle")
			and FileAccess.file_exists(Game.slot_path(1)), "save.cfg keeps only the settings and the slot (records in slot1.cfg)")
		_ok(not FileAccess.file_exists(Game.OLD_RUN) and RunSave.has_snapshot() == FileAccess.file_exists(Game.run_path(1)),
			"the 2.0 saved run is Slot 1's: %s" % (RunSave.summary() if RunSave.has_snapshot() else "(none in this profile)"))
	else:
		print("[slots] (no 2.0 save in this profile: the move into Slot 1 is not checked)")
	# ---- 2. the title, then Light the wick: the Slots screen
	main.goto("title")
	await at._wait(3.2)
	await at._shot("slots_title_" + tag)
	var title: Node = main.current
	title._play()
	await at._wait(0.5)
	var s := _slots_screen(title)
	_ok(s != null, "Light the wick opens the Slots screen")
	await at._shot("slots_screen_" + tag)
	# gamepad: focus starts on the slot played last; B / Esc goes back to the title
	Controls.set_device(Controls.PAD)
	await at._wait(0.3)
	var f := at.get_viewport().gui_get_focus_owner()
	var on_last := f != null and s.is_ancestor_of(f) and f.get_parent() and str(f.get_meta("default_focus", false)) == "true"
	_ok(on_last, "gamepad focus starts on slot %d's main button (%s)" % [Game.slot, f])
	await at._shot("slots_pad_" + tag)
	await at._ui("ui_right")
	await at._ui("ui_right")
	await at._shot("slots_pad_right_" + tag)
	await at._ui("ui_cancel")
	await at._wait(0.3)
	_ok(_slots_screen(title) == null, "B / Esc closes the Slots screen")
	Controls.set_device(Controls.TOUCH)
	title._play()
	await at._wait(0.4)
	s = _slots_screen(title)
	# ---- 3. an empty slot: New candle -> the level picker -> a run at level 3
	var empty := 0
	for n in range(1, Game.SLOTS + 1):
		if Game.slot_data(n).is_empty():
			empty = n
			break
	if empty == 0:
		Game.delete_slot(3)
		s._refresh(3)
		empty = 3
		await at._wait(0.2)
	s._new(empty)
	await at._wait(0.4)
	await at._shot("slots_pick_level_" + tag)
	_press(_top_modal(title), "Witching Hour")
	var w: Node = await _wait_game(at)
	_ok(w != null and w.level == 3 and Game.slot == empty and Game.level == 3 and FileAccess.file_exists(Game.slot_path(empty)),
		"New candle in slot %d at level 3: run level %s, slot file %s" % [empty, w.level if w else "?", FileAccess.file_exists(Game.slot_path(empty))])
	w.toggle_pause()
	await at._wait(0.4)
	await at._shot("slots_pause_level3_" + tag)
	var paused_txt := ""
	for l in w.hud.pause_layer.find_children("*", "Label", true, false):
		paused_txt += (l as Label).text + " | "
	_ok("Level 3 - Witching Hour" in paused_txt, "the pause menu shows the level")
	w.give_up()
	var res: Node = await _wait_screen(at, "Results")
	await at._wait(0.6)
	await at._shot("slots_results_level3_" + tag)
	_ok(res != null and int(res.params.get("level", 0)) == 3 and "at level 3" in Share.text(res.params),
		"results and Share carry the level: %s" % Share.text(res.params).split("\n")[1] if res else "?")
	var hist: Array = Game.records.get("run_history", [])
	_ok(not hist.is_empty() and int(hist[0].get("level", 0)) == 3, "the run history records level %s" % (hist[0].get("level", "?") if not hist.is_empty() else "?"))
	# ---- 4. back on the Slots screen: two used slots
	main.goto("title")
	await at._wait(3.2)
	title = main.current
	title._play()
	await at._wait(0.4)
	s = _slots_screen(title)
	await at._shot("slots_after_run_" + tag)
	# ---- 5. Level: the picker (NOW on the slot's level), the confirm, the change
	var other := 1 if empty != 1 else 2
	if Game.slot_data(other).is_empty():
		Game.start_slot(other, 2)   # (a fresh profile: give the tour a second used slot)
		Game.use_slot(empty)
		s._refresh(other)
		await at._wait(0.2)
	var was := int(Game.slot_data(other)["level"])
	var to := 1 if was != 1 else 4
	s._change_level(other)
	await at._wait(0.4)
	await at._shot("slots_level_picker_" + tag)
	_press(_top_modal(title), str(Records.level_def(to)["name"]))
	await at._wait(0.4)
	await at._shot("slots_level_confirm_" + tag)
	_press(_top_modal(title), "Change")
	await at._wait(0.4)
	_ok(int(Game.slot_data(other)["level"]) == to, "slot %d: level %d -> %d" % [other, was, int(Game.slot_data(other)["level"])])
	await at._shot("slots_level_changed_" + tag)
	# ---- 6. Delete asks twice
	s._delete(empty)
	await at._wait(0.4)
	await at._shot("slots_delete_1_" + tag)
	_press(_top_modal(title), "Delete")
	await at._wait(0.4)
	await at._shot("slots_delete_2_" + tag)
	_press(_top_modal(title), "Delete for good")
	await at._wait(0.4)
	_ok(not FileAccess.file_exists(Game.slot_path(empty)) and not FileAccess.file_exists(Game.run_path(empty)) and Game.slot_data(empty).is_empty(),
		"slot %d deleted (its file and saved run gone)" % empty)
	await at._shot("slots_deleted_" + tag)
	# ---- 7. Play over a saved run asks first; Continue keeps the run's own level
	if not RunSave.peek(other).is_empty():
		var run_lv := int((RunSave.peek(other)["run"] as Dictionary).get("level", 0))
		s._play(other)
		await at._wait(0.4)
		await at._shot("slots_abandon_" + tag)
		_press(_top_modal(title), "Keep it")
		await at._wait(0.3)
		_ok(not RunSave.peek(other).is_empty(), "Keep it keeps slot %d's saved run" % other)
		s._continue(other)
		w = await _wait_game(at)
		_ok(w != null and w.level == run_lv and Game.slot == other and Game.level == to,
			"Continue in slot %d: the run plays at its own level %d (the slot is at %d now)" % [other, w.level if w else -1, Game.level])
		w.toggle_pause()
		await at._wait(0.4)
		await at._shot("slots_continued_pause_" + tag)
		w.toggle_pause()
		await at._wait(0.2)
		var j := Journal.open(w.hud.root)
		await at._wait(0.4)
		j._set_tab(5, false)
		j._select(1)   # 0 How to play, 1 the Ledger (slot + level)
		await at._wait(0.3)
		await at._shot("slots_journal_ledger_" + tag)
		j.queue_free()
	else:
		print("[slots] (slot %d has no saved run: Play's confirm and Continue are not checked)" % other)
	print("[slots] DONE fails=%d" % fails)
