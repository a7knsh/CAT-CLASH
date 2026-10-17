extends Node
## Persistent user settings: audio, video, accessibility, gameplay defaults
## and input bindings. Stored as JSON in user://settings.json.

signal changed

const PATH := "user://settings.json"

const DEFAULTS := {
	"master_volume": 0.8,
	"music_volume": 0.55,
	"sfx_volume": 0.8,
	"fullscreen": false,
	"window_mode": "windowed",
	"resolution": "1440x810",
	"vsync": true,
	"max_fps": 0,
	"scaling": "smooth",
	"window_scale": 3,
	"screen_shake": 1.0,
	"reduce_flashing": false,
	"simple_vfx": false,
	"colorblind": false,
	"hud_scale": 1,
	"damage_numbers": true,
	"show_fps": false,
	"bot_difficulty": 1,
	"deadzone": 0.3,
	"stick_sensitivity": 1.0,
	"rumble": true,
	"bindings": {},
	"player_name": "",
	"last_ip": "",
}

const WINDOW_MODES := ["windowed", "borderless", "fullscreen", "exclusive"]
const WINDOW_MODE_NAMES := {"windowed": "WINDOWED", "borderless": "BORDERLESS WINDOW", "fullscreen": "FULLSCREEN", "exclusive": "EXCLUSIVE FULLSCREEN"}
const RESOLUTIONS := ["960x540", "1280x720", "1366x768", "1440x810", "1600x900", "1920x1080", "2560x1440", "3200x1800", "3840x2160"]
const FPS_CAPS := [0, 30, 60, 120, 144, 165, 240]

var data: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_video()


func get_value(key: String, fallback: Variant = null) -> Variant:
	if data.has(key):
		return data[key]
	if DEFAULTS.has(key):
		return DEFAULTS[key]
	return fallback


func set_value(key: String, value: Variant, save_now: bool = true) -> void:
	data[key] = value
	if key == "fullscreen":
		# Legacy toggle (F11 / Alt+Enter) maps onto the window mode.
		data["window_mode"] = "fullscreen" if value else "windowed"
	if key in ["fullscreen", "window_mode", "resolution", "vsync", "max_fps", "scaling", "window_scale"]:
		apply_video()
	if key.ends_with("_volume") and has_node("/root/AudioHub"):
		get_node("/root/AudioHub").apply_volumes()
	if save_now:
		save_settings()
	changed.emit()


func load_settings() -> void:
	data = DEFAULTS.duplicate(true)
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_warning("Settings: could not open settings file, using defaults.")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Settings: settings file corrupt, using defaults.")
		return
	for k in parsed.keys():
		if not DEFAULTS.has(k):
			continue
		if typeof(parsed[k]) == typeof(DEFAULTS[k]) or (_numeric(parsed[k]) and _numeric(DEFAULTS[k])):
			data[k] = parsed[k]
	# JSON numbers come back as floats; coerce integer settings.
	for k in ["window_scale", "hud_scale", "bot_difficulty", "max_fps"]:
		data[k] = int(data[k])
	# Migrate older settings files (window scale / fullscreen flag).
	if not parsed.has("resolution"):
		var sc := clampi(int(data.window_scale), 1, 8)
		var r := "%dx%d" % [480 * sc, 270 * sc]
		data["resolution"] = r if r in RESOLUTIONS else "1440x810"
	if not parsed.has("window_mode") and bool(data.get("fullscreen", false)):
		data["window_mode"] = "fullscreen"
	if not (data.window_mode in WINDOW_MODES):
		data["window_mode"] = "windowed"


func _numeric(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


func save_settings() -> void:
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Settings: unable to write settings.")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(PATH))


func reset_to_defaults() -> void:
	var keep_bindings: Dictionary = data.get("bindings", {})
	data = DEFAULTS.duplicate(true)
	data["bindings"] = keep_bindings
	apply_video()
	save_settings()
	changed.emit()


## Parse "WxH" into a size (falls back to 1440x810).
static func parse_resolution(r: String) -> Vector2i:
	var p := r.split("x")
	if p.size() == 2 and p[0].is_valid_int() and p[1].is_valid_int():
		return Vector2i(int(p[0]), int(p[1]))
	return Vector2i(1440, 810)


func apply_video() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode: String = get_value("window_mode")
	data["fullscreen"] = mode in ["fullscreen", "exclusive"]
	var screen := DisplayServer.screen_get_usable_rect()
	var full := DisplayServer.screen_get_size()
	var win := get_window()
	match mode:
		"fullscreen":
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"exclusive":
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"borderless":
			# Borderless "windowed fullscreen": covers the whole monitor.
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			var origin := DisplayServer.screen_get_position()
			DisplayServer.window_set_size(full)
			DisplayServer.window_set_position(origin)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			var size := parse_resolution(str(get_value("resolution")))
			if screen.size.x > 0 and (size.x > screen.size.x or size.y > screen.size.y):
				# Too big for this monitor: shrink, keeping 16:9.
				var k := minf(float(screen.size.x) / size.x, float(screen.size.y) / size.y)
				size = Vector2i(int(size.x * k), int(size.y * k))
			if DisplayServer.window_get_size() != size:
				DisplayServer.window_set_size(size)
				if screen.size.x > 0:
					DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if get_value("vsync") else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(get_value("max_fps"))
	if win:
		# Pixel-perfect uses whole-number scaling only (may add black borders).
		win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if get_value("scaling") == "pixel" else Window.CONTENT_SCALE_STRETCH_FRACTIONAL


func shake_amount() -> float:
	return float(get_value("screen_shake"))


func flash_ok() -> bool:
	return not bool(get_value("reduce_flashing"))


func simple_vfx() -> bool:
	return bool(get_value("simple_vfx"))
