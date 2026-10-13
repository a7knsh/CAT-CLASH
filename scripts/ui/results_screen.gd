extends Screen
## Match results: podium with victory/defeat poses, stats table, fun awards,
## rewards (yarn, achievements) and rematch options.

var res: Dictionary
var puppets: Array = []
var awards: Array = []
var confetti: Array = []
var _rng := RandomNumberGenerator.new()


func _build() -> void:
	_rng.randomize()
	res = Router.last_result
	var players: Array = res.get("players", [])
	var podium_x := [120.0, 70.0, 170.0, 220.0]
	var podium_y := [120.0, 132.0, 140.0, 146.0]
	for i in mini(players.size(), 4):
		var p: Dictionary = players[i]
		var cp := CatPuppet.new()
		cp.skin = Sprites.full_skin(p.skin)
		cp.preview_state = "victory" if p.won else ("idle" if i < 3 else "defeat")
		if not p.won and i == players.size() - 1 and players.size() > 1:
			cp.preview_state = "defeat"
		cp.preview_facing = 1 if i % 2 == 0 else -1
		cp.scale = Vector2(2, 2)
		cp.position = Vector2(podium_x[i], podium_y[i])
		add_child(cp)
		puppets.append(cp)
	_make_awards(players)
	for i in 80:
		confetti.append([Vector2(_rng.randf_range(0, 480), _rng.randf_range(-270, 0)), Color.from_hsv(_rng.randf(), 0.7, 1.0), _rng.randf_range(20, 50)])
	menu.pos = Vector2(320, 214)
	menu.width = 150
	menu.line_h = 13
	menu.max_visible = 3
	var tour: bool = not Router.tournament.is_empty()
	if Net.active:
		if Net.is_host:
			menu.add("net_rematch", "REMATCH (EVERYONE)")
			menu.add("net_lobby", "BACK TO LOBBY")
			menu.add("net_end", "END LAN SESSION", "button", "", {"color": Pal.UI_BAD})
		else:
			menu.add("net_wait", "WAITING FOR HOST...", "button", "", {"disabled": true})
			menu.add("net_leave", "LEAVE GAME", "button", "", {"color": Pal.UI_BAD})
			menu.index = 1
	else:
		if not tour:
			menu.add("rematch", "REMATCH")
			menu.add("setup", "CHANGE SETUP")
		menu.add("menu", "MAIN MENU")
	AudioHub.play("victory", -2.0)
	AudioHub.play_music("menu", {"tempo": 128, "root": 60, "scale": "major", "seed": 7})


func _make_awards(players: Array) -> void:
	var defs := [
		["kos", "KO KING", true], ["damage_dealt", "DAMAGE DEALER", true], ["best_combo", "COMBO MASTER", true],
		["parries", "PARRY GOD", true], ["throw_hits", "YEET MASTER", true], ["falls", "FREQUENT FLYER", true],
		["damage_taken", "PUNCHING BAG", true], ["ringouts", "SENT TO ORBIT", true],
	]
	for d in defs:
		var best: Dictionary = {}
		var bv := 0.0
		for p in players:
			var v := float(p.stats.get(d[0], 0))
			if v > bv:
				bv = v
				best = p
		if not best.is_empty() and bv > 0:
			awards.append({"name": d[1], "who": best.name, "slot": int(best.slot), "val": int(bv)})
	awards.shuffle()
	awards = awards.slice(0, 4)


func _on_menu(r: Dictionary) -> void:
	if r.action == "back":
		if not Net.active:
			_go("menu")
	elif r.action == "activate":
		_go(r.id)


func _go(id: String) -> void:
	match id:
		"net_rematch":
			var ses: Dictionary = Net.current_session.duplicate(true)
			Net.start_match(ses)
		"net_lobby":
			Net.return_to_lobby()
		"net_end", "net_leave":
			Net.leave()
			Router.goto("main_menu")
		"rematch":
			Router.session = res.get("session", Router.session)
			Router.goto("match")
		"setup":
			Router.session = res.get("session", Router.session)
			Router.goto("lobby")
		_:
			Router.tournament = {}
			Router.goto("main_menu")


func _update(dt: float) -> void:
	super._update(dt)
	for c in confetti:
		c[0].y += c[2] * dt
		c[0].x += sin(t * 2.0 + c[2]) * 10.0 * dt
		if c[0].y > 270:
			c[0].y = -5


func _paint() -> void:
	var title: String = res.get("title", "RESULTS")
	var col := Pal.UI_HILITE
	var wins: Array = res.get("winner_slots", [])
	if not wins.is_empty():
		col = Pal.player_color(int(wins[0]))
	if bool(res.get("teams", false)) and not res.get("players", []).is_empty():
		col = Pal.team_color(int(res.players[0].team))
	if not wins.is_empty() and Settings.flash_ok():
		for c in confetti:
			draw_rect(Rect2(c[0], Vector2(2, 2)), c[1])
	UI.title(self, title, 6, col)
	# Podium
	var steps := [Rect2(100, 120, 40, 50), Rect2(50, 132, 40, 38), Rect2(150, 140, 40, 30), Rect2(200, 146, 40, 24)]
	var players: Array = res.get("players", [])
	for i in mini(players.size(), 4):
		var r: Rect2 = steps[i]
		UI.panel(self, r, Pal.UI_PANEL2, Pal.player_color(int(players[i].slot)), false)
		PixelFont.draw_text(self, r.position + Vector2(r.size.x * 0.5, 4), str(i + 1), Pal.UI_HILITE if i == 0 else Pal.UI_TEXT, 2, 1)
		PixelFont.draw_text(self, Vector2(r.position.x + r.size.x * 0.5, r.end.y + 3), str(players[i].name).substr(0, 7), Pal.player_color(int(players[i].slot)), 1, 1)
	# Stats table
	var tx := 252.0
	var ty := 32.0
	UI.panel(self, Rect2(tx - 4, ty - 4, 224, 20 + players.size() * 12 + 4))
	var cols := ["", "KO", "FALL", "DMG", "COMBO", "PARRY"]
	var cx := [tx, tx + 70, tx + 96, tx + 128, tx + 162, tx + 196]
	for k in cols.size():
		PixelFont.draw_text(self, Vector2(cx[k], ty), cols[k], Pal.UI_DIM)
	for i in players.size():
		var p: Dictionary = players[i]
		var st: Dictionary = p.stats
		var y := ty + 12 + i * 12
		PixelFont.draw_text(self, Vector2(cx[0], y), str(p.name).substr(0, 10), Pal.player_color(int(p.slot)))
		PixelFont.draw_text(self, Vector2(cx[1], y), str(int(st.get("kos", 0))), Pal.UI_TEXT)
		PixelFont.draw_text(self, Vector2(cx[2], y), str(int(st.get("falls", 0))), Pal.UI_TEXT)
		PixelFont.draw_text(self, Vector2(cx[3], y), str(int(st.get("damage_dealt", 0))), Pal.UI_TEXT)
		PixelFont.draw_text(self, Vector2(cx[4], y), str(int(st.get("best_combo", 0))), Pal.UI_TEXT)
		PixelFont.draw_text(self, Vector2(cx[5], y), str(int(st.get("parries", 0))), Pal.UI_TEXT)
	# Awards
	var ay := ty + 30 + players.size() * 12
	for i in awards.size():
		var a: Dictionary = awards[i]
		PixelFont.draw_text(self, Vector2(tx, ay + i * 10), "★ " + a.name, Pal.UI_HILITE)
		PixelFont.draw_text(self, Vector2(tx + 220, ay + i * 10), "%s (%d)" % [str(a.who).substr(0, 8), a.val], Pal.player_color(a.slot), 1, 2)
	# Rewards
	var rw: Dictionary = res.get("rewards", {})
	var ry := 186.0
	if not rw.is_empty():
		UI.icon(self, "yarn", Vector2(14, ry), 1.0)
		PixelFont.draw_text(self, Vector2(24, ry), "+%d YARN  (TOTAL %d)" % [int(rw.get("yarn", 0)), int(SaveData.data.yarn)], Pal.UI_ACCENT)
		var achs: Array = rw.get("achievements", [])
		for i in mini(achs.size(), 3):
			PixelFont.draw_text(self, Vector2(14, ry + 11 + i * 10), "★ " + str(AchievementDefs.ALL[achs[i]].name), Pal.UI_HILITE)
	PixelFont.draw_text(self, Vector2(14, 250), "%s · %s · %s" % [ModeDefs.get_def(res.get("mode", "ffa")).name, ArenaDefs.get_def(res.get("arena", "garden")).name, UI.fmt_time(res.get("duration", 0.0))], Pal.UI_DIM)
	menu.draw(self, t)
