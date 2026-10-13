extends Node
## Two-process LAN test (localhost). Start the host, then the client:
##   godot --headless --path . -- --nettest=host
##   godot --headless --path . -- --nettest=client
## The host adds CPUs, waits for the client's player, runs a Stock match and
## checks the remote cat actually moved and attacked from the client's
## inputs. The client checks it received snapshots, events and the final
## results. Each process exits 0 on success.

var role := "host"
var t := 0.0
var stage := "start"
var problems: Array = []
var remote_x0 := INF
var remote_moved := false
var remote_attacked := false
var snaps_seen := 0
var events_seen := 0
var fighters_seen := 0
var want_clients := 1
var leave_after := 0.0
var expect_leave := false
var match_t := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--nettest="):
			role = a.substr(10)
		if a.begins_with("--clients="):
			want_clients = int(a.substr(10))
		if a.begins_with("--leave-after="):
			leave_after = float(a.substr(14))
		if a == "--expect-leave":
			expect_leave = true
	if role == "host":
		if not Net.host("HOST"):
			_fail("host failed: " + Net.last_error)
			return
		Net.request("mode", {"mode": "stock"})
		for i in 10 - want_clients:
			var r: Dictionary = CosmeticDefs.ROSTER[i % CosmeticDefs.ROSTER.size()]
			Net.request("add_bot", {"skin": Sprites.full_skin(r), "preset": r.id, "name": "BOT%d" % i})
		stage = "wait_client"
	else:
		InputHub.virtual_held["virt1"] = {}
		if not Net.join("127.0.0.1", "CLIENT"):
			_fail("join failed")
			return
		stage = "connecting"
	print("[%s] started" % role)


func _fail(msg: String) -> void:
	problems.append(msg)
	_finish()


func _finish() -> void:
	print("[%s] %s" % [role, "PASS" if problems.is_empty() else "FAIL: " + ", ".join(problems)])
	get_tree().quit(0 if problems.is_empty() else 1)


func _physics_process(dt: float) -> void:
	t += dt
	if t > 150.0:
		_fail("timeout in stage " + stage)
		return
	if role == "host":
		_host_tick()
	else:
		_client_tick()


func _host_tick() -> void:
	match stage:
		"wait_client":
			var ready_remote := 0
			for s in Net.lobby.slots:
				if s.kind == "human" and int(s.owner) != 1 and s.ready:
					ready_remote += 1
			if ready_remote >= want_clients:
				var rules := ModeDefs.default_rules("stock")
				rules["stocks"] = 1
				rules["bot_level"] = 2
				var ses := Net.build_session(rules, "garden")
				ses["smoke"] = true
				Net.start_match(ses)
				stage = "match"
				print("[host] match started with %d fighters at %d ms" % [ses.players.size(), Time.get_unix_time_from_system() * 1000.0])
		"match":
			var mc: Node = Net.match_ctl
			if mc == null or not is_instance_valid(mc):
				return
			for f in mc.fighters:
				if f.owner_peer != 1 and not f.is_bot:
					if OS.has_environment("NET_DEBUG") and Engine.get_physics_frames() % 60 == 0:
						print("[host] remote %s phase=%s pos=%s state=%s move=%s" % [f.display_name, mc.phase, f.global_position, f.state, f.input.move])
					if mc.phase == "fight":
						if not f.has_meta("x0"):
							f.set_meta("x0", f.global_position.x)
						elif absf(f.global_position.x - float(f.get_meta("x0"))) > 30.0:
							f.set_meta("moved", true)
							remote_moved = true
						if f.state == "attack" or int(f.stats.weapons.get("paws", 0)) > 0:
							remote_attacked = true
			if mc.phase == "fight" and int(mc.time * 60.0) % 300 == 0:
				print("[host] snapshot %d bytes compressed" % Net.last_snapshot_bytes)
			if mc.finished:
				if expect_leave:
					var taken := 0
					for f in mc.fighters:
						if f.owner_peer != 1 and f.is_bot:
							taken += 1
					print("[host] cats taken over by CPU after their device left: %d" % taken)
					if taken < 1:
						problems.append("left player's cat was not handed to a CPU")
				var movers := 0
				for f in mc.fighters:
					if f.has_meta("moved"):
						movers += 1
				print("[host] remote fighters that moved: %d / %d" % [movers, want_clients])
				if movers < want_clients:
					problems.append("only %d of %d remote fighters moved" % [movers, want_clients])
				if not remote_attacked:
					problems.append("remote fighter never attacked")
				print("[host] match finished: %s (last snapshot %d bytes compressed)" % [str(Router.last_result.get("title", "?")), Net.last_snapshot_bytes])
				stage = "done"
				# Give the client a moment to receive the results.
				get_tree().create_timer(2.0).timeout.connect(_finish)


func _client_tick() -> void:
	match stage:
		"connecting":
			if Net.lobby.get("slots", []).size() > 0 and Net._got_lobby:
				Net.request("join", {"device": "virt1", "skin": Sprites.full_skin(CosmeticDefs.ROSTER[5]), "preset": CosmeticDefs.ROSTER[5].id, "name": "CLIENT", "profile": -1})
				Net.request("set", {"device": "virt1", "ready": true})
				stage = "lobby"
				print("[client] joined lobby")
		"lobby":
			if Net.match_ctl and is_instance_valid(Net.match_ctl):
				stage = "match"
				print("[client] match started at %d ms" % [Time.get_unix_time_from_system() * 1000.0])
		"match":
			var mc: Node = Net.match_ctl
			match_t += get_physics_process_delta_time()
			if leave_after > 0.0 and match_t > leave_after:
				print("[client] leaving mid-match on purpose at %d ms (match_t %.1f)" % [Time.get_unix_time_from_system() * 1000.0, match_t])
				Net.leave()
				_finish()
				return
			if mc and is_instance_valid(mc):
				if mc._snap_age < 0.2:
					snaps_seen += 1
				fighters_seen = maxi(fighters_seen, mc.fighters.size())
				events_seen = maxi(events_seen, 1 if mc.fx._life.size() > 0 and _any_particles(mc) else events_seen)
				# Drive our cat: run right/left, jump, attack.
				var k := int(t * 2.0) % 6
				var held := {}
				if k < 2:
					held["right"] = true
				elif k < 4:
					held["left"] = true
				if int(t * 10.0) % 7 == 0:
					held["light"] = true
				if int(t * 10.0) % 13 == 0:
					held["jump"] = true
				InputHub.virtual_held["virt1"] = held
			if Router.current_name == "results":
				if snaps_seen < 30:
					problems.append("too few snapshots (%d)" % snaps_seen)
				if fighters_seen < 10:
					problems.append("expected 10 fighters, saw %d" % fighters_seen)
				if events_seen == 0:
					problems.append("no effect events replayed")
				print("[client] results: %s (snapshots %d)" % [Router.last_result.get("title", "?"), snaps_seen])
				_finish()


func _any_particles(mc: Node) -> bool:
	for l in mc.fx._life:
		if l > 0.0:
			return true
	return false
