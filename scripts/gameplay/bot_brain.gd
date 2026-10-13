class_name BotBrain
extends RefCounted
## CPU opponent. Writes into the fighter's FighterInput exactly like a human
## would, so bots obey every movement and combat rule. Difficulty scales
## reaction time, defensive skill, aggression and decision quality.
## Also drives training dummies (stand / walk / jump / block / cpu).

const LEVELS := [
	{"react": 0.42, "block": 0.06, "parry": 0.0, "aggr": 0.45, "dodge": 0.04, "pickup": 0.6, "throw": 0.15, "heavy": 0.15, "recover": 0.7, "jitter": 14.0},
	{"react": 0.24, "block": 0.22, "parry": 0.05, "aggr": 0.7, "dodge": 0.1, "pickup": 0.85, "throw": 0.25, "heavy": 0.25, "recover": 0.95, "jitter": 8.0},
	{"react": 0.14, "block": 0.35, "parry": 0.15, "aggr": 0.85, "dodge": 0.18, "pickup": 1.0, "throw": 0.3, "heavy": 0.3, "recover": 1.0, "jitter": 4.0},
	{"react": 0.08, "block": 0.45, "parry": 0.32, "aggr": 0.95, "dodge": 0.22, "pickup": 1.0, "throw": 0.35, "heavy": 0.35, "recover": 1.0, "jitter": 2.0},
]

var f: CatFighter
var level := 1
var p: Dictionary
var rng := RandomNumberGenerator.new()
var dummy_mode := ""
var think_t := 0.0
var goal := Vector2.ZERO
var goal_kind := "fight"
var target: CatFighter = null
var target_item: WeaponItem = null
var move_dir := 0.0
var want_jump := false
var want_drop := false
var block_t := 0.0
var attack_cd := 0.0
var stuck_t := 0.0
var last_pos := Vector2.ZERO
var unstick_t := 0.0
var unstick_dir := 1.0
var defend_cd := 0.0
var dummy_t := 0.0
var jumped_t := 0.0


func _init(fighter: CatFighter, lvl: int) -> void:
	f = fighter
	level = clampi(lvl, 0, LEVELS.size() - 1)
	p = LEVELS[level]
	rng.randomize()


func think(dt: float) -> void:
	var inp := f.input
	inp.move = Vector2.ZERO
	for a in InputHub.ACTIONS:
		inp.bot_hold(a, false)
	if f.ctl == null or not f.ctl.fighting:
		return
	if dummy_mode != "" and dummy_mode != "cpu":
		_dummy(dt)
		return
	think_t -= dt
	attack_cd -= dt
	defend_cd -= dt
	block_t -= dt
	unstick_t -= dt
	jumped_t -= dt
	if think_t <= 0.0:
		think_t = float(p.react) * rng.randf_range(0.7, 1.3)
		_decide()
	_execute(dt)


# ------------------------------------------------------------- decisions

func _enemies() -> Array:
	var out: Array = []
	for o in f.ctl.fighters:
		if o != f and o.targetable() and f.ctl.can_damage(f, o):
			out.append(o)
	return out


func _decide() -> void:
	target = null
	target_item = null
	var me := f.global_position
	# Mode objective (hill, fish, base...)
	var obj: Variant = f.ctl.mode.bot_objective(f) if f.ctl.mode else null
	var enemies := _enemies()
	var best_d := INF
	for e in enemies:
		var d := me.distance_to(e.global_position)
		if level >= 2:
			d *= 0.6 + 0.4 * (e.hp / e.max_hp)
		if e.is_decoy:
			d *= 1.3 if level >= 2 else 0.9
		if d < best_d:
			best_d = d
			target = e
	# Grab a weapon if unarmed and one is close.
	if f.weapon.is_empty() and rng.randf() < float(p.pickup):
		var bi: WeaponItem = null
		var bd := 170.0
		for it in f.ctl.items():
			if not it.pickable() or it.id() == "fishobj" and not (obj is Dictionary and obj.get("fish", false)):
				continue
			var d2 := me.distance_to(it.global_position) + absf(it.global_position.y - me.y) * 1.5
			if d2 < bd:
				bd = d2
				bi = it
		if bi and (target == null or best_d > 60.0):
			target_item = bi
	if obj is Dictionary and obj.has("pos") and (target == null or best_d > 70.0 or obj.get("force", false)):
		goal = obj.pos
		goal_kind = "objective"
	elif target_item:
		goal = target_item.global_position
		goal_kind = "item"
	elif target:
		goal = target.global_position
		goal_kind = "fight"
		if _ranged() and level >= 1:
			# Keep some distance with guns.
			var side := signf(me.x - target.global_position.x)
			if side == 0.0:
				side = 1.0
			goal.x = target.global_position.x + side * 110.0
	else:
		goal = f.ctl.arena.size * 0.5
		goal_kind = "idle"
	goal.x += rng.randf_range(-float(p.jitter), float(p.jitter))


func _ranged() -> bool:
	var d := f.weapon_def()
	return not d.is_empty() and WeaponDefs.is_ranged(d) and int(f.weapon.get("ammo", 0)) != 0


func _reach() -> float:
	if f.weapon.is_empty():
		return 16.0
	var d := f.weapon_def()
	return float(d.get("reach", 18)) + 8.0


# -------------------------------------------------------------- execution

func _execute(dt: float) -> void:
	var inp := f.input
	if target != null and (not is_instance_valid(target) or not target.targetable()):
		target = null
		think_t = 0.0
	if target_item != null and not is_instance_valid(target_item):
		target_item = null
	var me := f.global_position
	var arena: Arena = f.ctl.arena
	# 1) Off-stage recovery.
	if not f.on_floor and _over_pit(me):
		if rng.randf() < float(p.recover):
			var cx := arena.size.x * 0.5
			var dir := signf(cx - me.x)
			inp.move.x = dir
			if f.velocity.y > -20.0 and f.air_jumps > 0 and jumped_t <= 0.0:
				inp.bot_press("jump")
				jumped_t = 0.25
			elif f.wall_dir != 0 and jumped_t <= 0.0:
				inp.move.x = float(f.wall_dir)
				inp.bot_press("jump")
				jumped_t = 0.2
			elif f.air_dodge_ready and f.air_jumps == 0 and f.velocity.y > 120.0 and level >= 1:
				inp.move = Vector2(dir, -1).normalized()
				inp.bot_press("dodge")
		return
	# 2) Hazard avoidance.
	var danger := arena.danger_at(me + Vector2(0, -4))
	if danger > 0.5:
		var dl := arena.danger_at(me + Vector2(-40, -4))
		var dr := arena.danger_at(me + Vector2(40, -4))
		inp.move.x = -1.0 if dl < dr else 1.0
		var trapped := dl > 0.5 and dr > 0.5
		if f.on_floor and (trapped or arena.danger_at(me + Vector2(0, -30)) < 0.3):
			if jumped_t <= 0.0:
				inp.bot_press("jump")
				jumped_t = 0.4
		return
	# 3) Defence against close attacks and incoming projectiles.
	if defend_cd <= 0.0:
		_defend()
	if block_t > 0.0:
		inp.bot_hold("block", true)
		return
	# 4) Navigation toward goal.
	var dx := goal.x - me.x
	var dy := goal.y - me.y
	if goal_kind == "fight" and target:
		dx = target.global_position.x - me.x
		dy = target.global_position.y - me.y
	var reach := _reach()
	var want_x := 0.0
	var close_enough := reach * 0.8 if goal_kind == "fight" else 6.0
	if goal_kind == "fight" and _ranged():
		close_enough = 40.0
		dx = goal.x - me.x
	if absf(dx) > close_enough:
		want_x = signf(dx)
	# Gap / edge check.
	if f.on_floor and want_x != 0.0:
		var ahead := me + Vector2(want_x * 18.0, -6.0)
		var gy := arena.ground_y_at(ahead.x, me.y - 10.0)
		if gy == INF or gy > me.y + 50.0:
			# Jump the gap if the goal is across and there's ground on the far side.
			var far := arena.ground_y_at(me.x + want_x * 110.0, me.y - 30.0)
			if far < me.y + 40.0 and jumped_t <= 0.0:
				inp.bot_press("jump")
				inp.bot_hold("jump", true)
				jumped_t = 0.5
			elif goal_kind != "fight" or absf(dy) < 40.0:
				want_x = 0.0
	inp.move.x = want_x
	# Climb toward targets above / drop toward targets below.
	if dy < -26.0 and f.on_floor and jumped_t <= 0.0 and absf(dx) < 140.0:
		inp.bot_press("jump")
		inp.bot_hold("jump", true)
		jumped_t = 0.45
	elif dy < -26.0 and not f.on_floor and f.velocity.y > 0.0 and f.air_jumps > 0 and jumped_t <= 0.0:
		inp.bot_press("jump")
		jumped_t = 0.3
	elif dy > 30.0 and f.on_floor and absf(dx) < 60.0 and jumped_t <= 0.0:
		inp.move.y = 1.0
		inp.bot_press("jump")
		jumped_t = 0.4
	if f.is_on_wall() and f.on_floor and want_x != 0.0 and jumped_t <= 0.0:
		inp.bot_press("jump")
		inp.bot_hold("jump", true)
		jumped_t = 0.4
	# 5) Pick up items we're standing on.
	if f.weapon.is_empty():
		for it in f.ctl.items():
			if it.pickable() and it.global_position.distance_to(me + Vector2(0, -4)) < 18.0:
				if it.id() != "fishobj" or (f.ctl.mode and f.ctl.mode.bot_wants_fish(f)):
					inp.bot_press("throw")
					break
	# 6) Attack.
	if target and attack_cd <= 0.0 and f.actionable():
		_attack(dx, dy)
	# 7) Anti-stuck.
	stuck_t += dt
	if stuck_t > 1.2:
		if me.distance_to(last_pos) < 4.0 and want_x != 0.0:
			unstick_t = 0.5
			unstick_dir = -want_x if rng.randf() < 0.5 else want_x
			inp.bot_press("jump")
			inp.bot_hold("jump", true)
		stuck_t = 0.0
		last_pos = me
	if unstick_t > 0.0:
		inp.move.x = unstick_dir


func _attack(dx: float, dy: float) -> void:
	var inp := f.input
	var reach := _reach()
	var ady := absf(dy)
	if _ranged():
		if ady < 16.0 and absf(dx) < 300.0:
			f.facing = 1 if dx > 0 else -1
			inp.move.x = signf(dx) * 0.3
			inp.bot_press("heavy" if rng.randf() < float(p.heavy) * 0.5 else "light")
			attack_cd = rng.randf_range(0.25, 0.6) / maxf(0.5, float(p.aggr))
		elif dy < -40.0 and absf(dx) < 40.0:
			inp.move.y = -1.0
			inp.bot_press("light")
			attack_cd = 0.4
		return
	if absf(dx) < reach and ady < 22.0:
		if rng.randf() > float(p.aggr):
			attack_cd = 0.25
			return
		f.facing = 1 if dx > 0 else -1
		if not f.on_floor and dy > 8.0:
			inp.move.y = 1.0
		elif dy < -14.0:
			inp.move.y = -1.0
		elif f.on_floor and target.state == "crouch" and rng.randf() < 0.5:
			inp.move.y = 1.0
		var heavy := rng.randf() < float(p.heavy)
		inp.bot_press("heavy" if heavy else "light")
		if heavy and level >= 2 and target.state in ["stunned", "knockdown", "frozen", "bubbled"]:
			inp.bot_hold("heavy", true)
		attack_cd = rng.randf_range(0.08, 0.3) / float(p.aggr)
	elif absf(dx) < 26.0 and dy < -20.0 and dy > -70.0:
		inp.move.y = -1.0
		inp.bot_press("light")
		attack_cd = 0.3
	elif not f.weapon.is_empty() and absf(dx) < 160.0 and ady < 24.0 and rng.randf() < float(p.throw) * 0.15:
		f.facing = 1 if dx > 0 else -1
		inp.bot_press("throw")
		attack_cd = 0.5


func _defend() -> void:
	var inp := f.input
	var me := f.center()
	for e in _enemies():
		if e.state != "attack" or e.attack.is_empty():
			continue
		var mv: Dictionary = e.attack.mv
		if mv.kind != "melee":
			continue
		var d := me.distance_to(e.center())
		if d > 46.0 or e.attack.t > mv.startup:
			continue
		var toward := signf(me.x - e.global_position.x) == float(e.facing)
		if not toward:
			continue
		defend_cd = 0.4
		var r := rng.randf()
		f.facing = 1 if e.global_position.x > f.global_position.x else -1
		if r < float(p.parry):
			inp.bot_press("block")
			block_t = 0.15
		elif r < float(p.parry) + float(p.block) and f.on_floor:
			inp.bot_press("block")
			block_t = 0.35
		elif r < float(p.parry) + float(p.block) + float(p.dodge):
			inp.move.x = -float(f.facing)
			inp.bot_press("dodge")
		return
	# Projectiles
	for pr in f.ctl.proj.list:
		if pr.owner == f or pr.dead:
			continue
		if pr.owner and not f.ctl.can_damage(pr.owner, f):
			continue
		var to: Vector2 = me - pr.pos
		if to.length() < 70.0 and pr.vel.dot(to) > 0.0:
			defend_cd = 0.5
			var r2 := rng.randf()
			if r2 < float(p.parry) * 0.7:
				f.facing = 1 if pr.pos.x > f.global_position.x else -1
				inp.bot_press("block")
				block_t = 0.12
			elif r2 < float(p.block) + float(p.parry) and f.on_floor:
				f.facing = 1 if pr.pos.x > f.global_position.x else -1
				inp.bot_press("block")
				block_t = 0.3
			elif r2 < 0.6 and f.on_floor:
				inp.bot_press("jump")
			return


func _over_pit(me: Vector2) -> bool:
	var arena: Arena = f.ctl.arena
	var gy := arena.ground_y_at(me.x, me.y - 4.0)
	if gy == INF:
		return true
	if me.y > arena.size.y - 20.0:
		return true
	return false


# ---------------------------------------------------------------- dummies

func _dummy(dt: float) -> void:
	var inp := f.input
	dummy_t += dt
	match dummy_mode:
		"walk":
			var cx: float = f.spawn_point.x
			inp.move.x = 1.0 if sin(dummy_t * 0.8) > 0.0 else -1.0
			if absf(f.global_position.x - cx) > 70.0:
				inp.move.x = signf(cx - f.global_position.x)
		"jump":
			if f.on_floor and fmod(dummy_t, 1.4) < dt * 1.5:
				inp.bot_press("jump")
				inp.bot_hold("jump", true)
		"block":
			inp.bot_hold("block", true)
			if f.state == "idle":
				inp.bot_press("block")
	# Always try to get back onto the stage.
	if not f.on_floor and _over_pit(f.global_position):
		inp.move.x = signf(f.ctl.arena.size.x * 0.5 - f.global_position.x)
		if f.velocity.y > 0.0 and f.air_jumps > 0:
			inp.bot_press("jump")
