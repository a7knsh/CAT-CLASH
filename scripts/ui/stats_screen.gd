extends Screen
## Profiles & statistics, plus save-data management (backup, restore, reset).

var pidx := 0
var confirm_reset := 0
var msg := ""
var msg_t := 0.0
var naming := false
var name_buf := ""


func _build() -> void:
	menu.pos = Vector2(16, 44)
	menu.width = 168
	menu.line_h = 14
	menu.max_visible = 13
	_rebuild()


func _rebuild() -> void:
	var keep := menu.index
	menu.clear()
	menu.add("profile", "PROFILE", "choice", SaveData.profile_name(pidx))
	menu.add("new", "NEW PROFILE")
	menu.add("rename", "RENAME PROFILE")
	menu.add("delete", "DELETE PROFILE", "button", "", {"disabled": SaveData.profiles().size() <= 1, "color": Pal.UI_BAD})
	menu.add("", "— SAVE DATA —", "label")
	menu.add("backup", "EXPORT BACKUP", "button", "", {"hint": "Writes a copy of your save to the backups folder."})
	menu.add("restore", "RESTORE LATEST BACKUP", "button", "", {"hint": "Replaces current progress with the newest backup."})
	menu.add("folder", "OPEN SAVE FOLDER")
	menu.add("reset", ["RESET ALL PROGRESS", "ARE YOU SURE?", "LAST CHANCE: CONFIRM"][confirm_reset], "button", "", {"color": Pal.UI_BAD, "hint": "Deletes profiles, stats, unlocks and custom cats."})
	menu.add("back", "BACK")
	menu.index = clampi(keep, 0, menu.items.size() - 1)


func _say(m: String) -> void:
	msg = m
	msg_t = 3.0


func _update(dt: float) -> void:
	msg_t -= dt
	if naming:
		return
	super._update(dt)


func _input(ev: InputEvent) -> void:
	if not naming:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_BACKSPACE:
			name_buf = name_buf.substr(0, maxi(0, name_buf.length() - 1))
		elif ev.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			naming = false
			if name_buf.strip_edges() != "":
				SaveData.rename_profile(pidx, name_buf.strip_edges().to_upper())
			_rebuild()
		elif ev.keycode == KEY_ESCAPE:
			naming = false
		elif ev.unicode >= 32 and ev.unicode < 127 and name_buf.length() < 12:
			name_buf += char(ev.unicode).to_upper()
		get_viewport().set_input_as_handled()
		InputHub.consume_menu()
	elif ev is InputEventJoypadButton and ev.pressed:
		# Pads: confirm keeps a generated name.
		naming = false
		if name_buf.strip_edges() != "":
			SaveData.rename_profile(pidx, name_buf.strip_edges().to_upper())
		_rebuild()


func _on_menu(r: Dictionary) -> void:
	match r.action:
		"back":
			Router.goto("main_menu")
		"change":
			if r.id == "profile":
				pidx = posmod(pidx + r.delta, SaveData.profiles().size())
				_rebuild()
		"activate":
			if r.id != "reset":
				confirm_reset = 0
			match r.id:
				"new":
					pidx = SaveData.add_profile("PLAYER %d" % (SaveData.profiles().size() + 1))
					_say("PROFILE CREATED")
				"rename":
					naming = true
					name_buf = ""
					if r.device.begins_with("pad"):
						name_buf = ["TABBY", "FLUFF", "ZOOMIES", "BEANS", "MITTENS", "SOCKS", "PURRITO"][randi() % 7]
				"delete":
					SaveData.delete_profile(pidx)
					pidx = 0
					_say("PROFILE DELETED")
				"backup":
					var p := SaveData.export_backup()
					_say("SAVED TO " + p.get_file() if p != "" else "BACKUP FAILED")
				"restore":
					var list := SaveData.list_backups()
					if list.is_empty():
						_say("NO BACKUPS FOUND")
					elif SaveData.import_backup(list[0]):
						_say("RESTORED " + str(list[0]).get_file())
					else:
						_say("BACKUP UNREADABLE")
				"folder":
					OS.shell_open(ProjectSettings.globalize_path("user://"))
				"reset":
					confirm_reset += 1
					if confirm_reset >= 3:
						SaveData.reset_all()
						confirm_reset = 0
						pidx = 0
						_say("ALL PROGRESS RESET")
				"back":
					Router.goto("main_menu")
			_rebuild()


func _paint() -> void:
	UI.title(self, "PROFILES & STATS", 6)
	menu.draw(self, t)
	UI.panel(self, Rect2(196, 40, 270, 200))
	var prof: Dictionary = SaveData.profiles()[pidx]
	var st: Dictionary = prof.stats
	PixelFont.draw_text(self, Vector2(206, 46), str(prof.name), Pal.UI_HILITE, 2)
	var m := int(st.get("matches", 0))
	var w := int(st.get("wins", 0))
	var rows := [
		["MATCHES", str(m)], ["WINS / LOSSES", "%d / %d" % [w, int(st.get("losses", 0))]],
		["WIN RATE", "%d%%" % (0 if m == 0 else int(100.0 * w / m))],
		["KOS", str(int(st.get("kos", 0)))], ["FALLS", str(int(st.get("falls", 0)))],
		["RING-OUTS", str(int(st.get("ringouts", 0)))],
		["DAMAGE DEALT", str(int(st.get("damage_dealt", 0)))], ["DAMAGE TAKEN", str(int(st.get("damage_taken", 0)))],
		["PARRIES", str(int(st.get("parries", 0)))], ["THROWS THAT HIT", str(int(st.get("throw_hits", 0)))],
		["BEST COMBO", str(int(st.get("best_combo", 0)))], ["PLAY TIME", UI.fmt_time(float(st.get("playtime", 0)))],
	]
	for i in rows.size():
		var y := 68 + i * 11
		PixelFont.draw_text(self, Vector2(206, y), rows[i][0], Pal.UI_DIM)
		PixelFont.draw_text(self, Vector2(356, y), rows[i][1], Pal.UI_TEXT, 1, 2)
	var fav := SaveData.favorite_weapon(pidx)
	PixelFont.draw_text(self, Vector2(372, 68), "FAVOURITE", Pal.UI_DIM)
	if fav != "" and WeaponDefs.ALL.has(fav):
		UI.weapon(self, fav, Vector2(410, 90), 1.5)
		PixelFont.draw_text(self, Vector2(410, 104), WeaponDefs.ALL[fav].name, Pal.UI_TEXT, 1, 1)
	elif fav == "paws":
		PixelFont.draw_text(self, Vector2(410, 86), "BARE PAWS", Pal.UI_TEXT, 1, 1)
	else:
		PixelFont.draw_text(self, Vector2(410, 86), "-", Pal.UI_DIM, 1, 1)
	var modes: Dictionary = st.get("modes", {})
	var best_m := ""
	var bm := 0
	for k in modes.keys():
		if int(modes[k]) > bm:
			bm = int(modes[k])
			best_m = k
	PixelFont.draw_text(self, Vector2(372, 120), "TOP MODE", Pal.UI_DIM)
	PixelFont.draw_text(self, Vector2(372, 130), ModeDefs.get_def(best_m).short if best_m != "" else "-", Pal.UI_TEXT)
	PixelFont.draw_text(self, Vector2(372, 150), "GLOBAL", Pal.UI_DIM)
	PixelFont.draw_text(self, Vector2(372, 160), "%d TROPHIES" % SaveData.data.achievements.size(), Pal.UI_TEXT)
	PixelFont.draw_text(self, Vector2(372, 170), "%d YARN" % int(SaveData.data.yarn), Pal.UI_ACCENT)
	if naming:
		draw_rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, 0.6))
		UI.panel(self, Rect2(130, 110, 220, 40))
		PixelFont.draw_text(self, Vector2(240, 116), "TYPE A NAME, ENTER TO SAVE", Pal.UI_DIM, 1, 1)
		PixelFont.draw_text(self, Vector2(240, 130), name_buf + ("_" if int(t * 3.0) % 2 == 0 else ""), Pal.UI_HILITE, 2, 1)
	if msg_t > 0.0:
		PixelFont.draw_text(self, Vector2(240, 246), msg, Pal.UI_HILITE, 1, 1)
	UI.hints(self, "SAVES ARE STORED LOCALLY · BACKUPS IN THE SAVE FOLDER")
