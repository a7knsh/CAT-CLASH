class_name ArenaBackdrop
extends Node2D
## Procedural layered parallax backdrop: banded pixel sky, a far layer and a
## mid layer of seeded silhouettes per arena style, plus ambient particles
## (snow, embers, petals, stars...). Layers scroll at different rates relative
## to the shared camera for depth.

var def: Dictionary
var arena: Arena
var style := ""
var far: Array = []    # [type, data...]
var mid: Array = []
var lights: Array = []
var ambient: Array = []
var t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(d: Dictionary, a: Arena) -> void:
	def = d
	arena = a
	style = d.style
	z_index = -100
	_rng.seed = int(d.music.seed) * 31 + 7
	_generate()


func _rect(layer: Array, r: Rect2, c: Color) -> void:
	layer.append(["r", r, c])


func _poly(layer: Array, pts: PackedVector2Array, c: Color) -> void:
	layer.append(["p", pts, c])


func _circ(layer: Array, p: Vector2, rad: float, c: Color) -> void:
	layer.append(["c", p, rad, c])


func _generate() -> void:
	var W: float = def.size.x
	var H: float = def.size.y
	var farc: Color = def.far
	var midc: Color = def.mid
	var acc: Color = def.accent
	var x := -300.0
	match style:
		"city":
			_circ(far, Vector2(W * 0.75, 60), 18, Color("fff4c0"))
			_circ(far, Vector2(W * 0.75 - 6, 56), 16, def.sky[0].lerp(Color("fff4c0"), 0.15))
			while x < W + 300:
				var bw := _rng.randf_range(24, 60)
				var bh := _rng.randf_range(80, 220)
				_rect(far, Rect2(x, H - bh, bw, bh + 200), farc)
				for wy in range(int(H - bh + 6), int(H), 8):
					for wx in range(int(x + 4), int(x + bw - 4), 7):
						if _rng.randf() < 0.35:
							lights.append([Vector2(wx, wy), acc.darkened(_rng.randf() * 0.4), _rng.randf() * TAU, "far"])
				x += bw + _rng.randf_range(2, 10)
			x = -300.0
			while x < W + 300:
				var bw2 := _rng.randf_range(40, 80)
				var bh2 := _rng.randf_range(60, 130)
				_rect(mid, Rect2(x, H - bh2 + 40, bw2, bh2 + 200), midc)
				if _rng.randf() < 0.4:
					_rect(mid, Rect2(x + bw2 * 0.5, H - bh2 + 20, 1, 20), midc)
					lights.append([Vector2(x + bw2 * 0.5, H - bh2 + 19), Color("ff4a4a"), 0.0, "mid"])
				x += bw2 + _rng.randf_range(20, 60)
		"restaurant":
			_rect(far, Rect2(-400, -200, W + 800, H + 400), farc)
			for wx in range(-200, int(W) + 200, 90):
				_rect(far, Rect2(wx, 90, 60, 90), Color("f0d8a8").darkened(0.4))
				for gx in 3:
					_rect(far, Rect2(wx + 19 * gx + 19, 90, 2, 90), farc.darkened(0.2))
				_rect(far, Rect2(wx, 134, 60, 2), farc.darkened(0.2))
			for sx in range(-150, int(W) + 150, 130):
				_rect(mid, Rect2(sx, 200, 70, 4), Color("5a3020"))
				for b in 5:
					var bc = [Color("3a8a5a"), Color("e8e0d0"), Color("8a2a2a"), Color("2a4a8a")][b % 4]
					_rect(mid, Rect2(sx + 6 + b * 13, 188, 6, 12), bc)
			for nx in range(-100, int(W) + 100, 160):
				_rect(mid, Rect2(nx, 0, 50, 26), acc.darkened(0.2))
				_rect(mid, Rect2(nx + 24, 0, 2, 26), acc.darkened(0.5))
		"neon":
			while x < W + 300:
				var bw := _rng.randf_range(20, 50)
				var bh := _rng.randf_range(120, 260)
				_rect(far, Rect2(x, H - bh, bw, bh + 200), farc)
				if _rng.randf() < 0.5:
					var sc := Color("ff4ad0") if _rng.randf() < 0.5 else Color("40e0ff")
					lights.append([Vector2(x + 4, H - bh + 10), sc, _rng.randf() * TAU, "sign", Vector2(bw - 8, _rng.randf_range(10, 30))])
				x += bw + _rng.randf_range(4, 14)
			for gx in range(-100, int(W) + 200, 220):
				_rect(mid, Rect2(gx, 120, 6, 200), midc)
				_rect(mid, Rect2(gx + 80, 120, 6, 200), midc)
				_rect(mid, Rect2(gx - 10, 112, 106, 6), Color("ff4ad0").darkened(0.3))
				_rect(mid, Rect2(gx - 4, 126, 94, 4), midc)
		"sea":
			for i in 7:
				var cx := _rng.randf_range(-200, W + 200)
				var cy := _rng.randf_range(30, 120)
				for k in 4:
					_circ(far, Vector2(cx + k * 10, cy + (k % 2) * 3), _rng.randf_range(8, 13), Color(1, 1, 1, 0.85))
			_poly(far, PackedVector2Array([Vector2(W * 0.15, 262), Vector2(W * 0.22, 236), Vector2(W * 0.3, 262)]), farc.darkened(0.2))
			_rect(far, Rect2(-600, 262, W + 1200, 400), Color("3a7ac0"))
			_rect(mid, Rect2(-600, 316, W + 1200, 400), Color("2a5a90"))
		"snow":
			for i in 9:
				var mx := -300.0 + i * (W + 600) / 8.0 + _rng.randf_range(-30, 30)
				var mh := _rng.randf_range(120, 200)
				_poly(far, PackedVector2Array([Vector2(mx - 120, H), Vector2(mx, H - mh), Vector2(mx + 120, H)]), farc)
				_poly(far, PackedVector2Array([Vector2(mx - 30, H - mh + 45), Vector2(mx, H - mh), Vector2(mx + 30, H - mh + 45)]), Color.WHITE)
			while x < W + 300:
				var tx := x
				var th := _rng.randf_range(40, 80)
				for k in 3:
					var w := 16.0 - k * 4.0
					var y0 := H - 60 - k * th * 0.28
					_poly(mid, PackedVector2Array([Vector2(tx - w, y0), Vector2(tx, y0 - th * 0.45), Vector2(tx + w, y0)]), Color("3a6a5a"))
					_rect(mid, Rect2(tx - w * 0.6, y0 - 3, w * 1.2, 2), Color.WHITE)
				_rect(mid, Rect2(tx - 2, H - 60, 4, 80), Color("4a3a30"))
				x += _rng.randf_range(30, 70)
		"volcano":
			_poly(far, PackedVector2Array([Vector2(W * 0.1, H), Vector2(W * 0.42, 70), Vector2(W * 0.58, 70), Vector2(W * 0.9, H)]), farc)
			_rect(far, Rect2(W * 0.44, 66, W * 0.12, 6), Color("ff6a2a"))
			for i in 6:
				_circ(far, Vector2(W * 0.5 + _rng.randf_range(-30, 30), 40 - i * 14), 10 + i * 3, Color(0.3, 0.2, 0.2, 0.5))
			while x < W + 300:
				var sw := _rng.randf_range(20, 40)
				var sh := _rng.randf_range(40, 120)
				_poly(mid, PackedVector2Array([Vector2(x, H + 20), Vector2(x + sw * 0.5, H - sh), Vector2(x + sw, H + 20)]), midc)
				x += sw + _rng.randf_range(30, 90)
		"castle":
			_circ(far, Vector2(W * 0.3, 120), 30, Color("ffd0a0"))
			for i in 6:
				var hx := -300.0 + i * (W + 600) / 5.0
				_circ(far, Vector2(hx, H + 40), 150, farc.lightened(0.1))
			for tx in [W * 0.6, W * 0.68, W * 0.8]:
				var th: float = _rng.randf_range(100, 160)
				_rect(far, Rect2(tx, H - th, 22, th + 100), farc)
				_poly(far, PackedVector2Array([Vector2(tx - 3, H - th), Vector2(tx + 11, H - th - 26), Vector2(tx + 25, H - th)]), farc.darkened(0.2))
				_rect(far, Rect2(tx + 11, H - th - 40, 1, 14), farc)
				_rect(far, Rect2(tx + 12, H - th - 40, 8, 5), acc)
			_rect(mid, Rect2(-600, 230, W + 1200, 200), midc)
			for bx in range(-200, int(W) + 200, 60):
				_rect(mid, Rect2(bx, 220, 30, 10), midc)
				if (bx / 60) % 2 == 0:
					_rect(mid, Rect2(bx + 8, 236, 14, 28), Color("8a2a3a"))
					_rect(mid, Rect2(bx + 13, 244, 4, 4), Color("ffd23f"))
		"arcade":
			for i in 70:
				lights.append([Vector2(_rng.randf_range(-300, W + 300), _rng.randf_range(-100, H)), Color.WHITE, _rng.randf() * TAU, "far"])
			for i in 5:
				var ix := -200.0 + i * (W + 400) / 4.0
				var invader := ["..x....x..", "...xxxx...", "..xxxxxx..", ".xx.xx.xx.", "xxxxxxxxxx", "x.x....x.x"]
				for ry in invader.size():
					for rx in str(invader[ry]).length():
						if invader[ry][rx] == "x":
							_rect(far, Rect2(ix + rx * 3, 60 + ry * 3 + (i % 2) * 20, 3, 3), Color("ff4ad0").darkened(0.5))
			for gx in range(-600, int(W) + 600, 40):
				_poly(mid, PackedVector2Array([Vector2(gx, H), Vector2(gx + 1, H), Vector2(W * 0.5 + (gx - W * 0.5) * 0.3 + 1, 200), Vector2(W * 0.5 + (gx - W * 0.5) * 0.3, 200)]), Color("40e0ff").darkened(0.55))
		"junk":
			while x < W + 300:
				var jw := _rng.randf_range(60, 140)
				var jh := _rng.randf_range(60, 130)
				_poly(far, PackedVector2Array([Vector2(x, H), Vector2(x + jw * 0.4, H - jh), Vector2(x + jw * 0.6, H - jh + 10), Vector2(x + jw, H)]), farc)
				x += jw * 0.7
			_rect(far, Rect2(W * 0.8, 40, 6, 300), farc.darkened(0.2))
			_rect(far, Rect2(W * 0.55, 40, W * 0.3, 5), farc.darkened(0.2))
			_rect(far, Rect2(W * 0.6, 45, 1, 50), farc.darkened(0.3))
			for fx in range(-300, int(W) + 300, 12):
				_rect(mid, Rect2(fx, 210, 1, 100), midc)
			_rect(mid, Rect2(-300, 214, W + 600, 1), midc)
			_rect(mid, Rect2(-300, 240, W + 600, 1), midc)
		"haunted":
			_rect(far, Rect2(-600, -300, W + 1200, H + 600), farc)
			for wx in range(-150, int(W) + 150, 150):
				_rect(far, Rect2(wx, 60, 50, 110), Color("0a0a20"))
				_rect(far, Rect2(wx + 24, 60, 2, 110), farc)
				_rect(far, Rect2(wx, 110, 50, 2), farc)
				_circ(far, Vector2(wx + 36, 80), 8, Color("e8e8c0"))
			for px in range(-100, int(W) + 100, 150):
				_rect(mid, Rect2(px + 70, 120, 34, 42), Color("8a7040"))
				_rect(mid, Rect2(px + 73, 123, 28, 36), Color("3a2a40"))
				_circ(mid, Vector2(px + 87, 138), 6, Color("e0c0a0").darkened(0.3))
		"space":
			for i in 120:
				lights.append([Vector2(_rng.randf_range(-400, W + 400), _rng.randf_range(-300, H + 100)), Color(1, 1, 1, _rng.randf_range(0.4, 1.0)), _rng.randf() * TAU, "far"])
			_circ(far, Vector2(W * 0.2, 90), 40, Color("c86a4a"))
			_circ(far, Vector2(W * 0.2 - 8, 82), 34, Color("e08a5a"))
			_rect(far, Rect2(W * 0.2 - 64, 88, 128, 3), Color(0.9, 0.8, 0.6, 0.6))
			_circ(far, Vector2(W * 0.82, 50), 14, Color("6a8ad0"))
			for i in 4:
				_circ(far, Vector2(_rng.randf_range(0, W), _rng.randf_range(0, H)), _rng.randf_range(40, 70), Color(0.5, 0.2, 0.6, 0.08))
			_rect(mid, Rect2(-300, 300, W + 600, 6), midc)
			for sx in range(-300, int(W) + 300, 50):
				_rect(mid, Rect2(sx, 300, 4, 200), midc)
		"garden":
			_circ(far, Vector2(W * 0.7, 90), 26, Color("fff0d0"))
			for i in 6:
				var mx2 := -300.0 + i * (W + 600) / 5.0
				_poly(far, PackedVector2Array([Vector2(mx2 - 150, H), Vector2(mx2, H - 170 + _rng.randf_range(-20, 20)), Vector2(mx2 + 150, H)]), farc)
			var px2 := W * 0.25
			for k in 4:
				var pw := 30.0 + k * 12.0
				var py := 120.0 + k * 30.0
				_rect(far, Rect2(px2 - pw * 0.5 - 6, py, pw + 12, 5), farc.darkened(0.3))
				_rect(far, Rect2(px2 - pw * 0.35, py + 5, pw * 0.7, 25), farc.darkened(0.12))
			_rect(far, Rect2(px2 - 1, 104, 2, 16), farc.darkened(0.3))
			while x < W + 300:
				_rect(mid, Rect2(x + 10, 200, 4, 120), Color("5a3a30"))
				for k in 6:
					_circ(mid, Vector2(x + 12 + _rng.randf_range(-22, 22), 196 + _rng.randf_range(-16, 10)), _rng.randf_range(8, 13), Color("ffb0c8").darkened(_rng.randf() * 0.15))
				x += _rng.randf_range(80, 150)
	# Ambient particles
	var n := 0
	match style:
		"snow": n = 70
		"volcano": n = 40
		"garden": n = 25
		"haunted": n = 20
		"space": n = 0
		"neon", "arcade": n = 0
		_: n = 0
	if Settings.simple_vfx():
		n /= 2
	for i in n:
		ambient.append([Vector2(_rng.randf_range(-100, W + 100), _rng.randf_range(-100, H)), _rng.randf_range(0.5, 1.5)])


func _process(dt: float) -> void:
	t += dt
	var W: float = def.size.x
	var H: float = def.size.y
	for a in ambient:
		var p: Vector2 = a[0]
		match style:
			"snow":
				p += Vector2(sin(t + a[1] * 10.0) * 10.0, 22.0 * a[1]) * dt
			"volcano":
				p += Vector2(sin(t * 2.0 + a[1] * 10.0) * 8.0, -30.0 * a[1]) * dt
			"garden":
				p += Vector2(14.0 + sin(t + a[1]) * 10.0, 16.0 * a[1]) * dt
			"haunted":
				p += Vector2(sin(t * 0.5 + a[1] * 5.0) * 6.0, cos(t * 0.4 + a[1]) * 6.0) * dt
		if p.y > H + 20:
			p.y = -60
		if p.y < -80:
			p.y = H + 10
		if p.x > W + 120:
			p.x = -100
		a[0] = p
	queue_redraw()


func _draw_layer(layer: Array, off: Vector2) -> void:
	for s in layer:
		match s[0]:
			"r":
				var r: Rect2 = s[1]
				draw_rect(Rect2(r.position + off, r.size), s[2])
			"p":
				var pts: PackedVector2Array = s[1]
				var moved := PackedVector2Array()
				for q in pts:
					moved.append(q + off)
				draw_colored_polygon(moved, s[2])
			"c":
				draw_circle(s[1] + off, s[2], s[3])


func _draw() -> void:
	var cam: Camera2D = arena.ctl.camera if arena.ctl and arena.ctl.camera else null
	var center: Vector2 = def.size * 0.5
	var zoom := Vector2.ONE
	if cam:
		center = cam.get_screen_center_position()
		zoom = cam.zoom
	var half := Vector2(240, 135) / zoom
	var view := Rect2(center - half - Vector2(4, 4), half * 2.0 + Vector2(8, 8))
	# Banded sky
	var sky: Array = def.sky
	var bands := 10
	for i in bands:
		var c: Color = sky[0].lerp(sky[1], float(i) / (bands - 1))
		var y0 := lerpf(-200.0, def.size.y, float(i) / bands)
		var y1 := lerpf(-200.0, def.size.y, float(i + 1) / bands)
		var top := y0 if i > 0 else minf(y0, view.position.y)
		var bot := y1 if i < bands - 1 else maxf(y1, view.end.y)
		draw_rect(Rect2(view.position.x, top, view.size.x, bot - top + 1), c)
	var arena_c: Vector2 = def.size * 0.5
	var off_far := (center - arena_c) * 0.75
	var off_mid := (center - arena_c) * 0.45
	_draw_layer(far, off_far)
	for l in lights:
		var kind: String = l[3]
		var off := off_far if kind != "mid" else off_mid
		var c2: Color = l[1]
		var tw := 0.75 + 0.25 * sin(t * 2.0 + l[2])
		c2.a *= tw
		if kind == "sign":
			var sz: Vector2 = l[4]
			draw_rect(Rect2(l[0] + off - Vector2(1, 1), sz + Vector2(2, 2)), Color(c2, 0.25))
			draw_rect(Rect2(l[0] + off, sz), Color(c2, 0.8 * tw))
		else:
			draw_rect(Rect2(l[0] + off, Vector2(2, 2) if style != "space" else Vector2(1, 1)), c2)
	_draw_layer(mid, off_mid)
	if style == "sea":
		for wx in range(-400, int(def.size.x) + 400, 16):
			var wy := 316.0 + sin(t * 2.0 + wx * 0.1) * 2.0
			draw_rect(Rect2(wx + off_mid.x, wy + off_mid.y, 8, 2), Color(1, 1, 1, 0.5))
	for a in ambient:
		var p: Vector2 = a[0]
		match style:
			"snow":
				draw_rect(Rect2(p, Vector2(1, 1) * (1.0 + float(int(a[1] * 2.0) % 2))), Color(1, 1, 1, 0.9))
			"volcano":
				draw_rect(Rect2(p, Vector2(1, 1)), Color(1.0, 0.6, 0.2, 0.9))
			"garden":
				draw_rect(Rect2(p, Vector2(2, 1)), Color("ffb0c8"))
			"haunted":
				draw_rect(Rect2(p, Vector2(1, 1)), Color(0.6, 1.0, 0.6, 0.5 + 0.5 * sin(t * 3.0 + a[1] * 9.0)))
