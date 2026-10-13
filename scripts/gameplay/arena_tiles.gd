class_name ArenaTiles
extends Node2D
## Static pixel-art rendering of arena geometry. Each arena style paints its
## own surface (bricks, planks, ice, neon...). Static parts are drawn once and
## cached by the renderer; moving platforms redraw every frame.

var def: Dictionary
var arena: Arena
var style := "garden"
var _movers: Node2D


func setup(d: Dictionary, a: Arena) -> void:
	def = d
	arena = a
	style = d.get("style", "garden")
	z_index = -5
	_movers = Node2D.new()
	_movers.z_index = 0
	_movers.draw.connect(_draw_movers)
	add_child(_movers)


func _process(_dt: float) -> void:
	if not arena.movers.is_empty():
		_movers.queue_redraw()


func _h(x: float, y: float) -> float:
	return fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)


func _draw() -> void:
	var g: Array = def.ground
	var top: Color = g[0]
	var fill: Color = g[1]
	var dark: Color = g[2]
	_draw_decor()
	for r in def.solids:
		_draw_solid(r, top, fill, dark)
	for r in def.platforms:
		_draw_platform(r)
	_draw_front_decor()


func _draw_solid(r: Rect2, top: Color, fill: Color, dark: Color) -> void:
	draw_rect(r.grow(1), Pal.OUTLINE)
	draw_rect(r, fill)
	var x0 := int(r.position.x)
	var y0 := int(r.position.y)
	var w := int(r.size.x)
	var h := int(r.size.y)
	match style:
		"city", "castle":
			var bw := 8 if style == "city" else 12
			var bh := 4 if style == "city" else 6
			for yy in range(0, h, bh):
				var off := (bw / 2) if (yy / bh) % 2 == 1 else 0
				for xx in range(-off, w, bw):
					var bx := maxi(xx, 0)
					var bwid := mini(bw - 1, w - bx) if xx >= 0 else bw - 1 - off
					if bwid <= 0:
						continue
					var shade := fill.darkened(_h(x0 + xx, y0 + yy) * 0.12)
					draw_rect(Rect2(x0 + bx, y0 + yy, bwid, bh - 1), shade)
		"restaurant", "sea", "haunted":
			for yy in range(0, h, 5):
				draw_rect(Rect2(x0, y0 + yy + 4, w, 1), dark)
				var seg := 18 + int(_h(x0, yy) * 12)
				for xx in range(int(_h(yy, x0) * seg), w, seg):
					draw_rect(Rect2(x0 + xx, y0 + yy, 1, 4), dark)
					if style == "sea" and yy % 10 == 0:
						draw_rect(Rect2(x0 + xx + 2, y0 + yy + 2, 1, 1), Color("d8dcec"))
		"snow":
			for i in int(w * h / 90.0):
				var px := _h(i, x0) * w
				var py := _h(y0, i) * h
				draw_rect(Rect2(x0 + px, y0 + py, 3, 1), fill.lightened(0.25))
		"volcano":
			for i in int(w / 10.0):
				var px := _h(i, x0) * w
				var py := 4.0 + _h(x0, i) * (h - 6)
				draw_rect(Rect2(x0 + px, y0 + py, 4, 1), Color("ff6a2a").darkened(0.3))
				draw_rect(Rect2(x0 + px + 3, y0 + py + 1, 2, 1), Color("ff8a2a").darkened(0.2))
		"neon", "arcade":
			for xx in range(0, w, 16):
				draw_rect(Rect2(x0 + xx, y0, 1, h), dark.lightened(0.08))
			for yy in range(0, h, 16):
				draw_rect(Rect2(x0, y0 + yy, w, 1), dark.lightened(0.08))
			if style == "arcade":
				for xx in range(0, w, 8):
					for yy in range(4, h, 8):
						if ((xx + yy) / 8) % 2 == 0:
							draw_rect(Rect2(x0 + xx, y0 + yy, 8, 8), fill.lightened(0.06))
		"junk":
			for i in int(w * h / 60.0):
				var px := _h(i, y0) * (w - 4)
				var py := _h(x0, i) * (h - 4)
				var c = [Color("8a5a3a"), Color("6a7080"), Color("9a8a60"), Color("5a4a40")][i % 4]
				draw_rect(Rect2(x0 + px, y0 + py, 3 + i % 4, 2 + i % 3), c)
		"space":
			for xx in range(0, w, 24):
				draw_rect(Rect2(x0 + xx, y0, 1, h), dark)
				draw_rect(Rect2(x0 + xx + 3, y0 + 4, 1, 1), Color("d8dcec"))
			for xx in range(0, w, 12):
				draw_rect(Rect2(x0 + xx, y0 + h - 4, 6, 2), Color("ffd23f") if (xx / 12) % 2 == 0 else Pal.OUTLINE)
		"garden":
			for i in int(w * h / 120.0):
				var px := _h(i, x0) * (w - 3)
				var py := 6.0 + _h(y0, i) * (h - 8)
				draw_rect(Rect2(x0 + px, y0 + py, 3, 2), Color("8a8070"))
	# Top surface band
	var cap := 3
	match style:
		"snow":
			cap = 4
			draw_rect(Rect2(x0, y0, w, cap), Color.WHITE)
			for xx in range(0, w, 6):
				draw_rect(Rect2(x0 + xx, y0 + cap, 3, 1 + int(_h(xx, y0) * 2)), Color.WHITE)
		"garden":
			draw_rect(Rect2(x0, y0, w, cap), top)
			for xx in range(0, w, 3):
				draw_rect(Rect2(x0 + xx, y0 - 1, 1, 1), top.lightened(0.2))
				if _h(xx, y0) > 0.6:
					draw_rect(Rect2(x0 + xx, y0 + cap, 1, 1), top.darkened(0.2))
		"neon", "arcade":
			draw_rect(Rect2(x0, y0, w, 2), top)
			draw_rect(Rect2(x0, y0 + 2, w, 1), top.darkened(0.4))
		_:
			draw_rect(Rect2(x0, y0, w, cap), top)
			draw_rect(Rect2(x0, y0, w, 1), top.lightened(0.15))
	# Edge shading
	draw_rect(Rect2(x0, y0 + cap, 1, h - cap), fill.lightened(0.08))
	draw_rect(Rect2(x0 + w - 1, y0 + cap, 1, h - cap), dark)
	# Ice sheen
	if r in _ice_rects():
		for xx in range(0, w, 14):
			draw_rect(Rect2(x0 + xx + 2, y0 + 1, 4, 1), Color(1, 1, 1, 0.7))


func _ice_rects() -> Array:
	var out: Array = []
	var all: Array = []
	all.append_array(def.solids)
	all.append_array(def.platforms)
	for i in def.get("ice", []):
		if i < all.size():
			out.append(all[i])
	return out


func _draw_platform(r: Rect2, extra_canvas: CanvasItem = null) -> void:
	var ci: CanvasItem = extra_canvas if extra_canvas else self
	var c: Color = def.plat
	ci.draw_rect(r.grow(1), Pal.OUTLINE)
	ci.draw_rect(r, c)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), c.lightened(0.25))
	ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), c.darkened(0.3))
	match style:
		"neon", "arcade", "space":
			ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y + 1), Vector2(r.size.x, 1)), Color(c, 0.4))
		"snow":
			ci.draw_rect(Rect2(r.position + Vector2(0, -1), Vector2(r.size.x, 2)), Color.WHITE)
		_:
			for xx in range(6, int(r.size.x) - 2, 12):
				ci.draw_rect(Rect2(r.position + Vector2(xx, 1), Vector2(1, r.size.y - 2)), c.darkened(0.25))


func _draw_movers() -> void:
	for m in arena.movers:
		var r: Rect2 = m.rect
		var body: Node2D = m.body
		_draw_platform(Rect2(body.position, r.size), _movers)
		# Little cables / jets to explain the motion.
		match style:
			"city":
				_movers.draw_line(body.position + Vector2(4, 0), body.position + Vector2(4, -400), Color(0.1, 0.1, 0.12), 1.0)
				_movers.draw_line(body.position + Vector2(r.size.x - 4, 0), body.position + Vector2(r.size.x - 4, -400), Color(0.1, 0.1, 0.12), 1.0)
			"space", "neon", "arcade":
				var fl := 2.0 + sin(Time.get_ticks_msec() / 60.0) * 1.5
				_movers.draw_rect(Rect2(body.position + Vector2(r.size.x * 0.5 - 2, r.size.y + 1), Vector2(4, fl)), Color("ffd23f"))
			"haunted":
				_movers.draw_rect(Rect2(body.position + Vector2(4, -4), Vector2(r.size.x - 8, 4)), Color("6a3040"))
				_movers.draw_rect(Rect2(body.position + Vector2(6, -3), Vector2(r.size.x - 12, 1)), Color("f0e0c0"))


func _draw_decor() -> void:
	# Small per-arena foreground details that sit on the geometry.
	var acc: Color = def.accent
	match id_style():
		"city":
			draw_rect(Rect2(540, 166, 4, 96), Color("4a4460"))
			draw_rect(Rect2(556, 166, 4, 86), Color("4a4460"))
		"restaurant":
			# Lanterns and the stove
			for x in [140, 320, 500]:
				draw_line(Vector2(x, 0), Vector2(x, 60), Color("2a1010"), 1.0)
				draw_rect(Rect2(x - 5, 60, 10, 12), Pal.OUTLINE)
				draw_rect(Rect2(x - 4, 61, 8, 10), acc)
				draw_rect(Rect2(x - 2, 63, 4, 6), Color("ffd8a0"))
			draw_rect(Rect2(562, 248, 52, 4), Color("3a3a40"))
			for x in [570, 588, 604]:
				draw_rect(Rect2(x, 246, 6, 2), Color("1a1a1e"))
		"sea":
			# Mast + flag
			draw_rect(Rect2(298, 60, 4, 212), Color("6a3e22"))
			draw_rect(Rect2(302, 64, 30, 18), Color("f4f0ea"))
			draw_rect(Rect2(312, 68, 10, 8), Color("181420"))
			draw_rect(Rect2(296, 136, 8, 2), Color("4a2a18"))
		"castle":
			for r in def.solids:
				if r.size.x < 70:
					for xx in range(0, int(r.size.x), 10):
						draw_rect(Rect2(r.position + Vector2(xx, -6), Vector2(6, 6)), def.ground[1])
						draw_rect(Rect2(r.position + Vector2(xx, -6), Vector2(6, 1)), def.ground[0])
		"garden":
			# Bamboo stalks at the stage edges
			for x in [96, 104, 536, 544]:
				draw_rect(Rect2(x, 150, 3, 120), Color("6aa04a"))
				for y in range(150, 270, 14):
					draw_rect(Rect2(x, y, 3, 1), Color("4a7a3a"))
		"haunted":
			draw_line(Vector2(320, 0), Vector2(320, 120), Color("3a3040"), 1.0)
			draw_rect(Rect2(300, 120, 40, 4), Color("8a7040"))
			for x in [302, 318, 334]:
				draw_rect(Rect2(x, 116, 2, 4), Color("f0e0c0"))
				draw_rect(Rect2(x, 113, 2, 3), Color("ffd060"))


func _draw_front_decor() -> void:
	match style:
		"city":
			for r in def.solids:
				if r.size.y < 40:
					# AC units / chimneys
					draw_rect(Rect2(r.position + Vector2(3, 6), Vector2(r.size.x - 6, 2)), Color("3a3650"))
					draw_rect(Rect2(r.position + Vector2(3, 10), Vector2(r.size.x - 6, 2)), Color("3a3650"))
					draw_rect(Rect2(r.position + Vector2(3, 14), Vector2(r.size.x - 6, 2)), Color("3a3650"))
		"arcade":
			for r in def.solids:
				if r.size.x < 50:
					draw_rect(Rect2(r.position + Vector2(4, 6), Vector2(r.size.x - 8, 14)), Color("101030"))
					draw_rect(Rect2(r.position + Vector2(6, 8), Vector2(r.size.x - 12, 10)), Color("40e0ff").darkened(0.4))
					draw_rect(Rect2(r.position + Vector2(8, 24), Vector2(3, 3)), Color("ff4ad0"))
					draw_rect(Rect2(r.position + Vector2(14, 24), Vector2(3, 3)), Color("ffe84a"))
		"junk":
			# Wrecked car body on the centre block
			draw_rect(Rect2(252, 248, 88, 14), Color("8a3a2a"))
			draw_rect(Rect2(262, 240, 50, 8), Color("8a3a2a"))
			draw_rect(Rect2(266, 242, 18, 5), Color("a0c0d0"))
			draw_rect(Rect2(288, 242, 18, 5), Color("a0c0d0"))
			draw_circle(Vector2(266, 262), 5, Color("1a1a1e"))
			draw_circle(Vector2(326, 262), 5, Color("1a1a1e"))


func id_style() -> String:
	return style
