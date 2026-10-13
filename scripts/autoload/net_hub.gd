extends Node
## LAN multiplayer service (Godot high-level multiplayer over ENet).
##
## Model: one device HOSTS and is authoritative. It owns the lobby, runs the
## whole match simulation (fighters, bots, items, hazards, modes) and streams
## snapshots (~30 Hz) plus reliable event batches (effects, sounds, puppet
## reactions, late-spawned fighters) to every client. Clients only send the
## input state of their local controllers every physics frame and render what
## the host tells them. Up to 10 fighters total, from any mix of devices; each
## device may bring several local players (keyboard halves, gamepads).
##
## Discovery: hosts broadcast a small UDP beacon on the LAN once a second;
## the Join screen lists them. Direct IP entry also works.
##
## Offline play uses the same lobby code path with this node acting as a
## local authority (active = false, is_host = true).

signal lobby_changed
signal servers_changed
signal status(text: String)

const PORT := 47810
const BEACON_PORT := 47811
const MAX_FIGHTERS := 10
const MAX_CLIENTS := 9
const VERSION := "catclash-net-1"
const SNAPSHOT_HZ := 30.0

var active := false
var is_host := true
var my_id := 1
var player_name := "CAT"
var lobby: Dictionary = {}
var peer_names: Dictionary = {}
var servers: Dictionary = {}
var in_match := false
var current_session: Dictionary = {}
var match_ctl: Node = null
var last_error := ""
var last_snapshot_bytes := 0

var _beacon: PacketPeerUDP
var _listen: PacketPeerUDP
var _beacon_t := 0.0
var _browsing := false
## Host side: "net:<peer>:<device>" -> {move, held_bits, counts:[], used:[]}
var remote: Dictionary = {}
## Client side: per local device press counters (so no press is ever lost).
var _counts: Dictionary = {}
var _got_lobby := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -900
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	reset_lobby("ffa")


# ================================================================= session

func host(pname: String) -> bool:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		last_error = "COULD NOT OPEN PORT %d (ERROR %d)" % [PORT, err]
		return false
	multiplayer.multiplayer_peer = peer
	active = true
	is_host = true
	my_id = 1
	player_name = pname
	peer_names = {1: pname}
	reset_lobby(lobby.get("mode", "ffa"))
	_beacon = PacketPeerUDP.new()
	_beacon.set_broadcast_enabled(true)
	_beacon.set_dest_address("255.255.255.255", BEACON_PORT)
	status.emit("HOSTING ON PORT %d" % PORT)
	return true


func join(ip: String, pname: String) -> bool:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		last_error = "COULD NOT CONNECT (ERROR %d)" % err
		return false
	multiplayer.multiplayer_peer = peer
	active = true
	is_host = false
	player_name = pname
	status.emit("CONNECTING TO %s..." % ip)
	return true


## Close any network session and return to offline authority.
func leave() -> void:
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = false
	is_host = true
	my_id = 1
	in_match = false
	match_ctl = null
	remote.clear()
	_counts.clear()
	_got_lobby = false
	peer_names.clear()
	_beacon = null
	reset_lobby(lobby.get("mode", "ffa"))


func is_client() -> bool:
	return active and not is_host


func reset_lobby(mode: String) -> void:
	var slots: Array = []
	for i in MAX_FIGHTERS:
		slots.append(_empty_slot())
	lobby = {"mode": mode, "slots": slots, "setup": false, "host": player_name}


func _empty_slot() -> Dictionary:
	return {"kind": "empty", "owner": 0, "device": "", "skin": {}, "preset": "", "name": "", "mastery": "", "team": 0, "ready": false, "profile": -1}


# ============================================================ discovery

func start_browsing() -> void:
	stop_browsing()
	_listen = PacketPeerUDP.new()
	var err := _listen.bind(BEACON_PORT)
	_browsing = err == OK
	if not _browsing:
		last_error = "LAN SCAN UNAVAILABLE (PORT %d BUSY) - USE DIRECT IP" % BEACON_PORT
	servers.clear()


func stop_browsing() -> void:
	if _listen:
		_listen.close()
	_listen = null
	_browsing = false


func _process(dt: float) -> void:
	# Host beacon
	if active and is_host and _beacon:
		_beacon_t -= dt
		if _beacon_t <= 0.0:
			_beacon_t = 1.0
			var info := {"g": "catclash", "v": VERSION, "name": player_name, "port": PORT,
				"players": count_fighters(), "max": MAX_FIGHTERS, "mode": ModeDefs.get_def(lobby.get("mode", "ffa")).name, "busy": in_match}
			_beacon.put_packet(JSON.stringify(info).to_utf8_buffer())
	# Browser
	if _browsing and _listen:
		var changed := false
		while _listen.get_available_packet_count() > 0:
			var pkt := _listen.get_packet()
			var ip := _listen.get_packet_ip()
			var d: Variant = JSON.parse_string(pkt.get_string_from_utf8())
			if typeof(d) == TYPE_DICTIONARY and d.get("g", "") == "catclash":
				d["ip"] = ip
				d["t"] = Time.get_ticks_msec()
				servers[ip] = d
				changed = true
		for k in servers.keys():
			if Time.get_ticks_msec() - int(servers[k].t) > 4000:
				servers.erase(k)
				changed = true
		if changed:
			servers_changed.emit()


# ================================================================ peers

func _on_peer_connected(id: int) -> void:
	if is_host:
		status.emit("PLAYER CONNECTED")


func _on_peer_disconnected(id: int) -> void:
	if not is_host:
		return
	peer_names.erase(id)
	for k in remote.keys():
		if str(k).begins_with("net:%d:" % id):
			remote.erase(k)
	if in_match and match_ctl:
		match_ctl.on_peer_left(id)
	for i in lobby.slots.size():
		if int(lobby.slots[i].owner) == id and lobby.slots[i].kind == "human":
			lobby.slots[i] = _empty_slot()
	_push()
	Router.show_toast("A PLAYER LEFT", Pal.UI_BAD)


func _on_connected() -> void:
	my_id = multiplayer.get_unique_id()
	status.emit("CONNECTED! JOINING LOBBY...")
	_rpc_hello.rpc_id(1, player_name, VERSION)


func _on_connection_failed() -> void:
	last_error = "CONNECTION FAILED"
	status.emit(last_error)
	leave()


func _on_server_disconnected() -> void:
	leave()
	Router.show_toast("HOST DISCONNECTED", Pal.UI_BAD)
	Router.goto("main_menu")


# ================================================================ lobby

func count_fighters() -> int:
	var n := 0
	for s in lobby.get("slots", []):
		if s.kind != "empty":
			n += 1
	return n


func mode_max() -> int:
	return mini(MAX_FIGHTERS, int(ModeDefs.get_def(lobby.get("mode", "ffa")).max))


## Send a lobby request to the authority (applied directly when we are it).
func request(action: String, d: Dictionary = {}) -> void:
	if is_host:
		_apply(my_id, action, d)
	else:
		_rpc_req.rpc_id(1, action, d)


func _find(owner: int, device: String) -> int:
	for i in lobby.slots.size():
		var s: Dictionary = lobby.slots[i]
		if s.kind == "human" and int(s.owner) == owner and s.device == device:
			return i
	return -1


func _apply(sender: int, action: String, d: Dictionary) -> void:
	var slots: Array = lobby.slots
	match action:
		"join":
			if _find(sender, d.get("device", "")) >= 0:
				return
			if count_fighters() >= mode_max():
				# Make room by replacing a CPU.
				for i in slots.size():
					if slots[i].kind == "bot":
						slots[i] = _empty_slot()
						break
			if count_fighters() >= mode_max():
				if sender == my_id:
					Router.show_toast("LOBBY FULL", Pal.UI_BAD)
				return
			for i in slots.size():
				if slots[i].kind == "empty":
					slots[i] = {"kind": "human", "owner": sender, "device": d.get("device", ""), "skin": d.get("skin", {}),
						"preset": d.get("preset", ""), "name": str(d.get("name", "CAT")).substr(0, 12), "mastery": d.get("mastery", ""),
						"team": i % 2, "ready": false, "profile": int(d.get("profile", -1))}
					break
		"leave":
			var i2 := _find(sender, d.get("device", ""))
			if i2 >= 0:
				slots[i2] = _empty_slot()
		"set":
			var i3 := _find(sender, d.get("device", ""))
			if i3 < 0:
				return
			for k in d.keys():
				if k in ["skin", "preset", "name", "mastery", "team", "ready", "profile"]:
					slots[i3][k] = d[k]
		"add_bot":
			if sender != 1 or count_fighters() >= mode_max():
				return
			for i in slots.size():
				if slots[i].kind == "empty":
					slots[i] = {"kind": "bot", "owner": 1, "device": "", "skin": d.get("skin", {}), "preset": d.get("preset", ""),
						"name": d.get("name", "CPU"), "mastery": "", "team": i % 2, "ready": true, "profile": -1}
					break
		"remove_bot":
			if sender != 1:
				return
			for i in range(slots.size() - 1, -1, -1):
				if slots[i].kind == "bot":
					slots[i] = _empty_slot()
					break
		"bot_set":
			if sender != 1:
				return
			var bi: int = d.get("slot", -1)
			if bi >= 0 and bi < slots.size() and slots[bi].kind == "bot":
				for k in d.keys():
					if k in ["skin", "preset", "name", "team"]:
						slots[bi][k] = d[k]
		"mode":
			if sender != 1:
				return
			lobby.mode = d.get("mode", "ffa")
			# Trim if the new mode allows fewer fighters.
			while count_fighters() > mode_max():
				var removed := false
				for i in range(slots.size() - 1, -1, -1):
					if slots[i].kind == "bot":
						slots[i] = _empty_slot()
						removed = true
						break
				if not removed:
					break
		"setup":
			if sender != 1:
				return
			lobby.setup = bool(d.get("on", false))
	_push()


func _push() -> void:
	lobby_changed.emit()
	if active and is_host:
		_rpc_lobby.rpc(lobby)


## Build the match session from the lobby (authority only).
func build_session(rules: Dictionary, arena: String) -> Dictionary:
	var players: Array = []
	for i in lobby.slots.size():
		var s: Dictionary = lobby.slots[i]
		if s.kind == "empty":
			continue
		var bot: bool = s.kind == "bot"
		players.append({"slot": i, "name": s.name if s.name != "" else ("CPU" if bot else "P%d" % (i + 1)),
			"owner": int(s.owner), "ldev": s.device, "device": s.device, "bot": bot, "bot_level": int(rules.get("bot_level", 1)),
			"team": int(s.team), "skin": s.skin, "preset": s.preset, "profile": int(s.profile)})
	return {"mode": lobby.mode, "arena": arena, "rules": rules, "players": players, "net": active}


func start_match(session: Dictionary) -> void:
	current_session = session
	in_match = true
	lobby.setup = false
	if active and is_host:
		_rpc_start.rpc(session)
	Router.session = session
	Router.tournament = {}
	Router.goto("match")


func return_to_lobby() -> void:
	in_match = false
	for s in lobby.slots:
		if s.kind == "human":
			s.ready = false
	lobby.setup = false
	if active and is_host:
		_rpc_to_lobby.rpc()
		_push()
	Router.goto("lobby")


# ========================================================== match traffic

## Host: inputs for a remote fighter device ("net:<peer>:<dev>").
func remote_frame(device: String) -> Dictionary:
	var r: Dictionary = remote.get(device, {})
	if r.is_empty():
		return {}
	var held := {}
	var just := {}
	var bits: int = r.get("bits", 0)
	var counts: Array = r.get("counts", [])
	var used: Array = r.get("used", [])
	for i in InputHub.ACTIONS.size():
		var a: String = InputHub.ACTIONS[i]
		held[a] = (bits >> i) & 1 == 1
		var c: int = counts[i] if i < counts.size() else 0
		var u: int = used[i] if i < used.size() else 0
		just[a] = c > u
	r["used"] = counts.duplicate()
	return {"move": r.get("move", Vector2.ZERO), "held": held, "just": just}


func _physics_process(_dt: float) -> void:
	if not (active and not is_host and in_match):
		return
	# Client: send local controller states for our fighters every frame.
	var pkt := {}
	for pc in current_session.get("players", []):
		if int(pc.get("owner", 0)) != my_id or pc.get("bot", false):
			continue
		var dev: String = pc.get("ldev", "")
		if dev == "":
			continue
		if not _counts.has(dev):
			_counts[dev] = []
			_counts[dev].resize(InputHub.ACTIONS.size())
			_counts[dev].fill(0)
		var bits := 0
		var c: Array = _counts[dev]
		for i in InputHub.ACTIONS.size():
			var a: String = InputHub.ACTIONS[i]
			if a == "pause":
				continue
			if InputHub.held(dev, a):
				bits |= 1 << i
			if InputHub.just_pressed(dev, a):
				c[i] = int(c[i]) + 1
		pkt[dev] = [InputHub.move_vector(dev), bits, c.duplicate()]
	if not pkt.is_empty():
		_rpc_input.rpc_id(1, pkt)


func send_snapshot(snap: Dictionary, events: Array) -> void:
	if not (active and is_host):
		return
	# Compressed so a 10-fighter snapshot stays close to a single packet.
	var raw := var_to_bytes(snap)
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	last_snapshot_bytes = packed.size()
	_rpc_snap.rpc(packed, raw.size())
	if not events.is_empty():
		_rpc_events.rpc(events)


func send_end(summary: Dictionary) -> void:
	if active and is_host:
		_rpc_end.rpc(summary)


# ==================================================================== RPCs

@rpc("any_peer", "reliable")
func _rpc_hello(pname: String, version: String) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if version != VERSION:
		_rpc_reject.rpc_id(id, "VERSION MISMATCH - UPDATE THE GAME")
		return
	peer_names[id] = pname
	_rpc_lobby.rpc_id(id, lobby)
	if in_match:
		_rpc_start.rpc_id(id, current_session)
	Router.show_toast("%s JOINED" % pname.substr(0, 12), Pal.UI_GOOD)


@rpc("authority", "reliable")
func _rpc_reject(reason: String) -> void:
	last_error = reason
	leave()
	Router.show_toast(reason, Pal.UI_BAD)
	Router.goto("main_menu")


@rpc("any_peer", "reliable")
func _rpc_req(action: String, d: Dictionary) -> void:
	if is_host:
		_apply(multiplayer.get_remote_sender_id(), action, d)


@rpc("authority", "reliable")
func _rpc_lobby(state: Dictionary) -> void:
	var first := not _got_lobby
	_got_lobby = true
	lobby = state
	lobby_changed.emit()
	if first and not in_match and Router.current_name in ["net", "main_menu", "title"]:
		Router.goto("lobby")


@rpc("authority", "reliable")
func _rpc_start(session: Dictionary) -> void:
	current_session = session
	in_match = true
	Router.session = session
	Router.tournament = {}
	Router.goto("match")


@rpc("authority", "reliable")
func _rpc_to_lobby() -> void:
	in_match = false
	match_ctl = null
	Router.goto("lobby")


@rpc("any_peer", "unreliable_ordered")
func _rpc_input(pkt: Dictionary) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	for dev in pkt.keys():
		var v: Array = pkt[dev]
		var key := "net:%d:%s" % [id, dev]
		var r: Dictionary = remote.get(key, {"used": []})
		r["move"] = v[0]
		r["bits"] = v[1]
		r["counts"] = v[2]
		if r.used.is_empty():
			r["used"] = (v[2] as Array).duplicate()
		remote[key] = r


@rpc("authority", "unreliable_ordered")
func _rpc_snap(packed: PackedByteArray, raw_size: int) -> void:
	if match_ctl and is_instance_valid(match_ctl):
		var snap: Variant = bytes_to_var(packed.decompress(raw_size, FileAccess.COMPRESSION_ZSTD))
		if typeof(snap) == TYPE_DICTIONARY:
			match_ctl.apply_snapshot(snap)


@rpc("authority", "reliable")
func _rpc_events(events: Array) -> void:
	if match_ctl and is_instance_valid(match_ctl):
		match_ctl.apply_events(events)


@rpc("authority", "reliable")
func _rpc_end(summary: Dictionary) -> void:
	if match_ctl and is_instance_valid(match_ctl):
		match_ctl.client_finish(summary)
	else:
		Router.last_result = summary
		Router.goto("results")
