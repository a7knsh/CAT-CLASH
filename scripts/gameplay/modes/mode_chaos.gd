extends "res://scripts/gameplay/modes/mode_stock.gd"
## Chaos Mode: Stock rules plus a new random modifier every few seconds.

const MODS := {
	"lowgrav": "LOW GRAVITY!",
	"giant_weapons": "GIANT WEAPONS!",
	"slippery": "SLIPPERY FLOORS!",
	"bouncy": "BOUNCY BULLETS!",
	"swap": "WEAPON SWAP!",
	"rain": "ITEM RAIN!",
	"speed": "ZOOMIES!",
	"giants": "GIANT CATS!",
	"party": "POWER-UP PARTY!",
}

var mod_t := 4.0
var current := ""


func on_fight_start() -> void:
	mod_t = 3.0


func tick(dt: float) -> void:
	super.tick(dt)
	mod_t -= dt
	if mod_t <= 0.0:
		mod_t = float(rules.get("chaos_interval", 15))
		_clear()
		var keys: Array = MODS.keys()
		keys.erase(current)
		current = keys[ctl.rng.randi_range(0, keys.size() - 1)]
		_apply(current)
		ctl.show_banner(MODS[current], Pal.UI_ACCENT, 1.5, false)
		AudioHub.play("powerup", 0.0, 0.8)


func _clear() -> void:
	ctl.gravity_mult = ctl.base_gravity
	ctl.mod_giant_weapons = false
	ctl.mod_slippery = false
	ctl.mod_bouncy = false


func _apply(m: String) -> void:
	var dur := float(rules.get("chaos_interval", 15))
	match m:
		"lowgrav":
			ctl.gravity_mult = ctl.base_gravity * 0.45
		"giant_weapons":
			ctl.mod_giant_weapons = true
		"slippery":
			ctl.mod_slippery = true
		"bouncy":
			ctl.mod_bouncy = true
		"swap":
			for f in ctl.players():
				if f.alive_in_round():
					f.weapon = {}
					f.give_weapon(WeaponDefs.pick_random("all", ctl.rng))
		"rain":
			for i in 6:
				ctl.crate_loot(Vector2(ctl.rng.randf_range(80, ctl.arena.size.x - 80), -40.0 - i * 30.0))
		"speed":
			for f in ctl.players():
				f.add_status("speed", dur)
		"giants":
			for f in ctl.players():
				if f.alive_in_round():
					f.add_status("giant", minf(dur, 8.0))
		"party":
			for p in ctl.arena.def.get("powerups", []):
				ctl.spawn_powerup(p)


func hud_top() -> String:
	return "CHAOS · NEXT IN %d" % int(ceil(mod_t))


func hud_sub() -> String:
	return MODS.get(current, "")
