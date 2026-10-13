class_name Hazard
extends Node2D
## Data-driven stage hazards. Every dangerous hazard is telegraphed (warning
## sound, flashing marker or shaking prop) before it can hurt anyone, giving
## players a fair chance to react. Types:
##   vent      updraft that launches cats upward (recovery tool, not damage)
##   flame     stove burners that flare periodically (burn)
##   cannon    a cannonball sweeps across the deck
##   icicles   icicles shake, then fall
##   lava      lava rises to cover the low ground, then recedes
##   trapdoor  part of the floor opens over the moat
##   laser     a full-width laser beam (jump over it!)
##   crusher   a hydraulic press slams down
##   haunt     a ghostly vase is hurled at a random cat

var h: Dictionary
var arena: Arena
var type := ""
var t := 0.0
var phase := "idle"
var phase_t := 0.0
var cooldowns: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var lava_y := 0.0
var target_x := 0.0
var trap_body: StaticBody2D
var crusher_y := 0.0


func setup(d: Dictionary, a: Arena) -> void:
	h = d
	arena = a
	type = d.type
	z_index = 8 if type != "lava" else 12
	_rng.randomize()
	t = _rng.randf_range(0.0, 2.0)
	match type:
		"lava":
			lava_y = float(d.base_y)
		"trapdoor":
			trap_body = StaticBody2D.new()
			trap_body.collision_layer = 1
			var cs := CollisionShape2D.new()
			var sh := RectangleShape2D.new()
			var r: Rect2 = d.rect
			sh.size = r.size
			cs.shape = sh
			cs.position = r.position + r.size * 0.5
			trap_body.add_child(cs)
			a.add_child.call_deferred(trap_body)
		"crusher":
			crusher_y = (d.rect as Rect2).position.y


func ctl() -> Node:
	return arena.ctl


func _period() -> float:
	return float(h.get("period", 8.0))


func _set_phase(p: String) -> void:
	phase = p
	phase_t = 0.0


func tick(dt: float) -> void:
	t += dt
	phase_t += dt
	for k in cooldowns.keys():
		cooldowns[k] -= dt
	match type:
		"vent": _tick_vent(dt)
		"flame": _tick_flame(dt)
		"cannon": _tick_cannon(dt)
		"icicles": _tick_icicles(dt)
		"lava": _tick_lava(dt)
		"trapdoor": _tick_trapdoor(dt)
		"laser": _tick_laser(dt)
		"crusher": _tick_crusher(dt)
		"haunt": _tick_haunt(dt)
	queue_redraw()


func _cool(f: Object, dur: float) -> bool:
	if cooldowns.get(f, 0.0) > 0.0:
		return false
	cooldowns[f] = dur
	return true


# ------------------------------------------------------------------ vent
func _tick_vent(dt: float) -> void:
	var r: Rect2 = h.rect
	var zone := Rect2(r.position + Vector2(0, -60), Vector2(r.size.x, 60 + r.size.y))
	for f in ctl().fighters:
		if not f.targetable():
			continue
		if zone.has_point(f.global_position):
			f.velocity.y = minf(f.velocity.y, -float(h.power) * 0.75)
			if f.state in ["idle", "run", "crouch"]:
				f.set_state("air")
			if _cool(f, 0.4):
				AudioHub.play("dodge", -8.0, 0.7)
	if _rng.randf() < 0.4:
		ctl().fx.emit(Vector2(_rng.randf_range(r.position.x, r.end.x), r.position.y), Vector2(0, -90), 0.5, 1.0, Color(1, 1, 1, 0.5), EffectsSystem.K_PIXEL, 0.0)


# ----------------------------------------------------------------- flame
func _tick_flame(dt: float) -> void:
	var cyc := fmod(t, _period())
	var on: float = h.get("on", 2.0)
	var warn_start := _period() - on - 1.2
	var r: Rect2 = h.rect
	if cyc > warn_start and cyc < _period() - on:
		if _rng.randf() < 0.3:
			ctl().fx.emit(Vector2(_rng.randf_range(r.position.x, r.end.x), r.end.y), Vector2(0, -40), 0.3, 1.0, Color("ffb040"), EffectsSystem.K_SPARK, 0.0)
		phase = "warn"
	elif cyc >= _period() - on:
		if phase != "on":
			AudioHub.play("fire", -2.0)
		phase = "on"
		for f in ctl().fighters:
			if f.targetable() and r.grow(2).intersects(f.hurtbox()) and _cool(f, 0.6):
				ctl().hazard_hit(f, 9.0, Vector2(0, -330), "burn")
		if _rng.randf() < 0.8:
			ctl().fx.emit(Vector2(_rng.randf_range(r.position.x, r.end.x), r.end.y), Vector2(_rng.randf_range(-10, 10), -110), 0.35, 3.0, Color("ff8a2a"), EffectsSystem.K_SMOKE, -40.0)
	else:
		phase = "idle"


# ---------------------------------------------------------------- cannon
func _tick_cannon(_dt: float) -> void:
	var cyc := fmod(t, _period())
	var from_right: bool = h.get("from_right", true)
	var sx := arena.size.x + 40.0 if from_right else -40.0
	if cyc > _period() - 1.6 and phase != "warn" and phase != "fired":
		phase = "warn"
		AudioHub.play("warning", -6.0)
	if cyc < 0.1 and phase == "warn":
		phase = "fired"
		AudioHub.play("cannon", 0.0)
		ctl().fx.shake(3.0)
		ctl().proj.spawn("cannonball", Vector2(sx, float(h.y) - 6.0), Vector2(-330.0 if from_right else 330.0, 0), null,
			{"hostile_all": true, "dmg": 14.0, "kb": 380.0, "ang": 35.0, "radius": 5.0, "life": 4.0, "cause": "hazard", "pierce": 3})
	if cyc > 0.5 and phase == "fired":
		phase = "idle"


# --------------------------------------------------------------- icicles
func _tick_icicles(_dt: float) -> void:
	var cyc := fmod(t, _period())
	if cyc > _period() - 1.1 and phase == "idle":
		phase = "warn"
		target_x = _rng.randf_range(float(h.x_min), float(h.x_max))
		# Prefer dropping near a cat to keep things lively.
		var alive: Array = ctl().fighters.filter(func(f): return f.targetable())
		if not alive.is_empty() and _rng.randf() < 0.6:
			target_x = clampf(alive[_rng.randi_range(0, alive.size() - 1)].global_position.x + _rng.randf_range(-20, 20), float(h.x_min), float(h.x_max))
		AudioHub.play("hit_glass", -10.0, 0.6)
	if cyc < 0.1 and phase == "warn":
		phase = "idle"
		ctl().proj.spawn("icicle", Vector2(target_x, -10.0), Vector2(0, 40), null,
			{"hostile_all": true, "dmg": 11.0, "kb": 260.0, "ang": 70.0, "radius": 4.0, "grav": 700.0, "life": 3.0, "cause": "hazard"})


# ------------------------------------------------------------------ lava
func _tick_lava(dt: float) -> void:
	var cyc := fmod(t, _period())
	var warn: float = h.warn
	var hold: float = h.hold
	var base: float = h.base_y
	var top: float = h.rise_y
	var rise_start := _period() - warn - hold - 3.0
	if cyc < rise_start:
		lava_y = lerpf(lava_y, base, 2.0 * dt)
		phase = "idle"
	elif cyc < rise_start + warn:
		if phase != "warn":
			phase = "warn"
			AudioHub.play("warning", -2.0)
			AudioHub.play("rumble", -2.0)
			ctl().announce("LAVA RISING!", Color("ff8a2a"))
		lava_y = base + sin(t * 8.0) * 1.0
		ctl().fx.shake(0.4)
	elif cyc < rise_start + warn + 1.5:
		phase = "rise"
		lava_y = lerpf(base, top, (cyc - rise_start - warn) / 1.5)
	elif cyc < rise_start + warn + 1.5 + hold:
		phase = "hold"
		lava_y = top + sin(t * 3.0) * 1.0
	else:
		phase = "recede"
		lava_y = lerpf(lava_y, base, 1.5 * dt)
	for f in ctl().fighters:
		if f.targetable() and f.global_position.y > lava_y + 2.0 and _cool(f, 0.7):
			ctl().hazard_hit(f, 12.0, Vector2(_rng.randf_range(-60, 60), -480), "burn")
			AudioHub.play("fire", 0.0)
	for it in ctl().items():
		if it.global_position.y > lava_y + 2.0 and not it.permanent:
			ctl().fx.smoke(it.global_position, 3, Color(0.3, 0.3, 0.3, 0.7))
			it.queue_free()
		elif it.global_position.y > lava_y + 2.0 and it.permanent:
			it.global_position.y = lava_y - 30.0
			it.vel = Vector2(0, -200)
			it.resting = false
	if _rng.randf() < 0.5:
		ctl().fx.emit(Vector2(_rng.randf_range(0, arena.size.x), lava_y), Vector2(0, -30), 0.5, 1.0, Color("ffd040"), EffectsSystem.K_PIXEL, 50.0)


# -------------------------------------------------------------- trapdoor
func _tick_trapdoor(_dt: float) -> void:
	var cyc := fmod(t, _period())
	var open: float = h.open
	var r: Rect2 = h.rect
	var was := phase
	if cyc < _period() - open - 1.6:
		phase = "closed"
	elif cyc < _period() - open:
		phase = "warn"
	else:
		phase = "open"
	if phase != was:
		match phase:
			"warn":
				AudioHub.play("warning", -6.0)
			"open":
				AudioHub.play("crate_break", -4.0, 0.7)
				if trap_body:
					trap_body.process_mode = Node.PROCESS_MODE_DISABLED
					for c in trap_body.get_children():
						(c as CollisionShape2D).set_deferred("disabled", true)
			"closed":
				if trap_body:
					trap_body.process_mode = Node.PROCESS_MODE_INHERIT
					for c in trap_body.get_children():
						(c as CollisionShape2D).set_deferred("disabled", false)
				# Don't trap anyone inside the closing door.
				for f in ctl().fighters:
					if r.grow(1).has_point(f.global_position + Vector2(0, -2)):
						f.global_position.y = r.position.y - 1.0


# ----------------------------------------------------------------- laser
func _tick_laser(_dt: float) -> void:
	var cyc := fmod(t, _period())
	var warn: float = h.warn
	var y: float = h.y
	var fire_start := _period() - 0.7
	var was := phase
	if cyc > fire_start - warn and cyc < fire_start:
		phase = "warn"
	elif cyc >= fire_start:
		phase = "fire"
	else:
		phase = "idle"
	if phase != was:
		if phase == "warn":
			AudioHub.play("warning", -6.0, 1.3)
		elif phase == "fire":
			AudioHub.play("zap", 0.0, 0.8)
			ctl().fx.shake(2.0)
	if phase == "fire":
		var band := Rect2(float(h.x_min), y - 3.0, float(h.x_max) - float(h.x_min), 6.0)
		for f in ctl().fighters:
			if f.targetable() and band.intersects(f.hurtbox()) and _cool(f, 0.8):
				ctl().hazard_hit(f, 12.0, Vector2(_rng.randf_range(-80, 80), -360), "shock")


# --------------------------------------------------------------- crusher
func _tick_crusher(dt: float) -> void:
	var cyc := fmod(t, _period())
	var warn: float = h.warn
	var r: Rect2 = h.rect
	var floor_y: float = h.floor
	var top: float = r.position.y
	var slam := _period() - 1.4
	var was := phase
	if cyc < slam - warn:
		phase = "idle"
		crusher_y = lerpf(crusher_y, top, 3.0 * dt)
	elif cyc < slam:
		phase = "warn"
		crusher_y = top + sin(t * 30.0) * 1.5
	elif cyc < slam + 0.15:
		phase = "slam"
		crusher_y = lerpf(top, floor_y - r.size.y, (cyc - slam) / 0.15)
	else:
		phase = "down"
		crusher_y = floor_y - r.size.y
	if phase != was:
		if phase == "warn":
			AudioHub.play("warning", -6.0, 0.8)
		elif phase == "down":
			AudioHub.play("cannon", -2.0, 1.2)
			ctl().fx.shake(5.0)
			ctl().fx.dust(Vector2(r.position.x + r.size.x * 0.5, floor_y), 8, 0)
	if phase in ["slam", "down"] and phase_t < 0.4:
		var box := Rect2(r.position.x, crusher_y, r.size.x, r.size.y + 4)
		for f in ctl().fighters:
			if f.targetable() and box.intersects(f.hurtbox()) and _cool(f, 1.0):
				var side := -1.0 if f.global_position.x < r.position.x + r.size.x * 0.5 else 1.0
				ctl().hazard_hit(f, 18.0, Vector2(side * 380, -220), "")


# ----------------------------------------------------------------- haunt
func _tick_haunt(_dt: float) -> void:
	var cyc := fmod(t, _period())
	if cyc > _period() - 1.0 and phase == "idle":
		var alive: Array = ctl().fighters.filter(func(f): return f.targetable())
		if alive.is_empty():
			return
		phase = "warn"
		target_x = alive[_rng.randi_range(0, alive.size() - 1)].global_position.x
		AudioHub.play("hiss", -10.0, 0.6)
	if cyc < 0.1 and phase == "warn":
		phase = "idle"
		ctl().proj.spawn("vase", Vector2(target_x, 40.0), Vector2(0, 60), null,
			{"hostile_all": true, "dmg": 10.0, "kb": 240.0, "ang": 60.0, "radius": 5.0, "grav": 500.0, "life": 3.0, "cause": "hazard"})


# ------------------------------------------------------------- AI hints
func danger_at(p: Vector2) -> float:
	match type:
		"flame":
			if phase in ["warn", "on"] and (h.rect as Rect2).grow(10).has_point(p):
				return 1.0
		"lava":
			if phase in ["warn", "rise", "hold"] and p.y > float(h.rise_y) - 6.0:
				return 1.0
			if p.y > lava_y - 4.0:
				return 1.0
		"trapdoor":
			if phase in ["warn", "open"] and (h.rect as Rect2).grow(6).has_point(p + Vector2(0, 2)):
				return 1.0
		"laser":
			if phase in ["warn", "fire"] and absf(p.y - float(h.y)) < 14.0:
				return 0.8
		"crusher":
			var r: Rect2 = h.rect
			if phase in ["warn", "slam", "down"] and p.x > r.position.x - 6 and p.x < r.end.x + 6:
				return 1.0
		"icicles", "haunt":
			if phase == "warn" and absf(p.x - target_x) < 16.0:
				return 0.9
	return 0.0


# ------------------------------------------------------------------ draw
func _draw() -> void:
	match type:
		"vent":
			var r: Rect2 = h.rect
			draw_rect(r.grow(1), Pal.OUTLINE)
			draw_rect(r, Color("5a6078"))
			for xx in range(2, int(r.size.x), 4):
				draw_rect(Rect2(r.position + Vector2(xx, 2), Vector2(2, r.size.y - 4)), Color("2a2e40"))
			var a := 0.25 + 0.15 * sin(t * 6.0)
			draw_rect(Rect2(r.position + Vector2(2, -50), Vector2(r.size.x - 4, 50)), Color(1, 1, 1, a * 0.3))
		"flame":
			var r2: Rect2 = h.rect
			if phase == "warn":
				var blink := int(t * 10.0) % 2 == 0 or not Settings.flash_ok()
				if blink:
					PixelFont.draw_outlined(self, r2.position + Vector2(r2.size.x * 0.5, -14), "!", Color("ffb040"))
			elif phase == "on":
				for i in 6:
					var fx := r2.position.x + 4 + i * (r2.size.x - 8) / 5.0
					var fh := 10.0 + sin(t * 30.0 + i) * 4.0
					draw_rect(Rect2(fx - 2, r2.end.y - fh, 4, fh), Color("ff8a2a"))
					draw_rect(Rect2(fx - 1, r2.end.y - fh * 0.6, 2, fh * 0.6), Color("ffe080"))
		"cannon":
			var from_right: bool = h.get("from_right", true)
			var cx := arena.size.x - 16.0 if from_right else 16.0
			var cy: float = float(h.y) - 6.0
			draw_rect(Rect2(cx - 10, cy - 4, 20, 9), Pal.OUTLINE)
			draw_rect(Rect2(cx - 9, cy - 3, 18, 7), Color("3a3440"))
			if phase == "warn" and (int(t * 10.0) % 2 == 0 or not Settings.flash_ok()):
				PixelFont.draw_outlined(self, Vector2(cx - (20 if from_right else -20), cy - 16), "!", Color("ff5a5a"), Pal.OUTLINE, 2)
				draw_line(Vector2(0, cy), Vector2(arena.size.x, cy), Color(1, 0.3, 0.3, 0.25), 1.0)
		"icicles":
			for i in 10:
				var ix := float(h.x_min) + i * (float(h.x_max) - float(h.x_min)) / 9.0
				draw_colored_polygon(PackedVector2Array([Vector2(ix - 2, -40), Vector2(ix + 2, -40), Vector2(ix, -30)]), Color("c8f0ff"))
			if phase == "warn":
				var sx := sin(t * 50.0) * 1.5
				draw_colored_polygon(PackedVector2Array([Vector2(target_x - 3 + sx, -14), Vector2(target_x + 3 + sx, -14), Vector2(target_x + sx, 0)]), Color("e0f8ff"))
				var gy := arena.ground_y_at(target_x, -5.0)
				if gy < INF:
					draw_rect(Rect2(target_x - 6, gy - 1, 12, 1), Color(0.2, 0.3, 0.5, 0.5))
		"lava":
			var W := arena.size.x
			var top := lava_y
			draw_rect(Rect2(-400, top, W + 800, 800), Color("c8301a"))
			draw_rect(Rect2(-400, top + 4, W + 800, 800), Color("8a1a10"))
			for xx in range(-400, int(W) + 400, 6):
				var wy := top + sin(t * 3.0 + xx * 0.15) * 1.5
				draw_rect(Rect2(xx, wy - 1, 6, 3), Color("ff8a2a"))
				if (xx / 6) % 5 == 0:
					draw_rect(Rect2(xx + 2, wy - 2, 2, 1), Color("ffe080"))
			if phase == "warn":
				draw_rect(Rect2(-400, float(h.rise_y), W + 800, 1), Color(1, 0.5, 0.2, 0.5 + 0.4 * sin(t * 12.0)))
		"trapdoor":
			var r3: Rect2 = h.rect
			if phase == "open":
				draw_rect(Rect2(r3.position.x - 2, r3.position.y, 6, 26), Color("6a3e22"))
				draw_rect(Rect2(r3.end.x - 4, r3.position.y, 6, 26), Color("6a3e22"))
			else:
				var shake := sin(t * 40.0) * 1.0 if phase == "warn" else 0.0
				draw_rect(Rect2(r3.position + Vector2(shake, 0), r3.size).grow(1), Pal.OUTLINE)
				draw_rect(Rect2(r3.position + Vector2(shake, 0), r3.size), Color("8a5a30"))
				for xx in range(0, int(r3.size.x), 8):
					draw_rect(Rect2(r3.position + Vector2(xx + shake, 0), Vector2(1, r3.size.y)), Color("5a3a20"))
				if phase == "warn" and (int(t * 8.0) % 2 == 0 or not Settings.flash_ok()):
					PixelFont.draw_outlined(self, r3.position + Vector2(r3.size.x * 0.5, -14), "!", Color("ff5a5a"), Pal.OUTLINE, 2)
		"laser":
			var y: float = h.y
			var x0: float = h.x_min
			var x1: float = h.x_max
			draw_rect(Rect2(x0 - 8, y - 4, 8, 8), Color("ff4ad0"))
			draw_rect(Rect2(x1, y - 4, 8, 8), Color("ff4ad0"))
			if phase == "warn":
				for xx in range(int(x0), int(x1), 8):
					draw_rect(Rect2(xx, y, 4, 1), Color(1, 0.3, 0.5, 0.6))
			elif phase == "fire":
				draw_rect(Rect2(x0, y - 3, x1 - x0, 6), Color(1, 0.3, 0.6, 0.7))
				draw_rect(Rect2(x0, y - 1, x1 - x0, 2), Color.WHITE)
		"crusher":
			var r4: Rect2 = h.rect
			draw_rect(Rect2(r4.position.x + r4.size.x * 0.5 - 3, -200, 6, crusher_y + 200), Color("5a6078"))
			draw_rect(Rect2(r4.position.x, crusher_y, r4.size.x, r4.size.y).grow(1), Pal.OUTLINE)
			draw_rect(Rect2(r4.position.x, crusher_y, r4.size.x, r4.size.y), Color("8a8a92"))
			for xx in range(0, int(r4.size.x), 10):
				draw_rect(Rect2(r4.position.x + xx, crusher_y + r4.size.y - 4, 5, 4), Color("ffd23f"))
				draw_rect(Rect2(r4.position.x + xx + 5, crusher_y + r4.size.y - 4, 5, 4), Pal.OUTLINE)
			if phase == "warn":
				var fy: float = h.floor
				draw_rect(Rect2(r4.position.x, fy - 2, r4.size.x, 2), Color(1, 0.2, 0.2, 0.4 + 0.3 * sin(t * 20.0)))
		"haunt":
			if phase == "warn":
				var gy2 := arena.ground_y_at(target_x, 0.0)
				if gy2 < INF:
					draw_arc(Vector2(target_x, gy2 - 2), 8.0 + sin(t * 20.0) * 2.0, 0, TAU, 12, Color(0.6, 1.0, 0.6, 0.7), 1.0)
				draw_rect(Rect2(target_x - 4, 34, 8, 10), Color(0.6, 1.0, 0.6, 0.5))
