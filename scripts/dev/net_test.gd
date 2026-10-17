extends Node
## Two-process LAN test (localhost). Start the host, then the client:
##   godot --headless --path . -- --nettest=host
##   godot --headless --path . -- --nettest=client
## LAN games are players-only, so the host fills the other slots with its
## own virtual human players (virt0..), waits for the clients' players, runs
## a short Timed match and checks the remote cats actually moved and
## attacked from the clients' inputs. With --expect-leave it also checks that
## a client leaving mid-match removes its cat (no CPU takeover). The client checks it received snapshots, events and the final
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
		Net.request("mode", {"mode": "timed"})
		# CPUs must be refused in LAN games.
		Net.request("add_bot", {"skin": Sprites.full_skin(CosmeticDefs.ROSTER[0]), "preset": CosmeticDefs.ROSTER[0].id, "name": "BOT"})
		for s in Net.lobby.slots:
			if s.kind == "bot":
				problems.append("host accepted a CPU in a LAN lobby")
		for i in 10 - want_clients:
			var dev := "virt%d" % i
			InputHub.virtual_held[dev] = {}
			var r: Dictionary = CosmeticDefs.ROSTER[i % CosmeticDefs.ROSTER.size()]
			Net.request("join", {"device": dev, "skin": Sprites.full_skin(r), "preset": r.id, "name": "LOCAL%d" % i, "profile": -1})
			Net.request("set", {"device": dev, "ready": true})
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
				var rules := ModeDefs.default_rules("timed")
				rules["time"] = 40
				var ses := Net.build_session(rules, "garden")
				for p in ses.players:
					if bool(p.get("bot", false)):
						problems.append("LAN session contains a CPU fighter")
				ses["smoke"] = true
				Net.start_match(ses)
				stage = "match"
				print("[host] match started with %d fighters at %d ms" % [ses.players.size(), Time.get_unix_time_from_system() * 1000.0])
		"match":
			var mc: Node = Net.match_ctl
			if mc == null or not is_instance_valid(mc):
				return
			_drive_local(mc)
			for f in mc.fighters:
				if f.is_bot and not f.is_decoy and not f.is_enemy and not f.has_meta("cpu_reported"):
					f.set_meta("cpu_reported", true)
					problems.append("CPU fighter %s in a LAN match" % f.display_name)
				if f.owner_peer != 1 and not f.is_bot and not f.departed:
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
					var gone := 0
					for f in mc.fighters:
						if f.departed:
							gone += 1
							if not f.eliminated or f.visible:
								problems.append("departed cat %s is still in the fight" % f.display_name)
						if f.owner_peer != 1 and f.is_bot:
							problems.append("departed cat %s was handed to a CPU" % f.display_name)
					print("[host] cats removed after their device left: %d" % gone)
					if gone < 1:
						problems.append("left player's cat was not removed")
				var movers := 0
				for f in mc.fighters:
					if f.has_meta("moved"):
						movers += 1
				var need := want_clients - (1 if expect_leave else 0)
				print("[host] remote fighters that moved: %d / %d" % [movers, need])
				if movers < need:
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


## Host-side virtual players: wander and swing so the match has action.
func _drive_local(mc: Node) -> void:
	if mc.phase != "fight":
		return
	for i in 10 - want_clients:
		var k := int(t * 1.5 + i) % 6
		var held := {}
		if k < 2:
			held["right"] = true
		elif k < 4:
			held["left"] = true
		if int(t * 10.0 + i * 3) % 5 == 0:
			held["light"] = true
		if int(t * 10.0 + i * 7) % 17 == 0:
			held["jump"] = true
		InputHub.virtual_held["virt%d" % i] = held


func _any_particles(mc: Node) -> bool:
	for l in mc.fx._life:
		if l > 0.0:
			return true
	return false
