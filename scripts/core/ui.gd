class_name UI
extends RefCounted
## Shared pixel UI drawing helpers (panels, bars, hints, titles).


static func panel(ci: CanvasItem, r: Rect2, fill: Color = Pal.UI_PANEL, edge: Color = Pal.UI_EDGE, shadow: bool = true) -> void:
	if shadow:
		ci.draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.35))
	ci.draw_rect(r.grow(1), Pal.UI_BORDER)
	ci.draw_rect(r, fill)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), edge)
	ci.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), edge.darkened(0.2))
	ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), fill.darkened(0.3))


static func bar(ci: CanvasItem, r: Rect2, frac: float, col: Color, bg: Color = Color(0.05, 0.03, 0.08)) -> void:
	ci.draw_rect(r.grow(1), Pal.UI_BORDER)
	ci.draw_rect(r, bg)
	var w := floorf(r.size.x * clampf(frac, 0.0, 1.0))
	if w > 0:
		ci.draw_rect(Rect2(r.position, Vector2(w, r.size.y)), col)
		ci.draw_rect(Rect2(r.position, Vector2(w, 1)), col.lightened(0.3))


static func title(ci: CanvasItem, text: String, y: float = 8.0, color: Color = Pal.UI_HILITE) -> void:
	ci.draw_rect(Rect2(0, y - 3, 480, 22), Color(0, 0, 0, 0.35))
	PixelFont.draw_text(ci, Vector2(240, y), text, color, 2, 1)


static func hints(ci: CanvasItem, text: String) -> void:
	ci.draw_rect(Rect2(0, 258, 480, 12), Color(0, 0, 0, 0.5))
	PixelFont.draw_text(ci, Vector2(240, 260), text, Pal.UI_DIM, 1, 1, false)


static func bg(ci: CanvasItem, t: float, c1: Color = Color("1a1230"), c2: Color = Color("2c1f4a")) -> void:
	for i in 9:
		var c := c1.lerp(c2, i / 8.0)
		ci.draw_rect(Rect2(0, i * 30, 480, 31), c)
	# Drifting paw-print pattern.
	var off := fmod(t * 8.0, 40.0)
	for y in range(-40, 300, 40):
		for x in range(-40, 520, 40):
			var px := x + off + (20 if (y / 40) % 2 == 0 else 0)
			var py := y + off * 0.5
			var c3 := Color(1, 1, 1, 0.035)
			ci.draw_rect(Rect2(px, py + 2, 4, 3), c3)
			ci.draw_rect(Rect2(px - 2, py - 1, 2, 2), c3)
			ci.draw_rect(Rect2(px + 1, py - 2, 2, 2), c3)
			ci.draw_rect(Rect2(px + 4, py - 1, 2, 2), c3)


static func swatch(ci: CanvasItem, r: Rect2, c: Color, selected: bool) -> void:
	ci.draw_rect(r.grow(2 if selected else 1), Pal.UI_HILITE if selected else Pal.UI_BORDER)
	ci.draw_rect(r, c)


static func icon(ci: CanvasItem, id: String, pos: Vector2, scl: float = 1.0, tint: Color = Color.WHITE) -> void:
	var tex := Sprites.icon_texture(id)
	if tex == null:
		return
	ci.draw_set_transform(pos, 0.0, Vector2(scl, scl))
	ci.draw_texture(tex, Vector2.ZERO, tint)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func weapon(ci: CanvasItem, id: String, center: Vector2, scl: float = 1.0, skin: String = "default", tint: Color = Color.WHITE) -> void:
	if id == "":
		return
	var tex := Sprites.weapon_texture(id, skin)
	ci.draw_set_transform(center, 0.0, Vector2(scl, scl))
	ci.draw_texture(tex, -tex.get_size() * 0.5, tint)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func fmt_time(sec: float) -> String:
	var s := int(maxf(sec, 0.0))
	return "%d:%02d" % [s / 60, s % 60]
