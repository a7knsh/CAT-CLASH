extends Screen
## Control remapping for Keyboard Left, Keyboard Right and Gamepads.
## Every action has two slots (PRIMARY / ALT). Pick a slot with left/right,
## confirm and press the new key/button. If it's already used by another
## action - on this device or the other keyboard half - the bindings swap.
## HEAVY (or DELETE while waiting for a key) clears a slot.

const PROFILES := ["kb0", "kb1", "pad"]
const PROFILE_NAMES := ["KEYBOARD LEFT", "KEYBOARD RIGHT", "GAMEPADS"]
const SLOTS := 2
## Keys the game reserves for itself.
const RESERVED := [KEY_F11]
const SLOT_X := [150.0, 266.0]
const SLOT_W := 110.0

var prof := 0
var col := 0
var capturing := ""
var msg := ""
var confirm_all := false


func _build() -> void:
	menu.pos = Vector2(50, 46)
	menu.width = 380
	menu.line_h = 12
	menu.max_visible = 14
	InputHub.captured.connect(_on_captured)
	_rebuild()


func _exit_tree() -> void:
	InputHub.capturing = false


func _dev() -> String:
	return PROFILES[prof] if prof < 2 else "pad0"


func _is_action(id: String) -> bool:
	return id in InputHub.REBINDABLE


func _rebuild() -> void:
	var keep := menu.index
	menu.clear()
	menu.add("profile", "DEVICE", "choice", PROFILE_NAMES[prof])
	for a in InputHub.REBINDABLE:
		var hint := "LEFT/RIGHT: PICK SLOT · CONFIRM: REBIND · HEAVY: CLEAR SLOT"
		if prof == 2 and a in ["up", "down", "left", "right"]:
			hint = "THE LEFT STICK ALWAYS MOVES TOO. " + hint
		menu.add(a, InputHub.ACTION_LABELS[a], "button", "", {"hint": hint})
	menu.add("reset", "RESET THIS DEVICE", "button", "", {"color": Pal.UI_BAD})
	menu.add("reset_all", "RESET ALL DEVICES", "button", "ARE YOU SURE?" if confirm_all else "", {"color": Pal.UI_BAD})
	menu.add("back", "BACK")
	menu.index = clampi(keep, 0, menu.items.size() - 1)


# ---------------------------------------------------------------- bindings

func _slots(profile_dev: String, action: String) -> Array:
	var arr: Array = InputHub.bindings_for(profile_dev).get(action, []).duplicate()
	while arr.size() < SLOTS:
		arr.append(-1)
	return arr.slice(0, SLOTS)


func _store(profile: String, action: String, slots: Array) -> void:
	var out: Array = []
	for c in slots:
		if int(c) >= 0 and not (int(c) in out):
			out.append(int(c))
	InputHub.set_binding(profile, action, out)


func _profile_dev(p: String) -> String:
	return "pad0" if p == "pad" else p


func _code_name(code: int) -> String:
	if code < 0:
		return "-"
	return InputHub.pad_button_name(code) if prof == 2 else InputHub.key_name(code)


## Puts `code` into slot `slot` of `action`. Whoever used `code` before (any
## action on this device, or on the other keyboard half) receives our old
## code in its place - or loses it if we had none, unless that would leave
## it with nothing bound.
func _assign(action: String, slot: int, code: int) -> void:
	var pname: String = PROFILES[prof]
	var mine := _slots(_dev(), action)
	var old: int = mine[slot]
	if old == code:
		msg = "ALREADY BOUND"
		return
	var other: int = mine[1 - slot]
	if other == code:
		# Already in our other slot: just swap the two slots.
		mine[1 - slot] = old
		mine[slot] = code
		_store(pname, action, mine)
		msg = "SLOTS SWAPPED"
		return
	var owners: Array = [pname] if prof == 2 else ["kb0", "kb1"]
	for p in owners:
		var b := InputHub.bindings_for(_profile_dev(p))
		for a in b.keys():
			if p == pname and a == action:
				continue
			var theirs: Array = _slots(_profile_dev(p), a)
			var i := theirs.find(code)
			if i < 0:
				continue
			var left := 0
			for c in theirs:
				if c >= 0 and c != code:
					left += 1
			if old < 0 and left == 0:
				msg = "%s IS THE ONLY KEY FOR %s%s" % [_code_name(code), InputHub.ACTION_LABELS[a], " (OTHER HALF)" if p != pname else ""]
				AudioHub.play("ui_error")
				return
			theirs[i] = old
			_store(p, a, theirs)
			msg = "SWAPPED WITH " + str(InputHub.ACTION_LABELS[a]) + (" (OTHER HALF)" if p != pname else "")
	mine[slot] = code
	_store(pname, action, mine)
	if msg == "":
		msg = "BOUND!"


func _clear(action: String, slot: int) -> void:
	var mine := _slots(_dev(), action)
	if mine[slot] < 0:
		msg = "SLOT IS ALREADY EMPTY"
		return
	if mine[1 - slot] < 0:
		msg = "EVERY ACTION NEEDS AT LEAST ONE BINDING"
		AudioHub.play("ui_error")
		return
	mine[slot] = -1
	_store(PROFILES[prof], action, mine)
	msg = "SLOT CLEARED"
	AudioHub.play("ui_back")


# ------------------------------------------------------------------- input

func _update(dt: float) -> void:
	if capturing != "":
		return
	if _is_action(menu.current().get("id", "")):
		for e in InputHub.menu_events:
			if e.action in ["left", "right"]:
				col = 0 if e.action == "left" else 1
				AudioHub.play("ui_move", -8.0)
			elif e.action == "alt":
				_clear(menu.current().id, col)
	super._update(dt)


func _gui_input(ev: InputEvent) -> void:
	if capturing != "":
		return
	if ev is InputEventMouseButton and ev.pressed:
		var mx := get_local_mouse_position().x
		col = 1 if mx >= menu.pos.x + SLOT_X[1] - 3 else 0
	super._gui_input(ev)


func _on_menu(r: Dictionary) -> void:
	if r.action != "activate" or r.get("id", "") != "reset_all":
		if confirm_all:
			confirm_all = false
			_rebuild()
	match r.action:
		"back":
			Router.goto("settings")
		"change":
			if r.id == "profile":
				prof = posmod(prof + r.delta, PROFILES.size())
				msg = ""
				_rebuild()
		"activate":
			match r.id:
				"back": Router.goto("settings")
				"reset":
					InputHub.reset_bindings(PROFILES[prof])
					msg = PROFILE_NAMES[prof] + " RESET TO DEFAULTS"
					_rebuild()
				"reset_all":
					if confirm_all:
						Settings.set_value("bindings", {})
						confirm_all = false
						msg = "ALL DEVICES RESET TO DEFAULTS"
					else:
						confirm_all = true
						msg = "CONFIRM AGAIN TO RESET EVERY DEVICE"
					_rebuild()
				"profile": pass
				_:
					capturing = r.id
					msg = ""
					InputHub.start_capture()


func _on_captured(ev: InputEvent) -> void:
	if capturing == "":
		return
	var action := capturing
	capturing = ""
	var code := -1
	if ev is InputEventKey and ev.physical_keycode == KEY_ESCAPE and not (prof < 2 and action == "pause"):
		msg = "CANCELLED"
		return
	if ev is InputEventKey and ev.physical_keycode == KEY_DELETE:
		_clear(action, col)
		return
	if prof < 2:
		if not (ev is InputEventKey):
			msg = "PRESS A KEYBOARD KEY"
			return
		code = ev.physical_keycode
		if code in RESERVED:
			msg = InputHub.key_name(code) + " IS RESERVED (FULLSCREEN)"
			AudioHub.play("ui_error")
			return
	else:
		if ev is InputEventJoypadButton:
			code = ev.button_index
		elif ev is InputEventJoypadMotion:
			code = 100 if ev.axis == JOY_AXIS_TRIGGER_LEFT else 101
		else:
			msg = "PRESS A GAMEPAD BUTTON"
			return
	_assign(action, col, code)
	AudioHub.play("ui_select")


# -------------------------------------------------------------------- draw

func _fit(s: String) -> String:
	while s.length() > 1 and PixelFont.text_width(s) > SLOT_W - 4:
		s = s.substr(0, s.length() - 1)
	return s


func _paint() -> void:
	UI.title(self, "CONTROLS", 6)
	UI.panel(self, Rect2(40, 22, 400, 212), Color(Pal.UI_PANEL, 0.7))
	PixelFont.draw_text(self, Vector2(menu.pos.x + SLOT_X[0] + SLOT_W * 0.5, 36), "PRIMARY", Pal.UI_DIM, 1, 1)
	PixelFont.draw_text(self, Vector2(menu.pos.x + SLOT_X[1] + SLOT_W * 0.5, 36), "ALTERNATE", Pal.UI_DIM, 1, 1)
	menu.draw(self, t)
	# Binding slots, drawn over the menu rows.
	for rr in menu._rects:
		var r: Rect2 = rr[0]
		var it: Dictionary = menu.items[rr[1]]
		if not _is_action(it.id):
			continue
		var sel: bool = rr[1] == menu.index
		var codes := _slots(_dev(), it.id)
		for s in SLOTS:
			var box := Rect2(r.position.x + SLOT_X[s], r.position.y + 1, SLOT_W, r.size.y - 2)
			var active := sel and s == col
			draw_rect(box, Pal.UI_HILITE if active else Color(0, 0, 0, 0.35))
			var txt := _code_name(codes[s])
			if prof == 2 and s == 1 and codes[s] < 0 and it.id in ["up", "down", "left", "right"]:
				txt = "STICK"
			var c: Color = Pal.UI_PANEL if active else (Pal.UI_TEXT if codes[s] >= 0 else Pal.UI_LOCK)
			PixelFont.draw_text(self, Vector2(box.position.x + SLOT_W * 0.5, box.position.y + 1), _fit(txt), c, 1, 1)
	if capturing != "":
		draw_rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, 0.6))
		UI.panel(self, Rect2(110, 104, 260, 56))
		PixelFont.draw_text(self, Vector2(240, 112), "PRESS NEW %s FOR" % ("BUTTON" if prof == 2 else "KEY"), Pal.UI_TEXT, 1, 1)
		PixelFont.draw_text(self, Vector2(240, 124), "%s  (%s)" % [InputHub.ACTION_LABELS[capturing], "PRIMARY" if col == 0 else "ALTERNATE"], Pal.UI_HILITE, 1, 1)
		PixelFont.draw_text(self, Vector2(240, 138), "ESC: CANCEL · DELETE: CLEAR SLOT", Pal.UI_DIM, 1, 1)
		PixelFont.draw_text(self, Vector2(240, 148), PROFILE_NAMES[prof], Pal.UI_DIM, 1, 1)
	elif msg != "":
		PixelFont.draw_text(self, Vector2(240, 226), msg, Pal.UI_HILITE, 1, 1)
	UI.hints(self, "LT/RT CAN BE BOUND ON PADS · F11 = FULLSCREEN · KEYS SWAP BETWEEN HALVES")
