extends BaseMode
## Capture the Fish: two teams, one golden fish. Grab it (pick-up button),
## carry it to your team's basket to score. Carriers are slower, can't attack
## with weapons, drop it when hit hard - and can THROW it to a teammate.

var bases: Array = []      # [Vector2 team0, Vector2 team1]
var fish: WeaponItem = null
var fish_home := Vector2.ZERO
var free_t := 0.0
var respawn_fish_t := 0.0
var team_score := {0: 0, 1: 0}
var time_left := 240.0


func respawns() -> bool:
	return true


func uses_score() -> bool:
	return true


func respawn_delay() -> float:
	return 2.5


func setup() -> void:
	var t := int(rules.get("time", 240))
	time_left = float(t if t > 0 else 600)
	var pts: Array = ctl.arena.spawn_points()
	var left: Vector2 = pts[0]
	var right: Vector2 = pts[0]
	for p in pts:
		if p.x < left.x or (p.x == left.x and p.y > left.y):
			left = p
		if p.x > right.x or (p.x == right.x and p.y > right.y):
			right = p
	bases = [left, right]
	# The fish lives on solid ground near the middle: the main-floor spawn
	# point closest to the centre (never over a pit or a moving platform).
	var cx: float = ctl.arena.size.x * 0.5
	var best: Vector2 = pts[0]
	for i in mini(4, pts.size()):
		if absf(pts[i].x - cx) < absf(best.x - cx):
			best = pts[i]
	fish_home = Vector2(best.x + (cx - best.x) * 0.25, best.y - 40.0)
	var gy: float = ctl.arena.ground_y_at(fish_home.x, best.y - 60.0)
	if gy == INF or gy > best.y + 4.0:
		fish_home.x = best.x
	# Make sure there are exactly two teams.
	for f in ctl.players():
		f.team = clampi(f.team, 0, 1)


func on_round_start() -> void:
	super.on_round_start()
	for f in ctl.players():
		f.stocks = 999
		f.spawn_point = bases[f.team]
		f.global_position = bases[f.team] + Vector2(ctl.rng.randf_range(-12, 12), -40)
	_spawn_fish()


func _spawn_fish() -> void:
	if fish and is_instance_valid(fish):
		fish.queue_free()
	fish = ctl.spawn_item({"id": "fishobj", "ammo": -1, "dur": -1, "hits": 0}, fish_home + Vector2(0, -60), Vector2.ZERO, null, false)
	fish.permanent = true
	free_t = 0.0
	ctl.fx.ring(fish_home, Color("ffd23f"), 20.0)


func on_ko(victim: CatFighter, _killer: CatFighter, _cause: String) -> void:
	victim.respawn_timer = respawn_delay()


func carrier() -> CatFighter:
	for f in ctl.players():
		if f.weapon_id() == "fishobj" and f.alive_in_round():
			return f
	return null


func _fish_item() -> WeaponItem:
	for it in ctl.items():
		if it.id() == "fishobj":
			return it
	return null


func tick(dt: float) -> void:
	super.tick(dt)
	time_left -= dt
	var c := carrier()
	if c:
		var base: Vector2 = bases[c.team]
		if c.global_position.distance_to(base) < 26.0:
			team_score[c.team] = int(team_score[c.team]) + 1
			c.weapon = {}
			c.stats.fish_caps += 1
			for f in ctl.players():
				f.score = int(team_score[f.team])
			ctl.show_banner("%s TEAM SCORES!" % Pal.team_name(c.team), Pal.team_color(c.team), 1.6)
			AudioHub.play("round_win", 0.0)
			ctl.fx.burst(base + Vector2(0, -10), Color("ffd23f"), 24, 160.0)
			respawn_fish_t = 2.0
		return
	# Dead carrier dropped it into the void? The item handler calls on_objective_lost.
	var it := _fish_item()
	if it == null:
		if respawn_fish_t > 0.0:
			respawn_fish_t -= dt
			if respawn_fish_t <= 0.0:
				_spawn_fish()
		elif ctl.fighters.all(func(f): return f.weapon_id() != "fishobj"):
			respawn_fish_t = 1.0
		return
	if it.resting:
		free_t += dt
		if free_t > 10.0:
			ctl.fx.smoke(it.global_position, 6)
			it.queue_free()
			respawn_fish_t = 0.5
	else:
		free_t = 0.0


func on_objective_lost(_it: WeaponItem) -> void:
	respawn_fish_t = 1.5


func check_round_end() -> Dictionary:
	var target := int(rules.get("fish_target", 3))
	for k in [0, 1]:
		if int(team_score[k]) >= target:
			var winners: Array = ctl.players().filter(func(f): return f.team == k)
			return {"winners": winners, "key": k, "text": win_text(winners), "color": Pal.team_color(k)}
	if time_left <= 0.0:
		if int(team_score[0]) != int(team_score[1]):
			var k2 := 0 if int(team_score[0]) > int(team_score[1]) else 1
			var winners2: Array = ctl.players().filter(func(f): return f.team == k2)
			return {"winners": winners2, "key": k2, "text": win_text(winners2), "color": Pal.team_color(k2)}
		if time_left < -60.0:
			return {"winners": [], "key": null, "text": "DRAW!", "color": Pal.UI_TEXT}
	return {}


func win_text(winners: Array) -> String:
	if winners.is_empty():
		return "DRAW!"
	return "%s TEAM WINS!" % Pal.team_name(winners[0].team)


func hud_top() -> String:
	var ts := "%s %d - %d %s" % [Pal.team_name(0), int(team_score[0]), int(team_score[1]), Pal.team_name(1)]
	if time_left <= 0.0:
		return ts + " · OVERTIME"
	return ts + " · " + UI.fmt_time(time_left)


func hud_player_text(f: CatFighter) -> String:
	return "¤FISH" if f.weapon_id() == "fishobj" else ""


func camera_points() -> Array:
	var it := _fish_item()
	if it:
		return [it.global_position]
	return []


func can_take_fish(_f: CatFighter) -> bool:
	return true


func on_fish_taken(f: CatFighter) -> void:
	ctl.announce("%s HAS THE FISH!" % f.display_name, Pal.team_color(f.team))
	AudioHub.play("pickup", 0.0, 0.8)


func bot_wants_fish(f: CatFighter) -> bool:
	return carrier() == null


func bot_objective(f: CatFighter) -> Variant:
	var c := carrier()
	if c == f:
		return {"pos": bases[f.team], "force": true, "fish": true}
	if c and c.team == f.team:
		return null  # escort: fight nearby enemies
	if c and c.team != f.team:
		return {"pos": c.global_position, "force": true}
	var it := _fish_item()
	if it:
		return {"pos": it.global_position, "force": true, "fish": true}
	return null


func _rank_score(f: CatFighter) -> float:
	return float(team_score.get(f.team, 0)) * 100.0 + f.stats.fish_caps * 10.0 + f.stats.kos


func draw_world(ci: CanvasItem, t: float) -> void:
	for k in [0, 1]:
		var b: Vector2 = bases[k]
		var c := Pal.team_color(k)
		# Basket
		ci.draw_rect(Rect2(b + Vector2(-12, -8), Vector2(24, 8)).grow(1), Pal.OUTLINE)
		ci.draw_rect(Rect2(b + Vector2(-12, -8), Vector2(24, 8)), Color("a4683a"))
		for x in range(-12, 12, 4):
			ci.draw_rect(Rect2(b + Vector2(x, -8), Vector2(2, 8)), Color("6a3e22"))
		ci.draw_rect(Rect2(b + Vector2(-12, -9), Vector2(24, 2)), c)
		ci.draw_arc(b + Vector2(0, -4), 26.0, PI, TAU, 16, Color(c, 0.3 + 0.2 * sin(t * 4.0)), 1.0)
		PixelFont.draw_outlined(ci, b + Vector2(0, -22), Pal.team_shape(k) + Pal.team_name(k), c)
	var cr := carrier()
	if cr:
		PixelFont.draw_outlined(ci, cr.global_position + Vector2(0, -44), "¤", Color("ffd23f"))


func net_vars() -> Array:
	return ["bases", "team_score", "time_left", "fish_home"]
