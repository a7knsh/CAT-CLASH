extends BaseMode
## Survival: waves of Mecha-Mice and Alley Cats drop into the arena. Players
## share a team and each has a few lives. Co-op: clear all waves together.
## Compete: same waves, but the cat with the most enemy KOs wins.

var wave := 0
var to_spawn := 0
var spawn_t := 0.0
var break_t := 2.0
var state := "break"
var cleared := false
var failed := false
const MAX_CONCURRENT := 5


func respawns() -> bool:
	return true


func uses_score() -> bool:
	return rules.get("survival_rule", "coop") == "compete"


func respawn_delay() -> float:
	return 3.0


func on_round_start() -> void:
	super.on_round_start()
	wave = 0
	state = "break"
	break_t = 1.5


func on_ko(victim: CatFighter, killer: CatFighter, cause: String) -> void:
	if victim.is_enemy:
		if killer and not killer.is_enemy:
			killer.score += 1
		return
	super.on_ko(victim, killer, cause)


func _wave_size() -> int:
	return 2 + wave + (ctl.players().size() - 1)


func tick(dt: float) -> void:
	super.tick(dt)
	# Clean up enemies that have vanished.
	for f in ctl.fighters.duplicate():
		if f.is_enemy and f.dead:
			ctl.fighters.erase(f)
			f.queue_free()
	match state:
		"break":
			break_t -= dt
			if break_t <= 0.0:
				wave += 1
				to_spawn = _wave_size()
				state = "wave"
				spawn_t = 0.5
				ctl.show_banner("WAVE %d" % wave, Pal.UI_HILITE, 1.4)
				AudioHub.play("warning", -4.0)
				# Revive downed teammates between waves.
				for f in ctl.players():
					if not f.eliminated and not f.dead:
						f.heal(30.0)
		"wave":
			spawn_t -= dt
			var alive: int = ctl.enemies_alive().size()
			if to_spawn > 0 and spawn_t <= 0.0 and alive < MAX_CONCURRENT:
				spawn_t = 1.1
				to_spawn -= 1
				_spawn_enemy()
			if to_spawn <= 0 and alive == 0:
				AudioHub.play("round_win", -2.0)
				SaveData.max_progress("best_wave", wave)
				if wave >= int(rules.get("waves", 10)):
					cleared = true
				else:
					state = "break"
					break_t = 3.0
					ctl.announce("WAVE %d CLEARED!" % wave, Pal.UI_GOOD)


func _spawn_enemy() -> void:
	var xs: Array = ctl.arena.def.items
	var x: float = xs[ctl.rng.randi_range(0, xs.size() - 1)] + ctl.rng.randf_range(-20, 20)
	var gy: float = ctl.arena.ground_y_at(x, -50.0)
	var pos := Vector2(x, (gy if gy < INF else 200.0))
	var lvl := clampi(int(rules.get("bot_level", 1)) - 1 + wave / 4, 0, 3)
	var e: CatFighter
	if wave % 5 == 0 and to_spawn == 0:
		e = ctl.spawn_enemy("feral", pos, mini(lvl + 1, 3), 140.0)
		e.add_status("giant", 9999.0)
		e.display_name = "BOSS CAT"
	elif wave >= 3 and ctl.rng.randf() < 0.45:
		e = ctl.spawn_enemy("feral", pos, lvl, 45.0)
	else:
		e = ctl.spawn_enemy("mouse", pos, lvl, 28.0)
	e.global_position = pos + Vector2(0, -80)
	ctl.fx.ring(pos + Vector2(0, -10), Pal.UI_BAD, 16.0)


func check_round_end() -> Dictionary:
	var any_alive := false
	for f in ctl.players():
		if not f.eliminated:
			any_alive = true
	if cleared:
		var winners := _winners(true)
		return {"winners": winners, "key": 0, "text": "SURVIVED %d WAVES!" % wave, "color": Pal.UI_GOOD}
	if not any_alive:
		var w2 := _winners(false)
		return {"winners": w2, "key": null, "text": "WIPED OUT ON WAVE %d" % wave, "color": Pal.UI_BAD}
	return {}


func _winners(victory: bool) -> Array:
	if uses_score():
		var best := -1
		for f in ctl.players():
			best = maxi(best, f.score)
		return ctl.players().filter(func(f): return f.score == best and best > 0)
	return ctl.players() if victory else []


func final_winners() -> Array:
	return ctl.round_result.get("winners", [])


func final_title(winners: Array) -> String:
	if uses_score() and not winners.is_empty():
		return "%s WINS WITH %d KOS!" % [winners[0].display_name, winners[0].score]
	return ctl.round_result.get("text", "")


func hud_top() -> String:
	if state == "break":
		return "GET READY · WAVE %d" % (wave + 1)
	return "WAVE %d/%d · ENEMIES %d" % [wave, int(rules.get("waves", 10)), to_spawn + ctl.enemies_alive().size()]


func hud_player_text(f: CatFighter) -> String:
	return "%d KO" % f.score if uses_score() else ""


func _rank_score(f: CatFighter) -> float:
	return f.score * 100.0 + f.stocks


func extra_progress() -> Dictionary:
	return {"max:best_wave": float(wave - (0 if cleared else 1))}


func net_vars() -> Array:
	return ["wave", "to_spawn", "state", "cleared"]
