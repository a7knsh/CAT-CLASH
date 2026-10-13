extends Node
## Central multi-device input service.
##
## Devices:
##   "kb0"   left half of the keyboard (WASD)
##   "kb1"   right half of the keyboard (arrows + numpad)
##   "padN"  joypad with Godot device index N
##
## Gameplay reads per-device state (held / just_pressed + analog move) that is
## sampled once per physics tick. Menus read `menu_events`, a list of
## {device, action} produced once per idle frame with key-repeat.
## Bindings use physical keycodes, so layouts like AZERTY keep WASD positions.

signal device_connected(device: String)
signal device_disconnected(device: String)
signal captured(event: InputEvent)

const ACTIONS := ["up", "down", "left", "right", "jump", "light", "heavy", "throw", "dodge", "block", "taunt", "pause"]
const REBINDABLE := ["up", "down", "left", "right", "jump", "light", "heavy", "throw", "dodge", "block", "taunt", "pause"]

const ACTION_LABELS := {
	"up": "UP / AIM UP", "down": "DOWN / CROUCH", "left": "LEFT", "right": "RIGHT",
	"jump": "JUMP", "light": "LIGHT ATTACK", "heavy": "HEAVY ATTACK", "throw": "PICK UP / THROW",
	"dodge": "DODGE", "block": "BLOCK / PARRY", "taunt": "TAUNT", "pause": "PAUSE",
}

var DEFAULT_KB := {
	"kb0": {
		"up": [KEY_W], "down": [KEY_S], "left": [KEY_A], "right": [KEY_D],
		"jump": [KEY_SPACE], "light": [KEY_F], "heavy": [KEY_G], "throw": [KEY_R],
		"dodge": [KEY_E], "block": [KEY_Q], "taunt": [KEY_T], "pause": [KEY_ESCAPE],
	},
	"kb1": {
		"up": [KEY_UP], "down": [KEY_DOWN], "left": [KEY_LEFT], "right": [KEY_RIGHT],
		"jump": [KEY_KP_0, KEY_ENTER], "light": [KEY_KP_1, KEY_PERIOD], "heavy": [KEY_KP_2, KEY_SLASH],
		"throw": [KEY_KP_3, KEY_SEMICOLON], "dodge": [KEY_KP_5, KEY_APOSTROPHE], "block": [KEY_KP_4, KEY_L],
		"taunt": [KEY_KP_6, KEY_K], "pause": [KEY_KP_ENTER, KEY_BACKSPACE],
	},
}

var DEFAULT_PAD := {
	"up": [JOY_BUTTON_DPAD_UP], "down": [JOY_BUTTON_DPAD_DOWN], "left": [JOY_BUTTON_DPAD_LEFT], "right": [JOY_BUTTON_DPAD_RIGHT],
	"jump": [JOY_BUTTON_A], "light": [JOY_BUTTON_X], "heavy": [JOY_BUTTON_Y], "throw": [JOY_BUTTON_B],
	"dodge": [JOY_BUTTON_RIGHT_SHOULDER], "block": [JOY_BUTTON_LEFT_SHOULDER], "taunt": [JOY_BUTTON_BACK],
	"pause": [JOY_BUTTON_START],
}

## device -> {action -> bool}
var _held: Dictionary = {}
var _prev: Dictionary = {}
var _latch: Dictionary = {}
var _just: Dictionary = {}
var _move: Dictionary = {}

# Menu state
var menu_events: Array = []
var _menu_prev: Dictionary = {}
var _repeat_t: Dictionary = {}
var _menu_latch: Array = []
var capturing := false
var mouse_used := false

## Set when a device is virtually driven by tests (device -> {action: bool}).
var virtual_held: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -1000
	process_physics_priority = -1000
	Input.joy_connection_changed.connect(_on_joy_changed)


func _on_joy_changed(device: int, connected: bool) -> void:
	var id := "pad%d" % device
	if connected:
		device_connected.emit(id)
	else:
		device_disconnected.emit(id)


# ------------------------------------------------------------------ bindings

func bindings_for(device: String) -> Dictionary:
	var custom: Dictionary = Settings.get_value("bindings", {})
	var key := "pad" if device.begins_with("pad") else device
	var base: Dictionary = DEFAULT_PAD if key == "pad" else DEFAULT_KB.get(key, {})
	if custom.has(key):
		var merged := base.duplicate(true)
		var c: Dictionary = custom[key]
		for a in c.keys():
			var arr: Array = []
			for v in c[a]:
				arr.append(int(v))
			merged[a] = arr
		return merged
	return base


func set_binding(profile: String, action: String, codes: Array) -> void:
	var custom: Dictionary = Settings.get_value("bindings", {}).duplicate(true)
	if not custom.has(profile):
		custom[profile] = {}
	custom[profile][action] = codes
	Settings.set_value("bindings", custom)


func reset_bindings(profile: String) -> void:
	var custom: Dictionary = Settings.get_value("bindings", {}).duplicate(true)
	custom.erase(profile)
	Settings.set_value("bindings", custom)


func key_name(code: int) -> String:
	var kc := DisplayServer.keyboard_get_keycode_from_physical(code)
	var s := OS.get_keycode_string(kc if kc != 0 else code)
	if s.is_empty():
		s = "KEY %d" % code
	return s.to_upper()


func pad_button_name(b: int) -> String:
	match b:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_BACK: return "SELECT"
		JOY_BUTTON_START: return "START"
		JOY_BUTTON_LEFT_STICK: return "L3"
		JOY_BUTTON_RIGHT_STICK: return "R3"
		JOY_BUTTON_DPAD_UP: return "D-UP"
		JOY_BUTTON_DPAD_DOWN: return "D-DOWN"
		JOY_BUTTON_DPAD_LEFT: return "D-LEFT"
		JOY_BUTTON_DPAD_RIGHT: return "D-RIGHT"
		100: return "LT"
		101: return "RT"
	return "BTN %d" % b


func binding_text(device: String, action: String) -> String:
	var b: Dictionary = bindings_for(device)
	var parts: Array = []
	for code in b.get(action, []):
		parts.append(pad_button_name(code) if device.begins_with("pad") else key_name(code))
	return " / ".join(parts) if not parts.is_empty() else "-"


func device_label(device: String) -> String:
	if device == "kb0":
		return "KEYBOARD L"
	if device == "kb1":
		return "KEYBOARD R"
	if device.begins_with("pad"):
		var idx := int(device.substr(3))
		var n := Input.get_joy_name(idx).to_upper()
		if n.length() > 14:
			n = n.substr(0, 14)
		return "PAD %d %s" % [idx + 1, n]
	return "CPU"


func short_label(device: String) -> String:
	if device == "kb0":
		return "KB-L"
	if device == "kb1":
		return "KB-R"
	if device.begins_with("pad"):
		return "PAD%d" % (int(device.substr(3)) + 1)
	return "CPU"


func is_connected_device(device: String) -> bool:
	if device.begins_with("kb") or device.begins_with("virt"):
		return true
	if device.begins_with("pad"):
		return Input.get_connected_joypads().has(int(device.substr(3)))
	return false


func all_devices() -> Array:
	var out: Array = ["kb0", "kb1"]
	for j in Input.get_connected_joypads():
		out.append("pad%d" % j)
	for v in virtual_held.keys():
		out.append(v)
	return out


# ------------------------------------------------------------------ sampling

func _sample(device: String) -> Dictionary:
	var res := {}
	if virtual_held.has(device):
		var vh: Dictionary = virtual_held[device]
		for a in ACTIONS:
			res[a] = bool(vh.get(a, false))
		return res
	var b := bindings_for(device)
	if device.begins_with("kb"):
		if capturing:
			for a in ACTIONS:
				res[a] = false
			return res
		for a in ACTIONS:
			var on := false
			for code in b.get(a, []):
				if Input.is_physical_key_pressed(code):
					on = true
					break
			res[a] = on
	else:
		var idx := int(device.substr(3))
		var dz: float = Settings.get_value("deadzone")
		var ax := Input.get_joy_axis(idx, JOY_AXIS_LEFT_X)
		var ay := Input.get_joy_axis(idx, JOY_AXIS_LEFT_Y)
		var lt := Input.get_joy_axis(idx, JOY_AXIS_TRIGGER_LEFT)
		var rt := Input.get_joy_axis(idx, JOY_AXIS_TRIGGER_RIGHT)
		for a in ACTIONS:
			var on := false
			for code in b.get(a, []):
				if code == 100:
					on = on or lt > 0.5
				elif code == 101:
					on = on or rt > 0.5
				elif Input.is_joy_button_pressed(idx, code):
					on = true
			res[a] = on
		res["left"] = res["left"] or ax < -dz
		res["right"] = res["right"] or ax > dz
		res["up"] = res["up"] or ay < -max(dz, 0.5)
		res["down"] = res["down"] or ay > max(dz, 0.5)
		# Triggers double as block / dodge by default.
		res["block"] = res["block"] or lt > 0.5
		res["dodge"] = res["dodge"] or rt > 0.5
	return res


func _analog(device: String, held: Dictionary) -> Vector2:
	var v := Vector2(float(held["right"]) - float(held["left"]), float(held["down"]) - float(held["up"]))
	if device.begins_with("pad"):
		var idx := int(device.substr(3))
		var dz: float = Settings.get_value("deadzone")
		var sens: float = Settings.get_value("stick_sensitivity")
		var s := Vector2(Input.get_joy_axis(idx, JOY_AXIS_LEFT_X), Input.get_joy_axis(idx, JOY_AXIS_LEFT_Y))
		if s.length() > dz:
			var mag := clampf((s.length() - dz) / (1.0 - dz) * sens, 0.0, 1.0)
			s = s.normalized() * mag
			if absf(s.x) > absf(v.x) * 0.99:
				v.x = s.x
			if absf(s.y) > absf(v.y) * 0.99:
				v.y = s.y
	return v.limit_length(1.0)


func _physics_process(_dt: float) -> void:
	for d in all_devices():
		var h := _sample(d)
		var prev: Dictionary = _prev.get(d, {})
		var latch: Dictionary = _latch.get(d, {})
		var j := {}
		for a in ACTIONS:
			j[a] = (h[a] and not prev.get(a, false)) or latch.get(a, false)
		_just[d] = j
		_held[d] = h
		_prev[d] = h
		_move[d] = _analog(d, h)
		_latch[d] = {}


func held(device: String, action: String) -> bool:
	return _held.get(device, {}).get(action, false)


func just_pressed(device: String, action: String) -> bool:
	return _just.get(device, {}).get(action, false)


func move_vector(device: String) -> Vector2:
	return _move.get(device, Vector2.ZERO)


# ------------------------------------------------------------- event latches

func _input(event: InputEvent) -> void:
	if capturing:
		if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventJoypadButton and event.pressed):
			capturing = false
			captured.emit(event)
			get_viewport().set_input_as_handled()
		elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.7 and event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
			capturing = false
			captured.emit(event)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		mouse_used = true
		return
	if event is InputEventKey and event.pressed and not event.echo:
		mouse_used = false
		var code: int = event.physical_keycode
		for d in ["kb0", "kb1"]:
			var b := bindings_for(d)
			for a in ACTIONS:
				if code in b.get(a, []):
					_latch_action(d, a)
		# Generic keyboard menu keys (Enter / Esc) always work for menus.
		if code == KEY_ENTER or code == KEY_KP_ENTER:
			_menu_latch.append({"device": "kb1" if code == KEY_KP_ENTER else _kb_owner_of(code), "action": "confirm"})
		elif code == KEY_ESCAPE:
			_menu_latch.append({"device": "kb0", "action": "back"})
	elif event is InputEventJoypadButton and event.pressed:
		mouse_used = false
		var d := "pad%d" % event.device
		var b := bindings_for(d)
		for a in ACTIONS:
			if event.button_index in b.get(a, []):
				_latch_action(d, a)


func _kb_owner_of(code: int) -> String:
	for d in ["kb0", "kb1"]:
		var b := bindings_for(d)
		for a in ACTIONS:
			if code in b.get(a, []):
				return d
	return "kb1"


func _latch_action(d: String, a: String) -> void:
	if not _latch.has(d):
		_latch[d] = {}
	_latch[d][a] = true


func start_capture() -> void:
	capturing = true


# ------------------------------------------------------------------- menus

func _process(dt: float) -> void:
	menu_events.clear()
	var seen := {}
	for e in _menu_latch:
		menu_events.append(e)
		seen["%s:%s" % [e.device, e.action]] = true
	_menu_latch.clear()
	if capturing:
		return
	for d in all_devices():
		var h := _sample(d)
		if d.begins_with("pad"):
			# Menus also accept the stick with a firmer threshold.
			var idx := int(d.substr(3))
			var sx := Input.get_joy_axis(idx, JOY_AXIS_LEFT_X)
			var sy := Input.get_joy_axis(idx, JOY_AXIS_LEFT_Y)
			h["left"] = h["left"] or sx < -0.55
			h["right"] = h["right"] or sx > 0.55
			h["up"] = h["up"] or sy < -0.55
			h["down"] = h["down"] or sy > 0.55
		var prev: Dictionary = _menu_prev.get(d, {})
		var m := {
			"up": h["up"], "down": h["down"], "left": h["left"], "right": h["right"],
			"confirm": h["jump"] or h["light"],
			"back": h["throw"] or (d.begins_with("kb") and Input.is_physical_key_pressed(KEY_BACKSPACE) and d == "kb0"),
			"alt": h["heavy"], "alt2": h["taunt"], "start": h["pause"],
			"tab_l": h["block"], "tab_r": h["dodge"],
		}
		for a in m.keys():
			var on: bool = m[a]
			var was: bool = prev.get(a, false)
			var key := "%s:%s" % [d, a]
			if on and not was:
				if not seen.has(key):
					menu_events.append({"device": d, "action": a})
				_repeat_t[key] = 0.38
			elif on and a in ["up", "down", "left", "right"]:
				_repeat_t[key] = float(_repeat_t.get(key, 0.38)) - dt
				if _repeat_t[key] <= 0.0:
					_repeat_t[key] = 0.075
					menu_events.append({"device": d, "action": a, "repeat": true})
		_menu_prev[d] = m


## Returns true if any device fired `action` this frame (optionally a specific device).
func menu(action: String, device: String = "") -> bool:
	for e in menu_events:
		if e.action == action and (device == "" or e.device == device):
			return true
	return false


func menu_device(action: String) -> String:
	for e in menu_events:
		if e.action == action:
			return e.device
	return ""


func consume_menu() -> void:
	menu_events.clear()


func vibrate(device: String, weak: float, strong: float, duration: float) -> void:
	if not device.begins_with("pad") or not bool(Settings.get_value("rumble")):
		return
	Input.start_joy_vibration(int(device.substr(3)), weak, strong, duration)
