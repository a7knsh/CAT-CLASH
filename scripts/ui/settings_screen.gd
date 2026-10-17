extends Screen
## Audio, video, accessibility and gameplay settings.

const ROWS := [
	["label", "AUDIO"],
	["master_volume", "MASTER VOLUME", "vol"],
	["music_volume", "MUSIC VOLUME", "vol"],
	["sfx_volume", "SFX VOLUME", "vol"],
	["label", "VIDEO"],
	["window_mode", "DISPLAY MODE", "wmode"],
	["resolution", "RESOLUTION", "res"],
	["scaling", "SCALING", "scaling"],
	["vsync", "VSYNC", "bool"],
	["max_fps", "FPS LIMIT", "fps"],
	["show_fps", "SHOW FPS", "bool"],
	["label", "ACCESSIBILITY"],
	["screen_shake", "SCREEN SHAKE", "shake"],
	["reduce_flashing", "REDUCE FLASHING", "bool"],
	["simple_vfx", "SIMPLIFIED EFFECTS", "bool"],
	["colorblind", "COLOUR-BLIND PALETTE", "bool"],
	["hud_scale", "HUD SIZE", "hud"],
	["damage_numbers", "DAMAGE NUMBERS", "bool"],
	["label", "GAMEPLAY & INPUT"],
	["bot_difficulty", "DEFAULT BOT DIFFICULTY", "bot"],
	["deadzone", "STICK DEADZONE", "dz"],
	["stick_sensitivity", "STICK SENSITIVITY", "sens"],
	["rumble", "RUMBLE", "bool"],
]

const HINTS := {
	"window_mode": "Windowed, borderless (fills the monitor), fullscreen or exclusive fullscreen. F11 / Alt+Enter toggles fullscreen.",
	"resolution": "Window size in windowed mode (fullscreen modes use the monitor's resolution).",
	"scaling": "Smooth fills the screen; Pixel-perfect uses whole-number scaling for crisp pixels (may add borders).",
	"max_fps": "Cap the frame rate to save power. Unlimited follows VSync.",
	"screen_shake": "Scale or disable camera shake on big hits.",
	"reduce_flashing": "Replaces white hit flashes and blinking warnings with gentler effects.",
	"simple_vfx": "Halves particles and removes small rings for clearer, calmer visuals.",
	"colorblind": "Okabe-Ito colours for players and teams. Shapes (▲●■◆) always mark players too.",
	"hud_scale": "Larger HUD text for readability.",
	"bot_difficulty": "Default CPU skill for new lobbies (changeable per match).",
}


## Standard 16:9 sizes plus this monitor's own resolution.
func _resolutions() -> Array:
	var out: Array = Settings.RESOLUTIONS.duplicate()
	if DisplayServer.get_name() != "headless":
		var sz := DisplayServer.screen_get_size()
		var mine := "%dx%d" % [sz.x, sz.y]
		if sz.x > 0 and not (mine in out):
			out.append(mine)
	return out


func _build() -> void:
	menu.pos = Vector2(80, 34)
	menu.width = 320
	menu.line_h = 12
	menu.max_visible = 17
	_rebuild()


func _value_text(key: String, kind: String) -> String:
	var v: Variant = Settings.get_value(key)
	match kind:
		"vol": return "%d%%" % int(round(float(v) * 100))
		"bool": return "ON" if v else "OFF"
		"scale": return "%dX" % int(v)
		"shake": return "OFF" if float(v) <= 0.0 else "%d%%" % int(round(float(v) * 100))
		"hud": return "NORMAL" if int(v) == 1 else "LARGE"
		"bot": return ModeDefs.rule_label("bot_level", int(v))
		"dz": return "%.2f" % float(v)
		"wmode": return Settings.WINDOW_MODE_NAMES.get(str(v), "WINDOWED")
		"res":
			var txt := str(v).replace("x", " X ")
			if Settings.get_value("window_mode") != "windowed":
				txt += " (DESKTOP)"
			return txt
		"scaling": return "PIXEL-PERFECT" if v == "pixel" else "SMOOTH"
		"fps": return "UNLIMITED" if int(v) == 0 else "%d" % int(v)
		"sens": return "%.1fX" % float(v)
	return str(v)


func _rebuild() -> void:
	var keep := menu.index
	menu.clear()
	for r in ROWS:
		if r[0] == "label":
			menu.add("", "- " + r[1] + " -", "label")
		else:
			menu.add(r[0], r[1], "choice", _value_text(r[0], r[2]), {"hint": HINTS.get(r[0], ""), "kind2": r[2]})
	menu.add("controls", "CONTROLS & KEY BINDINGS...", "button", "", {"hint": "Remap keyboard halves and gamepads."})
	menu.add("reset", "RESET TO DEFAULTS", "button", "", {"color": Pal.UI_BAD})
	menu.add("back", "BACK")
	menu.index = keep if keep > 0 else 1


func _on_menu(r: Dictionary) -> void:
	match r.action:
		"back":
			Router.goto("main_menu")
		"activate":
			match r.id:
				"controls": Router.goto("controls")
				"reset":
					Settings.reset_to_defaults()
					AudioHub.apply_volumes()
					_rebuild()
				"back": Router.goto("main_menu")
		"change":
			var kind: String = menu.current().get("kind2", "")
			var key: String = r.id
			var d: int = r.delta
			var v: Variant = Settings.get_value(key)
			match kind:
				"vol": v = clampf(snappedf(float(v) + d * 0.1, 0.1), 0.0, 1.0)
				"wmode": v = cycle(Settings.WINDOW_MODES, v, d)
				"res": v = cycle(_resolutions(), v, d)
				"scaling": v = "smooth" if v == "pixel" else "pixel"
				"fps": v = cycle(Settings.FPS_CAPS, int(v), d)
				"bool": v = not bool(v)
				"scale": v = clampi(int(v) + d, 1, 6)
				"shake": v = clampf(snappedf(float(v) + d * 0.25, 0.25), 0.0, 1.5)
				"hud": v = 2 if int(v) == 1 else 1
				"bot": v = posmod(int(v) + d, 4)
				"dz": v = clampf(snappedf(float(v) + d * 0.05, 0.05), 0.1, 0.6)
				"sens": v = clampf(snappedf(float(v) + d * 0.1, 0.1), 0.5, 2.0)
			Settings.set_value(key, v)
			_rebuild()


func _paint() -> void:
	UI.title(self, "SETTINGS", 6)
	UI.panel(self, Rect2(70, 30, 340, 214), Color(Pal.UI_PANEL, 0.7))
	menu.draw(self, t)
	UI.hints(self, "LEFT/RIGHT CHANGE · SAVED AUTOMATICALLY · ESC/B BACK")
