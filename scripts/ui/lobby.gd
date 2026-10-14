extends Screen
## Lobby for up to 10 fighters, shared by local play and LAN games.
##
## Every device (keyboard half / gamepad) on every machine joins by pressing
## JUMP/confirm, then picks a cat and team and readies up with its own
## controls. The lobby state lives in Net (the host is the authority in LAN
## games; offline, this machine is). The host / local player 1 also:
##   HEAVY (+) / TAUNT (-)  add or remove CPU fighters
##   BLOCK / DODGE          change game mode
##   confirm when all ready continue to match setup

const COLS := 5
const ROWS := ["CAT", "TEAM", "READY"]

var local_ui: Dictionary = {}     # device -> {row, preset}
var presets: Array = []
var puppets: Array = []
var msg := ""
var msg_t := 0.0
var _rng := RandomNumberGenerator.new()


func _build() -> void:
	_rng.randomize()
	presets = SaveData.all_presets()
	var want: String = Router.session.get("mode", Net.lobby.get("mode", "ffa"))
	if Net.is_host and want != Net.lobby.get("mode", ""):
		if Net.active and want in ["training", "tournament"]:
			want = "ffa"
		Net.request("mode", {"mode": want})
	if Net.is_host:
		Net.request("setup", {"on": false})
	for i in Net.MAX_FIGHTERS:
		var p := CatPuppet.new()
		p.scale = Vector2(1.5, 1.5)
		var r := _slot_rect(i)
		p.position = Vector2(r.position.x + r.size.x * 0.5, r.position.y + 56)
		p.visible = false
		add_child(p)
		puppets.append(p)
	Net.lobby_changed.connect(_refresh)
	_refresh()


func _exit_tree() -> void:
	if Net.lobby_changed.is_connected(_refresh):
		Net.lobby_changed.disconnect(_refresh)


func _slots() -> Array:
	return Net.lobby.get("slots", [])


func _mode_id() -> String:
	return Net.lobby.get("mode", "ffa")


func _mdef() -> Dictionary:
	return ModeDefs.get_def(_mode_id())


func _slot_rect(i: int) -> Rect2:
	return Rect2(6 + (i % COLS) * 94, 30 + (i / COLS) * 100, 90, 96)


func _team_mode() -> bool:
	return _mdef().teams in ["forced", "optional"]


func _my_slot(device: String) -> int:
	var s := _slots()
	for i in s.size():
		if s[i].kind == "human" and int(s[i].owner) == Net.my_id and s[i].device == device:
			return i
	return -1


func _local_slots() -> Array:
	var out: Array = []
	var s := _slots()
	for i in s.size():
		if s[i].kind == "human" and int(s[i].owner) == Net.my_id:
			out.append(i)
	return out


func _humans() -> Array:
	return _slots().filter(func(s): return s.kind == "human")


func _count() -> int:
	return _slots().filter(func(s): return s.kind != "empty").size()


func _say(m: String) -> void:
	msg = m
	msg_t = 2.5


func _refresh() -> void:
	var s := _slots()
	for i in puppets.size():
		var p: CatPuppet = puppets[i]
		var sl: Dictionary = s[i] if i < s.size() else {}
		p.visible = not sl.is_empty() and sl.kind != "empty" and not (sl.skin as Dictionary).is_empty()
		if p.visible:
			p.skin = Sprites.full_skin(sl.skin)
			p.preview_facing = 1 if i % COLS < 3 else -1
			p.preview_state = "victory" if sl.ready else "idle"


func _preset_skin(idx: int) -> Dictionary:
	return Sprites.full_skin(presets[posmod(idx, presets.size())])


func _send_cat(device: String, idx: int) -> void:
	var p: Dictionary = presets[posmod(idx, presets.size())]
	Net.request("set", {"device": device, "skin": _preset_skin(idx), "preset": p.id, "mastery": SaveData.mastery_title(p.id)})


# ------------------------------------------------------------------ input

func _update(dt: float) -> void:
	msg_t -= dt
	for e in InputHub.menu_events:
		var d: String = e.device
		var si := _my_slot(d)
		match e.action:
			"alt":
				if Net.is_host:
					_add_bot()
				continue
			"alt2":
				if Net.is_host:
					Net.request("remove_bot")
				continue
			"tab_l", "tab_r":
				if Net.is_host:
					_cycle_mode(-1 if e.action == "tab_l" else 1)
				continue
		if si < 0:
			if e.action == "confirm":
				_join(d)
			elif e.action == "back" and _local_slots().is_empty():
				_leave_screen()
				return
			continue
		var ui: Dictionary = local_ui.get(d, {"row": 0, "preset": 0})
		local_ui[d] = ui
		var sl: Dictionary = _slots()[si]
		match e.action:
			"up", "down":
				if not sl.ready:
					ui.row = posmod(int(ui.row) + (-1 if e.action == "up" else 1), ROWS.size())
					AudioHub.play("ui_move", -10.0)
			"left", "right":
				if sl.ready:
					continue
				var dl := -1 if e.action == "left" else 1
				AudioHub.play("ui_move", -8.0)
				if int(ui.row) == 0:
					ui.preset = posmod(int(ui.preset) + dl, presets.size())
					_send_cat(d, ui.preset)
				elif int(ui.row) == 1 and _team_mode():
					Net.request("set", {"device": d, "team": posmod(int(sl.team) + dl, 2)})
			"confirm":
				if sl.ready and _all_ready() and Net.is_host:
					_continue()
					return
				if int(ui.row) == ROWS.size() - 1 or sl.ready:
					Net.request("set", {"device": d, "ready": true})
					AudioHub.play("ui_select")
					AudioHub.meow(1.0 + si * 0.05)
				else:
					ui.row = int(ui.row) + 1
					AudioHub.play("ui_move", -8.0)
			"start":
				if Net.is_host and _all_ready():
					_continue()
					return
			"back":
				AudioHub.play("ui_back")
				if sl.ready:
					Net.request("set", {"device": d, "ready": false})
				else:
					Net.request("leave", {"device": d})
					local_ui.erase(d)


func _join(device: String) -> void:
	var idx := _rng.randi_range(0, presets.size() - 1)
	local_ui[device] = {"row": 0, "preset": idx}
	var p: Dictionary = presets[idx]
	var prof := _local_slots().size()
	if prof >= SaveData.profiles().size():
		prof = -1
	var pname := Net.player_name if Net.active else ""
	if pname == "" or _local_slots().size() > 0:
		pname = SaveData.profile_name(prof) if prof >= 0 else "P%d" % (_count() + 1)
		if Net.active and _local_slots().size() > 0:
			pname = "%s %d" % [Net.player_name.substr(0, 9), _local_slots().size() + 1]
	Net.request("join", {"device": device, "skin": _preset_skin(idx), "preset": p.id, "name": pname,
		"mastery": SaveData.mastery_title(p.id), "profile": prof})
	AudioHub.play("ui_select")
	AudioHub.meow(1.2)


func _add_bot() -> void:
	if Net.active:
		_say("LAN GAMES ARE PLAYERS ONLY - NO CPUS")
		AudioHub.play("ui_error")
		return
	if _mode_id() == "training":
		_say("TRAINING USES DUMMIES")
		return
	if _count() >= Net.mode_max():
		_say("NO FREE SLOTS")
		AudioHub.play("ui_error")
		return
	var idx := _rng.randi_range(0, CosmeticDefs.ROSTER.size() - 1)
	var r: Dictionary = CosmeticDefs.ROSTER[idx]
	Net.request("add_bot", {"skin": Sprites.full_skin(r), "preset": r.id, "name": str(r.name).substr(0, 8)})
	AudioHub.play("ui_select", -4.0)


func _cycle_mode(d: int) -> void:
	var ids: Array = ModeDefs.ORDER.duplicate()
	if Net.active:
		ids.erase("training")
		ids.erase("tournament")
	var cur := ids.find(_mode_id())
	Net.request("mode", {"mode": ids[posmod(cur + d, ids.size())]})
	AudioHub.play("ui_move", -6.0)


func _leave_screen() -> void:
	AudioHub.play("ui_back")
	if Net.active:
		Net.leave()
		Router.goto("net")
	elif _mode_id() in ["training", "tournament"]:
		Router.goto("main_menu")
	else:
		Router.goto("mode_select")


func _all_ready() -> bool:
	var hum := _humans()
	if hum.is_empty():
		return false
	for s in hum:
		if not s.ready:
			return false
	return _valid_setup() == ""


func _valid_setup() -> String:
	var n := _count()
	var md := _mdef()
	if n < int(md.min):
		if Net.active:
			return "NEED %d+ PLAYERS - INVITE MORE DEVICES" % int(md.min)
		return "NEED %d+ FIGHTERS (HEAVY ADDS A CPU)" % int(md.min)
	if n > Net.mode_max():
		return "MAX %d FIGHTERS IN THIS MODE" % Net.mode_max()
	if md.teams == "forced":
		var t0 := _slots().filter(func(s): return s.kind != "empty" and int(s.team) == 0).size()
		var t1 := _slots().filter(func(s): return s.kind != "empty" and int(s.team) == 1).size()
		if t0 == 0 or t1 == 0:
			return "BOTH TEAMS NEED A CAT"
	return ""


func _continue() -> void:
	if not Net.is_host:
		return
	Router.session = Net.build_session(ModeDefs.default_rules(_mode_id()), "random")
	Router.session["mode"] = _mode_id()
	Net.request("setup", {"on": true})
	AudioHub.play("go", -4.0)
	Router.goto("setup")


func _on_mouse(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	var p := get_local_mouse_position()
	if Rect2(6, 234, 74, 14).has_point(p):
		if _local_slots().is_empty():
			_join("kb0")
		elif Net.is_host:
			_add_bot()
	elif Rect2(84, 234, 74, 14).has_point(p) and Net.is_host:
		Net.request("remove_bot")
	elif Rect2(162, 234, 156, 14).has_point(p) and Net.is_host:
		_cycle_mode(1)
	elif Rect2(322, 234, 74, 14).has_point(p):
		_leave_screen()
	elif Rect2(400, 234, 74, 14).has_point(p) and Net.is_host:
		if not _all_ready():
			for i in _local_slots():
				Net.request("set", {"device": _slots()[i].device, "ready": true})
		if _all_ready():
			_continue()
		else:
			_say(_valid_setup())


# ------------------------------------------------------------------ draw

func _paint() -> void:
	var md := _mdef()
	var title = md.name
	if Net.active:
		title += " · LAN" + (" HOST" if Net.is_host else "")
	PixelFont.draw_text(self, Vector2(240, 6), title, Pal.UI_HILITE, 2, 1)
	PixelFont.draw_text(self, Vector2(474, 20), "%d/%d FIGHTERS" % [_count(), Net.mode_max()], Pal.UI_DIM, 1, 2)
	if Net.active:
		PixelFont.draw_text(self, Vector2(6, 20), "%d DEVICE%s CONNECTED" % [Net.peer_names.size() if Net.is_host else 0, "S" if Net.peer_names.size() != 1 else ""] if Net.is_host else "HOST: " + str(Net.lobby.get("host", "")), Pal.UI_DIM)
	var s := _slots()
	for i in s.size():
		_draw_slot(i, s[i])
	# Bottom buttons
	var labels := ["+ CPU" if not _local_slots().is_empty() else "JOIN", "- CPU", "◄ MODE ►", "BACK", "START"]
	if Net.active:
		labels[0] = "JOIN" if _local_slots().is_empty() else "PLAYERS ONLY"
		labels[1] = "NO CPUS"
	var rects := [Rect2(6, 234, 74, 14), Rect2(84, 234, 74, 14), Rect2(162, 234, 156, 14), Rect2(322, 234, 74, 14), Rect2(400, 234, 74, 14)]
	for k in 5:
		var host_only := k in [1, 2, 4] or (k == 0 and not _local_slots().is_empty())
		var enabled := Net.is_host or not host_only
		if Net.active and (k == 1 or (k == 0 and not _local_slots().is_empty())):
			enabled = false
		var fill := Pal.UI_PANEL2
		if k == 4 and _all_ready() and Net.is_host:
			fill = Color("2a6a3a")
		UI.panel(self, rects[k], fill if enabled else Pal.UI_PANEL, Pal.UI_EDGE, false)
		PixelFont.draw_text(self, rects[k].position + Vector2(rects[k].size.x * 0.5, 3), labels[k], Pal.UI_TEXT if enabled else Pal.UI_LOCK, 1, 1)
	var status := _valid_setup()
	if msg_t > 0.0:
		status = msg
	elif not Net.is_host and Net.lobby.get("setup", false):
		status = "THE HOST IS SETTING UP THE MATCH..."
	elif _local_slots().is_empty():
		status = "PRESS JUMP / A ON ANY KEYBOARD HALF OR PAD TO JOIN"
	elif _all_ready():
		status = "ALL READY! CONFIRM / START TO CONTINUE" if Net.is_host else "ALL READY! WAITING FOR THE HOST..."
	elif status == "":
		status = "READY UP: CONFIRM ON READY"
	PixelFont.draw_text(self, Vector2(240, 250), status, Pal.UI_HILITE if _all_ready() else Pal.UI_TEXT, 1, 1)
	var hint := "JOIN: JUMP/A · LEAVE: THROW/B"
	if Net.active:
		hint += " · PLAYERS ONLY" + (" · MODE: BLOCK/DODGE" if Net.is_host else "")
	elif Net.is_host:
		hint += " · CPU +/-: HEAVY/TAUNT · MODE: BLOCK/DODGE"
	UI.hints(self, hint)


func _draw_slot(i: int, sl: Dictionary) -> void:
	var r := _slot_rect(i)
	var col := Pal.player_color(i)
	if sl.kind == "empty":
		UI.panel(self, r, Color(Pal.UI_PANEL, 0.55), Pal.UI_EDGE.darkened(0.3), false)
		var avail := i < Net.mode_max()
		PixelFont.draw_text(self, r.position + Vector2(r.size.x * 0.5, 34), "P%d" % (i + 1), Pal.UI_DIM if avail else Pal.UI_LOCK, 2, 1)
		if avail:
			PixelFont.draw_text(self, r.position + Vector2(r.size.x * 0.5, 58), "OPEN" if int(t * 2.0 + i) % 2 == 0 else "PRESS JUMP", Pal.UI_DIM, 1, 1)
		return
	var team_col := Pal.team_color(int(sl.team))
	var head_col: Color = team_col if _team_mode() else col
	var mine: bool = sl.kind == "human" and int(sl.owner) == Net.my_id
	UI.panel(self, r, Pal.UI_PANEL if not mine else Pal.UI_PANEL2, head_col, false)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 11)), head_col.darkened(0.25))
	var who := "%s%d" % [Pal.player_shape(i), i + 1]
	var tag := ""
	if sl.kind == "bot":
		tag = "CPU " + ModeDefs.rule_label("bot_level", int(Settings.get_value("bot_difficulty")))
	elif mine:
		tag = InputHub.short_label(sl.device)
	else:
		tag = "LAN"
	PixelFont.draw_text(self, r.position + Vector2(3, 2), who, Pal.UI_TEXT)
	PixelFont.draw_text(self, r.position + Vector2(r.size.x - 3, 2), tag, Pal.UI_TEXT, 1, 2)
	PixelFont.draw_text(self, r.position + Vector2(r.size.x * 0.5, 13), str(sl.name).substr(0, 14), col, 1, 1)
	draw_rect(Rect2(r.position.x + 6, r.position.y + 56, r.size.x - 12, 1), Color(0, 0, 0, 0.35))
	var ui: Dictionary = local_ui.get(sl.device, {"row": -1}) if mine else {"row": -1}
	var cat_name := str(Sprites.full_skin(sl.skin).get("name", "?"))
	var vals := [cat_name.substr(0, 10), Pal.team_name(int(sl.team)) if _team_mode() else "-", "READY!" if sl.ready else "..."]
	for k in ROWS.size():
		var y := r.position.y + 60 + k * 12
		var sel: bool = mine and int(ui.row) == k and not sl.ready
		if sel:
			draw_rect(Rect2(r.position.x + 2, y - 1, r.size.x - 4, 11), Color(Pal.UI_HILITE, 0.2))
		var v: String = vals[k]
		if sel and k < 2:
			v = "◄" + v + "►"
		var c := Pal.UI_TEXT
		if k == 2:
			c = Pal.UI_GOOD if sl.ready else Pal.UI_DIM
		if k == 1 and _team_mode():
			c = team_col
		PixelFont.draw_text(self, Vector2(r.position.x + r.size.x * 0.5, y), v, Pal.UI_HILITE if sel else c, 1, 1)
