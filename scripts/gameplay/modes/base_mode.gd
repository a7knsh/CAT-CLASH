class_name BaseMode
extends RefCounted
## Base class for game modes. The MatchController calls these hooks; a mode
## overrides only what it needs. Default behaviour is "last cat/team
## standing, no respawns", which FFA / Teams / Duel use directly.

var ctl: Node
var rules: Dictionary
var mode_id := ""
var elim_order: Array = []


func setup() -> void:
	pass


# ------------------------------------------------------------- properties

func uses_rounds() -> bool:
	return false


func respawns() -> bool:
	return false


func uses_score() -> bool:
	return false


func teams_active() -> bool:
	var t: String = ModeDefs.get_def(mode_id).get("teams", "none")
	return t == "forced" or t == "coop" or (t == "optional" and bool(rules.get("teams_on", false)))


## Colour players by team (false in co-op modes, where everyone shares a team).
func show_team_colors() -> bool:
	return teams_active() and ModeDefs.get_def(mode_id).get("teams", "none") != "coop"


func skip_countdown() -> bool:
	return false


func allow_item_spawns() -> bool:
	return true


func dummy_infinite() -> bool:
	return false


func hide_panels() -> bool:
	return false


func respawn_delay() -> float:
	return 2.0


# ----------------------------------------------------------------- flow

func on_round_start() -> void:
	elim_order.clear()


func on_fight_start() -> void:
	pass


func tick(dt: float) -> void:
	_tick_respawns(dt)


func _tick_respawns(dt: float) -> void:
	for f in ctl.players():
		if f.is_dummy:
			continue
		if f.dead and not f.eliminated and f.respawn_timer > 0.0:
			f.respawn_timer -= dt
			if f.respawn_timer <= 0.0:
				f.respawn(ctl.safe_spawn_point(f))


func on_ko(victim: CatFighter, _killer: CatFighter, _cause: String) -> void:
	if victim.is_enemy:
		return
	if respawns():
		victim.stocks -= 1
		if victim.stocks <= 0:
			_eliminate(victim)
		else:
			victim.respawn_timer = respawn_delay()
	else:
		_eliminate(victim)


func _eliminate(f: CatFighter) -> void:
	if f.eliminated:
		return
	f.eliminated = true
	elim_order.append(f)


func key_of(f: CatFighter) -> int:
	return f.team


func check_round_end() -> Dictionary:
	var groups := {}
	for f in ctl.players():
		if not f.eliminated:
			if not groups.has(key_of(f)):
				groups[key_of(f)] = []
			groups[key_of(f)].append(f)
	if ctl.players().size() < 2 and groups.size() == 1:
		return {}
	if groups.size() > 1:
		return {}
	if groups.is_empty():
		return {"winners": [], "key": null, "text": "DRAW!", "color": Pal.UI_TEXT}
	var k: int = groups.keys()[0]
	var winners: Array = ctl.players().filter(func(f): return key_of(f) == k)
	return {"winners": winners, "key": k, "text": win_text(winners), "color": win_color(winners)}


func win_text(winners: Array) -> String:
	if winners.is_empty():
		return "DRAW!"
	if teams_active() and winners.size() > 1:
		return "%s TEAM WINS!" % Pal.team_name(winners[0].team)
	return "%s WINS!" % winners[0].display_name


func win_color(winners: Array) -> Color:
	if winners.is_empty():
		return Pal.UI_TEXT
	return Pal.team_color(winners[0].team) if teams_active() else Pal.player_color(winners[0].slot)


func match_over(round_wins: Dictionary) -> bool:
	if not uses_rounds():
		return true
	var target := int(rules.get("rounds", 3))
	for k in round_wins.keys():
		if int(round_wins[k]) >= target:
			return true
	return false


# -------------------------------------------------------------- results

func final_winners() -> Array:
	if uses_rounds():
		var best_k: Variant = null
		var best := -1
		for k in ctl.round_wins.keys():
			if int(ctl.round_wins[k]) > best:
				best = int(ctl.round_wins[k])
				best_k = k
		if best_k == null:
			return []
		return ctl.players().filter(func(f): return key_of(f) == best_k)
	return ctl.round_result.get("winners", [])


func final_ranking() -> Array:
	var winners := final_winners()
	var rest: Array = ctl.players().filter(func(f): return not (f in winners))
	rest.sort_custom(func(a, b): return _rank_score(a) > _rank_score(b))
	var out: Array = winners.duplicate()
	out.append_array(rest)
	return out


func _rank_score(f: CatFighter) -> float:
	var s = float(ctl.round_wins.get(key_of(f), 0)) * 1000.0 + f.score * 100.0 + f.stocks * 50.0 + f.stats.kos * 10.0
	var idx := elim_order.find(f)
	if idx >= 0:
		s += idx
	else:
		s += 500.0
	return s


func final_title(winners: Array) -> String:
	if winners.is_empty():
		return "NO CONTEST"
	return win_text(winners)


func extra_progress() -> Dictionary:
	return {}


# ------------------------------------------------------------------ HUD

func hud_fighters() -> Array:
	return ctl.players()


func hud_top() -> String:
	if uses_rounds():
		return "ROUND %d" % ctl.round_num
	return ""


func hud_sub() -> String:
	if uses_rounds() and not ctl.round_wins.is_empty():
		var parts: Array = []
		for k in ctl.round_wins.keys():
			var label := Pal.team_name(k) if teams_active() else _name_for_key(k)
			parts.append("%s %d" % [label, int(ctl.round_wins[k])])
		return "  ".join(parts) + "  (FIRST TO %d)" % int(rules.get("rounds", 3))
	return ""


func _name_for_key(k: int) -> String:
	for f in ctl.players():
		if key_of(f) == k:
			return f.display_name
	return "?"


func hud_player_text(_f: CatFighter) -> String:
	return ""


func hud_lines() -> Array:
	return []


# ------------------------------------------------------------ world & AI

func camera_points() -> Array:
	return []


func draw_world(_ci: CanvasItem, _t: float) -> void:
	pass


func bot_objective(_f: CatFighter) -> Variant:
	return null


func bot_wants_fish(_f: CatFighter) -> bool:
	return false


func can_take_fish(_f: CatFighter) -> bool:
	return true


func on_fish_taken(_f: CatFighter) -> void:
	pass


func on_objective_lost(_it: WeaponItem) -> void:
	pass


func on_pedestal_taken(_pos: Vector2, _id: String) -> void:
	pass


func reset_positions() -> void:
	var pts: Array = ctl.arena.spawn_points()
	var i := 0
	for f in ctl.fighters:
		if f.is_decoy:
			continue
		f.respawn(pts[i % pts.size()], false)
		i += 1


func apply_dummy_ai() -> void:
	pass


func spawn_training_weapon(_id: String, _device: String) -> void:
	pass
