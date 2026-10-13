extends Screen
## Control remapping for Keyboard Left, Keyboard Right and Gamepads.
## Select an action and press the new key/button. If it's already used by
## another action on the same device, the two bindings swap.

const PROFILES := ["kb0", "kb1", "pad"]
const PROFILE_NAMES := ["KEYBOARD LEFT", "KEYBOARD RIGHT", "GAMEPADS"]

var prof := 0
var capturing := ""
var msg := ""


func _build() -> void:
	menu.pos = Vector2(70, 50)
	menu.width = 340
	menu.line_h = 13
	menu.max_visible = 14
	InputHub.captured.connect(_on_captured)
	_rebuild()


func _exit_tree() -> void:
	InputHub.capturing = false


func _dev() -> String:
	return PROFILES[prof] if prof < 2 else "pad0"


func _rebuild() -> void:
	var keep := menu.index
	menu.clear()
	menu.add("profile", "DEVICE", "choice", PROFILE_NAMES[prof])
	for a in InputHub.REBINDABLE:
		if prof == 2 and a in ["up", "down", "left", "right"]:
			menu.add(a, InputHub.ACTION_LABELS[a], "button", InputHub.binding_text(_dev(), a) + " / STICK", {"disabled": false})
		else:
			menu.add(a, InputHub.ACTION_LABELS[a], "button", InputHub.binding_text(_dev(), a))
	menu.add("reset", "RESET THIS DEVICE", "button", "", {"color": Pal.UI_BAD})
	menu.add("back", "BACK")
	menu.index = clampi(keep, 0, menu.items.size() - 1)


func _update(dt: float) -> void:
	if capturing != "":
		return
	super._update(dt)


func _on_menu(r: Dictionary) -> void:
	match r.action:
		"back":
			Router.goto("settings")
		"change":
			if r.id == "profile":
				prof = posmod(prof + r.delta, PROFILES.size())
				_rebuild()
		"activate":
			match r.id:
				"back": Router.goto("settings")
				"reset":
					InputHub.reset_bindings(PROFILES[prof])
					msg = "RESET TO DEFAULTS"
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
	if prof < 2:
		if not (ev is InputEventKey):
			msg = "PRESS A KEYBOARD KEY"
			_rebuild()
			return
		code = ev.physical_keycode
		if code == KEY_ESCAPE and action != "pause":
			msg = "CANCELLED"
			_rebuild()
			return
	else:
		if ev is InputEventJoypadButton:
			code = ev.button_index
		elif ev is InputEventJoypadMotion:
			code = 100 if ev.axis == JOY_AXIS_TRIGGER_LEFT else 101
		else:
			if ev is InputEventKey and ev.physical_keycode == KEY_ESCAPE:
				msg = "CANCELLED"
			else:
				msg = "PRESS A GAMEPAD BUTTON"
			_rebuild()
			return
	var pname: String = PROFILES[prof]
	var cur := InputHub.bindings_for(_dev())
	# Swap if the code is already used by another action.
	for a in cur.keys():
		if a != action and code in cur[a]:
			InputHub.set_binding(pname, a, cur[action].duplicate())
			msg = "SWAPPED WITH " + str(InputHub.ACTION_LABELS[a])
	InputHub.set_binding(pname, action, [code])
	if msg == "":
		msg = "BOUND!"
	AudioHub.play("ui_select")
	_rebuild()


func _paint() -> void:
	UI.title(self, "CONTROLS", 6)
	UI.panel(self, Rect2(60, 32, 360, 214), Color(Pal.UI_PANEL, 0.7))
	PixelFont.draw_text(self, Vector2(240, 38), "SELECT AN ACTION, THEN PRESS THE NEW KEY / BUTTON", Pal.UI_DIM, 1, 1)
	menu.draw(self, t)
	if capturing != "":
		draw_rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, 0.6))
		UI.panel(self, Rect2(120, 110, 240, 44))
		PixelFont.draw_text(self, Vector2(240, 118), "PRESS NEW BINDING FOR", Pal.UI_TEXT, 1, 1)
		PixelFont.draw_text(self, Vector2(240, 132), InputHub.ACTION_LABELS[capturing], Pal.UI_HILITE, 1, 1)
		PixelFont.draw_text(self, Vector2(240, 144), "(ESC TO CANCEL)", Pal.UI_DIM, 1, 1)
	elif msg != "":
		PixelFont.draw_text(self, Vector2(240, 236), msg, Pal.UI_HILITE, 1, 1)
	UI.hints(self, "TRIGGERS ALSO BLOCK (LT) AND DODGE (RT) · LEFT STICK ALWAYS MOVES")
