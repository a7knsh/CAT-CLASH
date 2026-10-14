class_name Arena
extends Node2D
## Builds an arena from ArenaDefs: collision (solid, one-way, moving, ice,
## conveyor), static tile art, parallax backdrop and hazards.

var def: Dictionary = {}
var id := ""
var ctl: Node = null
var size := Vector2(640, 360)
var blast := Vector2(150, 140)
var hazards: Array = []
var movers: Array = []     # [{body, base, move, period, rect}]
var backdrop: ArenaBackdrop
var tiles: ArenaTiles
var t := 0.0


func build(arena_id: String, controller: Node, hazards_on: bool) -> void:
	id = arena_id
	def = ArenaDefs.get_def(arena_id)
	ctl = controller
	size = def.size
	blast = def.blast
	backdrop = ArenaBackdrop.new()
	backdrop.setup(def, self)
	add_child(backdrop)
	var ice: Array = def.get("ice", [])
	var idx := 0
	for r in def.solids:
		_make_body(r, 1, false, idx in ice)
		idx += 1
	for r in def.platforms:
		_make_body(r, 4, true, idx in ice)
		idx += 1
	for c in def.get("conveyor", []):
		for child in get_children():
			if child is StaticBody2D and child.get_meta("rect", Rect2()) == c.rect:
				child.set_meta("conveyor", float(c.speed))
	for m in def.get("moving", []):
		var body := AnimatableBody2D.new()
		body.collision_layer = 4
		body.collision_mask = 0
		body.sync_to_physics = true
		var r: Rect2 = m.rect
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = r.size
		cs.shape = sh
		cs.position = r.size * 0.5
		cs.one_way_collision = true
		cs.one_way_collision_margin = 4.0
		body.add_child(cs)
		body.position = r.position
		add_child(body)
		movers.append({"body": body, "base": r.position, "move": m.move, "period": float(m.period), "rect": r})
	tiles = ArenaTiles.new()
	tiles.setup(def, self)
	add_child(tiles)
	if hazards_on:
		for h in def.get("hazards", []):
			var hz := Hazard.new()
			hz.setup(h, self)
			add_child(hz)
			hazards.append(hz)


func _make_body(r: Rect2, layer: int, oneway: bool, ice: bool) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	cs.shape = sh
	cs.position = r.position + r.size * 0.5
	if oneway:
		cs.one_way_collision = true
		cs.one_way_collision_margin = 4.0
	body.add_child(cs)
	body.set_meta("rect", r)
	if ice:
		body.set_meta("surface", "ice")
	add_child(body)
	return body


func tick(dt: float) -> void:
	t += dt
	sync_movers()
	for h in hazards:
		h.tick(dt)


## Position moving platforms for the current arena time (also used by LAN clients).
func sync_movers() -> void:
	for m in movers:
		var ph := sin(t / m.period * TAU) * 0.5 + 0.5
		m.body.position = m.base + m.move * ph


func blast_rect() -> Rect2:
	return Rect2(-blast.x, -blast.y - 120.0, size.x + blast.x * 2.0, size.y + blast.y + 120.0 + 40.0)


## Spawn points (feet). Arenas define 8; extra ones for up to 10 fighters
## are derived by nudging existing points sideways.
func spawn_points() -> Array:
	var pts: Array = def.spawns.duplicate()
	var base: Array = def.spawns
	var i := 0
	while pts.size() < Net.MAX_FIGHTERS:
		var p: Vector2 = base[i % base.size()]
		var off := 16.0 if p.x < size.x * 0.5 else -16.0
		pts.append(p + Vector2(off, 0))
		i += 1
	return pts


func gravity() -> float:
	return float(def.get("gravity", 1.0))


## Highest walkable surface y under x (for respawn & AI), or INF.
func ground_y_at(x: float, from_y: float = -100.0) -> float:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(Vector2(x, from_y), Vector2(x, size.y + 50), 1 | 4)
	var r := space.intersect_ray(q)
	return r.position.y if not r.is_empty() else INF


## Danger level (0..1) at a world position - used by bots to avoid hazards.
func danger_at(p: Vector2) -> float:
	var d := 0.0
	for h in hazards:
		d = maxf(d, h.danger_at(p))
	return d
