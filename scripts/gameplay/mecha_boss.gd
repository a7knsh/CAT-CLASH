class_name MechaBoss
extends Node2D
## MECHA-MOUSER 9000 — the Boss Battle opponent. A giant robot mouse with
## telegraphed attacks: stomp shockwaves, a wall-bonking charge, homing
## missiles and (phase 2) a sweeping eye laser plus minion summons.
## Super-armoured: hits damage it but don't knock it around.

const W := 56.0
const H := 44.0

var ctl: Node = null
var max_hp := 600.0
var hp := 600.0
var phase := 1
var state := "intro"
var st := 0.0
var vel := Vector2.ZERO
var facing := -1
var flash := 0.0
var dead := false
var target: CatFighter = null
var contact_cd: Dictionary = {}
var laser_from := 0.0
var laser_to := 0.0
var laser_ang := 0.0
var stomp_x := 0.0
var floor_y := 0.0
var min_x := 40.0
var max_x := 600.0
var t := 0.0
var attack_count := 0
var _rng := RandomNumberGenerator.new()


func setup(controller: Node, players: int) -> void:
	ctl = controller
	_rng.randomize()
	max_hp = 420.0 + 180.0 * players
	hp = max_hp
	z_index = 9
	# Fight on the widest solid block.
	var best: Rect2 = ctl.arena.def.solids[0]
	for r in ctl.arena.def.solids:
		if r.size.x > best.size.x:
			best = r
	floor_y = best.position.y
	min_x = best.position.x + W * 0.5 + 4.0
	max_x = best.end.x - W * 0.5 - 4.0
	global_position = Vector2((min_x + max_x) * 0.5 + 60.0, floor_y - 220.0)


func hurtbox() -> Rect2:
	return Rect2(global_position + Vector2(-W * 0.5, -H), Vector2(W, H))


func targetable() -> bool:
	return not dead and state != "intro"


func is_enemy_of(f: Variant) -> bool:
	return f == null or not f.is_enemy


func receive_hit(h: Dictionary) -> String:
	if dead or state in ["intro", "dying"]:
		return "miss"
	var dmg: float = h.dmg
	if state == "dizzy":
		dmg *= 1.6
	hp -= dmg
	flash = 0.08
	var a: CatFighter = h.get("attacker")
	if a:
		a.stats.damage_dealt += dmg
	if bool(Settings.get_value("damage_numbers")):
		ctl.fx.number(hurtbox().get_center() + Vector2(_rng.randf_range(-10, 10), -20), dmg)
	if phase == 1 and hp <= max_hp * 0.5:
		phase = 2
		_go("roar")
	if hp <= 0.0:
		hp = 0.0
		_go("dying")
		AudioHub.play("ko", 0.0, 0.6)
	return "hit"


func _go(s: String) -> void:
	state = s
	st = 0.0


func _pick_target() -> void:
	var best: CatFighter = null
	var bd := INF
	for f in ctl.fighters:
		if f.is_enemy or not f.targetable():
			continue
		var d := absf(f.global_position.x - global_position.x)
		if d < bd:
			bd = d
			best = f
	target = best


func tick(dt: float) -> void:
	t += dt
	st += dt
	flash = maxf(0.0, flash - dt)
	for k in contact_cd.keys():
		contact_cd[k] -= dt
	var spd := 1.0 if phase == 1 else 1.35
	match state:
		"intro":
			vel.y += 600.0 * dt
			global_position.y = minf(global_position.y + vel.y * dt, floor_y)
			if global_position.y >= floor_y and st > 0.4:
				if st < 0.5:
					pass
				ctl.fx.shake(8.0)
				ctl.fx.dust(global_position, 10, 0)
				AudioHub.play("cannon", 0.0)
				AudioHub.play("roar", 0.0, 0.7)
				_go("idle")
		"idle":
			_pick_target()
			if target:
				facing = 1 if target.global_position.x > global_position.x else -1
				global_position.x = clampf(global_position.x + facing * 38.0 * spd * dt, min_x, max_x)
			if st > (1.3 if phase == 1 else 0.75):
				_choose_attack()
		"stomp_air":
			vel.y += 900.0 * dt
			global_position += vel * dt
			global_position.x = clampf(global_position.x, min_x, max_x)
			if global_position.y >= floor_y and vel.y > 0.0:
				global_position.y = floor_y
				_land_stomp()
		"stomp_land":
			if st > 0.6 / spd:
				_go("idle")
		"charge_warn":
			if st > 0.75 / spd:
				_go("charge")
				AudioHub.play("roar", -2.0, 1.2)
		"charge":
			global_position.x += facing * 300.0 * spd * dt
			if (facing > 0 and global_position.x >= max_x) or (facing < 0 and global_position.x <= min_x):
				global_position.x = clampf(global_position.x, min_x, max_x)
				ctl.fx.shake(7.0)
				ctl.fx.stars(global_position + Vector2(0, -H), 8)
				AudioHub.play("hit_metal", 0.0, 0.6)
				_go("dizzy")
			if st > 3.0:
				_go("idle")
		"dizzy":
			if st > 1.6:
				_go("idle")
		"missiles":
			var n := 3 if phase == 1 else 5
			var interval := 0.25
			if int(st / interval) > attack_count and attack_count < n:
				attack_count += 1
				var p: ProjectileSystem.Proj = ctl.proj.spawn("missile", global_position + Vector2(-facing * 10, -H - 4), Vector2(_rng.randf_range(-90, 90), -260), null,
					{"dmg": 9.0, "kb": 280.0, "ang": 50.0, "radius": 4.0, "life": 4.0, "homing": true, "explode_r": 22.0, "team": 99, "cause": "explosion"})
				p.from_boss = true
				AudioHub.play("shoot_pew", -2.0, 0.6)
			if st > interval * n + 0.6:
				_go("idle")
		"laser_warn":
			laser_ang = laser_from
			if st > 0.9:
				_go("laser")
				AudioHub.play("zap", 0.0, 0.6)
		"laser":
			var dur := 1.3
			laser_ang = lerpf(laser_from, laser_to, clampf(st / dur, 0.0, 1.0))
			_laser_hits()
			if st > dur:
				_go("idle")
		"summon":
			if st > 0.5 and attack_count == 0:
				attack_count = 1
				for i in 2:
					var x := clampf(global_position.x + (i * 2 - 1) * 60.0, min_x, max_x)
					ctl.spawn_enemy("mouse", Vector2(x, floor_y - 40), 1, 22.0)
				AudioHub.play("powerup", 0.0, 0.6)
			if st > 1.0:
				_go("idle")
		"roar":
			if st < dt * 1.5:
				ctl.show_banner("PHASE 2!", Pal.UI_BAD, 1.6)
				AudioHub.play("roar", 2.0, 0.5)
				ctl.fx.shake(10.0)
				ctl.hud.flash(Color(1, 0.3, 0.3, 0.35))
				for f in ctl.fighters:
					if f.targetable() and not f.is_enemy and f.center().distance_to(global_position) < 130.0:
						var dir := 1 if f.global_position.x > global_position.x else -1
						f.receive_hit({"attacker": null, "dmg": 4.0, "kb": 320.0, "ang": 50.0, "dir": dir, "src": global_position, "hitstop": 0.05, "cause": "hit", "can_block": true})
			if st > 1.5:
				_go("idle")
		"dying":
			if _rng.randf() < 0.25:
				var p2 := hurtbox().position + Vector2(_rng.randf() * W, _rng.randf() * H)
				ctl.fx.explosion(p2, 14.0)
				AudioHub.play("explosion", -6.0, _rng.randf_range(0.8, 1.3))
			if st > 2.4:
				dead = true
				visible = false
				ctl.fx.explosion(hurtbox().get_center(), 50.0)
				ctl.fx.burst(hurtbox().get_center(), Color("ffd23f"), 40, 260.0)
				AudioHub.play("explosion", 4.0, 0.6)
	_contact()
	queue_redraw()


func _choose_attack() -> void:
	attack_count = 0
	var options := ["stomp", "charge", "missiles"]
	if phase == 2:
		options.append_array(["laser", "summon", "stomp"])
	var pick: String = options[_rng.randi_range(0, options.size() - 1)]
	if pick == "summon" and ctl.enemies_alive().size() >= 3:
		pick = "laser"
	match pick:
		"stomp":
			_pick_target()
			stomp_x = clampf(target.global_position.x if target else global_position.x, min_x, max_x)
			vel = Vector2((stomp_x - global_position.x) / 0.85, -430.0)
			_go("stomp_air")
			AudioHub.play("jump", 0.0, 0.5)
		"charge":
			_pick_target()
			if target:
				facing = 1 if target.global_position.x > global_position.x else -1
			_go("charge_warn")
			AudioHub.play("warning", -4.0, 1.2)
		"missiles":
			_go("missiles")
		"laser":
			_pick_target()
			if target:
				facing = 1 if target.global_position.x > global_position.x else -1
			laser_from = deg_to_rad(-40.0)
			laser_to = deg_to_rad(28.0)
			_go("laser_warn")
			AudioHub.play("warning", -4.0, 1.5)
		"summon":
			_go("summon")


func _land_stomp() -> void:
	_go("stomp_land")
	ctl.fx.shake(9.0)
	ctl.fx.dust(global_position, 12, 0)
	AudioHub.play("cannon", 0.0, 0.8)
	for d in [-1, 1]:
		var p: ProjectileSystem.Proj = ctl.proj.spawn("shockwave", global_position + Vector2(d * W * 0.5, -2), Vector2(d * (230.0 if phase == 1 else 290.0), 0), null,
			{"dmg": 10.0, "kb": 300.0, "ang": 65.0, "radius": 6.0, "life": 1.3, "team": 99, "pierce": 4})
		p.from_boss = true


func _eye_pos() -> Vector2:
	return global_position + Vector2(facing * 22.0, -H + 14.0)


func _laser_dir() -> Vector2:
	return Vector2(cos(laser_ang) * facing, sin(laser_ang))


func _laser_hits() -> void:
	var a := _eye_pos()
	var dir := _laser_dir()
	for f in ctl.fighters:
		if f.is_enemy or not f.targetable():
			continue
		var c: Vector2 = f.center()
		var along := (c - a).dot(dir)
		if along < 0.0 or along > 420.0:
			continue
		var perp := absf((c - a).cross(dir))
		if perp < 9.0 and contact_cd.get(f, 0.0) <= 0.0:
			contact_cd[f] = 0.6
			f.receive_hit({"attacker": null, "dmg": 12.0, "kb": 330.0, "ang": 45.0, "dir": facing, "src": a, "hitstop": 0.06, "cause": "hit", "can_block": true})
			ctl.fx.hit(c, dir, 0.7, Color("ff5a5a"))


func _contact() -> void:
	if state in ["intro", "dying", "dizzy"] or dead:
		return
	var hb := hurtbox().grow(-4)
	for f in ctl.fighters:
		if f.is_enemy or not f.targetable():
			continue
		if hb.intersects(f.hurtbox()) and contact_cd.get(f, 0.0) <= 0.0:
			contact_cd[f] = 0.8
			var dir := 1 if f.global_position.x > global_position.x else -1
			var strong := state == "charge" or state == "stomp_land" and st < 0.1
			var res: String = f.receive_hit({"attacker": null, "dmg": 14.0 if strong else 6.0, "kb": 420.0 if strong else 240.0, "ang": 40.0, "dir": dir,
				"src": global_position + Vector2(0, -H * 0.5), "hitstop": 0.06, "cause": "hit", "can_block": true})
			if res == "hit":
				AudioHub.play("hit_metal", -2.0, 0.7)
				ctl.fx.hit(f.center(), Vector2(dir, -0.4), 0.6)


func _draw() -> void:
	var fx := float(facing)
	var white := flash > 0.0 and Settings.flash_ok()
	var metal := Color("9aa0b0") if not white else Color.WHITE
	var dark := Color("5a6070") if not white else Color(0.9, 0.9, 0.9)
	var bob := sin(t * 6.0) * 1.0 if state == "idle" else 0.0
	draw_set_transform(Vector2(0, bob), 0.0, Vector2(fx, 1))
	# Tail cable
	var prev := Vector2(-W * 0.5, -14)
	for i in 8:
		var p := Vector2(-W * 0.5 - 6 - i * 5, -14 + sin(t * 3.0 + i * 0.8) * 4 - i * 2)
		draw_line(prev, p, Pal.OUTLINE, 3.0)
		draw_line(prev, p, Color("ff9ab8"), 1.0)
		prev = p
	# Legs
	var step := sin(t * 8.0) * 2.0 if state in ["idle", "charge"] else 0.0
	for lx in [-16.0, 10.0]:
		draw_rect(Rect2(lx - 1, -12 + (step if lx < 0 else -step) * 0.5, 12, 13), Pal.OUTLINE)
		draw_rect(Rect2(lx, -11 + (step if lx < 0 else -step) * 0.5, 10, 11), dark)
		draw_rect(Rect2(lx - 2, -2, 14, 3), Pal.OUTLINE)
	# Body
	draw_rect(Rect2(-W * 0.5 - 1, -H + 8, W + 2, 30), Pal.OUTLINE)
	draw_rect(Rect2(-W * 0.5, -H + 9, W, 28), metal)
	draw_rect(Rect2(-W * 0.5, -H + 9, W, 2), metal.lightened(0.2))
	draw_rect(Rect2(-W * 0.5 + 8, -H + 22, 26, 12), Color("c8ccd8") if not white else Color.WHITE)
	for i in 3:
		draw_rect(Rect2(-W * 0.5 + 10 + i * 8, -H + 25, 5, 2), dark)
	if phase == 2:
		draw_line(Vector2(-10, -H + 12), Vector2(-4, -H + 20), Pal.OUTLINE, 1.0)
		draw_line(Vector2(-4, -H + 20), Vector2(-8, -H + 28), Pal.OUTLINE, 1.0)
	# Ears
	for ex in [6.0, 20.0]:
		draw_circle(Vector2(ex, -H + 2), 9.0, Pal.OUTLINE)
		draw_circle(Vector2(ex, -H + 2), 8.0, metal)
		draw_circle(Vector2(ex, -H + 3), 5.0, Color("ff9ab8"))
	# Head
	draw_rect(Rect2(4, -H + 4, 26, 24), Pal.OUTLINE)
	draw_rect(Rect2(5, -H + 5, 24, 22), metal)
	# Visor eye
	var eye_c := Color("ff3a3a") if phase == 1 else Color("ff1a6a")
	if state in ["charge_warn", "laser_warn"] and int(t * 12.0) % 2 == 0:
		eye_c = Color.WHITE
	draw_rect(Rect2(12, -H + 11, 16, 6), Pal.OUTLINE)
	draw_rect(Rect2(13, -H + 12, 14, 4), eye_c)
	draw_rect(Rect2(20 + sin(t * 2.0) * 3.0, -H + 12, 3, 4), Color.WHITE)
	# Nose + whisker antennae
	draw_rect(Rect2(29, -H + 20, 4, 4), Color("ff5a8a"))
	draw_line(Vector2(30, -H + 23), Vector2(42, -H + 19), Color(0.9, 0.9, 0.9), 1.0)
	draw_line(Vector2(30, -H + 24), Vector2(42, -H + 27), Color(0.9, 0.9, 0.9), 1.0)
	# Jets while airborne
	if state in ["stomp_air", "intro"]:
		for jx in [-14.0, 12.0]:
			draw_rect(Rect2(jx, 2, 6, 4 + sin(t * 40.0) * 2.0), Color("ffd23f"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Telegraphs (world-aligned)
	if state == "charge_warn":
		PixelFont.draw_outlined(self, Vector2(0, -H - 16), "!", Pal.UI_BAD, Pal.OUTLINE, 2)
		draw_line(Vector2(fx * W * 0.5, -10), Vector2(fx * 500.0, -10), Color(1, 0.2, 0.2, 0.3), 2.0)
	if state == "stomp_air":
		var sx := stomp_x - global_position.x
		draw_rect(Rect2(sx - W * 0.5, floor_y - global_position.y - 2, W, 2), Color(0, 0, 0, 0.4))
	if state in ["laser_warn", "laser"]:
		var a := _eye_pos() - global_position
		var d := _laser_dir()
		if state == "laser_warn":
			for i in 20:
				draw_rect(Rect2(a + d * (i * 20.0), Vector2(3, 1)), Color(1, 0.3, 0.3, 0.6))
		else:
			draw_line(a, a + d * 420.0, Color(1, 0.2, 0.4, 0.7), 6.0)
			draw_line(a, a + d * 420.0, Color.WHITE, 2.0)
	if state == "dizzy":
		for i in 3:
			var ang := t * 5.0 + i * TAU / 3.0
			draw_rect(Rect2(Vector2(cos(ang) * 16.0, -H - 6 + sin(ang) * 3.0), Vector2(3, 3)), Color("ffe84a"))
