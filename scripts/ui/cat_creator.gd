extends Screen
## Cat Creator: build custom fighters with a live animated preview. Tabs for
## coat, face, gear and style; presets can be saved, renamed, duplicated and
## deleted. Built-in roster cats are read-only (saving makes a copy).
## Cosmetics never alter hitboxes or stats — body size is visual only.

const TABS := ["COAT", "FACE", "GEAR", "STYLE", "PRESETS"]
const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -!?"

var tab := 0
var skin: Dictionary = {}
var presets: Array = []
var pidx := 0
var dirty := false
var preview: CatPuppet
var preview_mode := 0
var msg := ""
var msg_t := 0.0
var confirm_delete := false
var typing := false
var type_buf := ""
var key_idx := 0
var _rng := RandomNumberGenerator.new()


func _build() -> void:
	_rng.randomize()
	presets = SaveData.all_presets()
	skin = Sprites.full_skin(presets[0])
	preview = CatPuppet.new()
	preview.scale = Vector2(4, 4)
	preview.position = Vector2(92, 196)
	add_child(preview)
	menu.pos = Vector2(196, 50)
	menu.width = 270
	menu.line_h = 14
	menu.max_visible = 12
	_rebuild()


func _say(m: String) -> void:
	msg = m
	msg_t = 2.5


func _rebuild() -> void:
	var keep := menu.index
	menu.clear()
	match TABS[tab]:
		"COAT":
			_color_row("fur", "MAIN FUR")
			_color_row("fur2", "SECOND COLOUR")
			_color_row("fur3", "PATCH COLOUR")
			_opt_row("pattern", "PATTERN", CosmeticDefs.PATTERNS)
			_opt_row("body", "BODY (COSMETIC)", CosmeticDefs.BODIES, "Body size is cosmetic only: every cat has the same hitbox.")
			_opt_row("tail", "TAIL", CosmeticDefs.TAILS)
			_opt_row("personality", "IDLE PERSONALITY", CosmeticDefs.PERSONALITIES)
		"FACE":
			_color_row("eye_color", "EYE COLOUR", true)
			_opt_row("eye_shape", "EYE SHAPE", CosmeticDefs.EYE_SHAPES)
			_opt_row("ears", "EARS", CosmeticDefs.EARS)
			_opt_row("whiskers", "WHISKERS", CosmeticDefs.WHISKERS)
			_opt_row("expression", "EXPRESSION", CosmeticDefs.EXPRESSIONS)
			_unlock_row("taunt", "TAUNT", "taunt")
		"GEAR":
			for slot in [["head_acc", "HEAD", "head"], ["face_acc", "FACE", "face"], ["neck_acc", "NECK", "neck"], ["back_acc", "BACK", "back"], ["ear_acc", "EAR", "ear"]]:
				var cur: String = skin.get(slot[0], "")
				var label := "NONE" if cur == "" else str(CosmeticDefs.ACCESSORIES.get(cur, {}).get("name", cur))
				var locked := cur != "" and not SaveData.is_unlocked("accessory", cur)
				menu.add(slot[0], slot[1], "choice", label + (" (LOCKED)" if locked else ""), {"hint": SaveData.unlock_hint("accessory", cur) if locked else "Accessories never cover hitboxes or change stats."})
		"STYLE":
			_unlock_row("weapon_skin", "WEAPON SKIN", "weapon_skin")
			_unlock_row("trail", "ATTACK TRAIL", "trail")
			_unlock_row("victory", "VICTORY POSE", "victory")
			_unlock_row("entrance", "ENTRANCE", "entrance")
			_unlock_row("ko_fx", "KO EFFECT", "ko_fx")
			_unlock_row("nameplate", "NAMEPLATE", "nameplate")
			_unlock_row("icon", "PROFILE ICON", "icon")
		"PRESETS":
			var cur_p: Dictionary = presets[pidx % presets.size()]
			menu.add("preset", "EDITING", "choice", str(cur_p.name) + (" (BUILT-IN)" if cur_p.get("builtin", false) else ""), {"hint": "Pick a cat to edit. Built-in cats are copied when saved."})
			menu.add("name", "NAME", "button", str(skin.name), {"hint": "Rename this cat (type or use the on-screen keyboard)."})
			menu.add("save", "SAVE", "button", "", {"color": Pal.UI_GOOD, "hint": "Save changes (built-in cats save as a new copy)."})
			menu.add("save_new", "SAVE AS NEW CAT")
			menu.add("duplicate", "DUPLICATE")
			menu.add("delete", "DELETE" if not confirm_delete else "REALLY DELETE? CONFIRM AGAIN", "button", "", {"color": Pal.UI_BAD, "disabled": cur_p.get("builtin", false)})
			menu.add("random", "RANDOMIZE LOOK", "button", "", {"hint": "Roll a random cat from your unlocked options."})
			menu.add("back", "BACK TO MENU")
	menu.index = clampi(keep, 0, maxi(0, menu.items.size() - 1))


func _color_row(key: String, label: String, eyes: bool = false) -> void:
	menu.add(key, label, "choice", "", {"swatch": Sprites.col(skin.get(key, "ffffff")), "hint": "LEFT/RIGHT to pick a colour."})


func _opt_row(key: String, label: String, opts: Dictionary, hint: String = "") -> void:
	menu.add(key, label, "choice", str(opts.get(skin.get(key, ""), skin.get(key, ""))), {"hint": hint})


func _unlock_row(key: String, label: String, cat: String) -> void:
	var cur: String = skin.get(key, "")
	var d: Dictionary = CosmeticDefs.category(cat).get(cur, {})
	var locked := not SaveData.is_unlocked(cat, cur)
	menu.add(key, label, "choice", str(d.get("name", cur)) + (" (LOCKED)" if locked else ""), {"hint": SaveData.unlock_hint(cat, cur) if locked else ""})


func _options_for(key: String) -> Array:
	match key:
		"fur", "fur2", "fur3": return CosmeticDefs.FUR_COLORS
		"eye_color": return CosmeticDefs.EYE_COLORS
		"pattern": return CosmeticDefs.PATTERNS.keys()
		"body": return CosmeticDefs.BODIES.keys()
		"tail": return CosmeticDefs.TAILS.keys()
		"personality": return CosmeticDefs.PERSONALITIES.keys()
		"eye_shape": return CosmeticDefs.EYE_SHAPES.keys()
		"ears": return CosmeticDefs.EARS.keys()
		"whiskers": return CosmeticDefs.WHISKERS.keys()
		"expression": return CosmeticDefs.EXPRESSIONS.keys()
		"taunt": return CosmeticDefs.TAUNTS.keys()
		"weapon_skin": return CosmeticDefs.WEAPON_SKINS.keys()
		"trail": return CosmeticDefs.TRAILS.keys()
		"victory": return CosmeticDefs.VICTORY_POSES.keys()
		"entrance": return CosmeticDefs.ENTRANCES.keys()
		"ko_fx": return CosmeticDefs.KO_EFFECTS.keys()
		"nameplate": return CosmeticDefs.NAMEPLATES.keys()
		"icon": return CosmeticDefs.ICONS.keys()
		"head_acc", "face_acc", "neck_acc", "back_acc", "ear_acc":
			var slot: String = key.replace("_acc", "")
			var arr: Array = [""]
			arr.append_array(CosmeticDefs.accessories_for_slot(slot))
			return arr
	return []


func _on_menu(r: Dictionary) -> void:
	match r.action:
		"back":
			Router.goto("main_menu")
		"change":
			if r.id == "preset":
				pidx = posmod(pidx + r.delta, presets.size())
				skin = Sprites.full_skin(presets[pidx])
				confirm_delete = false
			else:
				var opts := _options_for(r.id)
				skin[r.id] = cycle(opts, skin.get(r.id, ""), r.delta)
				dirty = true
				_preview_for(r.id)
			_rebuild()
		"activate":
			_activate(r.id)


func _preview_for(key: String) -> void:
	match key:
		"weapon_skin", "trail":
			preview_mode = 2
		"victory":
			preview_mode = 3
		"taunt":
			preview_mode = 4
		_:
			pass


func _locked_items() -> Array:
	var out: Array = []
	for pair in [["taunt", "taunt"], ["weapon_skin", "weapon_skin"], ["trail", "trail"], ["victory", "victory"], ["entrance", "entrance"], ["ko_fx", "ko_fx"], ["nameplate", "nameplate"], ["icon", "icon"]]:
		var v: String = skin.get(pair[0], "")
		if v != "" and not SaveData.is_unlocked(pair[1], v):
			out.append(v)
	for k in ["head_acc", "face_acc", "neck_acc", "back_acc", "ear_acc"]:
		var a: String = skin.get(k, "")
		if a != "" and not SaveData.is_unlocked("accessory", a):
			out.append(a)
	return out


func _activate(id: String) -> void:
	match id:
		"back":
			Router.goto("main_menu")
		"name":
			typing = true
			type_buf = str(skin.name)
			key_idx = 0
		"save", "save_new":
			if not _locked_items().is_empty():
				_say("UNLOCK EVERYTHING FIRST (SEE COLLECTION)")
				AudioHub.play("ui_error")
				return
			var s := skin.duplicate()
			if id == "save_new" or presets[pidx].get("builtin", false):
				s.id = ""
			var new_id := SaveData.save_preset(s)
			presets = SaveData.all_presets()
			for i in presets.size():
				if presets[i].id == new_id:
					pidx = i
			skin = Sprites.full_skin(presets[pidx])
			dirty = false
			_say("SAVED!")
			AudioHub.meow(1.2)
		"duplicate":
			var nid := SaveData.duplicate_preset(presets[pidx].id)
			presets = SaveData.all_presets()
			for i in presets.size():
				if presets[i].id == nid:
					pidx = i
			skin = Sprites.full_skin(presets[pidx])
			_say("DUPLICATED")
		"delete":
			if presets[pidx].get("builtin", false):
				return
			if not confirm_delete:
				confirm_delete = true
			else:
				SaveData.delete_preset(presets[pidx].id)
				presets = SaveData.all_presets()
				pidx = 0
				skin = Sprites.full_skin(presets[0])
				confirm_delete = false
				_say("DELETED")
		"random":
			_randomize()
	_rebuild()


func _randomize() -> void:
	for k in ["fur", "fur2", "fur3", "eye_color", "pattern", "body", "tail", "personality", "eye_shape", "ears", "whiskers", "expression"]:
		var o := _options_for(k)
		skin[k] = o[_rng.randi_range(0, o.size() - 1)]
	for k in ["head_acc", "face_acc", "neck_acc", "back_acc", "ear_acc"]:
		var o2 := _options_for(k).filter(func(a): return a == "" or SaveData.is_unlocked("accessory", a))
		skin[k] = o2[_rng.randi_range(0, o2.size() - 1)] if _rng.randf() < 0.5 else ""
	dirty = true


func _update(dt: float) -> void:
	msg_t -= dt
	if typing:
		_update_typing()
		return
	for e in InputHub.menu_events:
		if e.action in ["tab_l", "tab_r"]:
			tab = posmod(tab + (-1 if e.action == "tab_l" else 1), TABS.size())
			menu.index = 0
			confirm_delete = false
			AudioHub.play("ui_move", -6.0)
			_rebuild()
	super._update(dt)
	# Preview animation cycle
	var cyc := fmod(t, 12.0)
	var auto := ["idle", "run", "attack", "victory", "emote"]
	if preview_mode == 0:
		preview.preview_state = auto[int(cyc / 2.4) % auto.size()]
	else:
		preview.preview_state = auto[preview_mode]
		if fmod(t, 4.0) < 0.02:
			preview_mode = 0
	preview.preview_weapon = "sword" if int(t / 4.8) % 2 == 0 else "fish"
	preview.skin = skin


func _update_typing() -> void:
	var cols := 10
	for e in InputHub.menu_events:
		match e.action:
			"left": key_idx = posmod(key_idx - 1, LETTERS.length() + 2)
			"right": key_idx = posmod(key_idx + 1, LETTERS.length() + 2)
			"up": key_idx = posmod(key_idx - cols, LETTERS.length() + 2)
			"down": key_idx = posmod(key_idx + cols, LETTERS.length() + 2)
			"confirm":
				if key_idx < LETTERS.length():
					if type_buf.length() < 12:
						type_buf += LETTERS[key_idx]
				elif key_idx == LETTERS.length():
					type_buf = type_buf.substr(0, maxi(0, type_buf.length() - 1))
				else:
					_finish_typing()
					return
			"back":
				typing = false
				return
			"start":
				_finish_typing()
				return
	queue_redraw()


func _finish_typing() -> void:
	typing = false
	if type_buf.strip_edges() != "":
		skin["name"] = type_buf.strip_edges().to_upper()
		dirty = true
	_rebuild()


func _input(ev: InputEvent) -> void:
	if not typing:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_BACKSPACE:
			type_buf = type_buf.substr(0, maxi(0, type_buf.length() - 1))
			get_viewport().set_input_as_handled()
		elif ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER:
			_finish_typing()
			get_viewport().set_input_as_handled()
		elif ev.unicode >= 32 and ev.unicode < 127:
			var ch := char(ev.unicode).to_upper()
			if LETTERS.contains(ch) and type_buf.length() < 12:
				type_buf += ch
			get_viewport().set_input_as_handled()
		InputHub.consume_menu()


func _on_mouse(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var p := get_local_mouse_position()
		for i in TABS.size():
			if Rect2(196 + i * 54, 32, 52, 13).has_point(p):
				tab = i
				menu.index = 0
				_rebuild()


func _paint() -> void:
	UI.title(self, "CAT CREATOR", 6)
	# Preview stage
	UI.panel(self, Rect2(10, 32, 176, 210))
	for i in 6:
		draw_rect(Rect2(14, 36 + i * 27, 168, 28), Color("2a3a6a").lerp(Color("6a4a8a"), i / 5.0))
	draw_rect(Rect2(14, 196, 168, 42), Color("3c3650"))
	draw_rect(Rect2(14, 196, 168, 2), Color("5a5470"))
	PixelFont.draw_text(self, Vector2(98, 40), str(skin.name), Pal.UI_HILITE, 2, 1)
	PixelFont.draw_text(self, Vector2(98, 58), SaveData.mastery_title(str(skin.get("id", ""))) + (" · UNSAVED" if dirty else ""), Pal.UI_DIM if not dirty else Pal.UI_ACCENT, 1, 1)
	PixelFont.draw_text(self, Vector2(98, 226), "LB/RB OR Q/E: SWITCH TAB", Pal.UI_DIM, 1, 1)
	# Tabs
	for i in TABS.size():
		var r := Rect2(196 + i * 54, 32, 52, 13)
		UI.panel(self, r, Pal.UI_PANEL2 if i == tab else Pal.UI_PANEL, Pal.UI_HILITE if i == tab else Pal.UI_EDGE, false)
		PixelFont.draw_text(self, r.position + Vector2(26, 3), TABS[i], Pal.UI_HILITE if i == tab else Pal.UI_DIM, 1, 1)
	menu.draw(self, t)
	# Colour swatches for colour rows
	for i in range(menu.scroll, mini(menu.items.size(), menu.scroll + menu.max_visible)):
		var it: Dictionary = menu.items[i]
		if it.has("swatch"):
			var y := menu.pos.y + (i - menu.scroll) * menu.line_h
			var opts := _options_for(it.id)
			var cur: int = opts.find(skin.get(it.id, ""))
			for k in range(-2, 3):
				var c: Color = Sprites.col(opts[posmod(cur + k, opts.size())])
				UI.swatch(self, Rect2(menu.pos.x + menu.width - 70 + (k + 2) * 13, y + 2, 9, 7), c, k == 0)
	if msg_t > 0.0:
		PixelFont.draw_text(self, Vector2(330, 228), msg, Pal.UI_HILITE, 1, 1)
	if typing:
		_draw_keyboard()
	UI.hints(self, "UP/DOWN: OPTION · LEFT/RIGHT: CHANGE · Q/E LB/RB: TAB · ESC/B: BACK")


func _draw_keyboard() -> void:
	draw_rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, 0.6))
	UI.panel(self, Rect2(110, 70, 260, 120))
	PixelFont.draw_text(self, Vector2(240, 78), "NAME YOUR CAT", Pal.UI_HILITE, 1, 1)
	PixelFont.draw_text(self, Vector2(240, 92), type_buf + ("_" if int(t * 3.0) % 2 == 0 else " "), Pal.UI_TEXT, 2, 1)
	var cols := 10
	for i in LETTERS.length() + 2:
		var x := 128 + (i % cols) * 23
		var y := 116 + (i / cols) * 14
		var label := LETTERS[i] if i < LETTERS.length() else ("DEL" if i == LETTERS.length() else "OK")
		if label == " ":
			label = "SPC"
		var sel := i == key_idx
		if sel:
			draw_rect(Rect2(x - 2, y - 2, 21, 12), Pal.UI_HILITE.darkened(0.3))
		PixelFont.draw_text(self, Vector2(x + 8, y), label, Pal.UI_TEXT if not sel else Pal.UI_HILITE, 1, 1)
	PixelFont.draw_text(self, Vector2(240, 180), "TYPE ON KEYBOARD OR PICK LETTERS · ENTER/START: DONE", Pal.UI_DIM, 1, 1)
