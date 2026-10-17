extends Screen
## Game mode selection with descriptions.


func _build() -> void:
	menu.pos = Vector2(24, 40)
	menu.width = 170
	menu.line_h = 15
	menu.max_visible = 13
	for id in ModeDefs.ORDER:
		if id in ["training", "tournament"]:
			continue
		var d: Dictionary = ModeDefs.ALL[id]
		menu.add(id, d.name, "button", "%d-%dP" % [int(d.min), int(d.max)])
	var last: String = SaveData.data.last_setup.get("mode", "")
	for i in menu.items.size():
		if menu.items[i].id == last:
			menu.index = i


func _on_menu(r: Dictionary) -> void:
	if r.action == "back":
		Router.goto("main_menu")
	elif r.action == "activate":
		if Net.active:
			Net.leave()
		Router.session = {"mode": r.id}
		Router.goto("lobby")


func _paint() -> void:
	UI.title(self, "CHOOSE A MODE")
	menu.draw(self, t)
	var id: String = menu.current().get("id", "ffa")
	var d: Dictionary = ModeDefs.ALL[id]
	UI.panel(self, Rect2(214, 40, 248, 200))
	PixelFont.draw_text(self, Vector2(224, 48), d.name, Pal.UI_HILITE, 2)
	var lines := PixelFont.wrap(d.desc, 228)
	for i in lines.size():
		PixelFont.draw_text(self, Vector2(224, 72 + i * 10), lines[i], Pal.UI_TEXT)
	var y := 72.0 + lines.size() * 10 + 8
	PixelFont.draw_text(self, Vector2(224, y), "PLAYERS: %d-%d" % [int(d.min), int(d.max)], Pal.UI_DIM)
	var tm := {"none": "SOLO", "forced": "TEAMS", "optional": "SOLO OR TEAMS", "coop": "CO-OP"}
	PixelFont.draw_text(self, Vector2(224, y + 10), "FORMAT: " + str(tm.get(d.teams, "")), Pal.UI_DIM)
	var wins := SaveData.progress("wins_" + id)
	PixelFont.draw_text(self, Vector2(224, y + 20), "YOUR WINS: %d" % int(wins), Pal.UI_DIM)
	# Little animated icon row
	for k in 3:
		var c := CatPuppet.draw_head
		c.call(self, Vector2(250 + k * 30, 210 + sin(t * 3.0 + k) * 2.0), Sprites.full_skin(CosmeticDefs.ROSTER[(k + menu.index) % CosmeticDefs.ROSTER.size()]), 2.0)
	UI.hints(self, "SELECT A MODE · BACK: ESC/B")
