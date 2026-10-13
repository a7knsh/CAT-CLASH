extends BaseMode
## King of the Hill: stand in the glowing zone ALONE (or only with teammates)
## to earn points. The zone hops to a new spot periodically. First to the
## target or highest score at time-up wins.

const MOVE_EVERY := 20.0

var zones: Array = []
var zone_idx := 0
var zone := Rect2()
var move_t := MOVE_EVERY
var time_left := 180.0
var owner_key: Variant = null
var points: Dictionary = {}
var tick_acc := 0.0


func respawns() -> bool:
	return true


func uses_score() -> bool:
	return true


func respawn_delay() -> float:
	return 2.5


func setup() -> void:
	var t := int(rules.get("time", 180))
	time_left = float(t if t > 0 else 600)
	# Candidate hills: centres of platforms and solid tops (from the arena data).
	var d: Dictionary = ctl.arena.def
	var cands: Array = []
	for r in d.platforms:
		cands.append(Rect2(r.position.x + r.size.x * 0.5 - 28, r.position.y - 34, 56, 34))
	for r in d.solids:
		if r.size.x >= 80:
			cands.append(Rect2(r.position.x + r.size.x * 0.5 - 30, r.position.y - 34, 60, 34))
	cands.shuffle()
	zones = cands
	if zones.is_empty():
		zones = [Rect2(ctl.arena.size.x * 0.5 - 30, 200, 60, 34)]
	zone = zones[0]


func on_round_start() -> void:
	super.on_round_start()
	for f in ctl.players():
		f.stocks = 999


func on_ko(victim: CatFighter, _killer: CatFighter, _cause: String) -> void:
	victim.respawn_timer = respawn_delay()


func tick(dt: float) -> void:
	super.tick(dt)
	time_left -= dt
	move_t -= dt
	if move_t <= 0.0:
		move_t = MOVE_EVERY
		zone_idx = (zone_idx + 1) % zones.size()
		zone = zones[zone_idx]
		ctl.announce("THE HILL MOVED!", Pal.UI_HILITE)
		AudioHub.play("powerup", -4.0)
	var inside := {}
	for f in ctl.players():
		if f.alive_in_round() and zone.has_point(f.global_position + Vector2(0, -2)):
			inside[key_of(f)] = true
	owner_key = inside.keys()[0] if inside.size() == 1 else null
	if owner_key != null:
		tick_acc += dt
		if tick_acc >= 1.0:
			tick_acc -= 1.0
			points[owner_key] = int(points.get(owner_key, 0)) + 1
			for f in ctl.players():
				if key_of(f) == owner_key:
					f.score = points[owner_key]
			AudioHub.play("coin", -12.0)
	else:
		tick_acc = 0.0


func check_round_end() -> Dictionary:
	var target := int(rules.get("hill_target", 60))
	var best_k: Variant = null
	var best := -1
	var tie := false
	for k in points.keys():
		if int(points[k]) > best:
			best = int(points[k])
			best_k = k
			tie = false
		elif int(points[k]) == best:
			tie = true
	if best >= target or (time_left <= 0.0 and not tie and best_k != null):
		var winners: Array = ctl.players().filter(func(f): return key_of(f) == best_k)
		return {"winners": winners, "key": best_k, "text": win_text(winners), "color": win_color(winners)}
	if time_left <= -30.0:
		return {"winners": [], "key": null, "text": "DRAW!", "color": Pal.UI_TEXT}
	return {}


func hud_top() -> String:
	if time_left <= 0.0:
		return "OVERTIME!"
	return "%s · TO %d" % [UI.fmt_time(time_left), int(rules.get("hill_target", 60))]


func hud_player_text(f: CatFighter) -> String:
	return "%d" % int(points.get(key_of(f), 0))


func camera_points() -> Array:
	return [zone.get_center()]


func bot_objective(f: CatFighter) -> Variant:
	var inside := zone.has_point(f.global_position + Vector2(0, -2))
	return {"pos": Vector2(zone.get_center().x, zone.end.y - 2), "force": not inside}


func _rank_score(f: CatFighter) -> float:
	return float(points.get(key_of(f), 0))


func extra_progress() -> Dictionary:
	return {}


func draw_world(ci: CanvasItem, t: float) -> void:
	var c := Pal.UI_HILITE
	if owner_key != null:
		c = Pal.team_color(owner_key) if teams_active() else Pal.player_color(_slot_for_key(owner_key))
	var a := 0.12 + 0.06 * sin(t * 4.0)
	ci.draw_rect(zone, Color(c, a))
	for x in range(int(zone.position.x), int(zone.end.x), 6):
		var h := 2.0 + sin(t * 5.0 + x * 0.3) * 1.5
		ci.draw_rect(Rect2(x, zone.end.y - h - 1, 3, h), Color(c, 0.6))
	ci.draw_rect(Rect2(zone.position, Vector2(1, zone.size.y)), Color(c, 0.6))
	ci.draw_rect(Rect2(Vector2(zone.end.x - 1, zone.position.y), Vector2(1, zone.size.y)), Color(c, 0.6))
	PixelFont.draw_outlined(ci, Vector2(zone.get_center().x, zone.position.y - 10), "HILL %d" % int(ceil(move_t)), c)


func _slot_for_key(k: int) -> int:
	for f in ctl.players():
		if key_of(f) == k:
			return f.slot
	return 0


func net_vars() -> Array:
	return ["zones", "zone", "zone_idx", "move_t", "owner_key", "points", "time_left"]
