class_name MatchOverlay
extends Node2D
## World-space overlay: player tags (colour + shape, so they stay readable
## for colour-blind players), team rings, pickup hints and mode visuals
## (hill zone, fish baskets...).

var ctl: Node = null
var t := 0.0


func _init() -> void:
	z_index = 60


func _process(dt: float) -> void:
	t += dt
	queue_redraw()


func _draw() -> void:
	if ctl == null:
		return
	if ctl.mode:
		ctl.mode.draw_world(self, t)
	var teams: bool = ctl.mode.show_team_colors() if ctl.mode else false
	var placed: Array = []
	for f in ctl.fighters:
		if not f.visible or f.dead or f.is_enemy:
			continue
		var col: Color = Pal.team_color(f.team) if teams else Pal.player_color(f.slot)
		var top: Vector2 = f.global_position + Vector2(0, -30 * f.size_mult - 4)
		var tag: String
		if f.is_dummy:
			tag = "DUMMY"
			col = Pal.UI_DIM
		elif f.is_decoy:
			tag = "?"
		elif f.is_bot:
			tag = "CPU"
		else:
			tag = "P%d" % (f.slot + 1)
		var shape := Pal.team_shape(f.team) if teams else Pal.player_shape(f.slot)
		if not f.is_dummy:
			tag = shape + tag
		# Stagger tags that would overlap another cat's tag.
		var w := PixelFont.text_width(tag) + 4
		var tr := Rect2(top + Vector2(-w * 0.5, -9), Vector2(w, 9))
		for k in 3:
			var hit := false
			for r in placed:
				if tr.intersects(r):
					hit = true
					break
			if not hit:
				break
			tr.position.y -= 10
		placed.append(tr)
		var ty := tr.position.y + 1 - top.y
		PixelFont.draw_outlined(self, top + Vector2(0, ty), tag, col)
		draw_rect(Rect2(top + Vector2(-1, 1), Vector2(3, 1)), col)
		draw_rect(Rect2(top + Vector2(0, 2), Vector2(1, 1)), col)
		# Team ring at the feet (dashed for even teams so it's not colour-only).
		if teams and f.alive_in_round():
			var n := 10
			for i in n:
				if f.team % 2 == 1 and i % 2 == 1:
					continue
				var a0 := TAU * i / n
				draw_arc(f.global_position + Vector2(0, 1), 9.0, a0, a0 + TAU / n * 0.8, 3, Color(col, 0.75), 1.0)
		# Pickup hint for humans next to items.
		if not f.is_bot and f.weapon.is_empty() and f.alive_in_round():
			for it in ctl.items():
				if it.pickable() and (it.global_position as Vector2).distance_to(f.global_position + Vector2(0, -5)) < 20.0:
					var bob := sin(t * 8.0) * 1.5
					PixelFont.draw_outlined(self, it.global_position + Vector2(0, -18 + bob), "▼", col)
					break
