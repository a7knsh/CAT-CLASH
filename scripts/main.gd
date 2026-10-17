extends Node
## Entry point. Hosts the active screen and handles developer command-line
## switches (pass them after `--`):
##   --smoke          run the automated smoke test suite and quit
##   --shots          take a screenshot tour into user://shots and quit
##   --bench          run a 4-bot chaos match and report frame times
##   --quick=MODE,ARENA,N   jump straight into an all-bot match


func _ready() -> void:
	Router.root = self
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a == "--check":
			var files: Array = []
			_scan("res://scripts", files)
			for f in files:
				load(f)
			print("checked %d scripts" % files.size())
			get_tree().quit()
			return
		if a == "--smoke":
			add_child(load("res://scripts/dev/smoke_test.gd").new())
			return
		if a == "--shots":
			add_child(load("res://scripts/dev/screenshot_tour.gd").new())
			return
		if a.begins_with("--nettest="):
			add_child(load("res://scripts/dev/net_test.gd").new())
			return
		if a == "--bench":
			add_child(load("res://scripts/dev/bench.gd").new())
			return
		if a.begins_with("--quick="):
			var parts := a.substr(8).split(",")
			var mode := parts[0] if parts.size() > 0 else "ffa"
			var arena := parts[1] if parts.size() > 1 else "garden"
			var count := int(parts[2]) if parts.size() > 2 else 4
			Router.session = Sessions.quick_session(mode, arena, count, true)
			Router.goto("match", {}, false)
			return
	Router.goto("title", {}, false)


func _scan(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		_scan(dir + "/" + sub, out)
