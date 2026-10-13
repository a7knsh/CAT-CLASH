extends Node
## Automated smoke tests (run: godot --headless --path . --fixed-fps 60 -- --smoke).
## Plays all-bot matches for every mode across several arenas and player
## counts, checking that matches finish, nobody gets stuck or goes NaN, and
## that save data round-trips. Prints a PASS/FAIL table and exits with the
## number of failures as the process exit code.

const MAX_FRAMES := 60 * 60 * 6   # 6 simulated minutes per match

var cases: Array = []
var idx := -1
var match_node: Node = null
var frames := 0
var results: Array = []
var stuck: Dictionary = {}
var problems: Array = []
var only := ""
var only_arena := ""
var only_count := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
		if a.begins_with("--arena="):
			only_arena = a.substr(8)
		if a.begins_with("--count="):
			only_count = int(a.substr(8))
	var arenas: Array = ArenaDefs.ORDER
	var plan := [
		["ffa", 2], ["ffa", 3], ["ffa", 4], ["team", 4], ["duel", 2], ["stock", 4], ["timed", 3],
		["roulette", 4], ["koth", 4], ["capture", 4], ["survival", 2], ["boss", 3], ["chaos", 4], ["training", 1],
		["stock", 2], ["ffa", 4], ["team", 2], ["capture", 2], ["survival", 1], ["boss", 1], ["koth", 2], ["stock", 3],
		["ffa", 10], ["team", 10], ["capture", 10], ["boss", 10], ["chaos", 10],
	]
	var i := 0
	for p in plan:
		if only != "" and p[0] != only:
			continue
		if only_count > 0 and p[1] != only_count:
			continue
		var arena: String = arenas[i % arenas.size()]
		if p[0] == "boss":
			arena = "neon" if i % 2 == 0 else "garden"
		if only_arena != "":
			arena = only_arena
		cases.append({"mode": p[0], "count": p[1], "arena": arena})
		i += 1
	_test_save_roundtrip()
	_test_audio()
	_next()


func _test_save_roundtrip() -> void:
	var before: Dictionary = SaveData.data.duplicate(true)
	var path := SaveData.export_backup()
	if path == "":
		problems.append("save: export_backup failed")
	var backups := SaveData.list_backups()
	if backups.is_empty():
		problems.append("save: no backups listed")
	else:
		if not SaveData.import_backup(backups[0]):
			problems.append("save: import failed")
	var id := SaveData.save_preset({"name": "TEST CAT", "fur": "ff0000"})
	if SaveData.get_preset(id).fur != "ff0000":
		problems.append("save: preset roundtrip failed")
	SaveData.delete_preset(id)
	SaveData.data = before
	SaveData.save()


func _test_audio() -> void:
	var n: int = AudioHub._sfx.size()
	if n < 50:
		problems.append("audio: only %d sound effects generated" % n)
	var t0 := Time.get_ticks_msec()
	var stream := MusicGen.render(ArenaDefs.ALL.garden.music, AudioHub.MUSIC_SR)
	var ms := Time.get_ticks_msec() - t0
	if stream == null or stream.data.size() < AudioHub.MUSIC_SR * 2 * 8:
		problems.append("audio: music render produced too little data")
	print("audio: %d sfx, music loop %.1fs rendered in %d ms" % [n, stream.data.size() / 2.0 / AudioHub.MUSIC_SR, ms])


func _next() -> void:
	if match_node:
		match_node.queue_free()
		match_node = null
	Engine.time_scale = 1.0
	idx += 1
	if idx >= cases.size():
		await _input_test()
		_report()
		return
	var c: Dictionary = cases[idx]
	var s := Sessions.quick_session(c.mode, c.arena, c.count, true)
	s["smoke"] = true
	# Round modes need 2 round wins; with 10 cats that can take 7+ rounds,
	# so big lobbies play a single round to keep the run time bounded.
	s.rules["rounds"] = 2 if c.count < 6 else 1
	s.rules["stocks"] = 2
	s.rules["time"] = 60
	s.rules["hill_target"] = 30
	s.rules["fish_target"] = 2
	s.rules["waves"] = 3
	s.rules["bot_level"] = 2
	if c.mode == "boss":
		s.rules["stocks"] = 3
	Router.session = s
	Router.tournament = {}
	match_node = load("res://scripts/gameplay/match_controller.gd").new()
	match_node.setup({})
	match_node.headless_fast = true
	Router.root.add_child(match_node)
	frames = 0
	stuck.clear()


func _physics_process(_dt: float) -> void:
	if match_node == null or idx >= cases.size() or not cases[idx].has("mode"):
		return
	frames += 1
	var c: Dictionary = cases[idx]
	# Health checks
	for f in match_node.fighters:
		if not is_instance_valid(f):
			continue
		var p: Vector2 = f.global_position
		if is_nan(p.x) or is_nan(p.y):
			problems.append("%s: NaN position" % c.mode)
			_finish(false, "nan")
			return
		if f.alive_in_round() and f.is_embedded():
			stuck[f] = int(stuck.get(f, 0)) + 1
			if stuck[f] > 180:
				problems.append("%s/%s: fighter stuck in geometry at %s" % [c.mode, c.arena, p])
				stuck[f] = -100000
		else:
			stuck[f] = 0
	if OS.has_environment("CAT_DEBUG") and frames % 300 == 0:
		var line := "t=%ds %s |" % [frames / 60, match_node.mode.hud_top()]
		for f in match_node.fighters:
			if is_instance_valid(f):
				var goal: String = f.brain.goal_kind if f.brain else "-"
				line += " %s(%d,%d %s w=%s g=%s mv=%.1f wall=%s floor=%s)" % [f.display_name, int(f.global_position.x), int(f.global_position.y), f.state, f.weapon_id(), goal, f.input.move.x, f.is_on_wall(), f.on_floor]
		for it in match_node.items():
			if it.id() == "fishobj":
				line += " FISH@(%d,%d)" % [int(it.global_position.x), int(it.global_position.y)]
		print(line)
	if match_node.proj.list.size() > 150:
		problems.append("%s: projectile overflow" % c.mode)
	if match_node.finished:
		_finish(true, "")
		return
	if c.mode == "training" and frames > 60 * 40:
		_finish(true, "training ok")
		return
	if frames > MAX_FRAMES:
		_finish(false, "timeout (phase=%s round=%d)" % [match_node.phase, match_node.round_num])


func _finish(ok: bool, note: String) -> void:
	var c: Dictionary = cases[idx]
	var title := ""
	if match_node.finished:
		title = Router.last_result.get("title", "")
	var kos := 0
	for f in match_node.fighters:
		if is_instance_valid(f):
			kos += int(f.stats.kos)
	results.append({"case": "%-9s %-9s %dp" % [c.mode, c.arena, c.count], "ok": ok, "note": note if note != "" else title,
		"time": "%.0fs" % (frames / 60.0), "kos": kos})
	_next()


## Drive a "human" cat through a virtual controller to verify the whole
## input -> movement -> combat pipeline (run, jump, attack, pick up, throw).
func _input_test() -> void:
	var s := Sessions.quick_session("training", "garden", 1, false)
	s.players[0].device = "virt0"
	s["smoke"] = true
	s.rules["dummy_count"] = 1
	s.rules["dummy_ai"] = "stand"
	Router.session = s
	InputHub.virtual_held["virt0"] = {}
	match_node = load("res://scripts/gameplay/match_controller.gd").new()
	match_node.setup({})
	match_node.headless_fast = true
	Router.root.add_child(match_node)
	var ok := true
	var notes: Array = []
	await _frames(70)
	var me: CatFighter = null
	var dummy: CatFighter = null
	for f in match_node.fighters:
		if f.is_dummy:
			dummy = f
		elif not f.is_bot:
			me = f
	if me == null or dummy == null:
		results.append({"case": "input pipeline", "ok": false, "note": "fighters missing", "time": "-", "kos": 0})
		return
	# Run right
	var x0 := me.global_position.x
	InputHub.virtual_held["virt0"] = {"right": true}
	await _frames(40)
	InputHub.virtual_held["virt0"] = {}
	if me.global_position.x - x0 < 40.0:
		ok = false
		notes.append("run failed (%.0f px)" % (me.global_position.x - x0))
	await _frames(20)
	# Jump
	InputHub.virtual_held["virt0"] = {"jump": true}
	await _frames(6)
	InputHub.virtual_held["virt0"] = {}
	await _frames(4)
	if me.on_floor:
		ok = false
		notes.append("jump failed")
	await _frames(70)
	# Attack the dummy
	me.global_position = dummy.global_position + Vector2(-14, -2)
	me.facing = 1
	await _frames(10)
	var before: float = dummy.stats.damage_taken
	for k in 3:
		InputHub.virtual_held["virt0"] = {"light": true}
		await _frames(2)
		InputHub.virtual_held["virt0"] = {}
		await _frames(14)
	if dummy.stats.damage_taken <= before:
		ok = false
		notes.append("attack did no damage")
	# Pick up and throw
	await _frames(40)
	match_node.spawn_item({"id": "sword", "ammo": -1, "dur": -1, "hits": 0}, me.global_position + Vector2(0, -4), Vector2.ZERO, null, false)
	await _frames(20)
	InputHub.virtual_held["virt0"] = {"throw": true}
	await _frames(2)
	InputHub.virtual_held["virt0"] = {}
	await _frames(10)
	if me.weapon_id() != "sword":
		ok = false
		notes.append("pickup failed")
	InputHub.virtual_held["virt0"] = {"throw": true}
	await _frames(2)
	InputHub.virtual_held["virt0"] = {}
	await _frames(10)
	if not me.weapon.is_empty():
		ok = false
		notes.append("throw failed")
	InputHub.virtual_held.erase("virt0")
	results.append({"case": "input pipeline (virtual pad)", "ok": ok, "note": ", ".join(notes) if not notes.is_empty() else "run/jump/attack/pickup/throw OK", "time": "-", "kos": 0})
	match_node.queue_free()
	match_node = null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _report() -> void:
	var fails := 0
	print("\n================ CAT CLASH SMOKE TEST ================")
	for r in results:
		print("%s  %-28s %6s  KOs:%-3d %s" % ["PASS" if r.ok else "FAIL", r.case, r.time, r.kos, r.note])
		if not r.ok:
			fails += 1
	for p in problems:
		print("PROBLEM: " + p)
	fails += problems.size()
	print("======================================================")
	print("%d cases, %d failures" % [results.size(), fails])
	get_tree().quit(fails)
