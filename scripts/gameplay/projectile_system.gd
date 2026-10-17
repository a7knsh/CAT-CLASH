class_name ProjectileSystem
extends Node2D
## All projectiles (arrows, lasers, snowballs, rockets, boomerangs, void orbs,
## boss missiles, hazard cannonballs...) live in one pooled list and are drawn
## by this node. Hit resolution goes through MatchController.projectile_hit so
## blocking, parrying (reflects!) and shields behave like melee.

class Proj:
	var kind := "laser"
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var grav := 0.0
	var life := 2.0
	var age := 0.0
	var owner: CatFighter = null
	var team := -1
	var dmg := 5.0
	var kb := 150.0
	var ang := 20.0
	var radius := 2.0
	var pierce := 0
	var bounces := 0
	var effect := ""
	var color := Color.WHITE
	var homing := false
	var returning := false
	var explode_r := 0.0
	var hits: Dictionary = {}
	var weapon := ""
	var cause := "projectile"
	var vortex := 0.0
	var dead := false
	var hostile_all := false
	var from_boss := false
	var trail: Array = []

const MAX := 160

var ctl: Node = null
var list: Array = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	z_index = 20
	_rng.randomize()


func spawn(kind: String, pos: Vector2, vel: Vector2, owner: CatFighter, opts: Dictionary = {}) -> Proj:
	if list.size() >= MAX:
		list.pop_front()
	var p := Proj.new()
	p.kind = kind
	p.pos = pos
	p.vel = vel
	p.owner = owner
	p.team = owner.team if owner else -1
	for k in opts.keys():
		p.set(k, opts[k])
	list.append(p)
	return p


func clear_all() -> void:
	list.clear()
	queue_redraw()


func tick(dt: float) -> void:
	var space := get_world_2d().direct_space_state
	for p in list:
		if p.dead:
			continue
		# The shooter may have been freed (e.g. a defeated survival enemy).
		if p.owner != null and not is_instance_valid(p.owner):
			p.owner = null
		p.age += dt
		p.life -= dt
		if p.life <= 0.0:
			_expire(p)
			continue
		if p.vortex > 0.0:
			_tick_vortex(p, dt)
			continue
		if p.homing:
			var tgt = _nearest_target(p, 220.0)
			if tgt:
				var desired = (tgt - p.pos).normalized() * p.vel.length()
				p.vel = p.vel.lerp(desired, 3.0 * dt)
		if p.kind == "boomerang":
			if p.age > 0.42:
				p.returning = true
			if p.returning:
				if p.owner == null or p.owner.dead:
					_expire(p)
					continue
				var to_owner = p.owner.center() - p.pos
				p.vel = p.vel.lerp(to_owner.normalized() * 420.0, 5.0 * dt)
				if to_owner.length() < 12.0:
					p.dead = true
					p.owner.boomerang_out = false
					if p.owner.weapon.is_empty():
						p.owner.give_weapon("boomerang")
					else:
						ctl.spawn_item({"id": "boomerang", "ammo": -1, "dur": -1, "hits": 0}, p.pos, Vector2(0, -40), null, false)
					continue
		if p.kind == "voidorb" and p.age > 0.7:
			_start_vortex(p)
			continue
		p.vel.y += p.grav * dt * (ctl.gravity_mult if ctl else 1.0)
		var from = p.pos
		var to = from + p.vel * dt
		var q := PhysicsRayQueryParameters2D.create(from, to, 1)
		var r := space.intersect_ray(q)
		if not r.is_empty():
			if p.kind == "boomerang":
				p.returning = true
				p.vel = p.vel.bounce(r.normal) * 0.7
				p.pos = r.position + r.normal
			elif p.bounces > 0 or (ctl and ctl.mod_bouncy and p.kind != "voidorb"):
				p.bounces -= 1
				p.vel = p.vel.bounce(r.normal) * 0.85
				p.pos = r.position + r.normal * 2.0
				AudioHub.play("land", -14.0, 1.6)
			elif p.kind == "voidorb":
				p.pos = r.position + r.normal * 4.0
				_start_vortex(p)
			else:
				p.pos = r.position
				_impact(p)
			continue
		p.pos = to
		if p.kind in ["rocket", "fireball", "missile"] and _rng.randf() < 0.6:
			ctl.fx.emit(p.pos, Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-10, 10)), 0.3, 2.0, Color(0.6, 0.55, 0.6, 0.6) if p.kind != "fireball" else Color(1, 0.6, 0.2, 0.8), EffectsSystem.K_SMOKE, -20.0)
		if p.kind in ["laser", "energy", "star", "ice", "bolt", "arrow"]:
			p.trail.append(p.pos)
			if p.trail.size() > 5:
				p.trail.pop_front()
		# Leaving the world
		if ctl and not ctl.world_rect().grow(80).has_point(p.pos):
			p.dead = true
			continue
		_check_hits(p)
	list = list.filter(func(x): return not x.dead)
	queue_redraw()


func _check_hits(p: Proj) -> void:
	for tgt in ctl.hittables():
		if p.dead:
			return
		if p.hits.has(tgt):
			continue
		if p.from_boss and (tgt == ctl.boss or (tgt is CatFighter and tgt.is_enemy)):
			continue
		if tgt is CatFighter:
			var f: CatFighter = tgt
			if f == p.owner and not p.hostile_all:
				continue
			if not f.targetable():
				continue
			if not p.hostile_all and is_instance_valid(p.owner) and not ctl.can_damage(p.owner, f):
				continue
		elif tgt.has_method("is_enemy_of") and p.owner and not tgt.is_enemy_of(p.owner) and not p.hostile_all:
			continue
		var hb: Rect2 = tgt.hurtbox()
		if not _circle_rect(p.pos, p.radius, hb):
			continue
		p.hits[tgt] = true
		var res: String = ctl.projectile_hit(p, tgt)
		match res:
			"parry":
				p.owner = tgt if tgt is CatFighter else p.owner
				p.team = p.owner.team if p.owner else -1
				p.vel = -p.vel * 1.25
				p.hits.clear()
				p.hits[tgt] = true
				p.life = maxf(p.life, 1.0)
				p.homing = false
				return
			"miss":
				continue
			_:
				if p.explode_r > 0.0:
					_impact(p)
					return
				if p.pierce > 0:
					p.pierce -= 1
				else:
					_impact(p, false)
					return


static func _circle_rect(c: Vector2, r: float, rect: Rect2) -> bool:
	var cx := clampf(c.x, rect.position.x, rect.end.x)
	var cy := clampf(c.y, rect.position.y, rect.end.y)
	return c.distance_squared_to(Vector2(cx, cy)) <= r * r


func _nearest_target(p: Proj, maxd: float) -> Variant:
	var best: Variant = null
	var bd := maxd
	for tgt in ctl.hittables():
		if tgt is Crate:
			continue
		if p.from_boss and tgt == ctl.boss:
			continue
		if tgt is CatFighter:
			if tgt == p.owner or not tgt.targetable() or (p.owner and not ctl.can_damage(p.owner, tgt)):
				continue
			if p.from_boss and tgt.is_enemy:
				continue
		elif p.owner == null:
			continue
		var c: Vector2 = tgt.hurtbox().get_center()
		var d := c.distance_to(p.pos)
		if d < bd:
			bd = d
			best = c
	return best


func _impact(p: Proj, world: bool = true) -> void:
	p.dead = true
	if p.explode_r > 0.0:
		ctl.explode(p.pos, p.explode_r, p.dmg, p.kb, p.owner, p.weapon)
		return
	match p.kind:
		"snowball":
			ctl.fx.burst(p.pos, Color.WHITE, 8, 80.0)
			AudioHub.play("hit_soft", -8.0, 1.4)
		"paint":
			ctl.fx.burst(p.pos, p.color, 6, 60.0)
		"fireball":
			ctl.fx.burst(p.pos, Color("ff8a2a"), 8, 90.0)
			AudioHub.play("fire", -8.0)
		"bubble":
			ctl.fx.ring(p.pos, Color(0.7, 0.95, 1.0), 8.0)
			AudioHub.play("bubble", -8.0, 1.3)
		"ice":
			ctl.fx.burst(p.pos, Color("c8f0ff"), 6, 80.0)
		"boomerang":
			pass
		"icicle", "vase":
			ctl.fx.burst(p.pos, Color("c8f0ff") if p.kind == "icicle" else Color("a0ffa0"), 10, 100.0)
			AudioHub.play("hit_glass", -6.0)
		_:
			if world:
				ctl.fx.spark(p.pos, -p.vel.normalized(), p.color, 4, 100.0)


func _expire(p: Proj) -> void:
	p.dead = true
	if p.kind == "boomerang" and p.owner:
		p.owner.boomerang_out = false
		ctl.spawn_item({"id": "boomerang", "ammo": -1, "dur": -1, "hits": 0}, p.pos, Vector2.ZERO, null, false)
	elif p.vortex > 0.0 or p.kind == "voidorb":
		ctl.explode(p.pos, 34.0, p.dmg, p.kb, p.owner, p.weapon)
	elif p.explode_r > 0.0:
		ctl.explode(p.pos, p.explode_r, p.dmg, p.kb, p.owner, p.weapon)


func _start_vortex(p: Proj) -> void:
	p.vortex = 2.2
	p.life = 2.2
	p.vel = Vector2.ZERO
	AudioHub.play("rumble", -4.0, 1.6)


func _tick_vortex(p: Proj, dt: float) -> void:
	p.vortex -= dt
	for f in ctl.fighters:
		if not f.targetable() or f == p.owner:
			continue
		var d: Vector2 = p.pos - f.center()
		if d.length() < 95.0:
			f.velocity += d.normalized() * 900.0 * dt * (1.0 - d.length() / 95.0 + 0.3)
			if f.state in ["idle", "run"]:
				f.set_state("air")
	for it in ctl.items():
		var d2: Vector2 = p.pos - it.global_position
		if d2.length() < 95.0:
			it.resting = false
			it.vel += d2.normalized() * 700.0 * dt


func _draw() -> void:
	for p in list:
		if p.dead:
			continue
		var dir: Vector2 = p.vel.normalized() if p.vel.length() > 1.0 else Vector2.RIGHT
		match p.kind:
			"arrow", "bolt":
				var c := Color("a4683a") if p.kind == "arrow" else Color("5a6078")
				draw_line(p.pos - dir * 7.0, p.pos, c, 1.0)
				draw_rect(Rect2(p.pos - Vector2(1, 1), Vector2(2, 2)), Color("d8dcec"))
				draw_rect(Rect2(p.pos - dir * 7.0 - Vector2(1, 1), Vector2(2, 2)), Color("f4f0ff"))
			"pebble":
				draw_rect(Rect2(p.pos - Vector2(1, 1), Vector2(3, 3)), Color("8a8a92"))
			"laser":
				draw_line(p.pos - dir * 9.0, p.pos, Color("6ae0ff"), 2.0)
				draw_line(p.pos - dir * 7.0, p.pos, Color.WHITE, 1.0)
			"energy":
				draw_circle(p.pos, 3.0, Color(0.85, 0.3, 0.8, 0.6))
				draw_circle(p.pos, 1.5, Color.WHITE)
			"snowball":
				draw_rect(Rect2(p.pos - Vector2(2, 2), Vector2(4, 4)), Pal.OUTLINE)
				draw_rect(Rect2(p.pos - Vector2(1.5, 1.5), Vector2(3, 3)), Color.WHITE)
			"paint":
				draw_rect(Rect2(p.pos - Vector2(1, 1), Vector2(3, 3)), p.color)
			"star":
				var a = p.age * 10.0
				for i in 5:
					var v := Vector2.from_angle(a + i * TAU / 5.0) * 3.0
					draw_line(p.pos, p.pos + v, Color("ffd23f"), 1.0)
				draw_rect(Rect2(p.pos - Vector2(1, 1), Vector2(2, 2)), Color.WHITE)
			"boomerang":
				var tex := Sprites.weapon_texture("boomerang")
				draw_set_transform(p.pos, p.age * 18.0, Vector2.ONE)
				draw_texture(tex, -tex.get_size() * 0.5)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"rocket", "missile":
				draw_set_transform(p.pos, dir.angle(), Vector2.ONE)
				draw_rect(Rect2(-6, -2, 9, 4), Pal.OUTLINE)
				draw_rect(Rect2(-5, -1, 7, 2), Color("3ab85a") if p.kind == "rocket" else Color("9aa4bc"))
				draw_rect(Rect2(2, -1, 2, 2), Color("e83a4a"))
				draw_rect(Rect2(-8, -1, 2, 2), Color("ffd23f"))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"ice":
				draw_colored_polygon(PackedVector2Array([p.pos + Vector2(4, 0), p.pos + Vector2(0, 3), p.pos + Vector2(-4, 0), p.pos + Vector2(0, -3)]), Color("c8f0ff"))
			"fireball":
				draw_circle(p.pos, 3.5, Color(1.0, 0.45, 0.1, 0.7))
				draw_circle(p.pos, 2.0, Color("ffe080"))
			"bubble":
				draw_arc(p.pos, 6.0, 0, TAU, 14, Color(0.7, 0.95, 1.0, 0.85), 1.0)
				draw_rect(Rect2(p.pos + Vector2(-3, -4), Vector2(2, 1)), Color.WHITE)
			"voidorb":
				var rr := 5.0 if p.vortex <= 0.0 else 7.0 + sin(p.age * 20.0)
				if p.vortex > 0.0:
					for i in 3:
						var ra := 30.0 + fmod(p.age * 60.0 + i * 20.0, 60.0)
						draw_arc(p.pos, 90.0 - ra, 0, TAU, 24, Color(0.55, 0.3, 0.9, 0.25), 1.0)
				draw_circle(p.pos, rr + 2.0, Color("8a4ae0"))
				draw_circle(p.pos, rr, Color("0a0612"))
			"shockwave":
				draw_rect(Rect2(p.pos + Vector2(-4, -8), Vector2(8, 8)), Color(1, 0.8, 0.4, 0.8))
				draw_rect(Rect2(p.pos + Vector2(-2, -12), Vector2(4, 4)), Color(1, 1, 0.8, 0.6))
			"cannonball":
				draw_circle(p.pos, 5.0, Pal.OUTLINE)
				draw_circle(p.pos, 4.0, Color("3a3440"))
				draw_rect(Rect2(p.pos + Vector2(-2, -2), Vector2(1, 1)), Color(1, 1, 1, 0.6))
			"icicle":
				draw_colored_polygon(PackedVector2Array([p.pos + Vector2(-3, -10), p.pos + Vector2(3, -10), p.pos + Vector2(0, 2)]), Color("c8f0ff"))
			"vase":
				draw_rect(Rect2(p.pos - Vector2(4, 6), Vector2(8, 10)), Color(0.6, 1.0, 0.6, 0.6))
				draw_rect(Rect2(p.pos - Vector2(3, 5), Vector2(6, 8)), Color("6a5a8a"))
			_:
				draw_circle(p.pos, p.radius, p.color)
		if p.trail.size() > 1:
			for i in range(1, p.trail.size()):
				var c2: Color = p.color
				c2.a = float(i) / p.trail.size() * 0.5
				draw_line(p.trail[i - 1], p.trail[i], c2, 1.0)
