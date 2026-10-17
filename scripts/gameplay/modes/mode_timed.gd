extends BaseMode
## Timed Battle: unlimited respawns. +1 point per KO, -1 per self-destruct.
## Highest score when time runs out wins; ties go to Sudden Death.

var time_left := 120.0
var sudden_death := false


func respawns() -> bool:
	return not sudden_death


func uses_score() -> bool:
	return true


func setup() -> void:
	var t := int(rules.get("time", 120))
	time_left = float(t if t > 0 else 300)


func on_round_start() -> void:
	super.on_round_start()
	for f in ctl.players():
		f.stocks = 999


func on_ko(victim: CatFighter, killer: CatFighter, _cause: String) -> void:
	if killer and is_instance_valid(killer) and killer != victim:
		_add_score(killer, 1)
	else:
		_add_score(victim, -1)
	if sudden_death:
		_eliminate(victim)
	else:
		victim.respawn_timer = respawn_delay()


func _add_score(f: CatFighter, n: int) -> void:
	if teams_active():
		for o in ctl.players():
			if o.team == f.team:
				o.score += n
	else:
		f.score += n


func tick(dt: float) -> void:
	super.tick(dt)
	if sudden_death:
		return
	time_left -= dt
	if time_left <= 0.0:
		time_left = 0.0
		var best := -INF
		for f in ctl.players():
			best = maxf(best, f.score)
		var tied: Array = ctl.players().filter(func(f): return f.score == best)
		var keys := {}
		for f in tied:
			keys[key_of(f)] = true
		if keys.size() > 1:
			sudden_death = true
			ctl.show_banner("SUDDEN DEATH!", Pal.UI_BAD, 2.0)
			AudioHub.play("warning", 0.0)
			for f in ctl.players():
				if f in tied:
					if f.dead:
						f.respawn(ctl.safe_spawn_point(f))
					f.max_hp = 30.0
					f.hp = 30.0
				else:
					_eliminate(f)
					if not f.dead:
						f.vanish()
		else:
			for f in ctl.players():
				if not (f in tied):
					_eliminate(f)


func check_round_end() -> Dictionary:
	if time_left > 0.0 and not sudden_death:
		return {}
	return super.check_round_end()


func final_winners() -> Array:
	return ctl.round_result.get("winners", [])


func hud_top() -> String:
	if sudden_death:
		return "SUDDEN DEATH"
	return UI.fmt_time(time_left)


func hud_player_text(f: CatFighter) -> String:
	return "%+d PTS" % f.score if f.score != 0 else "0 PTS"


func _rank_score(f: CatFighter) -> float:
	return f.score * 100.0 + f.stats.kos


func respawn_delay() -> float:
	return 1.6


func net_vars() -> Array:
	return ["time_left", "sudden_death"]
