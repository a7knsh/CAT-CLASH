class_name PauseMenu
extends CanvasLayer
## Pause menu (any player's START/ESC). Also handles controller-disconnect
## prompts and Training-mode tools (dummy behaviour, weapon spawner, reset).

var ctl: Node = null
var canvas: Control
var open := false
var menu := MenuList.new()
var t := 0.0
var paused_by := ""
var confirm_quit := false
var spawn_idx := 0


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	canvas = Control.new()
	canvas.size = Vector2(480, 270)
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.draw.connect(_draw_menu)
	canvas.gui_input.connect(_on_gui)
	canvas.visible = false
	add_child(canvas)
	menu.pos = Vector2(150, 70)
	menu.width = 180


func open_menu(device: String) -> void:
	if open or ctl.finished:
		return
	open = true
	paused_by = device
	confirm_quit = false
	# LAN games keep running for everyone else while you're in the menu.
	if not _net():
		get_tree().paused = true
	canvas.visible = true
	_build()
	AudioHub.play("ui_select", -4.0)


func _net() -> bool:
	return Net.active and ctl.session.get("net", false)


func close_menu() -> void:
	open = false
	canvas.visible = false
	get_tree().paused = false
	InputHub.consume_menu()


func _build() -> void:
	var keep := menu.index
	menu.clear()
	if ctl.disconnect_msg != "":
		menu.add("cpu", "CONTINUE WITH CPU")
		menu.add("resume", "RESUME (RECONNECTED)")
	else:
		menu.add("resume", "RESUME")
	if not _net() or Net.is_host:
		menu.add("restart", "RESTART MATCH" if not _net() else "RESTART MATCH (EVERYONE)")
	if _net() and Net.is_host:
		menu.add("to_lobby", "END MATCH: BACK TO LOBBY")
	if ctl.mode_id == "training":
		menu.add("dummy", "DUMMY", "choice", ModeDefs.rule_label("dummy_ai", ctl.rules.get("dummy_ai", "stand")))
		var ids: Array = WeaponDefs.ALL.keys()
		menu.add("spawn", "WEAPON", "choice", WeaponDefs.ALL[ids[spawn_idx % ids.size()]].name)
		menu.add("spawn_go", "SPAWN THAT WEAPON")
		menu.add("reset", "RESET POSITIONS")
	menu.add("sfx", "SFX VOLUME", "choice", "%d%%" % int(round(float(Settings.get_value("sfx_volume")) * 100)))
	menu.add("music", "MUSIC VOLUME", "choice", "%d%%" % int(round(float(Settings.get_value("music_volume")) * 100)))
	menu.add("shake", "SCREEN SHAKE", "choice", "%d%%" % int(round(Settings.shake_amount() * 100)))
	var quit_label := "QUIT TO MENU"
	if _net():
		quit_label = "LEAVE LAN GAME" if not Net.is_host else "CLOSE LAN SESSION"
	menu.add("quit", quit_label if not confirm_quit else "REALLY? PRESS AGAIN", "button", "", {"color": Pal.UI_BAD})
	menu.index = clampi(keep, 0, menu.items.size() - 1)


func _process(dt: float) -> void:
	t += dt
	if not open:
		if ctl and not ctl.finished and ctl.phase != "match_end":
			for e in InputHub.menu_events:
				if e.action == "start" and _is_player_device(e.device):
					open_menu(e.device)
					return
		return
	canvas.queue_redraw()
	for e in InputHub.menu_events:
		if e.action == "start":
			if ctl.disconnect_msg == "":
				close_menu()
				return
	_handle(menu.handle())


func _is_player_device(d: String) -> bool:
	for f in ctl.players():
		if f.device == d and not f.is_bot:
			return true
	# With only bots, let the keyboard pause.
	return d.begins_with("kb")


func _on_gui(ev: InputEvent) -> void:
	if open:
		_handle(menu.mouse_event(ev, canvas.get_local_mouse_position()))


func _handle(r: Dictionary) -> void:
	if r.is_empty():
		return
	match r.action:
		"back":
			if ctl.disconnect_msg == "":
				close_menu()
		"activate":
			match r.id:
				"resume":
					ctl.disconnect_msg = ""
					close_menu()
				"cpu":
					ctl.convert_to_bot(paused_by)
					close_menu()
				"restart":
					close_menu()
					ctl.restart_match()
				"reset":
					ctl.mode.reset_positions()
					close_menu()
				"spawn_go":
					var ids: Array = WeaponDefs.ALL.keys()
					ctl.mode.spawn_training_weapon(ids[spawn_idx % ids.size()], paused_by)
					close_menu()
				"to_lobby":
					close_menu()
					Net.return_to_lobby()
				"quit":
					if confirm_quit:
						get_tree().paused = false
						Router.tournament = {}
						if _net():
							Net.leave()
						Router.goto("main_menu")
					else:
						confirm_quit = true
						_build()
		"change":
			var dl: int = r.delta
			match r.id:
				"sfx", "music":
					var key: String = "sfx_volume" if r.id == "sfx" else "music_volume"
					Settings.set_value(key, clampf(snappedf(float(Settings.get_value(key)) + dl * 0.1, 0.1), 0.0, 1.0))
				"shake":
					Settings.set_value("screen_shake", clampf(snappedf(Settings.shake_amount() + dl * 0.25, 0.25), 0.0, 1.5))
				"dummy":
					var vals: Array = ModeDefs.RULES.dummy_ai.values
					var cur: int = vals.find(ctl.rules.get("dummy_ai", "stand"))
					ctl.rules["dummy_ai"] = vals[posmod(cur + dl, vals.size())]
					ctl.mode.apply_dummy_ai()
				"spawn":
					spawn_idx = posmod(spawn_idx + dl, WeaponDefs.ALL.size())
			_build()


func _draw_menu() -> void:
	canvas.draw_rect(Rect2(0, 0, 480, 270), Color(0.03, 0.02, 0.06, 0.65))
	UI.panel(canvas, Rect2(130, 30, 220, 196))
	PixelFont.draw_text(canvas, Vector2(240, 38), "PAUSED", Pal.UI_HILITE, 2, 1)
	if ctl.disconnect_msg != "":
		PixelFont.draw_text(canvas, Vector2(240, 56), ctl.disconnect_msg, Pal.UI_BAD, 1, 1)
	elif paused_by != "":
		PixelFont.draw_text(canvas, Vector2(240, 56), "BY " + InputHub.device_label(paused_by), Pal.UI_DIM, 1, 1)
	menu.draw(canvas, t)
	UI.hints(canvas, "UP/DOWN SELECT · LEFT/RIGHT CHANGE · CONFIRM · START/ESC RESUME")
