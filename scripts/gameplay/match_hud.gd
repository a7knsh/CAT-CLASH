class_name MatchHud
extends CanvasLayer
## In-match HUD: per-player panels (portrait, health, lives/score, weapon &
## ammo, status effects), mode info, banners, boss bar and off-screen
## indicators for cats knocked out of view.

var ctl: Node = null
var canvas: Control
var t := 0.0
var flash_c := Color(1, 1, 1, 0)


func _ready() -> void:
	layer = 5
	canvas = Control.new()
	canvas.size = Vector2(480, 270)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_hud)
	add_child(canvas)


func flash(c: Color) -> void:
	if ctl and ctl.has_method("net_event"):
		ctl.net_event(["flash", c])
	if Settings.flash_ok():
		flash_c = c


func _process(dt: float) -> void:
	t += dt
	flash_c.a = maxf(0.0, flash_c.a - dt * 3.0)
	canvas.queue_redraw()


func _draw_hud() -> void:
	if ctl == null:
		return
	var s := int(Settings.get_value("hud_scale"))
	s = clampi(s, 1, 2)
	var teams: bool = ctl.mode.show_team_colors()
	var list: Array = ctl.mode.hud_fighters()
	var n := list.size()
	if n > 4 and not ctl.mode.hide_panels():
		# 5-10 fighters: compact panels in up to two rows of five.
		var rows := int(ceil(n / 5.0))
		for i in n:
			var row := i / 5
			var in_row := mini(5, n - row * 5)
			var pw2 := 92.0
			var x0b := 240.0 - (pw2 * in_row + 3.0 * (in_row - 1)) * 0.5
			var y := 270.0 - (rows - row) * 21.0 - 1.0
			_panel_compact(list[i], Rect2(x0b + (i % 5) * (pw2 + 3.0), y, pw2, 19), teams)
	elif n > 0 and not ctl.mode.hide_panels():
		var pw := minf(116.0, (476.0 - (n - 1) * 4.0) / n)
		var ph := 26.0 if s == 1 else 36.0
		var total := pw * n + 4.0 * (n - 1)
		var x0 := 240.0 - total * 0.5
		for i in n:
			_panel(list[i], Rect2(x0 + i * (pw + 4.0), 270 - ph - 3, pw, ph), teams, s)
	# Top centre: mode info
	var top: String = ctl.mode.hud_top()
	if top != "":
		var w := PixelFont.text_width(top, s) + 12
		canvas.draw_rect(Rect2(240 - w * 0.5, 2, w, 11 * s), Color(0, 0, 0, 0.45))
		PixelFont.draw_text(canvas, Vector2(240, 4), top, Pal.UI_TEXT, s, 1)
	var sub: String = ctl.mode.hud_sub()
	if sub != "":
		PixelFont.draw_text(canvas, Vector2(240, 4 + 11 * s), sub, Pal.UI_DIM, 1, 1)
	# Boss bar
	if ctl.boss and is_instance_valid(ctl.boss):
		var b: Node = ctl.boss
		UI.bar(canvas, Rect2(140, 26, 200, 5), b.hp / b.max_hp, Color("ff5a6a") if b.phase == 2 else Color("ffb040"))
		PixelFont.draw_text(canvas, Vector2(240, 33), "MECHA-MOUSER 9000" + (" · PHASE 2" if b.phase == 2 else ""), Pal.UI_TEXT, 1, 1)
	_offscreen()
	# Banner
	if ctl.banner_t > 0.0 and ctl.banner_text != "":
		var big: bool = ctl.banner_big
		var sc := 3 if big else 2
		if ctl.banner_text.length() > 14:
			sc = 2
		var bw := PixelFont.text_width(ctl.banner_text, sc)
		var pop := clampf((1.2 - ctl.banner_t) * 10.0, 0.0, 1.0) if big else 1.0
		var y := 100.0 if big else 50.0
		canvas.draw_rect(Rect2(0, y - 6, 480, 7 * sc + 12), Color(0, 0, 0, 0.4 * pop))
		PixelFont.draw_text(canvas, Vector2(240, y), ctl.banner_text, ctl.banner_color, sc, 1, true, Pal.UI_BORDER)
	if flash_c.a > 0.0:
		canvas.draw_rect(Rect2(0, 0, 480, 270), flash_c)
	# Training data readout
	var info: Array = ctl.mode.hud_lines()
	for i in info.size():
		PixelFont.draw_text(canvas, Vector2(6, 18 + i * 9), info[i], Pal.UI_TEXT)


## Height of the bottom HUD band (the camera keeps fighters above it).
func height() -> float:
	if ctl == null or ctl.mode == null:
		return 29.0
	var n: int = ctl.mode.hud_fighters().size()
	if n > 4:
		return ceil(n / 5.0) * 21.0 + 2.0
	return 29.0 if int(Settings.get_value("hud_scale")) == 1 else 39.0


func _panel_compact(f: CatFighter, r: Rect2, teams: bool) -> void:
	var col: Color = Pal.team_color(f.team) if teams else Pal.player_color(f.slot)
	var out = f.eliminated or (f.dead and not ctl.mode.respawns())
	UI.panel(canvas, r, Pal.UI_PANEL if not out else Color("201828"), col.darkened(0.2), false)
	canvas.draw_rect(Rect2(r.position, Vector2(2, r.size.y)), col)
	CatPuppet.draw_head(canvas, r.position + Vector2(10, 9), f.skin, 0.75)
	var shape := Pal.team_shape(f.team) if teams else Pal.player_shape(f.slot)
	PixelFont.draw_text(canvas, r.position + Vector2(19, 2), (shape + f.display_name).substr(0, 9), col)
	var hp_frac: float = f.hp / f.max_hp if not f.dead else 0.0
	UI.bar(canvas, Rect2(r.position.x + 19, r.position.y + 12, r.size.x - 40, 3), hp_frac, Pal.hp_color(hp_frac))
	var right = ctl.mode.hud_player_text(f)
	if right == "" and ctl.mode.respawns() and not ctl.mode.uses_score():
		right = "♥%d" % f.stocks
	if out:
		right = "×"
	PixelFont.draw_text(canvas, Vector2(r.end.x - 2, r.position.y + 9), right.substr(0, 4), Pal.UI_TEXT, 1, 2)
	if not f.weapon.is_empty():
		var tex := Sprites.weapon_texture(f.weapon_id())
		var sc := minf(1.0, 12.0 / maxf(tex.get_width(), 1.0))
		canvas.draw_set_transform(Vector2(r.end.x - 9, r.position.y + 4), 0.0, Vector2(sc, sc))
		canvas.draw_texture(tex, -tex.get_size() * 0.5)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _panel(f: CatFighter, r: Rect2, teams: bool, s: int) -> void:
	var col: Color = Pal.team_color(f.team) if teams else Pal.player_color(f.slot)
	var plate: Color = Sprites.col(CosmeticDefs.NAMEPLATES.get(f.skin.get("nameplate", "classic"), CosmeticDefs.NAMEPLATES["classic"]).color)
	var out = f.eliminated or (f.dead and not ctl.mode.respawns())
	UI.panel(canvas, r, plate if not out else Color("201828"), col.darkened(0.2))
	canvas.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), col)
	# Portrait
	var pc := r.position + Vector2(10, 12 + (5 if s == 2 else 0))
	CatPuppet.draw_head(canvas, pc, f.skin, 1.0)
	if out:
		PixelFont.draw_text(canvas, pc + Vector2(0, -4), "×", Pal.UI_BAD, 1, 1)
	# Name
	var shape := Pal.team_shape(f.team) if teams else Pal.player_shape(f.slot)
	var label := "%s%s" % [shape, f.display_name]
	var max_chars := int((r.size.x - 24) / (6 * s))
	if label.length() > max_chars:
		label = label.substr(0, max_chars)
	PixelFont.draw_text(canvas, r.position + Vector2(20, 4), label, col, s)
	# HP bar
	var by := r.position.y + 4 + 9 * s
	var hp_frac: float = f.hp / f.max_hp if not f.dead else 0.0
	UI.bar(canvas, Rect2(r.position.x + 20, by, r.size.x - 24, 2 + s), hp_frac, Pal.hp_color(hp_frac))
	# Guard meter (thin)
	if f.guard < CatFighter.GUARD_MAX - 1.0:
		canvas.draw_rect(Rect2(r.position.x + 20, by + 3 + s, (r.size.x - 24) * f.guard / CatFighter.GUARD_MAX, 1), Color("6ae0ff"))
	# Lives / score
	var ly := by + 5 + s * 2
	var right = ctl.mode.hud_player_text(f)
	if right != "":
		PixelFont.draw_text(canvas, Vector2(r.end.x - 3, ly), right, Pal.UI_TEXT, 1, 2)
	elif ctl.mode.respawns() and not ctl.mode.uses_score():
		if f.stocks <= 5:
			for k in f.stocks:
				PixelFont.draw_text(canvas, Vector2(r.position.x + 20 + k * 6, ly), "♥", col, 1, 0, false)
		else:
			PixelFont.draw_text(canvas, Vector2(r.position.x + 20, ly), "♥×%d" % f.stocks, col)
	# Weapon
	if not f.weapon.is_empty():
		var wid := f.weapon_id()
		var tex := Sprites.weapon_texture(wid, f.skin.get("weapon_skin", "default"))
		var sc := minf(1.0, 16.0 / maxf(tex.get_width(), 1.0))
		var wc := Vector2(r.end.x - 22, ly + 3)
		canvas.draw_set_transform(wc, 0.0, Vector2(sc, sc))
		canvas.draw_texture(tex, -tex.get_size() * 0.5)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var ammo := int(f.weapon.get("ammo", -1))
		if ammo >= 0 and right == "":
			PixelFont.draw_text(canvas, Vector2(r.end.x - 3, ly), str(ammo), Pal.UI_TEXT if ammo > 2 else Pal.UI_BAD, 1, 2)
	# Status icons
	var ix := r.position.x + 20.0
	var iy := r.position.y - 8.0
	for st in ["speed", "extra_jump", "shield", "magnet", "giant", "lowgrav", "elemental", "upgrade", "tiger", "burn", "slow"]:
		if f.has_status(st):
			var icon := {"speed": "boot", "extra_jump": "feather", "shield": "shield", "magnet": "magnet", "giant": "grow", "lowgrav": "wing", "elemental": "flame", "upgrade": "up", "tiger": "star", "burn": "flame", "slow": "bubble"}[st] as String
			UI.icon(canvas, icon, Vector2(ix, iy))
			ix += 8.0
	if f.dead and f.respawn_timer > 0.0 and not f.eliminated:
		PixelFont.draw_text(canvas, r.position + Vector2(r.size.x * 0.5, r.size.y * 0.5 - 2), "%.1f" % f.respawn_timer, Pal.UI_TEXT, 1, 1)


func _offscreen() -> void:
	var xf := ctl.get_viewport().get_canvas_transform()
	for f in ctl.fighters:
		if not f.alive_in_round() or not f.visible or f.is_decoy:
			continue
		var sp: Vector2 = xf * f.center()
		if sp.x >= 0 and sp.x <= 480 and sp.y >= 0 and sp.y <= 250:
			continue
		var c := Vector2(clampf(sp.x, 12, 468), clampf(sp.y, 12, 240))
		var col: Color = Pal.player_color(f.slot) if not f.is_enemy else Pal.UI_BAD
		canvas.draw_circle(c, 9.0, Pal.UI_BORDER)
		canvas.draw_circle(c, 8.0, col.darkened(0.3))
		CatPuppet.draw_head(canvas, c + Vector2(0, 1), f.skin, 0.75)
		var dir := (sp - c).normalized()
		var tip := c + dir * 12.0
		canvas.draw_colored_polygon(PackedVector2Array([tip, c + dir.rotated(0.5) * 8.5, c + dir.rotated(-0.5) * 8.5]), col)
