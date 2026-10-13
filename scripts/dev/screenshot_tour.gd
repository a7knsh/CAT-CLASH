extends Node
## Visual QA: walks through every screen and several arenas mid-fight, saving
## PNGs to user://shots/ (run with a renderer, e.g. under xvfb):
##   godot --path . --fixed-fps 60 --resolution 960x540 -- --shots [--arena=ID]

var steps: Array = []
var step := -1
var wait := 0
var out_dir := "user://shots"
var only_arena := ""
var only_steps := ""


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--arena="):
			only_arena = a.substr(8)
		if a.begins_with("--steps="):
			only_steps = a.substr(8)
	var arenas: Array = ArenaDefs.ORDER if only_arena == "" else [only_arena]
	if only_steps == "" or only_steps == "menus":
		steps.append(["screen", "title", 40, "01_title"])
		steps.append(["screen", "main_menu", 30, "02_main_menu"])
		steps.append(["screen", "mode_select", 20, "03_mode_select"])
		steps.append(["lobby", "ffa", 40, "04_lobby"])
		steps.append(["screen", "net", 30, "04b_lan_party"])
		steps.append(["setup", "team", 20, "05_setup"])
		steps.append(["creator", 0, 40, "06_creator_coat"])
		steps.append(["creator", 2, 40, "07_creator_gear"])
		steps.append(["creator", 4, 20, "08_creator_presets"])
		steps.append(["collection", 0, 20, "09_collection_weapons"])
		steps.append(["collection", 1, 20, "10_collection_trophies"])
		steps.append(["collection", 2, 20, "11_collection_shop"])
		steps.append(["collection", 3, 20, "12_collection_challenges"])
		steps.append(["screen", "stats", 20, "13_stats"])
		steps.append(["screen", "settings", 20, "14_settings"])
		steps.append(["screen", "controls", 20, "15_controls"])
		steps.append(["screen", "credits", 120, "16_credits"])
		steps.append(["tournament", "", 30, "17_tournament"])
	if only_steps == "" or only_steps == "arenas":
		var i := 0
		for a in arenas:
			var modes := ["ffa", "team", "stock", "koth", "capture", "chaos", "roulette", "timed", "survival", "ffa", "boss", "training"]
			var m: String = modes[i % modes.size()]
			if a == "neon" and only_arena == "":
				m = "boss"
			steps.append(["match", [m, a], 260, "20_%02d_%s_%s_a" % [i, a, m]])
			steps.append(["shot", "", 420, "20_%02d_%s_%s_b" % [i, a, m]])
			i += 1
		steps.append(["results", "", 40, "30_results"])
	_next()


func _next() -> void:
	step += 1
	if step >= steps.size():
		print("Screenshots written to ", ProjectSettings.globalize_path(out_dir))
		get_tree().quit()
		return
	var s: Array = steps[step]
	wait = s[2]
	match s[0]:
		"screen":
			Router.goto(s[1], {}, false)
		"lobby":
			Router.session = {"mode": s[1]}
			Router.goto("lobby", {}, false)
			await get_tree().process_frame
			await get_tree().process_frame
			var l: Node = Router.current
			l._join("kb0")
			l._join("kb1")
			for k in 8:
				l._add_bot()
			Net.request("set", {"device": "kb0", "ready": true})
		"setup":
			Router.session = Sessions.quick_session(s[1], "random", 4, false)
			Router.goto("setup", {}, false)
		"creator":
			Router.goto("creator", {}, false)
			await get_tree().process_frame
			await get_tree().process_frame
			Router.current.tab = s[1]
			Router.current._rebuild()
		"collection":
			Router.goto("collection", {}, false)
			await get_tree().process_frame
			await get_tree().process_frame
			Router.current.tab = s[1]
			Router.current.widx = 5
		"tournament":
			Router.session = Sessions.quick_session("ffa", "random", 2, false)
			Router.session.mode = "tournament"
			Router.goto("setup", {}, false)
			await get_tree().process_frame
			await get_tree().process_frame
			Router.current.rules["bracket"] = 8
			Router.current._create_tournament()
			Router.tournament.rounds[0][0].winner = Router.tournament.rounds[0][0].a
			Router.tournament.rounds[1][0].a = Router.tournament.rounds[0][0].a
			Router.tournament.cur_match = 1
			Router.goto("tournament", {}, false)
		"match":
			var p: Array = s[1]
			Router.session = Sessions.quick_session(p[0], p[1], 10 if step % 4 == 0 else 4, true)
			Router.tournament = {}
			Router.session["smoke"] = true
			Router.goto("match", {}, false)
		"results":
			var mc: Node = Router.current
			if mc and mc.has_method("build_summary"):
				var sm: Dictionary = mc.build_summary()
				sm.rewards = {"yarn": 24, "achievements": ["first_win"], "daily": []}
				Router.last_result = sm
			Router.goto("results", {}, false)
		"shot":
			pass


func _process(_dt: float) -> void:
	if step < 0 or step >= steps.size():
		return
	wait -= 1
	if wait <= 0:
		var name: String = steps[step][3]
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [out_dir, name])
		_next()
