extends Node2D
## Runs a match: builds the arena, fighters, camera, HUD and the game mode;
## drives a deterministic per-physics-frame update order; resolves all combat
## (melee, projectiles, explosions, hazards, thrown weapons); handles items,
## crates, power-ups, KOs, rounds and the end-of-match summary.
##
## Update order each physics frame:
##   input -> fighters -> melee resolution -> items -> projectiles -> hazards
##   -> power-ups -> blast zones -> mode -> camera

const ITEM_INTERVALS := [15.0, 8.5, 5.0, 2.4]
const MAX_ITEMS := 10

var session: Dictionary = {}
var rules: Dictionary = {}
var mode_id := ""
var mode: BaseMode
var arena: Arena
var camera: MatchCamera
var fx: EffectsSystem
var proj: ProjectileSystem
var hud: Node
var pause_menu: Node
var overlay: Node2D
var world: Node2D
var fighters: Array = []
var boss: Node = null
var crates: Array = []
var powerups: Array = []

var time := 0.0
var match_time := 0.0
var phase := "intro"
var phase_t := 0.0
var fighting := false
var round_num := 0
var round_wins: Dictionary = {}
var round_result: Dictionary = {}
var item_t := 6.0
var powerup_t := 12.0
var gravity_mult := 1.0
var base_gravity := 1.0
var mod_slippery := false
var mod_giant_weapons := false
var mod_bouncy := false
var rng := RandomNumberGenerator.new()
var banner_text := ""
var banner_color := Color.WHITE
var banner_t := 0.0
var banner_big := true
var finished := false
var disconnect_msg := ""
var _slowmo_t := 0.0
var _stuck_t := 0.0
var _items_node: Node2D
var _fighters_node: Node2D
var headless_fast := false


func setup(_params: Dictionary) -> void:
	session = Router.session.duplicate(true)


func _ready() -> void:
	rng.randomize()
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mode_id = session.get("mode", "ffa")
	rules = ModeDefs.default_rules(mode_id)
	for k in session.get("rules", {}).keys():
		rules[k] = session.rules[k]
	var arena_id: String = session.get("arena", "garden")
	if arena_id == "random" or not ArenaDefs.ALL.has(arena_id):
		arena_id = GameDB.random_arena()
	session.arena = arena_id
	world = Node2D.new()
	add_child(world)
	arena = Arena.new()
	world.add_child(arena)
	arena.build(arena_id, self, bool(rules.get("hazards", true)))
	base_gravity = arena.gravity()
	gravity_mult = base_gravity
	_items_node = Node2D.new()
	world.add_child(_items_node)
	_fighters_node = Node2D.new()
	_fighters_node.z_index = 10
	world.add_child(_fighters_node)
	proj = ProjectileSystem.new()
	proj.ctl = self
	world.add_child(proj)
	fx = EffectsSystem.new()
	fx.ctl = self
	world.add_child(fx)
	overlay = MatchOverlay.new()
	overlay.ctl = self
	world.add_child(overlay)
	camera = MatchCamera.new()
	add_child(camera)
	camera.setup(self)
	camera.make_current()
	# Mode
	var mdef := ModeDefs.get_def(mode_id)
	var mscript: Script = load(mdef.script)
	mode = mscript.new()
	mode.ctl = self
	mode.rules = rules
	mode.mode_id = mode_id
	# Fighters
	for pc in session.get("players", []):
		add_fighter(pc)
	mode.setup()
	hud = MatchHud.new()
	hud.ctl = self
	add_child(hud)
	pause_menu = PauseMenu.new()
	pause_menu.ctl = self
	add_child(pause_menu)
	InputHub.device_disconnected.connect(_on_device_disconnected)
	InputHub.device_connected.connect(_on_device_connected)
	var mus: Dictionary = arena.def.music
	AudioHub.play_music("arena_" + arena_id, mus)
	_start_round()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if InputHub.device_disconnected.is_connected(_on_device_disconnected):
		InputHub.device_disconnected.disconnect(_on_device_disconnected)
	if InputHub.device_connected.is_connected(_on_device_connected):
		InputHub.device_connected.disconnect(_on_device_connected)


# ============================================================ fighters

func add_fighter(pc: Dictionary) -> CatFighter:
	var f := CatFighter.new()
	_fighters_node.add_child(f)
	var cfg := pc.duplicate()
	cfg["hp"] = rules.get("hp", 100)
	if mode and not mode.teams_active() and not cfg.get("enemy", false) and not cfg.get("dummy", false):
		cfg["team"] = cfg.get("slot", 0)
	elif mode and ModeDefs.get_def(mode_id).get("teams", "") == "coop" and not cfg.get("enemy", false):
		cfg["team"] = 0
	f.setup(cfg, self)
	f.stocks = int(rules.get("stocks", 3))
	fighters.append(f)
	return f


## Real competitors (excludes decoys and AI enemies).
func players() -> Array:
	return fighters.filter(func(f): return not f.is_decoy and not f.is_enemy)


func enemies_alive() -> Array:
	return fighters.filter(func(f): return f.is_enemy and f.alive_in_round())


func can_damage(a: CatFighter, b: CatFighter) -> bool:
	if a == null or b == null:
		return true
	if a == b:
		return false
	if a.team == b.team:
		return bool(rules.get("friendly_fire", false)) and not a.is_enemy
	return true


func hittables() -> Array:
	var out: Array = fighters.duplicate()
	if boss and is_instance_valid(boss) and boss.targetable():
		out.append(boss)
	for c in crates:
		if is_instance_valid(c):
			out.append(c)
	return out


func items() -> Array:
	var out: Array = []
	for c in _items_node.get_children():
		if c is WeaponItem and not c.is_queued_for_deletion():
			out.append(c)
	return out


func world_rect() -> Rect2:
	return arena.blast_rect()


func camera_points() -> Array:
	var pts: Array = mode.camera_points() if mode else []
	if boss and is_instance_valid(boss) and boss.targetable():
		pts.append(boss.global_position + Vector2(0, -24))
	return pts


func safe_spawn_point(f: CatFighter) -> Vector2:
	var pts: Array = arena.spawn_points()
	var best: Vector2 = pts[0]
	var best_score := -INF
	for p in pts:
		var sc := 0.0
		var nearest := INF
		for o in fighters:
			if o != f and o.alive_in_round() and can_damage(f, o):
				nearest = minf(nearest, (o.global_position as Vector2).distance_to(p))
		sc = nearest if nearest < INF else 500.0
		sc -= arena.danger_at(p + Vector2(0, -6)) * 400.0
		sc += rng.randf() * 30.0
		if sc > best_score:
			best_score = sc
			best = p
	return best


# ================================================================ rounds

func _start_round() -> void:
	round_num += 1
	proj.clear_all()
	for it in items():
		it.queue_free()
	for c in crates:
		if is_instance_valid(c):
			c.queue_free()
	crates.clear()
	for pu in powerups:
		if is_instance_valid(pu):
			pu.queue_free()
	powerups.clear()
	# Remove decoys / enemies from previous rounds.
	for f in fighters.duplicate():
		if f.is_decoy or f.is_enemy:
			fighters.erase(f)
			f.queue_free()
	var pts: Array = arena.spawn_points().duplicate()
	var start_weapon: String = rules.get("start_weapon", "none")
	var same_weapon := WeaponDefs.pick_random(rules.get("weapon_set", "all"), rng)
	var i := 0
	for f in players():
		f.eliminated = false
		f.stocks = int(rules.get("stocks", 3))
		var sp: Vector2 = pts[i % pts.size()]
		f.spawn_point = sp
		f.respawn(sp, false)
		f.global_position = sp + Vector2(0, -50 if f.skin.get("entrance", "drop") in ["drop", "box"] else 0)
		f.facing = 1 if sp.x < arena.size.x * 0.5 else -1
		match start_weapon:
			"random":
				var w := WeaponDefs.pick_random(rules.get("weapon_set", "all"), rng)
				if w != "":
					f.give_weapon(w)
			"same":
				if same_weapon != "":
					f.give_weapon(same_weapon)
		if f.skin.get("entrance", "") == "smoke":
			fx.smoke(sp + Vector2(0, -8), 10)
		elif f.skin.get("entrance", "") == "teleport":
			fx.ring(sp + Vector2(0, -8), Color("6ae0ff"), 16.0)
		i += 1
	item_t = rng.randf_range(2.5, 5.0)
	powerup_t = rng.randf_range(8.0, 14.0)
	time = 0.0
	phase = "intro"
	phase_t = 0.0
	fighting = false
	round_result = {}
	mode.on_round_start()
	if mode.uses_rounds():
		show_banner("ROUND %d" % round_num, Pal.UI_HILITE)
	else:
		show_banner(ModeDefs.get_def(mode_id).name, Pal.UI_HILITE)


func show_banner(text: String, color: Color, dur: float = 1.2, big: bool = true) -> void:
	banner_text = text
	banner_color = color
	banner_t = dur
	banner_big = big


func announce(text: String, color: Color) -> void:
	show_banner(text, color, 1.4, false)


func _physics_process(dt: float) -> void:
	if finished:
		return
	phase_t += dt
	banner_t -= dt
	match phase:
		"intro":
			_tick_intro(dt)
		"fight":
			_tick_fight(dt)
		"round_end":
			_tick_world(dt, false)
			if phase_t > 2.6:
				_after_round()
		"match_end":
			_tick_world(dt, false)
			if phase_t > 1.8:
				_finish_match()


func _tick_intro(dt: float) -> void:
	# Fighters can drop in (entrances) but can't act.
	for f in fighters:
		f.input.clear()
		f.input.enabled = false
	_tick_world(dt, false)
	var skip_intro: bool = mode.skip_countdown()
	var cd_start := 0.9
	var step := 0.55
	if skip_intro:
		phase_t = cd_start + step * 3.0
	var k := int((phase_t - cd_start) / step)
	if phase_t >= cd_start and k < 3:
		var label := str(3 - k)
		if banner_text != label:
			show_banner(label, Color.WHITE, step)
			AudioHub.play("count", -2.0)
	elif phase_t >= cd_start + step * 3.0:
		phase = "fight"
		phase_t = 0.0
		fighting = true
		for f in fighters:
			f.input.enabled = true
		if not skip_intro:
			show_banner("FIGHT!", Pal.UI_HILITE, 0.8)
			AudioHub.play("go", 0.0)
		mode.on_fight_start()


func _tick_fight(dt: float) -> void:
	time += dt
	match_time += dt
	_tick_world(dt, true)
	mode.tick(dt)
	if phase != "fight":
		return
	var res: Dictionary = mode.check_round_end()
	if not res.is_empty():
		_end_round(res)


func _tick_world(dt: float, active: bool) -> void:
	for f in fighters:
		f.input.pull_from_hub()
	for f in fighters.duplicate():
		if not is_instance_valid(f):
			continue
		if f.is_decoy:
			f.decoy_life -= dt
			if f.decoy_life <= 0.0 and not f.dead:
				fx.smoke(f.center(), 8, Color(1, 0.6, 0.8, 0.7))
				f.vanish()
		f.tick(dt)
	if boss and is_instance_valid(boss):
		boss.tick(dt)
	if active:
		_resolve_melee()
	for it in items():
		it.tick(dt)
		if it.thrown:
			_check_thrown(it)
		if it.global_position.y > arena.blast_rect().end.y:
			if it.permanent:
				mode.on_objective_lost(it)
			it.queue_free()
	proj.tick(dt)
	arena.tick(dt)
	for c in crates.duplicate():
		if not is_instance_valid(c):
			crates.erase(c)
			continue
		c.tick(dt)
	for pu in powerups.duplicate():
		if not is_instance_valid(pu):
			powerups.erase(pu)
			continue
		pu.tick(dt)
	if active:
		_check_blast_zones()
		_separate_fighters()
		_spawn_items(dt)
		_unstick(dt)
	camera.tick(dt)


# ================================================================ combat

func _resolve_melee() -> void:
	for a in fighters:
		if not a.alive_in_round() or a.hitstop > 0.0:
			continue
		var hb: Rect2 = a.active_hitbox()
		if hb.size == Vector2.ZERO:
			continue
		var mv: Dictionary = a.attack.mv
		for tgt in hittables():
			if tgt == a:
				continue
			if tgt is CatFighter:
				if not tgt.targetable() or not can_damage(a, tgt):
					continue
			elif tgt.has_method("is_enemy_of") and not tgt.is_enemy_of(a):
				continue
			var hits: Dictionary = a.attack.hits
			if hits.has(tgt):
				if mv.multi <= 0.0 or time - float(hits[tgt]) < mv.multi:
					continue
			if not hb.intersects(tgt.hurtbox()):
				continue
			if not _line_of_sight(a.center(), tgt.hurtbox().get_center()):
				continue
			hits[tgt] = time
			_melee_hit(a, tgt, mv, hb)
			if a.state != "attack":
				break
		# Melee swings swat projectiles; frying pans and parry-timed swings reflect them.
		if a.state == "attack":
			for p in proj.list:
				if p.dead or p.owner == a or p.vortex > 0.0 or p.kind in ["cannonball", "shockwave"]:
					continue
				if p.owner and not can_damage(p.owner, a):
					continue
				if hb.grow(2).has_point(p.pos):
					if a.weapon_def().get("effect", "") == "reflect":
						p.owner = a
						p.team = a.team
						p.vel = -p.vel * 1.3
						p.hits.clear()
						p.hostile_all = false
						AudioHub.play("hit_pan", 0.0, 1.2)
						fx.text(p.pos + Vector2(0, -8), "RETURN!", Pal.UI_HILITE)
					elif p.kind in ["laser", "energy", "pebble", "paint", "snowball", "arrow", "star", "bubble", "ice"]:
						p.dead = true
						fx.spark(p.pos, Vector2.UP, Color.WHITE, 5, 100.0)
						AudioHub.play("block", -6.0, 1.4)


func _line_of_sight(from: Vector2, to: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from, to, 1)
	return space.intersect_ray(q).is_empty()


func _melee_hit(a: CatFighter, tgt: Variant, mv: Dictionary, hb: Rect2) -> void:
	var dmg: float = a.attack_damage(mv)
	var kb: float = float(mv.kb) * (1.0 + float(a.attack.get("charge", 0.0)) / 0.8 * 0.5)
	var label := ""
	if mv.get("tipper", false):
		var c: Vector2 = tgt.hurtbox().get_center()
		var tip_x := hb.end.x if a.facing > 0 else hb.position.x
		if absf(c.x - tip_x) < hb.size.x * 0.35:
			dmg *= 1.4
			kb *= 1.25
			label = "TIPPER!"
	var eff: String = mv.get("effect", "")
	if eff in ["reflect", "pull", "explode", "homing", "transform", "blackhole"]:
		eff = ""
	if a.has_status("elemental"):
		eff = "burn"
	var wid := a.weapon_id()
	if wid == "chicken":
		var hits_n: int = int(a.weapon.get("hits", 0))
		if hits_n % 5 == 4:
			kb = 540.0
			dmg = 6.0
			label = "MEGA SQUEAK!"
			eff = ""
	if tgt is Crate:
		tgt.take_hit(dmg, a)
		a.hitstop = 0.03
		return
	var h := {"attacker": a, "dmg": dmg, "kb": kb, "ang": mv.ang, "dir": a.facing, "src": a.center(),
		"hitstop": mv.hitstop, "cause": "hit", "weapon": wid, "pull": mv.get("pull", false), "can_block": true}
	var res: String = tgt.receive_hit(h)
	_after_hit(a, tgt, h, res, eff, label)


func _after_hit(a: CatFighter, tgt: Variant, h: Dictionary, res: String, eff: String, label: String = "") -> void:
	var tpos: Vector2 = tgt.hurtbox().get_center()
	var strength := clampf(float(h.kb) / 450.0, 0.0, 1.0)
	match res:
		"hit":
			if a:
				a.hitstop = maxf(a.hitstop, float(h.hitstop))
				a.stats.hits += 1
				a.combo_dealt += 1
				a.combo_dealt_t = 1.0
				a.stats.best_combo = maxi(int(a.stats.best_combo), a.combo_dealt)
				if a.combo_dealt >= 3:
					fx.text(a.center() + Vector2(0, -26), "%d HIT!" % a.combo_dealt, Pal.UI_HILITE)
				a.on_weapon_hit()
				if mode_id == "training" and not a.is_bot:
					SaveData.max_progress("t_combo", a.combo_dealt)
			var mat := "soft"
			if a and not a.weapon.is_empty():
				mat = a.weapon_def().get("material", "metal")
			elif h.get("cause", "") == "projectile":
				mat = "energy"
			AudioHub.play_impact(mat, strength)
			if strength > 0.7 and rng.randf() < 0.4:
				AudioHub.meow(1.3)
			fx.hit(tpos, Vector2(float(h.dir), -0.3).normalized(), strength, Color.WHITE)
			fx.shake(1.0 + strength * 4.0)
			if tgt is CatFighter:
				if eff != "":
					tgt.apply_effect(eff, a)
				InputHub.vibrate(tgt.device, 0.3, 0.6 * strength, 0.15)
			if a:
				InputHub.vibrate(a.device, 0.2, 0.3 * strength, 0.08)
			if label != "":
				fx.text(tpos + Vector2(0, -18), label, Pal.UI_ACCENT)
		"block":
			AudioHub.play("block", -2.0)
			fx.spark(tpos, Vector2(-float(h.dir), -0.2).normalized(), Color("6ae0ff"), 5, 120.0)
			if a:
				a.velocity.x = -float(h.dir) * 90.0
				a.hitstop = 0.05
		"parry":
			AudioHub.play("parry", 0.0)
			fx.ring(tpos, Color.WHITE, 18.0)
			fx.text(tpos + Vector2(0, -18), "PARRY!", Color("aef0ff"))
			fx.shake(2.0)
			if tgt is CatFighter:
				tgt.stats.parries += 1
				tgt.invuln = 0.25
				tgt.hitstop = 0.08
				if mode_id == "training" and not tgt.is_bot:
					SaveData.max_progress("t_parry", 1)
			if a and h.get("cause", "") == "hit":
				a.attack = {}
				a.set_state("stunned")
				a.stun_kind = "parried"
				a.hitstun = 0.6
				a.velocity.x = -float(h.dir) * 120.0
				a.hitstop = 0.08
		"shield":
			if a:
				a.velocity.x = -float(h.dir) * 140.0


## Projectile vs target. Returns the receive_hit result.
func projectile_hit(p: ProjectileSystem.Proj, tgt: Variant) -> String:
	if tgt is Crate:
		tgt.take_hit(p.dmg, p.owner)
		return "hit"
	if p.from_boss and boss and tgt == boss:
		return "miss"
	var dir := 1 if p.vel.x >= 0.0 else -1
	var h := {"attacker": p.owner, "dmg": p.dmg, "kb": p.kb, "ang": p.ang, "dir": dir,
		"src": p.pos - p.vel.normalized() * 24.0, "hitstop": 0.04, "cause": p.cause, "weapon": p.weapon, "can_block": true}
	var res: String = tgt.receive_hit(h)
	var eff := p.effect
	if eff in ["homing", "explode", "blackhole"]:
		eff = ""
	if p.owner and p.owner.has_status("elemental"):
		eff = "burn"
	if res == "hit" and p.kind == "boomerang":
		AudioHub.play("hit_wood", -2.0)
	_after_hit(p.owner, tgt, h, res, eff)
	if res == "parry" and tgt is CatFighter and mode_id == "training" and not tgt.is_bot:
		SaveData.max_progress("t_parry", 1)
	return res


func _check_thrown(it: WeaponItem) -> void:
	for tgt in hittables():
		if tgt == it.thrower or it.hit_set.has(tgt):
			continue
		if tgt is CatFighter:
			if not tgt.targetable() or (it.thrower and not can_damage(it.thrower, tgt)):
				continue
			if tgt == it.thrower:
				continue
		if not tgt.hurtbox().grow(3).has_point(it.global_position):
			continue
		it.hit_set[tgt] = true
		var d := WeaponDefs.get_def(it.id())
		var dmg := WeaponDefs.throw_damage(d) if not d.is_empty() else 4.0
		if tgt is Crate:
			tgt.take_hit(dmg, it.thrower)
			continue
		var dir := 1 if it.vel.x >= 0.0 else -1
		var h := {"attacker": it.thrower, "dmg": dmg, "kb": 200.0 + float(d.get("weight", 1.0)) * 70.0, "ang": 30.0, "dir": dir,
			"src": it.global_position - it.vel.normalized() * 20.0, "hitstop": 0.06, "cause": "throw", "weapon": it.id(), "can_block": true}
		var res: String = tgt.receive_hit(h)
		_after_hit(it.thrower, tgt, h, res, "")
		if res == "hit":
			if it.thrower:
				it.thrower.stats.throw_hits += 1
				if mode_id == "training" and not it.thrower.is_bot:
					SaveData.max_progress("t_throw", 1)
			it.vel = Vector2(-it.vel.x * 0.25, -160.0)
			it.thrown = false
			if it.id() == "plate":
				fx.burst(it.global_position, Color.WHITE, 10, 120.0)
				AudioHub.play("hit_glass", 0.0)
				it.queue_free()
		elif res == "parry":
			it.vel = -it.vel
			it.thrower = tgt if tgt is CatFighter else null
			it.hit_set.clear()


func explode(pos: Vector2, radius: float, dmg: float, kb: float, owner: CatFighter, weapon: String) -> void:
	fx.explosion(pos, radius)
	AudioHub.play("explosion", 0.0)
	for tgt in hittables():
		var c: Vector2 = tgt.hurtbox().get_center()
		var d := c.distance_to(pos)
		if d > radius + 8.0:
			continue
		if tgt is CatFighter and not tgt.targetable():
			continue
		if tgt is CatFighter and owner and tgt != owner and not can_damage(owner, tgt):
			continue
		if not _line_of_sight(pos + (c - pos).normalized() * 2.0, c) and d > 12.0:
			continue
		var fall := 1.0 - clampf(d / (radius + 8.0), 0.0, 1.0) * 0.5
		var v := c - pos
		var ang := rad_to_deg(atan2(-v.y, absf(v.x)))
		ang = clampf(ang, 25.0, 90.0)
		var self_mult := 0.5 if tgt == owner else 1.0
		if tgt is Crate:
			tgt.take_hit(dmg * fall, owner)
			continue
		var h := {"attacker": owner, "dmg": dmg * fall * self_mult, "kb": kb * fall, "ang": ang, "dir": 1 if v.x >= 0.0 else -1,
			"src": pos, "hitstop": 0.08, "cause": "explosion", "weapon": weapon, "can_block": true}
		var res: String = tgt.receive_hit(h)
		_after_hit(owner if tgt != owner else null, tgt, h, res, "")
	for it in items():
		var d2: Vector2 = it.global_position - pos
		if d2.length() < radius * 1.5:
			it.resting = false
			it.vel = d2.normalized() * 260.0 + Vector2(0, -120)


func hazard_hit(f: CatFighter, dmg: float, kbv: Vector2, effect: String) -> void:
	var credit: CatFighter = f.recent_attacker(5.0)
	var ang := rad_to_deg(atan2(-kbv.y, absf(kbv.x)))
	var h := {"attacker": credit, "dmg": dmg, "kb": kbv.length(), "ang": ang, "dir": 1 if kbv.x >= 0.0 else -1,
		"src": f.center() + Vector2(-kbv.x, -kbv.y).normalized() * -10.0, "hitstop": 0.05, "cause": "hazard", "weapon": "", "can_block": false}
	var res := f.receive_hit(h)
	if res == "hit":
		if effect != "":
			f.apply_effect(effect, null)
		fx.hit(f.center(), kbv.normalized(), 0.6, Color("ffb040"))
		AudioHub.play("thump", 0.0)
		fx.shake(3.0)


# ============================================================= weapons

func weapon_special(f: CatFighter, mv: Dictionary) -> void:
	var d := f.weapon_def()
	match mv.kind:
		"shoot":
			_fire(f, mv, d)
		"beam":
			_beam(f, mv, d)
		"gravity_pull", "gravity_push":
			_gravity(f, mv, d)
		"boomerang":
			var aim := Vector2(f.facing, -0.08)
			if f.input.move.y < -0.55:
				aim = Vector2(f.facing * 0.5, -1.0)
			var spd := float(d.get("proj_speed", 380)) * (1.25 if mv.id == "heavy" else 1.0)
			proj.spawn("boomerang", f.center() + Vector2(f.facing * 8, 0), aim.normalized() * spd, f,
				{"dmg": mv.dmg * f.dmg_mult(), "kb": mv.kb, "ang": 30.0, "radius": 5.0, "life": 2.6, "weapon": "boomerang", "pierce": 3})
			f.weapon = {}
			f.boomerang_out = true
			f._note_weapon_use()
			AudioHub.play("throw", -2.0, 1.2)
		"potion":
			f.weapon = {}
			f.add_status("tiger", 8.0)
			fx.text(f.center() + Vector2(0, -22), "TIGER MODE!", Color("ff9f43"), true)
			fx.burst(f.center(), Color("ff9f43"), 16, 140.0)
			AudioHub.play("roar", 0.0)
			f._note_weapon_use()


func _fire(f: CatFighter, mv: Dictionary, d: Dictionary) -> void:
	if f.weapon.is_empty() or int(f.weapon.get("ammo", 0)) == 0:
		return
	var kind: String = d.get("proj", "laser")
	var aim_deg: float = float(mv.get("aim", 0.0))
	if mv.id in ["light1", "heavy", "nair", "air_heavy"] and f.input.move.y < -0.55:
		aim_deg = -45.0
	var dirv := Vector2(cos(deg_to_rad(aim_deg)) * f.facing, sin(deg_to_rad(aim_deg)))
	var spd: float = d.get("proj_speed", 450)
	var dmg: float = float(d.dmg) * f.dmg_mult()
	var kb: float = d.kb
	var power: bool = mv.get("power", false)
	var shots := 1
	var cost := 1
	var pierce := 0
	if power:
		if d.get("burst", 0) > 0:
			shots = mini(int(d.burst), int(f.weapon.ammo))
			cost = shots
		else:
			dmg *= 1.6
			kb *= 1.3
			spd *= 1.25
			pierce = 2 if kind in ["arrow", "bolt"] else 0
			cost = 2 if kind not in ["arrow", "bolt", "rocket", "voidorb"] and int(f.weapon.ammo) >= 2 else 1
			dmg *= 1.0 + float(f.attack.get("charge", 0.0)) / 0.8 * 0.5
	var paw := f.center() + Vector2(f.facing * 9, -1) * f.size_mult
	var radius := 2.0
	match kind:
		"snowball", "fireball": radius = 3.0
		"rocket": radius = 4.0
		"bubble": radius = 6.0
		"voidorb": radius = 5.0
		"star": radius = 4.0
	for s in shots:
		var spread := (s - (shots - 1) * 0.5) * 0.08
		var opts := {"dmg": dmg, "kb": kb, "ang": 20.0, "radius": radius, "grav": float(d.get("grav", 0)), "life": 2.4 if kind != "bubble" else 4.0,
			"effect": d.get("effect", ""), "weapon": f.weapon_id(), "pierce": pierce}
		if d.get("effect", "") == "homing":
			opts["homing"] = true
		if d.get("effect", "") == "explode":
			opts["explode_r"] = float(d.get("radius", 30))
		if kind == "paint":
			opts["color"] = Pal.player_color(f.slot)
		elif kind == "laser":
			opts["color"] = Color("6ae0ff")
		elif kind == "energy":
			opts["color"] = Color("d040c0")
		elif kind == "star":
			opts["color"] = Color("ffd23f")
		var v := dirv.rotated(spread * f.facing) * spd
		proj.spawn(kind, paw + dirv * float(s) * 6.0, v, f, opts)
	match kind:
		"arrow", "bolt": AudioHub.play("shoot_bow", -3.0)
		"pebble", "snowball", "paint", "bubble": AudioHub.play("shoot_pop", -4.0)
		"laser", "energy": AudioHub.play("shoot_pew", -5.0)
		"star": AudioHub.play("shoot_pew", -5.0, 1.5)
		"rocket": AudioHub.play("cannon", -6.0, 1.4)
		"ice": AudioHub.play("freeze", -4.0)
		"fireball": AudioHub.play("fire", -4.0)
		"voidorb": AudioHub.play("rumble", -4.0, 2.0)
	if kind == "rocket":
		f.velocity.x -= f.facing * 120.0
	fx.spark(paw, dirv, Color(1, 1, 0.8), 3, 80.0)
	f.weapon["cd"] = float(d.get("rate", 0.3))
	f._note_weapon_use()
	f.use_ammo(cost)


func _beam(f: CatFighter, mv: Dictionary, d: Dictionary) -> void:
	if f.weapon.is_empty() or int(f.weapon.get("ammo", 0)) == 0:
		return
	var power: bool = mv.get("power", false)
	var dmg: float = float(d.dmg) * f.dmg_mult() * (1.5 if power else 1.0)
	var start := f.center() + Vector2(f.facing * 10, -2)
	var targets: Array = []
	if power:
		# Sky strike: a bolt from above, a little ahead of the caster.
		var x := f.global_position.x + f.facing * 70.0
		var gy := arena.ground_y_at(x, f.global_position.y - 120.0)
		var top := Vector2(x, f.global_position.y - 200.0)
		var bot := Vector2(x, gy if gy < INF else f.global_position.y + 40.0)
		fx_bolt(top, bot)
		for o in fighters:
			if o != f and o.targetable() and can_damage(f, o) and absf(o.global_position.x - x) < 18.0 and o.global_position.y <= bot.y + 4.0:
				targets.append(o)
		fx.shake(4.0)
	else:
		var aim_deg: float = float(mv.get("aim", 0.0))
		if f.input.move.y < -0.55:
			aim_deg = -45.0
		var dirv := Vector2(cos(deg_to_rad(aim_deg)) * f.facing, sin(deg_to_rad(aim_deg)))
		var end := start + dirv * 230.0
		var space := get_world_2d().direct_space_state
		var r := space.intersect_ray(PhysicsRayQueryParameters2D.create(start, end, 1))
		if not r.is_empty():
			end = r.position
		var first: CatFighter = null
		var best := INF
		for o in fighters:
			if o == f or not o.targetable() or not can_damage(f, o):
				continue
			var hb: Rect2 = o.hurtbox().grow(3)
			var hit := false
			for i in 40:
				if hb.has_point(start.lerp(end, i / 39.0)):
					hit = true
					break
			if hit:
				var dd := start.distance_to(o.center())
				if dd < best:
					best = dd
					first = o
		if first:
			end = first.center()
			targets.append(first)
			# Chain to one more nearby foe.
			for o2 in fighters:
				if o2 != first and o2 != f and o2.targetable() and can_damage(f, o2) and o2.center().distance_to(first.center()) < 75.0:
					targets.append(o2)
					fx_bolt(first.center(), o2.center())
					break
		fx_bolt(start, end)
	AudioHub.play("zap", -2.0)
	var n := 0
	for o in targets:
		var mult := 1.0 if n == 0 else 0.6
		var h := {"attacker": f, "dmg": dmg * mult, "kb": float(d.kb) * mult, "ang": 50.0, "dir": f.facing, "src": f.center(),
			"hitstop": 0.06, "cause": "projectile", "weapon": f.weapon_id(), "can_block": true}
		var res: String = o.receive_hit(h)
		_after_hit(f, o, h, res, "shock")
		n += 1
	f.weapon["cd"] = float(d.get("rate", 0.5))
	f._note_weapon_use()
	f.use_ammo(2 if power else 1)


func fx_bolt(a: Vector2, b: Vector2) -> void:
	var prev := a
	var segs := 8
	for i in range(1, segs + 1):
		var p := a.lerp(b, float(i) / segs)
		if i < segs:
			p += Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6))
		var steps := 5
		for k in steps:
			fx.emit(prev.lerp(p, float(k) / steps), Vector2.ZERO, 0.14, 1.0, Color("e8f8ff"), EffectsSystem.K_PIXEL, 0.0)
		prev = p
	fx.ring(b, Color("aef0ff"), 10.0)


func _gravity(f: CatFighter, mv: Dictionary, d: Dictionary) -> void:
	if f.weapon.is_empty() or int(f.weapon.get("ammo", 0)) == 0:
		return
	var origin := f.center()
	if mv.kind == "gravity_pull":
		var best: CatFighter = null
		var bd := 170.0
		for o in fighters:
			if o == f or not o.targetable() or not can_damage(f, o):
				continue
			var v: Vector2 = o.center() - origin
			if v.x * f.facing < 0.0 or absf(v.y) > 50.0:
				continue
			if v.length() < bd:
				bd = v.length()
				best = o
		if best:
			var h := {"attacker": f, "dmg": 3.0, "kb": 10.0, "ang": 0.0, "dir": -f.facing, "src": origin, "hitstop": 0.02, "cause": "projectile", "weapon": "gravgun", "can_block": false}
			var res := best.receive_hit(h)
			if res == "hit":
				best.velocity = Vector2(-f.facing * 330.0, -120.0)
				best.set_state("hitstun")
				best.hitstun = 0.35
			fx_line(origin, best.center(), Color("c27bff"))
		else:
			# Pull items instead
			for it in items():
				var v2: Vector2 = it.global_position - origin
				if v2.length() < 170.0 and v2.x * f.facing > 0.0:
					it.resting = false
					it.vel = -v2.normalized() * 320.0 + Vector2(0, -80)
		AudioHub.play("shoot_pew", -3.0, 0.5)
	else:
		for o in fighters:
			if o == f or not o.targetable() or not can_damage(f, o):
				continue
			var v3: Vector2 = o.center() - origin
			if v3.x * f.facing < -4.0 or v3.length() > 120.0 or absf(v3.y) > 60.0:
				continue
			var fall := 1.0 - v3.length() / 140.0
			var h2 := {"attacker": f, "dmg": float(d.dmg), "kb": float(d.kb) * fall, "ang": 30.0, "dir": f.facing, "src": origin, "hitstop": 0.06, "cause": "projectile", "weapon": "gravgun", "can_block": true}
			var res2: String = o.receive_hit(h2)
			_after_hit(f, o, h2, res2, "")
		for it in items():
			var v4: Vector2 = it.global_position - origin
			if v4.length() < 120.0 and v4.x * f.facing > 0.0:
				it.resting = false
				it.vel = v4.normalized() * 360.0 + Vector2(0, -100)
		for p in proj.list:
			if p.pos.distance_to(origin) < 100.0 and (p.pos.x - origin.x) * f.facing > 0.0:
				p.vel = Vector2(f.facing * p.vel.length(), p.vel.y * 0.5)
				p.owner = f
				p.team = f.team
		fx.ring(origin + Vector2(f.facing * 20, 0), Color("c27bff"), 30.0)
		AudioHub.play("explosion", -8.0, 1.6)
		fx.shake(2.0)
	f.weapon["cd"] = float(d.get("rate", 0.5))
	f._note_weapon_use()
	f.use_ammo(1)


func fx_line(a: Vector2, b: Vector2, c: Color) -> void:
	for i in 16:
		fx.emit(a.lerp(b, i / 15.0), Vector2.ZERO, 0.18, 1.0, c, EffectsSystem.K_PIXEL, 0.0)


# =============================================================== items

func spawn_item(data: Dictionary, pos: Vector2, vel: Vector2, by: CatFighter, is_throw: bool) -> WeaponItem:
	var it := WeaponItem.new()
	_items_node.add_child(it)
	it.setup(data.duplicate(), pos, vel, by, is_throw, self)
	_trim_items()
	return it


func _trim_items() -> void:
	var list := items().filter(func(i): return i.resting and not i.permanent and i.pedestal == Vector2.INF)
	while list.size() > MAX_ITEMS:
		var oldest: WeaponItem = list[0]
		for i in list:
			if i.rest_t > oldest.rest_t:
				oldest = i
		fx.smoke(oldest.global_position, 3)
		oldest.queue_free()
		list.erase(oldest)


func try_pickup(f: CatFighter) -> bool:
	var best: WeaponItem = null
	var bd := 20.0 * f.size_mult
	for it in items():
		if not it.pickable():
			continue
		if it.id() == "fishobj" and not mode.can_take_fish(f):
			continue
		var d := (it.global_position as Vector2).distance_to(f.global_position + Vector2(0, -5))
		if d < bd:
			bd = d
			best = it
	if best == null:
		return false
	var data: Dictionary = best.data.duplicate()
	var ped: Vector2 = best.pedestal
	best.queue_free()
	f.weapon = data
	f.weapon["cd"] = 0.0
	if f.puppet:
		f.puppet.on_pickup()
	if data.get("id", "") == "fishobj":
		mode.on_fish_taken(f)
	if ped != Vector2.INF:
		mode.on_pedestal_taken(ped, data.get("id", ""))
	return true


func magnet_pull(f: CatFighter, dt: float) -> void:
	for it in items():
		if it.permanent or not it.pickable():
			continue
		var v: Vector2 = f.center() - it.global_position
		if v.length() < 100.0:
			it.resting = false
			it.vel = it.vel.lerp(v.normalized() * 240.0, 6.0 * dt)
			if v.length() < 14.0 and f.weapon.is_empty():
				f.weapon = it.data.duplicate()
				f.weapon["cd"] = 0.0
				it.queue_free()
				AudioHub.play("pickup", -6.0)


func _spawn_items(dt: float) -> void:
	if not mode.allow_item_spawns():
		return
	if bool(rules.get("items", true)) and rules.get("weapon_set", "all") != "none":
		item_t -= dt
		if item_t <= 0.0:
			var rate: int = clampi(int(rules.get("item_rate", 1)), 0, 3)
			item_t = ITEM_INTERVALS[rate] * rng.randf_range(0.75, 1.25)
			var xs: Array = arena.def.items
			var x: float = xs[rng.randi_range(0, xs.size() - 1)] + rng.randf_range(-20, 20)
			if rng.randf() < 0.3:
				var c := Crate.new()
				_items_node.add_child(c)
				c.setup(Vector2(x, -30), self)
				crates.append(c)
			else:
				var props: Array = arena.def.get("props", [])
				var id := WeaponDefs.pick_random(rules.get("weapon_set", "all"), rng)
				if not props.is_empty() and rng.randf() < 0.25:
					id = props[rng.randi_range(0, props.size() - 1)]
				if id != "":
					var it := spawn_item({"id": id, "ammo": int(WeaponDefs.get_def(id).get("ammo", -1)), "dur": int(WeaponDefs.get_def(id).get("dur", -1)), "hits": 0}, Vector2(x, -20), Vector2(0, 60), null, false)
					it.falling_in = true
	if bool(rules.get("powerups", true)):
		powerup_t -= dt
		if powerup_t <= 0.0:
			powerup_t = rng.randf_range(14.0, 22.0)
			var pts: Array = arena.def.get("powerups", [])
			if not pts.is_empty() and powerups.size() < 2:
				spawn_powerup(pts[rng.randi_range(0, pts.size() - 1)])


func spawn_powerup(pos: Vector2, kind: String = "") -> void:
	var kinds: Array = PowerUp.TYPES.keys()
	if kind == "":
		kind = kinds[rng.randi_range(0, kinds.size() - 1)]
	var pu := PowerUp.new()
	_items_node.add_child(pu)
	pu.setup(kind, pos, self)
	powerups.append(pu)
	fx.ring(pos, PowerUp.TYPES[kind].color, 14.0)


func crate_loot(pos: Vector2) -> void:
	if bool(rules.get("powerups", true)) and rng.randf() < 0.25:
		spawn_powerup(pos)
		return
	var id := WeaponDefs.pick_random(rules.get("weapon_set", "all"), rng)
	if id == "":
		id = WeaponDefs.pick_random("all", rng)
	spawn_item({"id": id, "ammo": int(WeaponDefs.get_def(id).get("ammo", -1)), "dur": int(WeaponDefs.get_def(id).get("dur", -1)), "hits": 0}, pos, Vector2(rng.randf_range(-40, 40), -160), null, false)


func spawn_decoy(f: CatFighter) -> void:
	var cfg := {"slot": f.slot, "team": f.team, "skin": f.skin, "name": f.display_name, "bot": true, "bot_level": 0}
	var d := add_fighter(cfg)
	d.is_decoy = true
	d.decoy_life = 8.0
	d.max_hp = 15.0
	d.hp = 15.0
	d.global_position = f.global_position + Vector2(-f.facing * 16, -4)
	d.set_state("air")
	fx.smoke(d.center(), 6, Color(1, 0.7, 0.85, 0.7))


func spawn_enemy(kind: String, pos: Vector2, lvl: int, hp: float) -> CatFighter:
	var skin: Dictionary = CosmeticDefs.ENEMY_MOUSE if kind == "mouse" else CosmeticDefs.ENEMY_FERAL
	var cfg := {"slot": 6, "team": 99, "skin": skin, "name": "CPU", "bot": true, "bot_level": lvl, "enemy": true}
	var e := add_fighter(cfg)
	e.max_hp = hp
	e.hp = hp
	e.respawn(pos, false)
	if kind == "feral" and rng.randf() < 0.7:
		var w := WeaponDefs.pick_random(rules.get("weapon_set", "all"), rng)
		if w != "":
			e.give_weapon(w)
	return e


func add_boss(b: Node) -> void:
	boss = b
	world.add_child(b)


# ============================================================ KOs etc.

func on_fighter_ko(victim: CatFighter, killer: CatFighter, cause: String) -> void:
	var credit := killer if killer != null and is_instance_valid(killer) else null
	if credit == null or credit == victim:
		if victim.recent_attacker() != null:
			credit = victim.recent_attacker()
	if credit == victim:
		credit = null
	if not victim.is_decoy:
		victim.stats.falls += 1
	if credit and is_instance_valid(credit) and can_damage(credit, victim) and not victim.is_decoy:
		credit.stats.kos += 1
		if cause == "ringout":
			credit.stats.ringouts += 1
		var wid: String = victim.last_hit_weapon
		var wd := WeaponDefs.get_def(wid)
		if not wd.is_empty():
			if wd.cat == "special":
				credit.stats.special_kos += 1
			elif wd.cat == "funny":
				credit.stats.funny_kos += 1
	elif not victim.is_decoy and not victim.is_enemy:
		victim.stats.selfdestructs += 1
	if victim.is_decoy:
		return
	if mode_id == "training" and cause == "ringout" and credit and not credit.is_bot:
		SaveData.max_progress("t_ringout", 1)
	AudioHub.play("ko", -2.0)
	AudioHub.duck_music(8.0, 0.8)
	fx.shake(6.0)
	if not victim.is_enemy:
		fx.text(victim.center() + Vector2(0, -20), "KO!", Pal.player_color(victim.slot), true)
	mode.on_ko(victim, credit, cause)
	# Dramatic slow-motion on round-deciding KOs.
	if phase == "fight" and not mode.check_round_end().is_empty():
		_slowmo(0.45)


func _slowmo(real_dur: float) -> void:
	if headless_fast:
		return
	Engine.time_scale = 0.3
	_slowmo_t = real_dur
	get_tree().create_timer(real_dur, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func on_tech(f: CatFighter) -> void:
	if mode_id == "training" and not f.is_bot:
		SaveData.max_progress("t_tech", 1)


func _check_blast_zones() -> void:
	var br := arena.blast_rect()
	for f in fighters:
		if f.dead or f.eliminated:
			continue
		if not br.has_point(f.global_position):
			var edge := Vector2(clampf(f.global_position.x, br.position.x + 20, br.end.x - 20), clampf(f.global_position.y, br.position.y + 20, br.end.y - 20))
			var killer: CatFighter = f.recent_attacker()
			if not f.is_decoy:
				fx.ring(edge, Pal.player_color(f.slot), 40.0)
				fx.burst(edge, Pal.player_color(f.slot), 20, 220.0)
				AudioHub.play("explosion", -4.0, 1.3)
			f.ring_out(killer)


func _separate_fighters() -> void:
	for i in fighters.size():
		var a: CatFighter = fighters[i]
		if not a.alive_in_round():
			continue
		for j in range(i + 1, fighters.size()):
			var b: CatFighter = fighters[j]
			if not b.alive_in_round():
				continue
			var d: Vector2 = b.global_position - a.global_position
			if absf(d.x) < 9.0 and absf(d.y) < 14.0:
				var s := 1.0 if d.x >= 0.0 else -1.0
				if d.x == 0.0:
					s = 1.0 if i % 2 == 0 else -1.0
				a.velocity.x -= s * 28.0
				b.velocity.x += s * 28.0


func _unstick(dt: float) -> void:
	_stuck_t += dt
	if _stuck_t < 0.5:
		return
	_stuck_t = 0.0
	for f in fighters:
		if f.alive_in_round() and f.test_move(f.global_transform, Vector2.ZERO):
			f.global_position.y -= 4.0


# ======================================================= round results

func _end_round(res: Dictionary) -> void:
	phase = "round_end"
	phase_t = 0.0
	fighting = false
	round_result = res
	var winners: Array = res.get("winners", [])
	for f in fighters:
		f.input.enabled = false
		f.attack = {}
		if f.alive_in_round():
			if f in winners:
				f.celebrate()
			elif not f.is_enemy:
				f.mourn()
	var key: Variant = res.get("key", null)
	if key != null:
		round_wins[key] = int(round_wins.get(key, 0)) + 1
	show_banner(res.get("text", "ROUND OVER"), res.get("color", Pal.UI_HILITE), 2.4)
	AudioHub.play("round_win" if not winners.is_empty() else "ui_back", 0.0)
	if not winners.is_empty():
		AudioHub.meow(1.2)


func _after_round() -> void:
	if mode.match_over(round_wins):
		phase = "match_end"
		phase_t = 0.0
		show_banner("GAME!", Pal.UI_HILITE, 1.8)
		AudioHub.play("victory", 0.0)
	else:
		_start_round()


func _finish_match() -> void:
	if finished:
		return
	finished = true
	Engine.time_scale = 1.0
	var summary := build_summary()
	Router.last_result = summary
	if session.get("smoke", false):
		return
	summary["rewards"] = SaveData.record_match(summary)
	if not Router.tournament.is_empty() and Router.tournament.get("active", false):
		Router.tournament["last"] = summary
		Router.goto("tournament", {"from_match": true})
	else:
		Router.goto("results")


func build_summary() -> Dictionary:
	var ranking: Array = mode.final_ranking()
	var winners: Array = mode.final_winners()
	var pl: Array = []
	var place := 1
	for f in ranking:
		pl.append({
			"slot": f.slot, "name": f.display_name, "bot": f.is_bot, "profile": f.profile_idx, "preset": f.preset_id,
			"team": f.team, "skin": f.skin, "stats": f.stats.duplicate(true), "won": f in winners, "score": f.score,
			"place": place, "device": f.device,
		})
		place += 1
	return {
		"mode": mode_id, "arena": session.arena, "duration": match_time, "players": pl,
		"winner_slots": winners.map(func(w): return w.slot), "title": mode.final_title(winners),
		"teams": mode.teams_active(), "extra_progress": mode.extra_progress(),
		"session": session,
	}


# ============================================================== devices

func _on_device_disconnected(device: String) -> void:
	for f in players():
		if f.device == device and not f.is_bot:
			disconnect_msg = "%s CONTROLLER DISCONNECTED" % f.display_name
			pause_menu.open_menu(device)
			return


func _on_device_connected(_device: String) -> void:
	if disconnect_msg != "":
		disconnect_msg = ""


func convert_to_bot(device: String) -> void:
	for f in players():
		if f.device == device:
			f.is_bot = true
			f.input.device = ""
			f.brain = BotBrain.new(f, int(rules.get("bot_level", 1)))
			f.display_name = f.display_name + "*"
	disconnect_msg = ""


func restart_match() -> void:
	Router.goto("match")
