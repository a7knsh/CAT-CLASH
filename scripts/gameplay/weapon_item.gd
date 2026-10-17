class_name WeaponItem
extends Node2D
## A weapon (or the capture fish) lying in, falling into, or flying through
## the arena. Uses lightweight ray-cast physics instead of rigid bodies so
## items never tunnel through floors or bounce forever.

const GRAVITY := 900.0
const LIFETIME := 18.0
const RADIUS := 5.0

var data: Dictionary = {}       # {id, ammo, dur, hits}
var vel := Vector2.ZERO
var ang := 0.0
var ang_vel := 0.0
var resting := false
var rest_t := 0.0
var thrower: CatFighter = null
var thrown := false
var thrown_t := 0.0
var hit_set: Dictionary = {}
var ctl: Node = null
var falling_in := false
var permanent := false   # objectives (fish) never despawn
var pedestal := Vector2.INF  # training racks restock here
var age := 0.0
var bounces := 0


func setup(d: Dictionary, pos: Vector2, v: Vector2, by: CatFighter, is_throw: bool, controller: Node) -> void:
	data = d
	global_position = pos
	vel = v
	thrower = by
	thrown = is_throw
	ctl = controller
	ang_vel = (14.0 if is_throw else 4.0) * (1.0 if v.x >= 0 else -1.0)
	z_index = 5
	permanent = d.get("id", "") == "fishobj"


func id() -> String:
	return data.get("id", "")


func tick(dt: float) -> void:
	age += dt
	if resting:
		rest_t += dt
		ang = lerp_angle(ang, 0.0, 10.0 * dt)
		# Still check that the ground under us exists (trapdoors, moving platforms).
		if not _ground_below(3.0):
			resting = false
		if rest_t > LIFETIME and not permanent:
			if ctl:
				ctl.fx.smoke(global_position, 4)
			queue_free()
		queue_redraw()
		return
	thrown_t += dt
	var grav = GRAVITY * (ctl.gravity_mult if ctl else 1.0)
	if thrown and thrown_t < 0.25:
		grav *= 0.35
	vel.y = minf(vel.y + grav * dt, 520.0)
	ang += ang_vel * dt
	var from := global_position
	var to := from + vel * dt
	var hit := _ray(from, to)
	if hit.is_empty():
		global_position = to
	else:
		var n: Vector2 = hit.normal
		global_position = hit.position + n * 1.0
		if n.y < -0.6 and vel.y > 0.0:
			# Floor: bounce once or twice, then rest.
			if absf(vel.y) > 140.0 and bounces < 2:
				vel = Vector2(vel.x * 0.55, -vel.y * 0.35)
				bounces += 1
				AudioHub.play("land", -14.0, 1.4)
			else:
				_settle()
		else:
			vel = vel.bounce(n) * 0.45
			ang_vel *= -0.5
			bounces += 1
		if thrown and vel.length() < 120.0:
			thrown = false
	if thrown and vel.length() < 140.0:
		thrown = false
	if bounces > 6 and vel.length() < 60.0:
		_settle()
	queue_redraw()


func _settle() -> void:
	resting = true
	rest_t = 0.0
	vel = Vector2.ZERO
	thrown = false
	ang_vel = 0.0
	if data.get("empty", false) and ctl:
		# Empty guns vanish once they land.
		ctl.fx.smoke(global_position, 3)
		queue_free()


func _ray(from: Vector2, to: Vector2) -> Dictionary:
	var space := get_world_2d().direct_space_state
	var mask := 1
	if vel.y > 0.0:
		mask |= 4
	var q := PhysicsRayQueryParameters2D.create(from, to + (to - from).normalized() * RADIUS, mask)
	var r := space.intersect_ray(q)
	if r.is_empty():
		return {}
	# One-way platforms only stop items falling onto them from above.
	if r.collider is CollisionObject2D and (r.collider as CollisionObject2D).collision_layer & 4 and r.normal.y > -0.6:
		return {}
	return r


func _ground_below(dist: float) -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -2), global_position + Vector2(0, RADIUS + dist), 1 | 4)
	return not space.intersect_ray(q).is_empty()


func pickable() -> bool:
	return not (thrown and thrown_t < 0.4) and not data.get("empty", false)


func _draw() -> void:
	var wid := id()
	var tex := Sprites.weapon_texture(wid)
	var grip := Sprites.weapon_grip(wid)
	var w := tex.get_width()
	var h := tex.get_height()
	var blink := rest_t > LIFETIME - 3.0 and not permanent and int(rest_t * 8.0) % 2 == 0
	if blink:
		return
	var off := Vector2(-w * 0.5, -h + 1) if resting else Vector2(-w * 0.5, -h * 0.5)
	if resting:
		# Rarity glow + bob so pickups read clearly.
		var d := WeaponDefs.get_def(wid)
		var rc: Color = Pal.RARITY_COLORS.get(d.get("rarity", "common"), Color.WHITE)
		if wid == "fishobj":
			rc = Color("ffd23f")
		var bob := sin(age * 4.0) * 1.0
		draw_rect(Rect2(Vector2(-w * 0.5 - 1, -1), Vector2(w + 2, 1)), Color(rc, 0.5))
		draw_set_transform(Vector2(0, bob - 1), 0.0, Vector2.ONE)
		draw_texture(tex, off)
		if int(age * 3.0) % 3 == 0:
			draw_rect(Rect2(Vector2(w * 0.5 - 2, -h - 1 + bob), Vector2(1, 1)), Color(1, 1, 1, 0.9))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_set_transform(Vector2.ZERO, ang, Vector2.ONE)
		draw_texture(tex, -Vector2(w, h) * 0.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
