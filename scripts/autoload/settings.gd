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
	"vsync": true,
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
}

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
	if key in ["fullscreen", "vsync", "window_scale"]:
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
	for k in ["window_scale", "hud_scale", "bot_difficulty"]:
		data[k] = int(data[k])


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


func apply_video() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var fs: bool = get_value("fullscreen")
	if fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var sc: int = clampi(int(get_value("window_scale")), 1, 6)
		var size := Vector2i(480 * sc, 270 * sc)
		var screen := DisplayServer.screen_get_usable_rect()
		if screen.size.x > 0 and (size.x > screen.size.x or size.y > screen.size.y):
			size = Vector2i(480 * 2, 270 * 2)
		if DisplayServer.window_get_size() != size:
			DisplayServer.window_set_size(size)
			if screen.size.x > 0:
				DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if get_value("vsync") else DisplayServer.VSYNC_DISABLED)


func shake_amount() -> float:
	return float(get_value("screen_shake"))


func flash_ok() -> bool:
	return not bool(get_value("reduce_flashing"))


func simple_vfx() -> bool:
	return bool(get_value("simple_vfx"))
