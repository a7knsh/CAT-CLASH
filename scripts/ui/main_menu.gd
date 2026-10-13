extends Screen
## Main menu hub.

var preview: CatPuppet
var featured := 0


func _build() -> void:
	menu.pos = Vector2(40, 64)
	menu.width = 170
	menu.line_h = 15
	menu.add("play", "PLAY", "button", "", {"hint": "Pick a game mode, gather your friends, fight!"})
	menu.add("quick", "QUICK MATCH", "button", "", {"hint": "Free-for-all stock match: you vs 3 bots on a random arena."})
	menu.add("training", "TRAINING", "button", "", {"hint": "Practise combos, parries and weapons on dummies."})
	menu.add("tournament", "TOURNAMENT", "button", "", {"hint": "A knockout bracket. Bots fill empty seats."})
	menu.add("creator", "CAT CREATOR", "button", "", {"hint": "Design your own fighters: fur, patterns, ears, hats and more."})
	menu.add("collection", "COLLECTION & SHOP", "button", "", {"hint": "Weapons, trophies, cosmetics and daily challenges."})
	menu.add("stats", "PROFILES & STATS", "button", "", {"hint": "Player profiles, statistics and save backups."})
	menu.add("settings", "SETTINGS", "button", "", {"hint": "Audio, video, accessibility and controls."})
	menu.add("credits", "CREDITS", "button", "", {"hint": "Who made this?"})
	menu.add("quit", "QUIT", "button", "", {"hint": "See you soon!", "color": Pal.UI_BAD})
	preview = CatPuppet.new()
	preview.scale = Vector2(3, 3)
	preview.position = Vector2(350, 190)
	add_child(preview)
	featured = randi() % SaveData.all_presets().size()
	_set_preview()
	AudioHub.play_music("menu", {"tempo": 128, "root": 60, "scale": "major", "seed": 7})


func _set_preview() -> void:
	var presets := SaveData.all_presets()
	preview.skin = Sprites.full_skin(presets[featured % presets.size()])
	preview.preview_state = "idle"


func _update(dt: float) -> void:
	super._update(dt)
	var cyc := fmod(t, 9.0)
	preview.preview_state = "idle" if cyc < 5.0 else ("victory" if cyc < 7.0 else "emote")
	if cyc > 8.95:
		featured += 1
		_set_preview()


func _on_menu(r: Dictionary) -> void:
	if r.action == "back":
		Router.goto("title")
		return
	if r.action != "activate":
		return
	match r.id:
		"play":
			Router.goto("mode_select")
		"quick":
			var dev: String = r.device if r.device != "mouse" else "kb0"
			var s := Sessions.quick_session("stock", "random", 4, true)
			s.players[0] = Sessions.player_cfg(0, dev, SaveData.all_presets()[featured % SaveData.all_presets().size()].id, 0, 0, false)
			s.rules["stocks"] = 3
			Router.session = s
			Router.goto("match")
		"training":
			Router.session = {"mode": "training"}
			Router.goto("lobby")
		"tournament":
			Router.session = {"mode": "tournament"}
			Router.goto("lobby")
		"creator":
			Router.goto("creator")
		"collection":
			Router.goto("collection")
		"stats":
			Router.goto("stats")
		"settings":
			Router.goto("settings")
		"credits":
			Router.goto("credits")
		"quit":
			get_tree().quit()


func _paint() -> void:
	PixelFont.draw_text(self, Vector2(40, 18), "CAT CLASH", Pal.UI_HILITE, 3)
	PixelFont.draw_text(self, Vector2(42, 44), "ULTIMATE ARENA", Color("6ae0ff"), 1)
	menu.draw(self, t)
	# Right column: featured cat + yarn + dailies
	UI.panel(self, Rect2(250, 30, 200, 84))
	PixelFont.draw_text(self, Vector2(258, 36), "DAILY CHALLENGES", Pal.UI_HILITE)
	var y := 48.0
	for it in SaveData.data.daily.get("items", []):
		var prog := SaveData.progress(it.stat) - float(it.start)
		var done: bool = it.done
		PixelFont.draw_text(self, Vector2(258, y), ("✓ " if done else "· ") + str(it.desc).to_upper(), Pal.UI_GOOD if done else Pal.UI_TEXT)
		UI.bar(self, Rect2(266, y + 9, 120, 2), prog / float(it.target), Pal.UI_GOOD if done else Pal.UI_HILITE)
		PixelFont.draw_text(self, Vector2(444, y + 4), "+%d" % int(it.yarn), Pal.UI_DIM, 1, 2)
		y += 20
	UI.icon(self, "yarn", Vector2(258, 120), 2.0)
	PixelFont.draw_text(self, Vector2(272, 122), "%d YARN" % int(SaveData.data.yarn), Pal.UI_ACCENT)
	var presets := SaveData.all_presets()
	var p: Dictionary = presets[featured % presets.size()]
	PixelFont.draw_text(self, Vector2(350, 200), str(p.name), Pal.UI_TEXT, 1, 1)
	PixelFont.draw_text(self, Vector2(350, 210), SaveData.mastery_title(p.id), Pal.UI_DIM, 1, 1)
	draw_rect(Rect2(300, 190, 100, 2), Color(0, 0, 0, 0.3))
	UI.hints(self, "MOVE: ARROWS/WASD/STICK · SELECT: SPACE/ENTER/A · BACK: ESC/B")
