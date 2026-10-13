extends BaseMode
## Training: practice against configurable dummies with weapon racks that
## restock, unlimited respawns, a combo counter, damage readout and frame
## data for your current move. Pause for dummy behaviour, weapon spawns and
## position resets. Training milestones are tracked as achievements.

const RACK := ["sword", "spear", "hammer", "bow", "blaster", "boomerang", "katana", "pan"]

var dummies: Array = []
var restock: Array = []   # [{pos, id, t}]
var last_damage := 0.0
var last_combo := 0
var show_t := 0.0


func respawns() -> bool:
	return true


func dummy_infinite() -> bool:
	return true


func skip_countdown() -> bool:
	return true


func allow_item_spawns() -> bool:
	return false


func respawn_delay() -> float:
	return 0.8


func setup() -> void:
	var n := int(rules.get("dummy_count", 1))
	for i in n:
		var cfg := {"slot": 5 + i, "team": 50, "skin": CosmeticDefs.ROSTER[(i + 3) % CosmeticDefs.ROSTER.size()], "name": "DUMMY", "bot": true, "bot_level": 0, "dummy": true}
		var d: CatFighter = ctl.add_fighter(cfg)
		dummies.append(d)
	apply_dummy_ai()


func apply_dummy_ai() -> void:
	var ai: String = rules.get("dummy_ai", "stand")
	for d in dummies:
		if d.brain:
			d.brain.dummy_mode = ai


func on_round_start() -> void:
	super.on_round_start()
	var pts: Array = ctl.arena.spawn_points()
	var i := 0
	for d in dummies:
		var p: Vector2 = pts[(i + 1) % pts.size()]
		d.spawn_point = p
		d.respawn(p, false)
		d.stocks = 999
		i += 1
	for f in ctl.players():
		f.stocks = 999
	var xs: Array = ctl.arena.def.items
	restock.clear()
	for k in mini(RACK.size(), xs.size()):
		_place(Vector2(xs[k], 0), RACK[k])


func _place(pos: Vector2, id: String) -> void:
	var gy: float = ctl.arena.ground_y_at(pos.x, 0.0)
	var p := Vector2(pos.x, (gy if gy < INF else 200.0) - 6.0)
	var it: WeaponItem = ctl.spawn_item({"id": id, "ammo": int(WeaponDefs.get_def(id).get("ammo", -1)), "dur": -1, "hits": 0}, p, Vector2.ZERO, null, false)
	it.permanent = true
	it.pedestal = p


func on_pedestal_taken(pos: Vector2, id: String) -> void:
	restock.append({"pos": pos, "id": id, "t": 2.0})


func on_ko(victim: CatFighter, _killer: CatFighter, _cause: String) -> void:
	victim.respawn_timer = respawn_delay()


func tick(dt: float) -> void:
	_tick_respawns(dt)
	for d in dummies:
		if d.dead and d.respawn_timer > 0.0:
			d.respawn_timer -= dt
			if d.respawn_timer <= 0.0:
				d.respawn(d.spawn_point, false)
		# Dummies heal after a breather so combos can be practised forever.
		if d.alive_in_round() and d.state in ["idle", "run", "air", "block"] and ctl.time - d.last_hit_time > 1.5:
			d.hp = d.max_hp
	for r in restock.duplicate():
		r.t -= dt
		if r.t <= 0.0:
			_place(r.pos, r.id)
			restock.erase(r)
	var me := _me()
	if me:
		if me.combo_dealt > 0:
			last_combo = me.combo_dealt
			show_t = 2.0
		show_t -= dt


func check_round_end() -> Dictionary:
	return {}


func _me() -> CatFighter:
	for f in ctl.players():
		if not f.is_bot:
			return f
	return null


func hud_fighters() -> Array:
	return ctl.players()


func hud_top() -> String:
	return "TRAINING · DUMMY: %s" % ModeDefs.rule_label("dummy_ai", rules.get("dummy_ai", "stand"))


func hud_sub() -> String:
	return "PAUSE FOR OPTIONS · RACKS RESTOCK AUTOMATICALLY"


func hud_lines() -> Array:
	var me := _me()
	if me == null:
		return []
	var out: Array = []
	var total := 0.0
	for d in dummies:
		total += d.stats.damage_taken
	out.append("COMBO %d   BEST %d" % [last_combo if show_t > 0.0 else 0, int(me.stats.best_combo)])
	out.append("DAMAGE DEALT %d" % int(total))
	var ms := AttackData.moveset(me.weapon_id())
	var mv: Dictionary = me.attack.mv if not me.attack.is_empty() else ms.light1
	out.append("%s %s: %dF STARTUP %dF ACTIVE %dF RECOVERY" % [
		(WeaponDefs.get_def(me.weapon_id()).get("name", "PAWS") as String), (mv.id as String).to_upper(),
		int(round(mv.startup * 60.0)), int(round(mv.active * 60.0)), int(round(mv.recovery * 60.0))])
	out.append("DMG %.1f  KB %d  ANGLE %d" % [mv.dmg, int(mv.kb), int(mv.ang)])
	return out


func spawn_training_weapon(id: String, device: String) -> void:
	var who: CatFighter = null
	for f in ctl.players():
		if f.device == device:
			who = f
	if who == null:
		who = _me()
	if who == null:
		return
	ctl.spawn_item({"id": id, "ammo": int(WeaponDefs.get_def(id).get("ammo", -1)), "dur": int(WeaponDefs.get_def(id).get("dur", -1)), "hits": 0},
		who.global_position + Vector2(who.facing * 16, -40), Vector2(0, -40), null, false)


func reset_positions() -> void:
	var pts: Array = ctl.arena.spawn_points()
	var i := 0
	for f in ctl.players():
		f.respawn(pts[i % pts.size()], false)
		i += 1
	for d in dummies:
		d.respawn(d.spawn_point, false)
		d.stats.damage_taken = 0.0
	for it in ctl.items():
		if it.pedestal == Vector2.INF:
			it.queue_free()
