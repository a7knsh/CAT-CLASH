extends BaseMode
## Boss Battle: all players team up (shared team, individual lives) against
## the MECHA-MOUSER 9000. Win by destroying it; lose if every cat runs out
## of lives.

var boss: MechaBoss
var won := false


func respawns() -> bool:
	return true


func respawn_delay() -> float:
	return 3.0


func on_round_start() -> void:
	super.on_round_start()
	if boss and is_instance_valid(boss):
		boss.queue_free()
	boss = MechaBoss.new()
	ctl.add_boss(boss)
	boss.setup(ctl, ctl.players().size())


func tick(dt: float) -> void:
	super.tick(dt)
	for f in ctl.fighters.duplicate():
		if f.is_enemy and f.dead:
			ctl.fighters.erase(f)
			f.queue_free()
	if boss and boss.dead:
		won = true


func check_round_end() -> Dictionary:
	if won:
		return {"winners": ctl.players(), "key": 0, "text": "MOUSER DESTROYED!", "color": Pal.UI_GOOD}
	for f in ctl.players():
		if not f.eliminated:
			return {}
	return {"winners": [], "key": null, "text": "THE MOUSER WINS...", "color": Pal.UI_BAD}


func final_winners() -> Array:
	return ctl.round_result.get("winners", [])


func final_title(winners: Array) -> String:
	return "MOUSER DESTROYED!" if not winners.is_empty() else "DEFEATED BY THE MOUSER"


func hud_top() -> String:
	return "BOSS BATTLE · %s" % UI.fmt_time(ctl.match_time)


func camera_points() -> Array:
	return []


func bot_objective(_f: CatFighter) -> Variant:
	if boss and boss.targetable():
		var p := boss.global_position
		return {"pos": p + Vector2(-30 if _f.global_position.x < p.x else 30, 0), "force": ctl.enemies_alive().is_empty()}
	return null


func extra_progress() -> Dictionary:
	return {"boss_wins": 1.0} if won else {}


func _rank_score(f: CatFighter) -> float:
	return f.stats.damage_dealt
