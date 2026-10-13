extends "res://scripts/gameplay/modes/mode_stock.gd"
## Weapon Roulette: Stock rules, but every few seconds every cat is handed a
## new random weapon. No item drops — the roulette is the only supply.

var swap_t := 3.0


func allow_item_spawns() -> bool:
	return false


func on_fight_start() -> void:
	swap_t = 0.2


func tick(dt: float) -> void:
	super.tick(dt)
	swap_t -= dt
	if swap_t <= 0.0:
		swap_t = float(rules.get("roulette_time", 8))
		var set_id: String = rules.get("weapon_set", "all")
		if set_id == "none":
			set_id = "all"
		for f in ctl.players():
			if not f.alive_in_round():
				continue
			if not f.weapon.is_empty():
				ctl.fx.smoke(f.center() + Vector2(f.facing * 8, 0), 3)
				f.weapon = {}
			f.give_weapon(WeaponDefs.pick_random(set_id, ctl.rng))
			ctl.fx.ring(f.center(), Pal.UI_HILITE, 14.0)
		AudioHub.play("powerup", -2.0)
		ctl.announce("SWAP!", Pal.UI_HILITE)


func hud_top() -> String:
	return "ROULETTE · NEXT SWAP %d" % int(ceil(swap_t))
