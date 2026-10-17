extends Screen
## Tournament bracket hub: shows the bracket, launches each duel (humans
## play, CPU-vs-CPU can be watched or simulated) and crowns the champion.

var tour: Dictionary
var champion_t := 0.0
var champ: CatPuppet
var confetti: Array = []
var _rng := RandomNumberGenerator.new()


func setup(_params: Dictionary) -> void:
	pass


func _build() -> void:
	_rng.randomize()
	tour = Router.tournament
	if tour.has("last"):
		_apply_result(tour.last)
		tour.erase("last")
	menu.pos = Vector2(300, 196)
	menu.width = 166
	menu.line_h = 13
	menu.max_visible = 4
	_rebuild()
	AudioHub.play_music("menu", {"tempo": 128, "root": 60, "scale": "major", "seed": 7})


func _current() -> Dictionary:
	var rounds: Array = tour.rounds
	var r: int = tour.cur_round
	if r >= rounds.size():
		return {}
	return rounds[r][tour.cur_match]


func _ent(i: int) -> Dictionary:
	return tour.entrants[i]


func _rebuild() -> void:
	menu.clear()
	if int(tour.get("champion", -1)) >= 0:
		menu.add("done", "FINISH")
		_setup_champion()
		return
	var m := _current()
	var human: bool = not _ent(m.a).bot or not _ent(m.b).bot
	if human:
		menu.add("play", "PLAY MATCH!")
	else:
		menu.add("watch", "WATCH CPU MATCH")
		menu.add("sim", "SIMULATE RESULT")
	menu.add("quit", "QUIT TOURNAMENT", "button", "", {"color": Pal.UI_BAD})


func _setup_champion() -> void:
	if champ:
		return
	var e := _ent(int(tour.champion))
	champ = CatPuppet.new()
	champ.skin = Sprites.full_skin(e.skin)
	champ.preview_state = "victory"
	champ.scale = Vector2(4, 4)
	champ.position = Vector2(240, 190)
	add_child(champ)
	for i in 100:
		confetti.append([Vector2(_rng.randf_range(0, 480), _rng.randf_range(-300, 0)), Color.from_hsv(_rng.randf(), 0.7, 1.0), _rng.randf_range(20, 60)])
	AudioHub.play("victory")
	if not e.bot:
		SaveData.add_progress("tournaments", 1)
		SaveData.check_achievements()
		SaveData.save()


func _apply_result(summary: Dictionary) -> void:
	var m := _current()
	if m.is_empty():
		return
	var wins: Array = summary.get("winner_slots", [])
	var w: int = -1
	if not wins.is_empty():
		var ws: int = int(wins[0])
		if int(_ent(m.a).slot) == ws:
			w = m.a
		elif int(_ent(m.b).slot) == ws:
			w = m.b
	if w < 0:
		# Draws are settled by a coin flip.
		w = m.a if _rng.randf() < 0.5 else m.b
	_set_winner(w)


func _set_winner(w: int) -> void:
	var m := _current()
	m.winner = w
	var rounds: Array = tour.rounds
	var r: int = tour.cur_round
	var mi: int = tour.cur_match
	if r + 1 < rounds.size():
		var nxt: Dictionary = rounds[r + 1][mi / 2]
		if mi % 2 == 0:
			nxt.a = w
		else:
			nxt.b = w
	mi += 1
	if mi >= rounds[r].size():
		mi = 0
		r += 1
	tour.cur_round = r
	tour.cur_match = mi
	if r >= rounds.size():
		tour.champion = w


func _launch() -> void:
	var m := _current()
	var a: Dictionary = _ent(m.a).duplicate(true)
	var b: Dictionary = _ent(m.b).duplicate(true)
	var rules: Dictionary = tour.rules.duplicate()
	var fmt: String = rules.get("match_format", "stock2")
	var mode := "stock"
	match fmt:
		"stock2": rules["stocks"] = 2
		"stock3": rules["stocks"] = 3
		"rounds2":
			mode = "duel"
			rules["rounds"] = 2
	a.team = 0
	b.team = 1
	Router.session = {"mode": mode, "arena": tour.get("arena", "random"), "rules": rules, "players": [a, b]}
	Router.goto("match")


func _on_menu(r: Dictionary) -> void:
	if r.action == "back":
		return
	if r.action != "activate":
		return
	match r.id:
		"play", "watch":
			_launch()
		"sim":
			var m := _current()
			_set_winner(m.a if _rng.randf() < 0.5 else m.b)
			AudioHub.play("ui_select")
			_rebuild()
		"quit", "done":
			Router.tournament = {}
			Router.goto("main_menu")


func _update(dt: float) -> void:
	super._update(dt)
	for c in confetti:
		c[0].y += c[2] * dt
		if c[0].y > 270:
			c[0].y = -4


func _paint() -> void:
	UI.title(self, "TOURNAMENT", 6)
	if int(tour.get("champion", -1)) >= 0:
		var e := _ent(int(tour.champion))
		for c in confetti:
			draw_rect(Rect2(c[0], Vector2(2, 2)), c[1])
		PixelFont.draw_text(self, Vector2(240, 40), "CHAMPION!", Pal.UI_HILITE, 3, 1)
		PixelFont.draw_text(self, Vector2(240, 70), str(e.name), Pal.player_color(int(e.slot)), 2, 1)
		UI.icon(self, "trophy", Vector2(222, 92), 6.0)
		draw_rect(Rect2(190, 190, 100, 3), Color(0, 0, 0, 0.4))
		menu.draw(self, t)
		return
	var rounds: Array = tour.rounds
	var col_w := 440.0 / rounds.size()
	for r in rounds.size():
		var ms: Array = rounds[r]
		var label := "FINAL" if r == rounds.size() - 1 else ("SEMIS" if r == rounds.size() - 2 else "ROUND %d" % (r + 1))
		PixelFont.draw_text(self, Vector2(20 + r * col_w + col_w * 0.5 - 10, 30), label, Pal.UI_DIM, 1, 1)
		for i in ms.size():
			var m: Dictionary = ms[i]
			var span := 148.0 / ms.size()
			var y := 44.0 + span * i + span * 0.5 - 12
			var x := 20.0 + r * col_w
			var cur: bool = r == int(tour.cur_round) and i == int(tour.cur_match)
			UI.panel(self, Rect2(x, y, col_w - 24, 24), Pal.UI_PANEL2 if cur else Pal.UI_PANEL, Pal.UI_HILITE if cur else Pal.UI_EDGE, false)
			for k in 2:
				var idx: int = m.a if k == 0 else m.b
				var yy := y + 3 + k * 11
				if idx < 0:
					PixelFont.draw_text(self, Vector2(x + 4, yy), "?", Pal.UI_LOCK)
					continue
				var e: Dictionary = _ent(idx)
				var won: bool = int(m.winner) == idx
				var lost: bool = int(m.winner) >= 0 and not won
				CatPuppet.draw_head(self, Vector2(x + 8, yy + 4), e.skin, 0.75)
				PixelFont.draw_text(self, Vector2(x + 16, yy), str(e.name).substr(0, 8) + ("" if e.bot else " ★"), Pal.UI_LOCK if lost else (Pal.UI_GOOD if won else Pal.player_color(int(e.slot))))
	var m2 := _current()
	if not m2.is_empty():
		var a := _ent(m2.a)
		var b := _ent(m2.b)
		PixelFont.draw_text(self, Vector2(150, 200), "NEXT MATCH", Pal.UI_DIM, 1, 1)
		PixelFont.draw_text(self, Vector2(150, 212), "%s  VS  %s" % [a.name, b.name], Pal.UI_HILITE, 1, 1)
		var fmt: String = tour.rules.get("match_format", "stock2")
		PixelFont.draw_text(self, Vector2(150, 224), ModeDefs.rule_label("match_format", fmt), Pal.UI_DIM, 1, 1)
	menu.draw(self, t)
	UI.hints(self, "★ = HUMAN PLAYER · CPU MATCHES CAN BE WATCHED OR SIMULATED")
