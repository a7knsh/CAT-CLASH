class_name CatPuppet
extends Node2D
## Procedural pixel "puppet" renderer for cats. Body parts are pixel textures
## generated from the skin (Sprites.cat_parts); this node poses and layers
## them every frame from the fighter's state, giving every cat — built-in or
## custom — the full animation set with anticipation, squash & stretch,
## follow-through and personality idles.
##
## Works without a fighter (menus) via the preview_* fields.

var fighter: CatFighter = null
var skin: Dictionary = {}

# Menu preview mode
var preview_state := "idle"
var preview_weapon := ""
var preview_facing := 1
var preview_t := 0.0

var t := 0.0
var sq := 0.0
var sq_v := 0.0
var tail_a := 0.4
var tail_v := 0.0
var lean := 0.0
var spin := 0.0
var body_y := 0.0
var head_off := Vector2.ZERO
var head_rot := 0.0
var weapon_rad := deg_to_rad(-40.0)
var arm_rad := 0.3
var arm_len := 5.0
var leg_phase := 0.0
var flash := 0.0
var hurt_lean := 0.0
var blink := 0.0
var blink_t := 2.5
var ear_rot := 0.0
var charge_glow := 0.0
var spawn_t := 0.0
var idle_cycle := 0.0
var trail: Array = []
var shake_off := Vector2.ZERO
var _last_attack_id := ""
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	blink_t = _rng.randf_range(1.0, 4.0)
	idle_cycle = _rng.randf_range(0.0, 3.0)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


# --------------------------------------------------------- state access

func _skin() -> Dictionary:
	if fighter:
		return fighter.skin
	return skin


func _state() -> String:
	return fighter.state if fighter else preview_state


func _state_t() -> float:
	return fighter.state_t if fighter else preview_t


func _vel() -> Vector2:
	if fighter:
		return fighter.velocity
	return Vector2(110, 0) if preview_state == "run" else Vector2.ZERO


func _facing() -> int:
	return fighter.facing if fighter else preview_facing


func _weapon() -> String:
	return fighter.weapon_id() if fighter else preview_weapon


func _attack() -> Dictionary:
	if fighter:
		return fighter.attack
	if preview_state == "attack":
		var ms := AttackData.moveset(preview_weapon)
		var mv: Dictionary = ms.light1 if fmod(preview_t, 2.4) < 1.2 else ms.heavy
		var cycle = mv.startup + mv.active + mv.recovery + 0.35
		return {"mv": mv, "t": fmod(preview_t, 1.2) * cycle / 1.2}
	return {}


func _on_floor() -> bool:
	return fighter.on_floor if fighter else preview_state != "air"


# ------------------------------------------------------------ events

func squash(amount: float) -> void:
	sq_v += amount * 14.0


func on_hurt(dir: int, speed: float) -> void:
	flash = 0.12
	hurt_lean = clampf(speed / 400.0, 0.2, 0.7) * -float(dir * _facing())
	squash(0.2)


func on_pickup() -> void:
	squash(-0.1)
	AudioHub.play("pickup", -6.0)


func on_throw() -> void:
	squash(-0.12)


func on_spawn() -> void:
	spawn_t = 0.0


# -------------------------------------------------------------- update

func _process(dt: float) -> void:
	if fighter == null:
		preview_t += dt
	elif fighter.hitstop > 0.0 and fighter.state in ["hitstun", "tumble"]:
		# Freeze-frame shake on the victim.
		shake_off = Vector2(_rng.randf_range(-1, 1), 0)
		queue_redraw()
		return
	shake_off = Vector2.ZERO
	if fighter and fighter.state == "frozen":
		queue_redraw()
		return
	t += dt
	spawn_t += dt
	flash = maxf(0.0, flash - dt)
	hurt_lean = lerpf(hurt_lean, 0.0, 6.0 * dt)
	# Squash spring
	sq_v += (-sq * 260.0 - sq_v * 16.0) * dt
	sq += sq_v * dt
	sq = clampf(sq, -0.4, 0.4)
	# Blink
	blink_t -= dt
	if blink_t <= 0.0:
		blink = 0.12
		blink_t = _rng.randf_range(2.0, 5.0)
	blink = maxf(0.0, blink - dt)
	_pose(dt)
	queue_redraw()


func _rest_weapon_angle(wid: String) -> float:
	if wid == "":
		return 0.4
	if wid == "fishobj":
		return 0.0
	var arch: String = WeaponDefs.get_def(wid).get("arch", "blade")
	match arch:
		"blade", "blunt": return deg_to_rad(-48)
		"pierce": return deg_to_rad(-12)
		"fist": return deg_to_rad(10)
		"chain": return deg_to_rad(40)
		"potion": return deg_to_rad(-20)
		"boomerang": return deg_to_rad(-30)
	return deg_to_rad(-4)


func _pose(dt: float) -> void:
	var st := _state()
	var stt := _state_t()
	var v := _vel()
	var tgt_lean := 0.0
	var tgt_body := 0.0
	var tgt_head := Vector2.ZERO
	var tgt_head_rot := 0.0
	var tgt_tail := 0.35 + sin(t * 2.2) * 0.15
	var tgt_spin := 0.0
	var tgt_ear := 0.0
	var wid := _weapon()
	var tgt_weapon := _rest_weapon_angle(wid)
	var tgt_arm := 0.5 if wid == "" else 0.1
	var tgt_arm_len := 4.0 if wid == "" else 5.0
	var k := 16.0
	match st:
		"idle":
			tgt_body = sin(t * 2.0) * 0.4
			var pers: String = _skin().get("personality", "tailflick")
			idle_cycle += dt
			var cyc := fmod(idle_cycle, 5.0)
			if cyc > 3.6:
				var p := (cyc - 3.6) / 1.4
				match pers:
					"tailflick":
						tgt_tail = 0.6 + sin(t * 14.0) * 0.5
					"groom":
						tgt_head = Vector2(1, 2)
						tgt_head_rot = 0.25
						tgt_arm = -0.9
						tgt_arm_len = 6.0
					"bounce":
						tgt_body = -absf(sin(p * TAU * 2.0)) * 3.0
					"stretch":
						tgt_lean = 0.22 * sin(p * PI)
						tgt_head = Vector2(2, 2) * sin(p * PI)
					"yawn":
						tgt_head_rot = -0.25 * sin(p * PI)
					"loaf":
						tgt_body = 2.0 * sin(p * PI)
			tgt_weapon += sin(t * 2.0) * 0.05
		"run":
			var spd := clampf(absf(v.x) / 160.0, 0.2, 1.3)
			leg_phase += dt * 15.0 * spd
			tgt_body = -absf(sin(leg_phase)) * 1.5 * spd
			tgt_lean = 0.08 * spd
			tgt_tail = 0.15 + sin(leg_phase) * 0.1
			tgt_ear = 0.25 * spd
			tgt_weapon += sin(leg_phase) * 0.1
		"air", "spawning":
			if v.y < 0:
				tgt_lean = -0.12
				tgt_tail = -0.2
			else:
				tgt_lean = 0.1
				tgt_tail = 0.9
			tgt_ear = -0.2
		"crouch":
			tgt_body = 3.0
			tgt_ear = 0.5
			tgt_head = Vector2(1, 3)
		"block":
			tgt_lean = -0.12
			tgt_ear = 0.6
			tgt_arm = -0.3
			tgt_weapon = deg_to_rad(-80) if wid != "" else -0.3
			tgt_arm_len = 6.0
		"dodge":
			if _on_floor():
				var dur := 0.34
				tgt_spin = -TAU * clampf(stt / dur, 0.0, 1.0)
				spin = tgt_spin
			tgt_body = 2.0
		"hitstun", "stunned", "lag", "throwing":
			tgt_lean = hurt_lean
			tgt_ear = 0.6
			if st == "throwing":
				tgt_arm = -1.6 + stt * 12.0
				tgt_arm_len = 7.0
			if st == "stunned":
				tgt_lean = sin(t * 5.0) * 0.12
		"tumble":
			spin += dt * clampf(v.length() / 30.0, 4.0, 18.0) * (1.0 if v.x * _facing() < 0 else -1.0)
			tgt_spin = spin
			k = 0.0
			tgt_tail = 1.2
		"knockdown":
			tgt_spin = -PI * 0.5
			tgt_body = 4.0
			k = 22.0
			tgt_tail = 1.4
		"getup":
			tgt_spin = 0.0
			k = 14.0
		"emote":
			var tt: String = _skin().get("taunt", "meow")
			match tt:
				"hiss":
					tgt_body = -2.0
					tgt_ear = 0.9
					tgt_tail = -0.3
				"lick":
					tgt_head = Vector2(1, 2)
					tgt_head_rot = 0.3
					tgt_arm = -1.0
					tgt_arm_len = 6.0
				"loaf":
					tgt_body = 3.0
				_:
					tgt_head_rot = -0.3
					tgt_head = Vector2(0, -1)
		"victory":
			var pose: String = _skin().get("victory", "bounce")
			match pose:
				"bounce":
					tgt_body = -absf(sin(t * 6.0)) * 6.0
					tgt_tail = 0.2 + sin(t * 12.0) * 0.4
				"flex":
					tgt_lean = -0.5
					tgt_arm = -1.6 + sin(t * 8.0) * 0.2
					tgt_arm_len = 6.0
				"spin":
					spin += dt * 6.0
					tgt_spin = spin
					k = 0.0
				"sit":
					tgt_lean = -0.35
					tgt_body = 1.0
					tgt_tail = 1.4
					tgt_head_rot = -0.1
				"dance":
					tgt_lean = sin(t * 7.0) * 0.25
					tgt_body = -absf(sin(t * 7.0)) * 2.0
					tgt_head_rot = sin(t * 7.0) * 0.2
				"wave":
					tgt_arm = -1.8 + sin(t * 12.0) * 0.5
					tgt_arm_len = 6.0
		"defeat":
			tgt_body = 2.0
			tgt_ear = 0.9
			tgt_head = Vector2(0, 2)
			tgt_tail = 1.5
		"frozen", "bubbled":
			pass
	# Attacks drive the weapon arc: wind-up -> strike -> follow-through.
	var a := _attack()
	if st == "attack" and not a.is_empty():
		var mv: Dictionary = a.mv
		var at: float = a.t
		var arc: Vector2 = mv.arc
		var rest := _rest_weapon_angle(wid)
		var s0: float = mv.startup
		var s1: float = s0 + mv.active
		var s2: float = s1 + mv.recovery
		if mv.kind == "shoot" or mv.kind == "beam" or mv.kind.begins_with("gravity"):
			var aim: float = deg_to_rad(float(mv.get("aim", 0.0)))
			tgt_weapon = aim
			if at > s0 and at < s0 + 0.08:
				tgt_weapon = aim - 0.35
			tgt_arm = aim * 0.6
			k = 30.0
		elif at < s0:
			var p := ease(at / maxf(s0, 0.001), 0.4)
			tgt_weapon = lerpf(rest, deg_to_rad(arc.x), p)
			tgt_lean = -0.1 * p
			if a.get("charging", false):
				tgt_weapon += sin(t * 40.0) * 0.04
			k = 40.0
		elif at < s1:
			var p2 := (at - s0) / maxf(mv.active, 0.001)
			tgt_weapon = lerpf(deg_to_rad(arc.x), deg_to_rad(arc.y), ease(p2, 0.5))
			tgt_lean = 0.15
			k = 60.0
		else:
			var p3 := (at - s1) / maxf(s2 - s1, 0.001)
			tgt_weapon = lerpf(deg_to_rad(arc.y), rest, ease(p3, 2.0))
			tgt_lean = 0.15 * (1.0 - p3)
			k = 25.0
		if wid == "":
			tgt_arm = tgt_weapon
			tgt_arm_len = 4.0 + (3.0 if at >= s0 and at < s1 else 0.0)
		else:
			tgt_arm = tgt_weapon * 0.5
			tgt_arm_len = 5.0 + (1.5 if at >= s0 and at < s1 else 0.0)
		if mv.id in ["nair"] and at >= s0 and at < s1:
			tgt_spin = -TAU * (at - s0) / maxf(mv.active, 0.001)
			spin = tgt_spin
		if mv.id in ["up", "uair"]:
			tgt_head_rot = -0.2
		if mv.id == "dair":
			tgt_lean = 0.3
		# Weapon trail capture during active frames.
		if at >= s0 and at < s1 and mv.kind == "melee":
			_last_attack_id = mv.id
		else:
			_last_attack_id = ""
	else:
		_last_attack_id = ""
	# Smoothly approach targets.
	var f := 1.0 - exp(-k * dt) if k > 0.0 else 1.0
	lean = lerpf(lean, tgt_lean, f)
	body_y = lerpf(body_y, tgt_body, f)
	head_off = head_off.lerp(tgt_head, f)
	head_rot = lerpf(head_rot, tgt_head_rot, f)
	ear_rot = lerpf(ear_rot, tgt_ear, f)
	weapon_rad = lerp_angle(weapon_rad, tgt_weapon, minf(1.0, f * 1.4))
	arm_rad = lerp_angle(arm_rad, tgt_arm, f)
	arm_len = lerpf(arm_len, tgt_arm_len, f)
	if st not in ["tumble", "dodge"] and not (st == "victory" and _skin().get("victory", "") == "spin") and not (st == "attack" and _last_attack_id == "nair"):
		spin = lerp_angle(spin, tgt_spin, 1.0 - exp(-16.0 * dt))
	# Tail spring follows body motion.
	var tail_target := tgt_tail - v.y * 0.0015 + v.x * _facing() * 0.002
	tail_v += ((tail_target - tail_a) * 90.0 - tail_v * 9.0) * dt
	tail_a += tail_v * dt


# ---------------------------------------------------------------- draw

func _draw() -> void:
	var s := _skin()
	if s.is_empty():
		return
	var parts := Sprites.cat_parts(s)
	var bw: int = parts.bw
	var bh: int = parts.bh
	var hw: int = parts.hw
	var hh: int = parts.hh
	var lw: int = parts.lw
	var face := float(_facing())
	var st := _state()
	var outline := Pal.OUTLINE
	# Status tints
	var mod := Color.WHITE
	if fighter:
		if fighter.has_status("spawn"):
			if Settings.flash_ok():
				mod.a = 0.45 if int(t * 16.0) % 2 == 0 else 1.0
			else:
				mod.a = 0.7
		if fighter.has_status("burn"):
			mod = mod * Color(1.0, 0.75, 0.6)
		if fighter.has_status("slow"):
			mod = mod * Color(0.8, 0.9, 1.1)
	if flash > 0.0:
		mod = Color(2.4, 2.4, 2.4, mod.a) if Settings.flash_ok() else Color(1.3, 1.1, 1.1, mod.a)
	if charge_glow > 0.0:
		var g := 1.0 + charge_glow * (0.5 + 0.5 * sin(t * 30.0)) * 0.6
		mod = Color(mod.r * g, mod.g * g, mod.b * 0.9, mod.a)
	modulate = mod
	# Entrance: teleport / box effects for the first moments after spawning.
	var ent: String = s.get("entrance", "drop")
	if fighter and st == "spawning" and ent == "box" and not fighter.on_floor:
		_draw_box()
		return
	if fighter and st == "spawning" and ent == "teleport" and spawn_t < 0.5:
		var h := 22.0 * spawn_t / 0.5
		draw_rect(Rect2(-8, -h, 16, h), Color(0.6, 0.9, 1.0, 0.5))
	# Root transform: mirror + squash/stretch around the feet + spin about the body.
	var sx := 1.0 + sq
	var sy := 1.0 - sq
	var pivot := Vector2(0, -9)
	var root := Transform2D(spin * face, pivot) * Transform2D(0.0, -pivot) * Transform2D(0.0, Vector2(face * sx, sy), 0.0, Vector2(0, body_y) + shake_off)
	var body_c := Vector2(0, -(4.0 + bh * 0.5))
	var body_xf := root * Transform2D(lean, Vector2(0, -4)) * Transform2D(0.0, body_c - Vector2(0, -4))
	var body_top := -(bh * 0.5)
	# Tail (behind everything)
	_draw_tail(body_xf, Vector2(-bw * 0.5 + 1, body_top + 2), parts, s)
	# Back accessories (behind)
	var back_acc: String = s.get("back_acc", "")
	if back_acc != "" and SpriteArt.ACCESSORIES.has(back_acc) and SpriteArt.ACCESSORIES[back_acc].get("layer", "") == "behind":
		var flutter := clampf(-_vel().x * face * 0.002, -0.4, 0.4)
		_draw_acc(back_acc, body_xf * Transform2D(flutter, Vector2(-bw * 0.5 + 6, body_top + 1)))
	# Legs: back pair, then body, then front pair.
	var leg_tex: Texture2D = parts.leg
	var arm_active = _weapon() != "" or st in ["attack", "block", "throwing"] or (st == "victory" and s.get("victory", "") in ["flex", "wave"]) or (st == "idle" and arm_rad < -0.5) or (st == "emote" and s.get("taunt", "") == "lick")
	var legs := _leg_offsets(st)
	var lx := [-bw * 0.5 + 2.0, -bw * 0.5 + 4.5, bw * 0.5 - 4.5, bw * 0.5 - 2.0]
	var loaf = (st == "emote" and s.get("taunt", "") == "loaf") or (st == "idle" and s.get("personality", "") == "loaf" and fmod(idle_cycle, 5.0) > 3.6)
	if not loaf and st != "knockdown":
		for i in [0, 2]:
			_draw_leg(root, leg_tex, Vector2(lx[i], -4) + legs[i], lw, Color(0.82, 0.82, 0.88))
	# Body
	draw_set_transform_matrix(body_xf)
	draw_texture(parts.body, Vector2(-(bw + 2) * 0.5, -(bh + 2) * 0.5))
	# Paint splats
	if fighter and fighter.has_status("paint"):
		for i in 5:
			var px := float((i * 7 + 3) % bw) - bw * 0.5
			var py := float((i * 5 + 1) % bh) - bh * 0.5
			draw_rect(Rect2(px, py, 2, 2), fighter.paint_color)
	# Front-layer back accessories
	if back_acc != "" and SpriteArt.ACCESSORIES.has(back_acc) and SpriteArt.ACCESSORIES[back_acc].get("layer", "") != "behind":
		var pos := Vector2(-bw * 0.5 + 3, body_top) if back_acc != "armor" else Vector2(-bw * 0.5 + 1, body_top)
		_draw_acc(back_acc, body_xf * Transform2D(0.0, pos))
	if not loaf and st != "knockdown":
		_draw_leg(root, leg_tex, Vector2(lx[1], -4) + legs[1], lw, Color.WHITE)
		if not arm_active:
			_draw_leg(root, leg_tex, Vector2(lx[3], -4) + legs[3], lw, Color.WHITE)
	# Hiss: fur spikes along the back
	if st == "emote" and s.get("taunt", "") == "hiss":
		draw_set_transform_matrix(body_xf)
		for i in 5:
			var x := -bw * 0.5 + 2 + i * 2.5
			draw_rect(Rect2(x, body_top - 2 - (i % 2), 1, 2), Sprites.col(s.fur).darkened(0.2))
	# Head
	var head_c := Vector2(bw * 0.5 - hw * 0.5 + 3, body_top - hh * 0.5 + 4) + head_off
	var head_xf := body_xf * Transform2D(head_rot, head_c)
	var ho := Vector2(-(hw + 2) * 0.5, -(hh + 2) * 0.5)
	var ear_tex: Texture2D = parts.ear
	var ew: int = parts.ear_w
	var eh: int = parts.ear_h
	var ear_back := head_xf * Transform2D(-0.15 - ear_rot * 0.6, ho + Vector2(3.5, 2))
	var ear_front := head_xf * Transform2D(0.1 + ear_rot * 0.6 + sin(t * 9.0) * (0.06 if st == "idle" and fmod(t, 4.0) < 0.3 else 0.0), ho + Vector2(hw - 3.0, 2))
	draw_set_transform_matrix(ear_back)
	draw_texture(ear_tex, Vector2(-(ew + 2) * 0.5, -(eh + 2) + 1), Color(0.8, 0.8, 0.85))
	draw_set_transform_matrix(head_xf)
	draw_texture(parts.head, ho)
	draw_set_transform_matrix(ear_front)
	draw_texture(ear_tex, Vector2(-(ew + 2) * 0.5, -(eh + 2) + 1))
	var ear_acc: String = s.get("ear_acc", "")
	if ear_acc != "":
		_draw_acc(ear_acc, ear_front * Transform2D(0.0, Vector2(0, -1)))
	draw_set_transform_matrix(head_xf)
	_draw_face(ho, hw, hh, s, st)
	# Head accessories
	var head_acc: String = s.get("head_acc", "")
	if head_acc != "":
		_draw_acc(head_acc, head_xf * Transform2D(0.0, ho + Vector2(1 + hw * 0.5, 1)))
	var face_acc: String = s.get("face_acc", "")
	if face_acc != "":
		_draw_acc(face_acc, head_xf * Transform2D(0.0, ho + Vector2(1 + hw - 8, 1 + 3)))
	var neck_acc: String = s.get("neck_acc", "")
	if neck_acc != "":
		_draw_acc(neck_acc, body_xf * Transform2D(0.0, Vector2(bw * 0.5 - 5, body_top + 4)))
	# Front arm + weapon
	var shoulder := Vector2(bw * 0.5 - 3.0, -1.0)
	var paw := shoulder + Vector2.from_angle(arm_rad) * arm_len
	if arm_active:
		var wid := _weapon()
		if wid != "":
			_draw_weapon(body_xf, paw, wid, s)
		# Paw: rotated leg used as an arm
		draw_set_transform_matrix(body_xf * Transform2D(arm_rad - PI * 0.5, shoulder))
		draw_texture(leg_tex, Vector2(-(lw + 2) * 0.5, -1), Color.WHITE)
		draw_set_transform_matrix(body_xf)
		draw_rect(Rect2(paw - Vector2(1.5, 1.5), Vector2(3, 3)), Pal.OUTLINE)
		draw_rect(Rect2(paw - Vector2(0.5, 0.5), Vector2(2, 2)), Sprites.fur_color(s, "leg", 0, 3, lw, 4))
	# Weapon/paw swipe trail
	_update_trail(body_xf, paw)
	_draw_trail(s)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_overlays(st, parts)


func _leg_offsets(st: String) -> Array:
	var o := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	match st:
		"run":
			var p := leg_phase
			o[0] = Vector2(sin(p) * 2.0, -maxf(0.0, cos(p)) * 1.5)
			o[1] = Vector2(sin(p + 0.6) * 2.0, -maxf(0.0, cos(p + 0.6)) * 1.5)
			o[2] = Vector2(sin(p + PI) * 2.0, -maxf(0.0, cos(p + PI)) * 1.5)
			o[3] = Vector2(sin(p + PI + 0.6) * 2.0, -maxf(0.0, cos(p + PI + 0.6)) * 1.5)
		"air", "spawning", "tumble", "hitstun":
			var up := _vel().y < 0
			o[0] = Vector2(-2, -1 if up else 1)
			o[1] = Vector2(-1, -1 if up else 1)
			o[2] = Vector2(2, -2 if up else 1)
			o[3] = Vector2(3, -2 if up else 1)
		"crouch", "block":
			o = [Vector2(0, -1), Vector2(0, -1), Vector2(1, -1), Vector2(1, -1)]
		"victory":
			if _skin().get("victory", "") == "dance":
				var d := sin(t * 7.0)
				o = [Vector2(0, -maxf(0, d) * 2), Vector2(0, -maxf(0, -d) * 2), Vector2(0, -maxf(0, -d) * 2), Vector2(0, -maxf(0, d) * 2)]
	return o


func _draw_leg(root: Transform2D, tex: Texture2D, top: Vector2, lw: int, tint: Color) -> void:
	draw_set_transform_matrix(root * Transform2D(0.0, top))
	draw_texture(tex, Vector2(-(lw + 2) * 0.5, -1), tint)


func _draw_tail(body_xf: Transform2D, root_pos: Vector2, parts: Dictionary, s: Dictionary) -> void:
	var cols: Array = parts.tail_cols
	var segs: int = parts.tail_segs
	var size: int = parts.tail_size
	var style: String = s.get("tail", "long")
	draw_set_transform_matrix(body_xf)
	var pts: Array = []
	var p := root_pos
	var ang := PI + 0.25 + tail_a * 0.5
	for i in segs:
		pts.append(p)
		var bend := 0.1 + tail_a * 0.12 + sin(t * 3.0 + i * 0.7) * 0.07
		if style == "curly" and i > segs - 4:
			bend += 0.7
		ang += bend
		p += Vector2.from_angle(ang) * (size * 0.85 + 0.5)
	# Outline pass then colour pass for a clean pixel silhouette.
	for i in pts.size():
		var sz := size + (1 if style == "fluffy" and i > 1 else 0)
		draw_rect(Rect2(pts[i] - Vector2(sz * 0.5 + 1, sz * 0.5 + 1), Vector2(sz + 2, sz + 2)), Pal.OUTLINE)
	for i in pts.size():
		var sz := size + (1 if style == "fluffy" and i > 1 else 0)
		draw_rect(Rect2(pts[i] - Vector2(sz * 0.5, sz * 0.5), Vector2(sz, sz)), cols[mini(i, cols.size() - 1)])


func _draw_face(ho: Vector2, hw: int, hh: int, s: Dictionary, st: String) -> void:
	var o := ho + Vector2(1, 1)
	var eye_c := Sprites.col(s.get("eye_color", "7ad04a"))
	var shape: String = s.get("eye_shape", "round")
	var expr: String = s.get("expression", "neutral")
	var ex := [hw - 7, hw - 4]
	var ey := 3 if hh >= 10 else 2
	var dark := Pal.OUTLINE
	var mode := "open"
	if blink > 0.0:
		mode = "closed"
	match st:
		"hitstun", "tumble":
			mode = "hurt"
		"stunned":
			mode = "dizzy"
		"knockdown", "defeat":
			mode = "x" if (fighter and fighter.fainting > 0.0) else "closed"
		"victory":
			mode = "happy"
		"emote":
			mode = "closed" if s.get("taunt", "") in ["lick", "loaf"] else ("angry" if s.get("taunt", "") == "hiss" else "happy")
		"attack":
			mode = "angry"
	if fighter and fighter.fainting > 0.0:
		mode = "x"
	if st == "idle" and s.get("personality", "") in ["yawn", "loaf", "groom"] and fmod(idle_cycle, 5.0) > 3.6:
		mode = "closed"
	for i in 2:
		var p := o + Vector2(ex[i], ey)
		match mode:
			"open", "angry":
				if shape == "sleepy" and mode == "open":
					draw_rect(Rect2(p + Vector2(0, 1), Vector2(2, 1)), eye_c)
					draw_rect(Rect2(p, Vector2(2, 1)), dark)
				else:
					var h := 3 if shape == "big" else 2
					draw_rect(Rect2(p, Vector2(2, h)), eye_c)
					if shape == "slit":
						draw_rect(Rect2(p + Vector2(1, 0), Vector2(1, h)), dark)
					else:
						draw_rect(Rect2(p + Vector2(1, h - 1), Vector2(1, 1)), dark)
						draw_rect(Rect2(p, Vector2(1, 1)), Color(1, 1, 1))
					if mode == "angry" or shape == "angry" or expr == "fierce":
						draw_rect(Rect2(p + Vector2(0, -1), Vector2(1 if i == 0 else 2, 1)), dark)
						draw_rect(Rect2(p + Vector2(1 if i == 0 else 0, -1), Vector2(1, 1)), dark)
					if expr == "smug":
						draw_rect(Rect2(p, Vector2(2, 1)), dark)
			"closed":
				draw_rect(Rect2(p + Vector2(0, 1), Vector2(2, 1)), dark)
			"happy":
				draw_rect(Rect2(p + Vector2(0, 1), Vector2(1, 1)), dark)
				draw_rect(Rect2(p + Vector2(1, 0), Vector2(1, 1)), dark)
			"hurt":
				if i == 0:
					draw_rect(Rect2(p, Vector2(1, 1)), dark)
					draw_rect(Rect2(p + Vector2(1, 1), Vector2(1, 1)), dark)
				else:
					draw_rect(Rect2(p + Vector2(1, 0), Vector2(1, 1)), dark)
					draw_rect(Rect2(p + Vector2(0, 1), Vector2(1, 1)), dark)
			"x":
				draw_rect(Rect2(p, Vector2(1, 1)), dark)
				draw_rect(Rect2(p + Vector2(1, 1), Vector2(1, 1)), dark)
				draw_rect(Rect2(p + Vector2(1, 0), Vector2(1, 1)), dark)
				draw_rect(Rect2(p + Vector2(0, 1), Vector2(1, 1)), dark)
			"dizzy":
				var spinp := int(t * 10.0) % 4
				draw_rect(Rect2(p + Vector2(spinp % 2, spinp / 2), Vector2(1, 1)), dark)
				draw_rect(Rect2(p, Vector2(2, 2)), Color(eye_c, 0.5))
	# Mouth
	var mouth_open = st in ["emote", "hitstun", "tumble"] or (st == "attack" and fighter and fighter.attack.get("mv", {}).get("sfx", "") == "swing_heavy") or (st == "idle" and s.get("personality", "") == "yawn" and fmod(idle_cycle, 5.0) > 3.9)
	if st == "emote" and s.get("taunt", "") in ["lick", "loaf"]:
		mouth_open = false
	var mp := o + Vector2(hw - 2, hh - 2)
	if mouth_open:
		draw_rect(Rect2(mp + Vector2(-1, 0), Vector2(2, 2)), dark)
		draw_rect(Rect2(mp + Vector2(-1, 1), Vector2(1, 1)), Color("ff7a9a"))
	elif expr == "happy" or st == "victory":
		draw_rect(Rect2(mp + Vector2(-1, 0), Vector2(1, 1)), dark)
	# Whiskers
	var wk: String = s.get("whiskers", "short")
	if wk != "none":
		var wl := 3.0 if wk == "short" else 5.0
		var wc := Color(1, 1, 1, 0.75)
		var base := o + Vector2(hw - 1, hh - 3)
		draw_line(base, base + Vector2(wl, -1), wc, 1.0)
		draw_line(base + Vector2(0, 1), base + Vector2(wl, 2), wc, 1.0)
		if wk == "curly":
			draw_rect(Rect2(base + Vector2(wl, -2), Vector2(1, 1)), wc)
			draw_rect(Rect2(base + Vector2(wl, 3), Vector2(1, 1)), wc)


func _draw_acc(id: String, xf: Transform2D) -> void:
	var tex := Sprites.accessory_texture(id)
	if tex == null:
		return
	var anchor: Vector2 = SpriteArt.ACCESSORIES[id].anchor
	draw_set_transform_matrix(xf)
	draw_texture(tex, -(anchor + Vector2(1, 1)))


func _draw_weapon(body_xf: Transform2D, paw: Vector2, wid: String, s: Dictionary) -> void:
	var tex := Sprites.weapon_texture(wid, s.get("weapon_skin", "default"))
	var grip := Sprites.weapon_grip(wid)
	var scl := 1.0
	if fighter and fighter.ctl and fighter.ctl.mod_giant_weapons:
		scl = 1.5
	draw_set_transform_matrix(body_xf * Transform2D(weapon_rad, Vector2(scl, scl), 0.0, paw))
	draw_texture(tex, -grip)
	if fighter and fighter.has_status("upgrade"):
		draw_texture(tex, -grip, Color(1.5, 1.3, 0.4, 0.35))


func _update_trail(body_xf: Transform2D, paw: Vector2) -> void:
	var wid := _weapon()
	if _last_attack_id == "":
		if not trail.is_empty():
			trail.pop_front()
		return
	var tip_local := Vector2(Sprites.weapon_length(wid) if wid != "" else 3.0, 0)
	var tip := body_xf * (paw + tip_local.rotated(weapon_rad))
	var mid := body_xf * (paw + (tip_local * 0.4).rotated(weapon_rad))
	trail.append([tip, mid])
	if trail.size() > 6:
		trail.pop_front()


func _draw_trail(s: Dictionary) -> void:
	if trail.size() < 2:
		return
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var tstyle: String = s.get("trail", "none")
	var base := Color(1, 1, 1, 0.55)
	match tstyle:
		"fire": base = Color(1.0, 0.6, 0.2, 0.7)
		"sparkle": base = Color(1.0, 0.95, 0.5, 0.7)
		"bubbles": base = Color(0.6, 0.9, 1.0, 0.6)
		"shadow": base = Color(0.3, 0.15, 0.45, 0.7)
		"none": base = Color(1, 1, 1, 0.35)
	for i in range(1, trail.size()):
		var a: Array = trail[i - 1]
		var b: Array = trail[i]
		var c := base
		if tstyle == "rainbow":
			c = Color.from_hsv(fmod(t * 2.0 + i * 0.12, 1.0), 0.7, 1.0, 0.7)
		c.a *= float(i) / trail.size()
		# Two triangles (never fails like a self-intersecting quad would).
		var cols := PackedColorArray([c, c, c])
		draw_primitive(PackedVector2Array([a[0], b[0], b[1]]), cols, PackedVector2Array())
		draw_primitive(PackedVector2Array([a[0], b[1], a[1]]), cols, PackedVector2Array())
	if tstyle in ["sparkle", "bubbles"] and trail.size() > 2:
		var p: Vector2 = trail[-1][0]
		draw_rect(Rect2(p + Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-3, 3)), Vector2(1, 1)), Color.WHITE)


func _draw_box() -> void:
	draw_rect(Rect2(-9, -15, 18, 15), Pal.OUTLINE)
	draw_rect(Rect2(-8, -14, 16, 13), Color("c89060"))
	draw_rect(Rect2(-8, -14, 16, 2), Color("e0b080"))
	draw_rect(Rect2(-1, -14, 2, 13), Color("a87040"))


func _draw_overlays(st: String, parts: Dictionary) -> void:
	if fighter == null:
		return
	var top = -(4.0 + parts.bh + parts.hh) - 2.0
	if st == "stunned" or (fighter.has_status("shock")):
		for i in 3:
			var a := t * 5.0 + i * TAU / 3.0
			var p := Vector2(cos(a) * 7.0, top + sin(a) * 2.0)
			draw_rect(Rect2(p, Vector2(2, 2)), Color("ffe84a"))
	if st == "frozen":
		draw_rect(Rect2(-10, -24, 20, 24), Color(0.7, 0.9, 1.0, 0.55))
		draw_rect(Rect2(-10, -24, 20, 1), Color(1, 1, 1, 0.8))
		draw_rect(Rect2(-10, -24, 1, 24), Color(1, 1, 1, 0.6))
	if st == "bubbled":
		draw_arc(Vector2(0, -10), 15.0, 0, TAU, 20, Color(0.7, 0.95, 1.0, 0.8), 1.0)
		draw_rect(Rect2(-8, -20, 3, 2), Color(1, 1, 1, 0.8))
	if fighter.has_status("shield"):
		var c := Color(0.4, 0.9, 1.0, 0.45 + 0.2 * sin(t * 8.0))
		draw_arc(Vector2(0, -10), 16.0, 0, TAU, 16, c, 1.0)
	if st == "block":
		var g := clampf(fighter.guard / CatFighter.GUARD_MAX, 0.0, 1.0)
		var gc := Color(0.5, 0.85, 1.0, 0.35 + 0.3 * g).lerp(Color(1, 0.3, 0.3, 0.6), 1.0 - g)
		var fx := float(_facing())
		draw_arc(Vector2(fx * 4, -10), 13.0 * (0.6 + 0.4 * g), -PI * 0.5 if fx > 0 else PI * 0.5, PI * 0.5 if fx > 0 else PI * 1.5, 10, gc, 2.0)
	if st == "emote" and fighter.skin.get("taunt", "meow") == "meow":
		PixelFont.draw_text(self, Vector2(6, top - 6 - fmod(t * 8.0, 6.0)), "♪", Color("fff0a0"), 1, 1, false)
	if fighter.hp / fighter.max_hp < 0.25 and fighter.alive_in_round() and int(t * 3.0) % 2 == 0:
		draw_rect(Rect2(-6, top + 4, 1, 2), Color(0.6, 0.85, 1.0))


## Draw a small cat head portrait (HUD, menus). `scale` is integer pixel scale.
static func draw_head(ci: CanvasItem, pos: Vector2, s: Dictionary, scl: float = 1.0, mirror: bool = false) -> void:
	var parts := Sprites.cat_parts(s)
	var hw: int = parts.hw
	var hh: int = parts.hh
	var xf := Transform2D(0.0, Vector2(-scl if mirror else scl, scl), 0.0, pos)
	var ho := Vector2(-(hw + 2) * 0.5, -(hh + 2) * 0.5)
	var ew: int = parts.ear_w
	var eh: int = parts.ear_h
	ci.draw_set_transform_matrix(xf * Transform2D(-0.15, ho + Vector2(3.5, 2)))
	ci.draw_texture(parts.ear, Vector2(-(ew + 2) * 0.5, -(eh + 2) + 1), Color(0.8, 0.8, 0.85))
	ci.draw_set_transform_matrix(xf)
	ci.draw_texture(parts.head, ho)
	ci.draw_set_transform_matrix(xf * Transform2D(0.1, ho + Vector2(hw - 3.0, 2)))
	ci.draw_texture(parts.ear, Vector2(-(ew + 2) * 0.5, -(eh + 2) + 1))
	ci.draw_set_transform_matrix(xf)
	var o := ho + Vector2(1, 1)
	var eye_c := Sprites.col(s.get("eye_color", "7ad04a"))
	var ey := 3 if hh >= 10 else 2
	for ex in [hw - 7, hw - 4]:
		ci.draw_rect(Rect2(o + Vector2(ex, ey), Vector2(2, 2)), eye_c)
		ci.draw_rect(Rect2(o + Vector2(ex + 1, ey + 1), Vector2(1, 1)), Pal.OUTLINE)
		ci.draw_rect(Rect2(o + Vector2(ex, ey), Vector2(1, 1)), Color.WHITE)
	var head_acc: String = s.get("head_acc", "")
	if head_acc != "" and SpriteArt.ACCESSORIES.has(head_acc):
		var tex := Sprites.accessory_texture(head_acc)
		ci.draw_texture(tex, ho + Vector2(1 + hw * 0.5, 1) - (SpriteArt.ACCESSORIES[head_acc].anchor + Vector2(1, 1)))
	var face_acc: String = s.get("face_acc", "")
	if face_acc != "" and SpriteArt.ACCESSORIES.has(face_acc):
		var tex2 := Sprites.accessory_texture(face_acc)
		ci.draw_texture(tex2, ho + Vector2(1 + hw - 8, 4) - (SpriteArt.ACCESSORIES[face_acc].anchor + Vector2(1, 1)))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
