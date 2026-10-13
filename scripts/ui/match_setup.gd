extends Screen
## Match setup: arena (with live layout preview) and mode-specific rules.
## Tournament setup creates the bracket here.

var mode_id := "ffa"
var mdef: Dictionary
var rules: Dictionary
var arena := "random"
var arenas: Array = []


func _build() -> void:
	mode_id = Router.session.get("mode", "ffa")
	mdef = ModeDefs.get_def(mode_id)
	rules = ModeDefs.default_rules(mode_id)
	rules["bot_level"] = int(Settings.get_value("bot_difficulty"))
	var last: Dictionary = SaveData.data.get("last_setup", {})
	if last.get("mode", "") == mode_id:
		for k in last.get("rules", {}).keys():
			rules[k] = last.rules[k]
		arena = last.get("arena", "random")
	elif mdef.get("defaults", {}).has("arena"):
		arena = mdef.defaults.arena
	arenas = ["random"]
	arenas.append_array(ArenaDefs.ORDER)
	menu.pos = Vector2(16, 40)
	menu.width = 210
	menu.line_h = 14
	menu.max_visible = 13
	_rebuild()


func _rebuild() -> void:
	var keep := menu.index
	menu.clear()
	menu.add("arena", "ARENA", "choice", _arena_name(arena))
	for r in mdef.rules:
		if r == "item_rate" and not bool(rules.get("items", true)):
			continue
		if r == "friendly_fire" and mdef.teams == "optional" and not bool(rules.get("teams_on", false)):
			continue
		menu.add(r, ModeDefs.RULES[r].label, "choice", ModeDefs.rule_label(r, rules.get(r)))
	menu.add("start", "START!" if mode_id != "tournament" else "CREATE BRACKET", "button", "", {"color": Pal.UI_GOOD})
	menu.add("back", "BACK")
	menu.index = clampi(keep, 0, menu.items.size() - 1)


func _arena_name(id: String) -> String:
	if id == "random":
		return "RANDOM"
	return ArenaDefs.ALL[id].name


func _on_menu(r: Dictionary) -> void:
	match r.action:
		"back":
			Router.goto("lobby")
		"change":
			if r.id == "arena":
				arena = cycle(arenas, arena, r.delta)
			else:
				rules[r.id] = cycle(ModeDefs.RULES[r.id].values, rules.get(r.id), r.delta)
			_rebuild()
		"activate":
			if r.id == "back":
				Router.goto("lobby")
			elif r.id == "start":
				_start()


func _start() -> void:
	Router.session["rules"] = rules.duplicate()
	Router.session["arena"] = arena
	SaveData.data["last_setup"] = {"mode": mode_id, "rules": rules.duplicate(), "arena": arena, "players": Router.session.get("players", [])}
	SaveData.save()
	for p in Router.session.players:
		p["bot_level"] = int(rules.get("bot_level", 1))
	if mode_id == "tournament":
		_create_tournament()
		Router.goto("tournament")
		return
	Router.tournament = {}
	Router.goto("match")


func _create_tournament() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var size := int(rules.get("bracket", 4))
	var entrants: Array = []
	var used: Array = []
	for p in Router.session.players:
		var c: Dictionary = p.duplicate(true)
		if c.get("bot", false):
			c.name = str(SaveData.get_preset(c.preset).name).substr(0, 8)
		entrants.append(c)
		used.append(c.preset)
	var slot := entrants.size()
	while entrants.size() < size:
		var pid := Sessions.random_preset_id(rng, used)
		used.append(pid)
		var c2 := Sessions.player_cfg(slot, "", pid, slot, -1, true, int(rules.get("bot_level", 1)))
		c2.name = str(SaveData.get_preset(pid).name).substr(0, 8)
		entrants.append(c2)
		slot += 1
	while entrants.size() > size:
		entrants.pop_back()
	for i in entrants.size():
		entrants[i].slot = i
	entrants.shuffle()
	var first: Array = []
	for i in range(0, entrants.size(), 2):
		first.append({"a": i, "b": i + 1, "winner": -1})
	var rounds: Array = [first]
	var n := first.size()
	while n > 1:
		n /= 2
		var rr: Array = []
		for i in n:
			rr.append({"a": -1, "b": -1, "winner": -1})
		rounds.append(rr)
	Router.tournament = {"active": true, "entrants": entrants, "rounds": rounds, "cur_round": 0, "cur_match": 0,
		"rules": rules.duplicate(), "arena": arena, "champion": -1}


func _paint() -> void:
	UI.title(self, mdef.name + " · SETUP", 6)
	menu.draw(self, t)
	# Arena preview
	var pr := Rect2(240, 40, 224, 126)
	UI.panel(self, pr)
	var aid := arena
	if aid == "random":
		aid = ArenaDefs.ORDER[int(t * 1.5) % ArenaDefs.ORDER.size()]
	var d: Dictionary = ArenaDefs.ALL[aid]
	var inner := pr.grow(-4)
	for i in 6:
		draw_rect(Rect2(inner.position.x, inner.position.y + i * inner.size.y / 6.0, inner.size.x, inner.size.y / 6.0 + 1), d.sky[0].lerp(d.sky[1], i / 5.0))
	var sc: float = minf(inner.size.x / d.size.x, inner.size.y / d.size.y)
	var off = inner.position + (inner.size - d.size * sc) * 0.5
	for r in d.solids:
		draw_rect(Rect2(off + r.position * sc, r.size * sc), d.ground[1])
		draw_rect(Rect2(off + r.position * sc, Vector2(r.size.x * sc, 1)), d.ground[0])
	for r in d.platforms:
		draw_rect(Rect2(off + r.position * sc, Vector2(r.size.x * sc, 1.5)), d.plat)
	for m in d.get("moving", []):
		var mr: Rect2 = m.rect
		draw_rect(Rect2(off + mr.position * sc, Vector2(mr.size.x * sc, 1.5)), d.accent)
	for i in mini(4, d.spawns.size()):
		draw_rect(Rect2(off + d.spawns[i] * sc - Vector2(1, 3), Vector2(2, 3)), Pal.player_color(i))
	PixelFont.draw_text(self, Vector2(pr.position.x + 4, pr.end.y + 4), d.name if arena != "random" else "RANDOM ARENA", Pal.UI_HILITE)
	PixelFont.draw_text(self, Vector2(pr.position.x + 4, pr.end.y + 14), d.tags if arena != "random" else "SURPRISE!", Pal.UI_ACCENT)
	var lines := PixelFont.wrap(d.desc if arena != "random" else "A random arena is chosen each match.", 220)
	for i in lines.size():
		PixelFont.draw_text(self, Vector2(pr.position.x + 4, pr.end.y + 26 + i * 9), lines[i], Pal.UI_DIM)
	# Players summary
	var y := 228.0
	var x := 240.0
	for p in Router.session.get("players", []):
		CatPuppet.draw_head(self, Vector2(x + 8, y + 6), p.skin, 1.0)
		PixelFont.draw_text(self, Vector2(x + 18, y + 2), ("CPU" if p.bot else "P%d" % (int(p.slot) + 1)), Pal.player_color(int(p.slot)))
		x += 56
	UI.hints(self, "LEFT/RIGHT CHANGE · CONFIRM ON START · BACK: ESC/B")
