class_name MatchCamera
extends Camera2D
## Shared dynamic camera: frames every active cat (plus mode objectives),
## zooms out smoothly as they spread, never shows far beyond the arena, and
## adds trauma-based screen shake (scaled / disabled by accessibility setting).

var ctl: Node = null
var trauma := 0.0
var min_zoom := 0.62
var max_zoom := 1.6
var _rng := RandomNumberGenerator.new()
var focus_override := Vector2.INF
var focus_t := 0.0
var anchor := Vector2.ZERO
var anchor_x0 := 0.0
var anchor_x1 := 0.0


func _ready() -> void:
	_rng.randomize()
	position_smoothing_enabled = false
	ignore_rotation = true


func setup(controller: Node) -> void:
	ctl = controller
	var size: Vector2 = ctl.arena.size
	min_zoom = clampf(minf(480.0 / (size.x + 40.0), 270.0 / (size.y + 20.0)), 0.5, 1.0)
	position = size * 0.5
	zoom = Vector2(min_zoom, min_zoom)
	var widest: Rect2 = ctl.arena.def.solids[0]
	for r in ctl.arena.def.solids:
		if r.size.x > widest.size.x:
			widest = r
	anchor = Vector2(widest.get_center().x, widest.position.y)
	anchor_x0 = widest.position.x
	anchor_x1 = widest.end.x


func add_shake(amount: float) -> void:
	trauma = minf(trauma + amount * 0.06 * Settings.shake_amount(), 1.0)


func focus(p: Vector2, dur: float) -> void:
	focus_override = p
	focus_t = dur


func tick(dt: float) -> void:
	var pts: Array = []
	for f in ctl.fighters:
		if f.alive_in_round() and f.visible and ctl.arena.blast_rect().has_point(f.global_position):
			pts.append(f.center())
	for p in ctl.camera_points():
		pts.append(p)
	var size: Vector2 = ctl.arena.size
	var target := size * 0.5
	var tz := min_zoom
	if focus_t > 0.0:
		focus_t -= dt
		target = focus_override
		tz = 1.5
	elif not pts.is_empty():
		var bb := Rect2(pts[0], Vector2.ZERO)
		for p in pts:
			bb = bb.expand(p)
		# If everyone is high in the air, keep the main stage in frame.
		if bb.end.y < anchor.y - 110.0:
			bb = bb.expand(Vector2(clampf(bb.get_center().x, anchor_x0, anchor_x1), anchor.y - 30.0))
		bb = bb.grow_individual(70, 80, 70, 50)
		# Leave room for the HUD panels along the bottom of the screen.
		tz = clampf(minf(480.0 / bb.size.x, 236.0 / bb.size.y), min_zoom, max_zoom)
		target = bb.get_center() + Vector2(0, 17.0 / tz)
	# Keep the view mostly inside the arena (with a little air for blast zones).
	var half := Vector2(240, 135) / tz
	var lo := Vector2(-60, -90) + half
	var hi := size + Vector2(60, 30 + 34.0 / tz) - half
	if lo.x > hi.x:
		target.x = size.x * 0.5
	else:
		target.x = clampf(target.x, lo.x, hi.x)
	if lo.y > hi.y:
		target.y = size.y * 0.5
	else:
		target.y = clampf(target.y, lo.y, hi.y)
	var k := 1.0 - exp(-4.0 * dt)
	position = position.lerp(target, k)
	var z := lerpf(zoom.x, tz, 1.0 - exp(-2.5 * dt))
	zoom = Vector2(z, z)
	# Shake
	trauma = maxf(0.0, trauma - dt * 1.6)
	var s := trauma * trauma
	offset = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * 10.0 * s
