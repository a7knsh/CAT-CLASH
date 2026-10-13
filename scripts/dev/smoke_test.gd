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


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	var arenas: Array = ArenaDefs.ORDER
	var plan := [
		["ffa", 2], ["ffa", 3], ["ffa", 4], ["team", 4], ["duel", 2], ["stock", 4], ["timed", 3],
		["roulette", 4], ["koth", 4], ["capture", 4], ["survival", 2], ["boss", 3], ["chaos", 4], ["training", 1],
		["stock", 2], ["ffa", 4], ["team", 2], ["capture", 2], ["survival", 1], ["boss", 1], ["koth", 2], ["stock", 3],
	]
	var i := 0
	for p in plan:
		if only != "" and p[0] != only:
			continue
		var arena: String = arenas[i % arenas.size()]
		if p[0] == "boss":
			arena = "neon" if i % 2 == 0 else "garden"
		cases.append({"mode": p[0], "count": p[1], "arena": arena})
		i += 1
	_test_save_roundtrip()
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


func _next() -> void:
	if match_node:
		match_node.queue_free()
		match_node = null
	Engine.time_scale = 1.0
	idx += 1
	if idx >= cases.size():
		_report()
		return
	var c: Dictionary = cases[idx]
	var s := Sessions.quick_session(c.mode, c.arena, c.count, true)
	s["smoke"] = true
	s.rules["rounds"] = 2
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
	if match_node == null or idx >= cases.size():
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
		if f.alive_in_round() and f.test_move(f.global_transform, Vector2.ZERO):
			stuck[f] = int(stuck.get(f, 0)) + 1
			if stuck[f] > 180:
				problems.append("%s/%s: fighter stuck in geometry at %s" % [c.mode, c.arena, p])
				stuck[f] = -100000
		else:
			stuck[f] = 0
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
