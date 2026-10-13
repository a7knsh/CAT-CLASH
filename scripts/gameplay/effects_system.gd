class_name EffectsSystem
extends Node2D
## Pooled particle + popup renderer. A single node draws every spark, dust
## puff, ring, damage number and KO effect, so effects stay cheap even with
## four players and a screen full of chaos. Honours the "simplified effects"
## accessibility setting by spawning fewer particles.

const CAP := 900
const K_PIXEL := 0
const K_SPARK := 1
const K_RING := 2
const K_SMOKE := 3
const K_STAR := 4

var ctl: Node = null

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _max := PackedFloat32Array()
var _size := PackedFloat32Array()
var _grav := PackedFloat32Array()
var _col := PackedColorArray()
var _kind := PackedInt32Array()
var _next := 0
var _texts: Array = []
var _ghosts: Array = []
var _after: Array = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	z_index = 50
	_rng.randomize()
	_pos.resize(CAP)
	_vel.resize(CAP)
	_life.resize(CAP)
	_max.resize(CAP)
	_size.resize(CAP)
	_grav.resize(CAP)
	_col.resize(CAP)
	_kind.resize(CAP)
	_life.fill(0.0)


func _count(n: int) -> int:
	return maxi(1, n / 2) if Settings.simple_vfx() else n


func emit(pos: Vector2, vel: Vector2, life: float, size: float, col: Color, kind: int = K_PIXEL, grav: float = 0.0) -> void:
	var i := _next
	_next = (_next + 1) % CAP
	_pos[i] = pos
	_vel[i] = vel
	_life[i] = life
	_max[i] = life
	_size[i] = size
	_col[i] = col
	_kind[i] = kind
	_grav[i] = grav


# ------------------------------------------------------------- presets

func dust(pos: Vector2, n: int = 3, dir: float = 0.0) -> void:
	for i in _count(n):
		var v := Vector2(_rng.randf_range(-30, 30) + dir * 40.0, _rng.randf_range(-30, -5))
		emit(pos + Vector2(_rng.randf_range(-4, 4), -1), v, _rng.randf_range(0.25, 0.45), _rng.randf_range(2, 4), Color(0.9, 0.88, 0.85, 0.7), K_SMOKE, -20.0)


func spark(pos: Vector2, dir: Vector2, col: Color, n: int = 6, spd: float = 180.0) -> void:
	for i in _count(n):
		var v := dir.rotated(_rng.randf_range(-0.9, 0.9)) * _rng.randf_range(spd * 0.4, spd)
		emit(pos, v, _rng.randf_range(0.12, 0.28), 1.0, col, K_SPARK, 300.0)


func burst(pos: Vector2, col: Color, n: int = 8, spd: float = 120.0) -> void:
	for i in _count(n):
		var v := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(spd * 0.3, spd)
		emit(pos, v, _rng.randf_range(0.25, 0.5), _rng.randf_range(1, 2.5), col, K_PIXEL, 260.0)


func ring(pos: Vector2, col: Color, radius: float = 14.0) -> void:
	if Settings.simple_vfx() and radius < 12.0:
		return
	emit(pos, Vector2.ZERO, 0.25, radius, col, K_RING)


func smoke(pos: Vector2, n: int = 6, col: Color = Color(0.5, 0.48, 0.52, 0.7)) -> void:
	for i in _count(n):
		var v := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(10, 50)
		emit(pos + Vector2(_rng.randf_range(-5, 5), _rng.randf_range(-5, 5)), v, _rng.randf_range(0.4, 0.8), _rng.randf_range(3, 6), col, K_SMOKE, -30.0)


func stars(pos: Vector2, n: int = 5) -> void:
	for i in _count(n):
		var v := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(60, 140)
		emit(pos, v, _rng.randf_range(0.4, 0.7), 2.0, Color("ffe84a"), K_STAR, 200.0)


func hit(pos: Vector2, dir: Vector2, strength: float, col: Color = Color.WHITE) -> void:
	spark(pos, dir, col, int(4 + strength * 8), 160.0 + strength * 160.0)
	if strength > 0.4:
		ring(pos, Color(1, 1, 1, 0.8), 6.0 + strength * 10.0)
	emit(pos, Vector2.ZERO, 0.08, 4.0 + strength * 6.0, Color(1, 1, 1, 0.9), K_STAR)


func explosion(pos: Vector2, radius: float) -> void:
	ring(pos, Color(1, 0.8, 0.4, 0.9), radius)
	for i in _count(18):
		var v := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(40, radius * 5)
		var c := Color("ffd23f").lerp(Color("ff5a2a"), _rng.randf())
		emit(pos, v, _rng.randf_range(0.25, 0.55), _rng.randf_range(2, 4), c, K_PIXEL, 120.0)
	smoke(pos, 10, Color(0.35, 0.3, 0.32, 0.8))
	shake(6.0)


func text(pos: Vector2, s: String, col: Color, big: bool = false) -> void:
	_texts.append({"pos": pos, "text": s, "col": col, "life": 0.9, "big": big})


func number(pos: Vector2, dmg: float) -> void:
	var c := Color(1, 1, 1).lerp(Color("ff5a5a"), clampf(dmg / 20.0, 0.0, 1.0))
	_texts.append({"pos": pos, "text": str(int(round(dmg))), "col": c, "life": 0.6, "big": false, "small": true})


func afterimage(f: CatFighter) -> void:
	_after.append({"pos": f.global_position, "life": 0.25, "col": Pal.player_color(f.slot), "facing": f.facing})


func ko_effect(f: CatFighter) -> void:
	var kind: String = f.skin.get("ko_fx", "ghost")
	var p := f.center()
	match kind:
		"stars":
			stars(p, 10)
		"fishbone":
			for i in 4:
				_ghosts.append({"pos": p + Vector2(i * 4 - 6, 0), "life": 1.2, "icon": "fish", "vel": Vector2(_rng.randf_range(-40, 40), -60)})
		"confetti":
			for i in _count(30):
				var v := Vector2(_rng.randf_range(-120, 120), _rng.randf_range(-220, -60))
				emit(p, v, _rng.randf_range(0.8, 1.3), 2.0, Color.from_hsv(_rng.randf(), 0.7, 1.0), K_PIXEL, 260.0)
		"poof":
			smoke(p, 14, Color(0.9, 0.9, 0.95, 0.8))
		_:
			_ghosts.append({"pos": p, "life": 1.4, "icon": "ghost", "vel": Vector2(0, -30)})
	burst(p, Pal.player_color(f.slot), 12, 150.0)


func shake(amount: float) -> void:
	if ctl and ctl.camera:
		ctl.camera.add_shake(amount)


# -------------------------------------------------------------- update

func _physics_process(dt: float) -> void:
	for i in CAP:
		if _life[i] <= 0.0:
			continue
		_life[i] -= dt
		var v := _vel[i]
		v.y += _grav[i] * dt
		if _kind[i] == K_SMOKE:
			v *= 0.94
		_vel[i] = v
		_pos[i] += v * dt
	for tx in _texts:
		tx.life -= dt
		tx.pos.y -= 22.0 * dt
	_texts = _texts.filter(func(x): return x.life > 0.0)
	for g in _ghosts:
		g.life -= dt
		g.pos += g.vel * dt
		g.pos.x += sin(g.life * 8.0) * 0.4
	_ghosts = _ghosts.filter(func(x): return x.life > 0.0)
	for a in _after:
		a.life -= dt
	_after = _after.filter(func(x): return x.life > 0.0)
	queue_redraw()


func _draw() -> void:
	for a in _after:
		var c: Color = a.col
		c.a = a.life * 1.6
		draw_rect(Rect2(a.pos + Vector2(-7, -14), Vector2(14, 10)), c)
		draw_rect(Rect2(a.pos + Vector2(a.facing * 3 - 4, -19), Vector2(8, 7)), c)
	for i in CAP:
		var l := _life[i]
		if l <= 0.0:
			continue
		var f := l / _max[i]
		var c := _col[i]
		var p := _pos[i]
		match _kind[i]:
			K_PIXEL:
				c.a *= minf(1.0, f * 2.0)
				var s := maxf(1.0, round(_size[i]))
				draw_rect(Rect2(p.floor(), Vector2(s, s)), c)
			K_SPARK:
				c.a *= f
				draw_line(p, p - _vel[i] * 0.03, c, 1.0)
			K_RING:
				c.a *= f
				draw_arc(p, _size[i] * (1.0 - f * 0.7), 0.0, TAU, 14, c, 1.0)
			K_SMOKE:
				c.a *= f * 0.8
				var s2 := _size[i] * (1.5 - f * 0.5)
				draw_rect(Rect2((p - Vector2(s2, s2) * 0.5).floor(), Vector2(s2, s2)), c)
			K_STAR:
				c.a *= minf(1.0, f * 2.0)
				var s3 := _size[i]
				draw_rect(Rect2(p - Vector2(s3, 0.5), Vector2(s3 * 2, 1)), c)
				draw_rect(Rect2(p - Vector2(0.5, s3), Vector2(1, s3 * 2)), c)
	for g in _ghosts:
		var tex := Sprites.icon_texture(g.icon)
		if tex:
			draw_texture(tex, g.pos - Vector2(3, 3), Color(1, 1, 1, minf(1.0, g.life)))
	for tx in _texts:
		var c2: Color = tx.col
		c2.a = minf(1.0, tx.life * 3.0)
		if tx.get("small", false):
			PixelFont.draw_outlined(self, tx.pos, tx.text, c2, Color(0.05, 0.03, 0.08, c2.a))
		else:
			PixelFont.draw_outlined(self, tx.pos, tx.text, c2, Color(0.05, 0.03, 0.08, c2.a), 2 if tx.big else 1)
