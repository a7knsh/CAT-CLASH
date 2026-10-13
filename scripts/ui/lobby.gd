extends Screen
## Local multiplayer lobby. Any keyboard half or gamepad joins by pressing
## its JUMP/confirm button; each player then picks a cat, team and profile
## with their own device and readies up. HEAVY adds a CPU, TAUNT removes one.

const MAX_SLOTS := 4

var mode_id := "ffa"
var mdef: Dictionary
var slots: Array = []
var puppets: Array = []
var msg := ""
var msg_t := 0.0
var presets: Array = []
var _rng := RandomNumberGenerator.new()


func _build() -> void:
	_rng.randomize()
	mode_id = Router.session.get("mode", "ffa")
	mdef = ModeDefs.get_def(mode_id)
	presets = SaveData.all_presets()
	for i in MAX_SLOTS:
		slots.append({"kind": "empty", "device": "", "preset": 0, "team": i % 2, "profile": -1, "ready": false, "row": 0})
		var p := CatPuppet.new()
		p.scale = Vector2(2, 2)
		p.position = Vector2(_slot_rect(i).position.x + _slot_rect(i).size.x * 0.5, 128)
		p.visible = false
		add_child(p)
		puppets.append(p)
	# Restore the previous lobby (same devices) for quick rematches.
	var last: Dictionary = SaveData.data.get("last_setup", {})
	var prev: Array = Router.session.get("players", []) if Router.session.has("players") else []
	if prev.is_empty() and last.get("mode", "") == mode_id:
		prev = last.get("players", [])
	for pc in prev:
		var s: int = pc.get("slot", 0)
		if s >= MAX_SLOTS:
			continue
		if pc.get("bot", false):
			slots[s] = {"kind": "bot", "device": "", "preset": _preset_index(pc.get("preset", "")), "team": pc.get("team", s % 2), "profile": -1, "ready": true, "row": 0}
		elif InputHub.is_connected_device(pc.get("device", "")):
			slots[s] = {"kind": "human", "device": pc.device, "preset": _preset_index(pc.get("preset", "")), "team": pc.get("team", s % 2), "profile": pc.get("profile", -1), "ready": false, "row": 0}
	_refresh()


func _preset_index(id: String) -> int:
	for i in presets.size():
		if presets[i].id == id:
			return i
	return _rng.randi_range(0, presets.size() - 1)


func _slot_rect(i: int) -> Rect2:
	return Rect2(10 + i * 117, 40, 109, 180)


func _team_mode() -> bool:
	return mdef.teams in ["forced", "optional"]


func _max_players() -> int:
	return mini(MAX_SLOTS, int(mdef.max)) if mode_id != "tournament" else MAX_SLOTS


func _count() -> int:
	return slots.filter(func(s): return s.kind != "empty").size()


func _humans() -> Array:
	return slots.filter(func(s): return s.kind == "human")


func _slot_of(device: String) -> int:
	for i in slots.size():
		if slots[i].kind == "human" and slots[i].device == device:
			return i
	return -1


func _say(m: String) -> void:
	msg = m
	msg_t = 2.5


func _refresh() -> void:
	for i in MAX_SLOTS:
		var s: Dictionary = slots[i]
		var p: CatPuppet = puppets[i]
		p.visible = s.kind != "empty"
		if p.visible:
			p.skin = Sprites.full_skin(presets[s.preset % presets.size()])
			p.preview_facing = 1 if i < 2 else -1
			p.preview_state = "victory" if s.ready else "idle"


func _update(dt: float) -> void:
	msg_t -= dt
	for e in InputHub.menu_events:
		var d: String = e.device
		var si := _slot_of(d)
		if si < 0:
			match e.action:
				"confirm":
					_join(d)
				"back":
					if _humans().is_empty():
						AudioHub.play("ui_back")
						Router.goto("main_menu" if mode_id in ["training", "tournament"] else "mode_select")
						return
				"alt":
					if not _humans().is_empty():
						_add_bot()
				"alt2":
					_remove_bot()
			continue
		var s: Dictionary = slots[si]
		match e.action:
			"up":
				if not s.ready:
					s.row = posmod(s.row - 1, 4)
					AudioHub.play("ui_move", -10.0)
			"down":
				if not s.ready:
					s.row = posmod(s.row + 1, 4)
					AudioHub.play("ui_move", -10.0)
			"left", "right":
				if not s.ready:
					_change(si, -1 if e.action == "left" else 1)
			"confirm":
				if _all_ready() and s.ready:
					_continue()
					return
				if s.row == 3 or s.ready:
					s.ready = true
					AudioHub.play("ui_select")
					AudioHub.meow(1.0 + si * 0.1)
					if _all_ready():
						AudioHub.play("powerup", -4.0)
				else:
					s.row += 1
					AudioHub.play("ui_move", -8.0)
			"back":
				if s.ready:
					s.ready = false
					AudioHub.play("ui_back")
				else:
					slots[si] = {"kind": "empty", "device": "", "preset": 0, "team": si % 2, "profile": -1, "ready": false, "row": 0}
					AudioHub.play("ui_back")
			"alt":
				_add_bot()
			"alt2":
				_remove_bot()
			"start":
				if _all_ready():
					_continue()
					return
	_refresh()


func _join(device: String) -> void:
	if _count() >= _max_players():
		# Replace a bot if the lobby is full of CPUs.
		for i in slots.size():
			if slots[i].kind == "bot":
				slots[i] = {"kind": "empty"}
				break
		if _count() >= _max_players():
			_say("LOBBY FULL")
			AudioHub.play("ui_error")
			return
	for i in slots.size():
		if slots[i].kind == "empty":
			var prof := -1
			var hum := _humans().size()
			if hum < SaveData.profiles().size():
				prof = hum
			slots[i] = {"kind": "human", "device": device, "preset": _rng.randi_range(0, presets.size() - 1), "team": i % 2, "profile": prof, "ready": false, "row": 0}
			AudioHub.play("ui_select")
			AudioHub.meow(1.2)
			return


func _add_bot() -> void:
	if mode_id in ["training"]:
		_say("TRAINING USES DUMMIES")
		return
	if _count() >= _max_players():
		_say("NO FREE SLOTS")
		AudioHub.play("ui_error")
		return
	for i in slots.size():
		if slots[i].kind == "empty":
			slots[i] = {"kind": "bot", "device": "", "preset": _rng.randi_range(0, presets.size() - 1), "team": i % 2, "profile": -1, "ready": true, "row": 0}
			AudioHub.play("ui_select", -4.0)
			return


func _remove_bot() -> void:
	for i in range(slots.size() - 1, -1, -1):
		if slots[i].kind == "bot":
			slots[i] = {"kind": "empty", "device": "", "preset": 0, "team": i % 2, "profile": -1, "ready": false, "row": 0}
			AudioHub.play("ui_back", -4.0)
			return


func _change(si: int, d: int) -> void:
	var s: Dictionary = slots[si]
	AudioHub.play("ui_move", -8.0)
	match int(s.row):
		0:
			s.preset = posmod(int(s.preset) + d, presets.size())
		1:
			if _team_mode():
				s.team = posmod(int(s.team) + d, 2)
		2:
			var n := SaveData.profiles().size()
			s.profile = posmod(int(s.profile) + 1 + d, n + 1) - 1


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
	var need := int(mdef.min)
	if n < need:
		return "NEED %d+ PLAYERS (HEAVY ADDS A CPU)" % need
	if n > int(mdef.max) and mode_id != "tournament":
		return "MAX %d PLAYERS" % int(mdef.max)
	if mdef.teams == "forced":
		var t0 := slots.filter(func(s): return s.kind != "empty" and int(s.team) == 0).size()
		var t1 := slots.filter(func(s): return s.kind != "empty" and int(s.team) == 1).size()
		if t0 == 0 or t1 == 0:
			return "BOTH TEAMS NEED A CAT"
	return ""


func _continue() -> void:
	var players: Array = []
	for i in slots.size():
		var s: Dictionary = slots[i]
		if s.kind == "empty":
			continue
		var bot: bool = s.kind == "bot"
		var cfg := Sessions.player_cfg(i, s.device, presets[s.preset % presets.size()].id, int(s.team), int(s.profile), bot, int(Settings.get_value("bot_difficulty")))
		players.append(cfg)
	Router.session["players"] = players
	Router.session["mode"] = mode_id
	AudioHub.play("go", -4.0)
	Router.goto("setup")


func _on_mouse(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	var p := get_local_mouse_position()
	if Rect2(10, 230, 90, 14).has_point(p):
		if _humans().is_empty():
			_join("kb0")
		else:
			_add_bot()
	elif Rect2(106, 230, 90, 14).has_point(p):
		_remove_bot()
	elif Rect2(380, 230, 90, 14).has_point(p):
		if _all_ready():
			_continue()
		else:
			for s in _humans():
				s.ready = true
			if _all_ready():
				_continue()
			else:
				_say(_valid_setup())
	elif Rect2(284, 230, 90, 14).has_point(p):
		Router.goto("main_menu" if mode_id in ["training", "tournament"] else "mode_select")


func _paint() -> void:
	UI.title(self, mdef.name + " · JOIN IN!", 6)
	for i in MAX_SLOTS:
		_draw_slot(i)
	# Bottom buttons (mouse friendly) and status
	var labels := ["+ CPU", "- CPU", "BACK", "START"]
	var xs := [10, 106, 284, 380]
	if _humans().is_empty():
		labels[0] = "JOIN (KB)"
	for k in 4:
		var r := Rect2(xs[k], 230, 90, 14)
		UI.panel(self, r, Pal.UI_PANEL2 if not (k == 3 and _all_ready()) else Color("2a6a3a"), Pal.UI_EDGE, false)
		PixelFont.draw_text(self, r.position + Vector2(45, 3), labels[k], Pal.UI_TEXT, 1, 1)
	var status := _valid_setup()
	if msg_t > 0.0:
		status = msg
	elif _all_ready():
		status = "ALL READY! PRESS CONFIRM/START TO CONTINUE"
	elif _humans().is_empty():
		status = "PRESS JUMP / A ON ANY KEYBOARD HALF OR PAD TO JOIN"
	elif status == "":
		status = "READY UP: CONFIRM ON ★READY"
	PixelFont.draw_text(self, Vector2(240, 248), status, Pal.UI_HILITE if _all_ready() else Pal.UI_TEXT, 1, 1)
	UI.hints(self, "JOIN: JUMP/A · CPU: HEAVY(+) TAUNT(-) · LEAVE: THROW/B")


func _draw_slot(i: int) -> void:
	var r := _slot_rect(i)
	var s: Dictionary = slots[i]
	var col := Pal.player_color(i)
	if s.kind == "empty":
		UI.panel(self, r, Color(Pal.UI_PANEL, 0.6), Pal.UI_EDGE.darkened(0.3))
		var avail := i < _max_players()
		PixelFont.draw_text(self, r.position + Vector2(r.size.x * 0.5, 70), "P%d" % (i + 1), Pal.UI_DIM if avail else Pal.UI_LOCK, 2, 1)
		if avail:
			var blink := int(t * 2.0 + i) % 2 == 0
			PixelFont.draw_text(self, r.position + Vector2(r.size.x * 0.5, 96), "PRESS JUMP" if blink else "TO JOIN", Pal.UI_DIM, 1, 1)
		else:
			PixelFont.draw_text(self, r.position + Vector2(r.size.x * 0.5, 96), "N/A", Pal.UI_LOCK, 1, 1)
		return
	var team_col := Pal.team_color(int(s.team))
	var head_col: Color = team_col if _team_mode() else col
	UI.panel(self, r, Pal.UI_PANEL, head_col)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 13)), head_col.darkened(0.25))
	var who := "P%d %s" % [i + 1, Pal.player_shape(i)]
	if s.kind == "bot":
		who = "CPU %s" % Pal.player_shape(i)
	PixelFont.draw_text(self, r.position + Vector2(4, 3), who, Pal.UI_TEXT)
	PixelFont.draw_text(self, r.position + Vector2(r.size.x - 4, 3), InputHub.short_label(s.device) if s.kind == "human" else ModeDefs.rule_label("bot_level", int(Settings.get_value("bot_difficulty"))), Pal.UI_TEXT, 1, 2)
	# Stage
	draw_rect(Rect2(r.position.x + 8, 128, r.size.x - 16, 2), Color(0, 0, 0, 0.35))
	var pr: Dictionary = presets[int(s.preset) % presets.size()]
	var rows := ["CAT", "TEAM", "PROFILE", "★READY"]
	var vals := [str(pr.name), Pal.team_name(int(s.team)) if _team_mode() else "-", SaveData.profile_name(int(s.profile)), "READY!" if s.ready else ""]
	for k in 4:
		var y := r.position.y + 100 + k * 18
		var sel: bool = s.kind == "human" and int(s.row) == k and not s.ready
		if sel:
			draw_rect(Rect2(r.position.x + 3, y - 2, r.size.x - 6, 16), Color(Pal.UI_HILITE, 0.18))
		PixelFont.draw_text(self, Vector2(r.position.x + 6, y), rows[k], Pal.UI_HILITE if sel else Pal.UI_DIM)
		var v: String = vals[k]
		if v != "":
			if sel and k < 3:
				v = "◄" + v + "►"
			PixelFont.draw_text(self, Vector2(r.position.x + r.size.x - 6, y + 8 if k < 3 else y), v, Pal.UI_TEXT if k < 3 else Pal.UI_GOOD, 1, 2)
	if s.ready:
		PixelFont.draw_text(self, r.position + Vector2(r.size.x * 0.5, 18), "READY!", Pal.UI_GOOD, 2, 1)
	PixelFont.draw_text(self, r.position + Vector2(r.size.x * 0.5, 92), SaveData.mastery_title(pr.id), Pal.UI_DIM, 1, 1)
