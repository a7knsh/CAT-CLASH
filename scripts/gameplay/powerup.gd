class_name PowerUp
extends Node2D
## Collectable power-up orb. Spawns at arena power-up points on a timer;
## touching it grants a temporary ability (shown above the cat and in the HUD).

const TYPES := {
	"speed": {"name": "SPEED BOOST", "icon": "boot", "color": Color("4fa8ff"), "dur": 8.0},
	"jump": {"name": "EXTRA JUMP", "icon": "feather", "color": Color("f4f0ff"), "dur": 12.0},
	"shield": {"name": "SHIELD", "icon": "shield", "color": Color("6ae0ff"), "dur": 10.0},
	"magnet": {"name": "WEAPON MAGNET", "icon": "magnet", "color": Color("ff5a6a"), "dur": 10.0},
	"teleport": {"name": "BLINK", "icon": "teleport", "color": Color("d040c0"), "dur": 0.0},
	"giant": {"name": "GIANT CAT", "icon": "grow", "color": Color("5fe07a"), "dur": 7.0},
	"lowgrav": {"name": "FEATHER FALL", "icon": "wing", "color": Color("c8f0ff"), "dur": 9.0},
	"decoy": {"name": "DECOY CLONE", "icon": "decoy", "color": Color("ff7ab0"), "dur": 0.0},
	"elemental": {"name": "FIRE PAWS", "icon": "flame", "color": Color("ff8a2a"), "dur": 9.0},
	"upgrade": {"name": "WEAPON UPGRADE", "icon": "up", "color": Color("ffd23f"), "dur": 10.0},
	"heal": {"name": "FISH SNACK", "icon": "fish", "color": Color("ffb0c8"), "dur": 0.0},
}

var kind := "speed"
var t := 0.0
var ctl: Node = null
var base_pos := Vector2.ZERO


func setup(k: String, pos: Vector2, controller: Node) -> void:
	kind = k
	base_pos = pos
	global_position = pos
	ctl = controller
	z_index = 6


func tick(dt: float) -> void:
	t += dt
	global_position = base_pos + Vector2(0, sin(t * 3.0) * 2.0)
	for f in ctl.fighters:
		if f.targetable() and not f.is_dummy and f.hurtbox().grow(3).has_point(global_position):
			apply_to(f)
			queue_free()
			return
	queue_redraw()


func apply_to(f: CatFighter) -> void:
	var d: Dictionary = TYPES[kind]
	match kind:
		"speed": f.add_status("speed", d.dur)
		"jump": f.add_status("extra_jump", d.dur)
		"shield": f.add_status("shield", d.dur)
		"magnet": f.add_status("magnet", d.dur)
		"giant": f.add_status("giant", d.dur)
		"lowgrav": f.add_status("lowgrav", d.dur)
		"elemental": f.add_status("elemental", d.dur)
		"upgrade": f.add_status("upgrade", d.dur)
		"heal": f.heal(25.0)
		"teleport":
			ctl.fx.smoke(f.center(), 8, Color(0.8, 0.4, 0.9, 0.7))
			f.global_position = ctl.safe_spawn_point(f)
			f.velocity = Vector2.ZERO
			ctl.fx.smoke(f.center(), 8, Color(0.8, 0.4, 0.9, 0.7))
		"decoy":
			ctl.spawn_decoy(f)
	ctl.fx.text(f.center() + Vector2(0, -18), d.name, d.color)
	ctl.fx.ring(global_position, d.color, 16.0)
	AudioHub.play("powerup", -2.0)
	f.stats["powerups"] = int(f.stats.get("powerups", 0)) + 1


func _draw() -> void:
	var d: Dictionary = TYPES[kind]
	var c: Color = d.color
	var pulse := 1.0 + 0.15 * sin(t * 6.0)
	draw_circle(Vector2.ZERO, 8.0 * pulse, Color(c, 0.25))
	draw_circle(Vector2.ZERO, 6.0, Pal.OUTLINE)
	draw_circle(Vector2.ZERO, 5.0, c.darkened(0.35))
	var tex := Sprites.icon_texture(d.icon)
	if tex:
		draw_texture(tex, -tex.get_size() * 0.5)
	draw_rect(Rect2(-3, -4, 2, 1), Color(1, 1, 1, 0.8))
