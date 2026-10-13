class_name Crate
extends Node2D
## Breakable supply crate dropped from the sky. Hit it (or throw something at
## it) to smash it open for a weapon or power-up.

var hp := 14.0
var vel := Vector2.ZERO
var resting := false
var ctl: Node = null
var t := 0.0
var shake := 0.0
var landed_t := 0.0


func setup(pos: Vector2, controller: Node) -> void:
	global_position = pos
	ctl = controller
	z_index = 4


func hurtbox() -> Rect2:
	return Rect2(global_position + Vector2(-7, -14), Vector2(14, 14))


func is_enemy_of(_f: Variant) -> bool:
	return true


func tick(dt: float) -> void:
	t += dt
	shake = maxf(0.0, shake - dt)
	if not resting:
		vel.y = minf(vel.y + 700.0 * dt * ctl.gravity_mult, 300.0)
		var space := get_world_2d().direct_space_state
		var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -2), global_position + Vector2(0, vel.y * dt + 1), 1 | 4)
		var r := space.intersect_ray(q)
		if not r.is_empty() and vel.y > 0.0:
			global_position.y = r.position.y
			resting = true
			vel = Vector2.ZERO
			ctl.fx.dust(global_position, 4, 0)
			AudioHub.play("land", -6.0, 0.8)
		else:
			global_position += vel * dt
	else:
		landed_t += dt
		var space2 := get_world_2d().direct_space_state
		var q2 := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -2), global_position + Vector2(0, 3), 1 | 4)
		if space2.intersect_ray(q2).is_empty():
			resting = false
		if landed_t > 25.0:
			smash(null)
	if global_position.y > ctl.arena.size.y + 200:
		queue_free()
	queue_redraw()


func take_hit(dmg: float, by: Variant) -> void:
	hp -= dmg
	shake = 0.15
	AudioHub.play("hit_wood", -4.0)
	ctl.fx.burst(global_position + Vector2(0, -7), Color("c89060"), 4, 60.0)
	if hp <= 0.0:
		smash(by)


func smash(_by: Variant) -> void:
	if is_queued_for_deletion():
		return
	ctl.fx.burst(global_position + Vector2(0, -7), Color("a4683a"), 14, 140.0)
	ctl.fx.smoke(global_position + Vector2(0, -7), 4)
	AudioHub.play("crate_break", -2.0)
	ctl.crate_loot(global_position + Vector2(0, -8))
	queue_free()


func _draw() -> void:
	var o := Vector2(sin(t * 60.0) * 1.0 if shake > 0.0 else 0.0, 0)
	if not resting:
		# Little parachute
		draw_line(o + Vector2(-6, -14), o + Vector2(-9, -26), Color(0.9, 0.9, 0.9, 0.8), 1.0)
		draw_line(o + Vector2(6, -14), o + Vector2(9, -26), Color(0.9, 0.9, 0.9, 0.8), 1.0)
		draw_rect(Rect2(o + Vector2(-12, -30), Vector2(24, 4)), Color("ff5d5d"))
		draw_rect(Rect2(o + Vector2(-12, -30), Vector2(8, 4)), Color("f4f0ea"))
		draw_rect(Rect2(o + Vector2(4, -30), Vector2(8, 4)), Color("f4f0ea"))
	draw_rect(Rect2(o + Vector2(-8, -15), Vector2(16, 15)), Pal.OUTLINE)
	draw_rect(Rect2(o + Vector2(-7, -14), Vector2(14, 13)), Color("c08040"))
	draw_rect(Rect2(o + Vector2(-7, -14), Vector2(14, 2)), Color("e0a060"))
	draw_line(o + Vector2(-6, -12), o + Vector2(6, -2), Color("7a4a22"), 1.0)
	draw_line(o + Vector2(6, -12), o + Vector2(-6, -2), Color("7a4a22"), 1.0)
	draw_rect(Rect2(o + Vector2(-2, -9), Vector2(4, 3)), Color("ffd23f"))
