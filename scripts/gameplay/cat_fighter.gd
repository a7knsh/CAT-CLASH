class_name CatFighter
extends CharacterBody2D
## A fighting cat: movement, state machine, attacks, defence and damage.
## Rendering lives in CatPuppet; hit resolution between fighters lives in
## Combat (called by MatchController) so update order stays deterministic.
## The controller calls tick() once per physics frame.

const RUN_SPEED := 122.0
const SPRINT_SPEED := 162.0
const SPRINT_DELAY := 0.38
const ACCEL_GROUND := 1300.0
const ACCEL_AIR := 820.0
const FRICTION := 1500.0
const ICE_FRICTION := 140.0
const ICE_ACCEL := 330.0
const GRAVITY := 980.0
const MAX_FALL := 420.0
const FAST_FALL := 580.0
const JUMP_V := 345.0
const AIR_JUMP_V := 318.0
const WALL_JUMP := Vector2(195.0, -322.0)
const COYOTE := 0.1
const JUMP_BUFFER := 0.12
const PARRY_WINDOW := 0.16
const TECH_WINDOW := 0.25
const GUARD_MAX := 100.0

# ---------------------------------------------------------------- identity
var slot := 0
var team := 0
var skin: Dictionary = {}
var display_name := "P1"
var is_bot := false
var bot_level := 1
var preset_id := ""
var profile_idx := -1
var is_dummy := false
var is_enemy := false
var is_decoy := false
## Network id (stable across host and clients).
var nid := -1
## Owning device's peer id in LAN games (1 = host).
var owner_peer := 1
var decoy_life := 0.0
var device := ""
var input := FighterInput.new()
var ctl: Node = null
var puppet: Node2D
var brain: RefCounted = null

# ------------------------------------------------------------------- state
var max_hp := 100.0
var hp := 100.0
var stocks := 3
var score := 0
var eliminated := false
var dead := false
var fainting := 0.0
var respawn_timer := -1.0
var state := "idle"
var state_t := 0.0
var facing := 1
var on_floor := false
var was_on_floor := false
var floor_kind := ""
var floor_speed := 0.0
var coyote := 0.0
var jump_buffer := 0.0
var jump_held := false
var air_jumps := 1
var air_dodge_ready := true
var wall_dir := 0
var wall_lock := 0.0
var run_time := 0.0
var drop_t := 0.0
var dodge_cd := 0.0
var dodge_dir := 0.0
var last_block_press := -10.0
var guard := GUARD_MAX
var hitstop := 0.0
var hitstun := 0.0
var invuln := 0.0
var combo_taken := 0
var combo_reset_t := 0.0
var bounce_count := 0
var last_hit_by: CatFighter = null
var last_hit_time := -10.0
var last_hit_weapon := ""
var prev_velocity := Vector2.ZERO
var stun_kind := ""
var size_mult := 1.0
var spawn_point := Vector2.ZERO

# attack instance (empty when not attacking)
var attack: Dictionary = {}
var queued_attack := ""
var queued_t := 0.0

# held weapon: {id, ammo, dur, hits} or {}
var weapon: Dictionary = {}
var boomerang_out := false

# status effects: name -> seconds remaining
var status: Dictionary = {}
var paint_color := Color.TRANSPARENT

var stats := {
	"kos": 0, "falls": 0, "damage_dealt": 0.0, "damage_taken": 0.0, "hits": 0, "parries": 0,
	"throw_hits": 0, "ringouts": 0, "best_combo": 0, "weapons": {}, "special_kos": 0,
	"funny_kos": 0, "fish_caps": 0, "selfdestructs": 0, "items_thrown": 0,
}
var combo_dealt := 0
var combo_dealt_t := 0.0

var _shape: CollisionShape2D
var _rect: RectangleShape2D


func _init() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 5.0
	floor_max_angle = deg_to_rad(50)
	platform_on_leave = CharacterBody2D.PLATFORM_ON_LEAVE_ADD_VELOCITY
	safe_margin = 0.06
	_rect = RectangleShape2D.new()
	_rect.size = Vector2(11, 17)
	_shape = CollisionShape2D.new()
	_shape.shape = _rect
	_shape.position = Vector2(0, -8.5)
	add_child(_shape)


func setup(cfg: Dictionary, controller: Node) -> void:
	ctl = controller
	slot = cfg.get("slot", 0)
	team = cfg.get("team", slot)
	skin = Sprites.full_skin(cfg.get("skin", {}))
	display_name = cfg.get("name", "P%d" % (slot + 1))
	is_bot = cfg.get("bot", false)
	bot_level = cfg.get("bot_level", 1)
	preset_id = cfg.get("preset", "")
	profile_idx = cfg.get("profile", -1)
	is_dummy = cfg.get("dummy", false)
	is_enemy = cfg.get("enemy", false)
	device = cfg.get("device", "")
	input.device = "" if is_bot else device
	max_hp = float(cfg.get("hp", 100))
	hp = max_hp
	if cfg.has("hp_mult"):
		max_hp *= float(cfg.hp_mult)
		hp = max_hp
	puppet = CatPuppet.new()
	puppet.fighter = self
	add_child(puppet)
	if is_bot:
		brain = BotBrain.new(self, bot_level)


# ================================================================ helpers

func alive_in_round() -> bool:
	return not eliminated and not dead and fainting <= 0.0


func targetable() -> bool:
	return alive_in_round() and visible


func weapon_id() -> String:
	return weapon.get("id", "")


func weapon_def() -> Dictionary:
	return WeaponDefs.get_def(weapon_id()) if not weapon.is_empty() else {}


func has_status(n: String) -> bool:
	return status.get(n, 0.0) > 0.0


## The last cat that hit us, if still valid and recent enough for KO credit.
func recent_attacker(window: float = 6.0) -> CatFighter:
	if last_hit_by == null or not is_instance_valid(last_hit_by):
		last_hit_by = null
		return null
	if ctl and ctl.time - last_hit_time > window:
		return null
	return last_hit_by


## Trigger a puppet reaction (squash, hurt flash...) and replicate it to LAN clients.
func _pup(method: String, args: Array) -> void:
	if puppet:
		puppet.callv(method, args)
	if ctl and ctl.has_method("net_event"):
		ctl.net_event(["p", nid, method, args])


func center() -> Vector2:
	return global_position + Vector2(0, -9 * size_mult)


func hurtbox() -> Rect2:
	var s := size_mult
	if state == "crouch" or (state == "attack" and attack.get("mv", {}).get("id", "") == "low"):
		return Rect2(global_position + Vector2(-7, -11) * s, Vector2(14, 11) * s)
	if state == "knockdown":
		return Rect2(global_position + Vector2(-9, -7) * s, Vector2(18, 7) * s)
	return Rect2(global_position + Vector2(-6, -18) * s, Vector2(12, 18) * s)


func is_invulnerable() -> bool:
	if invuln > 0.0 or has_status("spawn") or dead:
		return true
	if state == "dodge":
		return state_t > 0.03 and state_t < 0.26
	if state == "getup":
		return true
	return false


func actionable() -> bool:
	return state in ["idle", "run", "air", "crouch"]


func set_state(s: String) -> void:
	if state == s:
		return
	state = s
	state_t = 0.0


func speed_mult() -> float:
	var m := 1.0
	var d := weapon_def()
	if not d.is_empty():
		m -= clampf(float(d.get("weight", 1.0)) - 1.0, 0.0, 3.0) * 0.06
	if has_status("speed"):
		m *= 1.45
	if has_status("slow"):
		m *= 0.6
	if has_status("tiger"):
		m *= 1.15
	if weapon_id() == "fishobj":
		m *= 0.82
	return m


func dmg_mult() -> float:
	var m := 1.0
	if has_status("giant"):
		m *= 1.2
	if has_status("tiger"):
		m *= 1.35
	if has_status("upgrade"):
		m *= 1.3
	return m


func set_size(m: float) -> void:
	size_mult = m
	_rect.size = Vector2(11, 17) * m
	_shape.position = Vector2(0, -8.5 * m)
	if puppet:
		puppet.scale = Vector2(m, m)


func gravity_mult() -> float:
	var g: float = ctl.gravity_mult if ctl else 1.0
	if has_status("lowgrav"):
		g *= 0.5
	return g


# ================================================================== tick

func tick(dt: float) -> void:
	if dead:
		return
	state_t += dt
	_tick_status(dt)
	if fainting > 0.0:
		_tick_faint(dt)
		return
	if hitstop > 0.0:
		hitstop -= dt
		return
	if brain:
		brain.think(dt)
	_tick_timers(dt)
	match state:
		"idle", "run", "crouch":
			_ground_control(dt)
		"air":
			_air_control(dt)
		"attack":
			_tick_attack(dt)
		"block":
			_tick_block(dt)
		"dodge":
			_tick_dodge(dt)
		"hitstun":
			_tick_hitstun(dt)
		"tumble":
			_tick_tumble(dt)
		"knockdown":
			_tick_knockdown(dt)
		"getup":
			_apply_friction(dt, FRICTION)
			if state_t > 0.3:
				set_state("idle")
		"stunned", "lag", "throwing", "frozen":
			_tick_stunned(dt)
		"bubbled":
			_tick_bubbled(dt)
		"emote":
			_apply_friction(dt, FRICTION)
			if state_t > 1.1 or input.just("jump") or input.just("light") or input.just("dodge"):
				set_state("idle")
		"spawning":
			_air_control(dt)
		"victory", "defeat":
			_apply_friction(dt, FRICTION)
	_physics_move(dt)
	input.end_tick()


func _tick_timers(dt: float) -> void:
	coyote = maxf(0.0, coyote - dt)
	jump_buffer = maxf(0.0, jump_buffer - dt)
	dodge_cd = maxf(0.0, dodge_cd - dt)
	invuln = maxf(0.0, invuln - dt)
	wall_lock = maxf(0.0, wall_lock - dt)
	queued_t = maxf(0.0, queued_t - dt)
	if queued_t <= 0.0:
		queued_attack = ""
	if drop_t > 0.0:
		drop_t -= dt
		if drop_t <= 0.0:
			set_collision_mask_value(3, true)
	combo_reset_t -= dt
	if combo_reset_t <= 0.0 and state != "hitstun" and state != "tumble":
		combo_taken = 0
	combo_dealt_t -= dt
	if combo_dealt_t <= 0.0:
		combo_dealt = 0
	if state != "block":
		guard = minf(GUARD_MAX, guard + 28.0 * dt)
	if input.just("jump"):
		jump_buffer = JUMP_BUFFER
	if input.just("block"):
		last_block_press = ctl.time if ctl else 0.0
	if not weapon.is_empty():
		weapon["cd"] = maxf(0.0, float(weapon.get("cd", 0.0)) - dt)


func _tick_status(dt: float) -> void:
	var expired: Array = []
	for k in status.keys():
		status[k] -= dt
		if status[k] <= 0.0:
			expired.append(k)
	for k in expired:
		status.erase(k)
		_on_status_end(k)
	if has_status("burn"):
		var bt: float = status.get("burn_tick", 0.0) - dt
		if bt <= 0.0:
			bt = 0.5
			if not dead and fainting <= 0.0:
				_apply_damage(2.0, recent_attacker(), "burn")
				if ctl:
					ctl.fx.burst(center(), Color("ff8a2a"), 4, 40.0)
		status["burn_tick"] = bt
	if has_status("magnet") and ctl:
		ctl.magnet_pull(self, dt)


func _on_status_end(k: String) -> void:
	match k:
		"giant", "tiger":
			if not has_status("giant") and not has_status("tiger"):
				set_size(1.0)
				_unstick()
		"frozen":
			if state == "frozen":
				set_state("air" if not on_floor else "idle")
		"bubble":
			if state == "bubbled":
				set_state("air")
		"paint":
			paint_color = Color.TRANSPARENT


func add_status(n: String, t: float) -> void:
	status[n] = maxf(status.get(n, 0.0), t)
	match n:
		"giant":
			set_size(1.5)
			_unstick()
		"tiger":
			set_size(1.45)
			_unstick()
			hp = minf(max_hp, hp + 20.0)
		"extra_jump":
			pass


var _embed_query: PhysicsShapeQueryParameters2D


## True only when genuinely overlapping solid geometry (touching doesn't count).
func is_embedded() -> bool:
	if _embed_query == null:
		_embed_query = PhysicsShapeQueryParameters2D.new()
		_embed_query.collision_mask = 1
		_embed_query.shape = RectangleShape2D.new()
	(_embed_query.shape as RectangleShape2D).size = _rect.size - Vector2(3, 3)
	_embed_query.transform = Transform2D(0.0, global_position + _shape.position)
	return not get_world_2d().direct_space_state.intersect_shape(_embed_query, 1).is_empty()


func _unstick() -> void:
	for i in 12:
		if is_embedded():
			global_position.y -= 3.0
		else:
			break


# ========================================================== ground & air

func _horizontal(dt: float, accel: float, max_speed: float, friction: float) -> void:
	var mx := input.move.x
	if absf(mx) < 0.2:
		mx = 0.0
	if floor_kind == "ice" or (ctl and ctl.mod_slippery and on_floor):
		accel = ICE_ACCEL
		friction = ICE_FRICTION
	if mx != 0.0:
		var target := mx * max_speed
		velocity.x = move_toward(velocity.x, target, accel * dt)
	else:
		_apply_friction(dt, friction)


func _apply_friction(dt: float, friction: float) -> void:
	if not on_floor:
		friction *= 0.25
	if floor_kind == "ice" or (ctl and ctl.mod_slippery and on_floor):
		friction = minf(friction, ICE_FRICTION)
	velocity.x = move_toward(velocity.x, 0.0, friction * dt)


func _face_input() -> void:
	if absf(input.move.x) > 0.25:
		facing = 1 if input.move.x > 0 else -1


func _ground_control(dt: float) -> void:
	if not on_floor:
		set_state("air")
		_air_control(dt)
		return
	_face_input()
	if _try_actions():
		return
	var crouching := input.move.y > 0.55 and absf(input.move.x) < 0.5
	if crouching:
		set_state("crouch")
		_apply_friction(dt, FRICTION * 1.5)
		return
	if absf(input.move.x) > 0.2:
		run_time += dt
		var spd := (SPRINT_SPEED if run_time > SPRINT_DELAY else RUN_SPEED) * speed_mult()
		_horizontal(dt, ACCEL_GROUND, spd, FRICTION)
		if state != "run":
			set_state("run")
			if ctl and absf(velocity.x) < 40:
				ctl.fx.dust(global_position, 2, -facing)
		if run_time > SPRINT_DELAY and int(state_t * 10) % 3 == 0 and ctl and randf() < 0.2:
			ctl.fx.dust(global_position + Vector2(-facing * 4, 0), 1, -facing)
	else:
		run_time = 0.0
		_horizontal(dt, ACCEL_GROUND, RUN_SPEED * speed_mult(), FRICTION)
		if state != "idle":
			set_state("idle")


func _air_control(dt: float) -> void:
	if on_floor and state != "spawning":
		set_state("idle")
		return
	if state == "spawning":
		if on_floor or state_t > 1.4:
			set_state("idle")
		_horizontal(dt, ACCEL_AIR, RUN_SPEED * speed_mult(), FRICTION)
		return
	_face_input()
	if _try_actions():
		return
	var spd := RUN_SPEED
	if absf(velocity.x) > RUN_SPEED and signf(velocity.x) == signf(input.move.x):
		spd = absf(velocity.x)
	_horizontal(dt, ACCEL_AIR, minf(spd, SPRINT_SPEED) * speed_mult(), FRICTION)
	# Variable jump height
	if jump_held and not input.held("jump") and velocity.y < -110.0:
		velocity.y *= 0.5
		jump_held = false


func _try_actions() -> bool:
	if not input.enabled:
		return false
	# Jump / drop / wall-jump / air-jump
	if jump_buffer > 0.0:
		if on_floor or coyote > 0.0:
			if input.move.y > 0.55 and _on_oneway():
				_drop_through()
			else:
				_do_jump(JUMP_V)
			jump_buffer = 0.0
		elif wall_dir != 0 and wall_lock <= 0.0:
			_wall_jump()
			jump_buffer = 0.0
		elif air_jumps > 0:
			air_jumps -= 1
			_do_jump(AIR_JUMP_V)
			if ctl:
				ctl.fx.ring(global_position, Color(1, 1, 1, 0.7), 8.0)
			jump_buffer = 0.0
	# Dodge
	if input.just("dodge") and dodge_cd <= 0.0:
		_start_dodge()
		return true
	# Throw / pickup
	if input.just("throw"):
		if not weapon.is_empty():
			if on_floor and input.move.y > 0.55:
				drop_weapon(false)
			else:
				throw_weapon()
			return true
		elif ctl and ctl.try_pickup(self):
			return true
	# Attacks
	var want := ""
	if input.just("light"):
		want = "L"
	elif input.just("heavy"):
		want = "H"
	elif queued_attack != "":
		want = queued_attack
		queued_attack = ""
	if want != "":
		start_attack(_choose_move(want == "H"))
		return true
	# Block
	if input.held("block") and on_floor:
		set_state("block")
		velocity.x *= 0.3
		return true
	# Taunt
	if input.just("taunt") and on_floor:
		_start_taunt()
		return true
	return false


func _do_jump(v: float) -> void:
	velocity.y = -v
	if has_status("lowgrav"):
		velocity.y *= 0.9
	jump_held = true
	coyote = 0.0
	on_floor = false
	set_state("air")
	if puppet:
		_pup("squash", [-0.22])
	if ctl:
		ctl.fx.dust(global_position, 3, 0)
	AudioHub.play("jump", -10.0)


func _wall_jump() -> void:
	velocity = Vector2(-wall_dir * WALL_JUMP.x, WALL_JUMP.y)
	facing = -wall_dir
	wall_lock = 0.18
	jump_held = true
	set_state("air")
	if puppet:
		_pup("squash", [-0.18])
	if ctl:
		ctl.fx.dust(global_position + Vector2(wall_dir * 6, -8), 3, -wall_dir)
	AudioHub.play("jump", -10.0, 1.15)


func _on_oneway() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col := c.get_collider()
		if c.get_normal().y < -0.7 and col is CollisionObject2D and (col as CollisionObject2D).collision_layer & 4:
			return true
	return false


func _drop_through() -> void:
	set_collision_mask_value(3, false)
	drop_t = 0.24
	global_position.y += 2.0
	set_state("air")
	on_floor = false


# ============================================================== attacks

func _choose_move(heavy: bool) -> String:
	var up := input.move.y < -0.55
	var down := input.move.y > 0.55
	if on_floor:
		if up:
			return "up"
		if down and not heavy:
			return "low"
		if heavy:
			return "heavy"
		return "light1"
	if down:
		return "dair"
	if up:
		return "uair"
	return "air_heavy" if heavy else "nair"


func start_attack(move_id: String) -> void:
	var ms := AttackData.moveset(weapon_id())
	if not ms.has(move_id):
		move_id = "light1"
	var mv: Dictionary = ms[move_id]
	# Shooters respect fire rate.
	if mv.kind == "shoot" and float(weapon.get("cd", 0.0)) > 0.0:
		queued_attack = "H" if move_id in ["heavy", "air_heavy"] else "L"
		queued_t = 0.12
		return
	attack = {"mv": mv, "t": 0.0, "fired": false, "hits": {}, "hit_any": false, "charge": 0.0,
		"charging": mv.charge, "multi_t": 0.0, "dash": absf(velocity.x) > 140.0 and on_floor, "wid": weapon_id()}
	set_state("attack")
	run_time = 0.0
	if mv.kind == "melee" and ctl:
		_note_weapon_use()


func _note_weapon_use() -> void:
	var w := weapon_id()
	if w == "":
		w = "paws"
	stats.weapons[w] = int(stats.weapons.get(w, 0)) + 1


func _tick_attack(dt: float) -> void:
	if attack.is_empty() or not attack.has("mv"):
		set_state("idle" if on_floor else "air")
		return
	var mv: Dictionary = attack.mv
	var a := attack
	# Charging heavy: hold the button to power up (max 0.8s).
	if a.charging:
		var hb := "heavy"
		if input.held(hb) and a.charge < 0.8 and a.t >= mv.startup * 0.5:
			a.charge += dt
			if puppet:
				puppet.charge_glow = a.charge / 0.8
			_apply_friction(dt, FRICTION)
			velocity.y = minf(velocity.y, 60.0) if not on_floor else velocity.y
			return
		elif a.t >= mv.startup * 0.5:
			a.charging = false
			if puppet:
				puppet.charge_glow = 0.0
	a.t += dt
	var t: float = a.t
	var st: float = mv.startup
	var ac: float = mv.active
	var rc: float = mv.recovery
	if not a.fired and t >= st:
		a.fired = true
		_on_active_start(mv)
	# Movement during attacks
	if on_floor:
		if t < st or t > st + ac * 0.7:
			_apply_friction(dt, FRICTION * (0.6 if t < st else 1.0))
	else:
		_horizontal(dt, ACCEL_AIR * 0.6, RUN_SPEED * speed_mult(), FRICTION)
		if mv.id == "dair" and t >= st and t < st + ac:
			velocity.y = maxf(velocity.y, mv.lift)
	# Queue next input during recovery for responsive combos.
	if t > st and (input.just("light") or input.just("heavy")):
		queued_attack = "H" if input.just("heavy") else "L"
		queued_t = 0.2
	# Combo chain: cancel recovery into next move after a hit.
	if a.hit_any and mv.chain != "" and t > st + ac * 0.5 and queued_attack == "L":
		queued_attack = ""
		start_attack(mv.chain)
		return
	# Air attacks end when landing (with landing lag).
	if mv.air and on_floor and t > 0.03:
		attack = {}
		set_state("lag")
		stun_kind = "land"
		hitstun = mv.landing_lag
		if puppet:
			_pup("squash", [0.2])
		return
	if t >= st + ac + rc:
		attack = {}
		set_state("idle" if on_floor else "air")
		if queued_attack != "" and on_floor:
			var q := queued_attack
			queued_attack = ""
			start_attack(_choose_move(q == "H"))


func _on_active_start(mv: Dictionary) -> void:
	var dash_bonus := 1.0
	if attack.get("dash", false) and mv.id == "heavy":
		dash_bonus = 1.4
	if mv.lunge != 0.0 and mv.kind == "melee":
		velocity.x = facing * mv.lunge * dash_bonus
	if mv.kind == "melee":
		AudioHub.play(mv.sfx, -6.0 if mv.sfx == "swing_light" else -3.0, 1.0 + (0.0 if weapon.is_empty() else -0.1 * (float(weapon_def().get("weight", 1.0)) - 1.0)))
		return
	if ctl:
		ctl.weapon_special(self, mv)


## World-space hitbox while in active frames, else empty Rect2.
func active_hitbox() -> Rect2:
	if state != "attack" or attack.is_empty():
		return Rect2()
	var mv: Dictionary = attack.mv
	if mv.kind != "melee":
		return Rect2()
	var t: float = attack.t
	if t < mv.startup or t >= mv.startup + mv.active:
		return Rect2()
	var b: Rect2 = mv.box
	var reach_scale := 1.0
	if ctl and ctl.mod_giant_weapons and not weapon.is_empty():
		reach_scale = 1.5
	var bx := b.position.x
	var bw := b.size.x
	if reach_scale != 1.0:
		bw *= reach_scale
	var s := size_mult
	var r := Rect2(Vector2(bx, b.position.y) * s, Vector2(bw, b.size.y) * s)
	if facing < 0:
		r.position.x = -(r.position.x + r.size.x)
	r.position += global_position
	return r


func attack_damage(mv: Dictionary) -> float:
	var charge_bonus: float = 1.0 + float(attack.get("charge", 0.0)) / 0.8 * 0.6
	var giant := 1.0
	if ctl and ctl.mod_giant_weapons and not weapon.is_empty():
		giant = 1.25
	return float(mv.dmg) * charge_bonus * dmg_mult() * giant


# ======================================================== defence states

func _tick_block(dt: float) -> void:
	_apply_friction(dt, FRICTION * 2.0)
	if not on_floor:
		set_state("air")
		return
	if input.just("dodge") and dodge_cd <= 0.0:
		_start_dodge()
		return
	if input.just("jump"):
		set_state("idle")
		_do_jump(JUMP_V)
		return
	if not input.held("block"):
		set_state("idle")
		return
	if absf(input.move.x) > 0.5:
		facing = 1 if input.move.x > 0 else -1


func _start_dodge() -> void:
	if not on_floor and not air_dodge_ready:
		return
	var dir := Vector2(input.move.x, input.move.y)
	if dir.length() < 0.3:
		dir = Vector2.ZERO
	attack = {}
	set_state("dodge")
	dodge_cd = 0.5
	if on_floor:
		dodge_dir = signf(dir.x)
		velocity.x = dodge_dir * 265.0
	else:
		air_dodge_ready = false
		velocity = dir.normalized() * 250.0 if dir != Vector2.ZERO else Vector2(velocity.x * 0.3, -20.0)
		dodge_dir = signf(dir.x)
	AudioHub.play("dodge", -8.0)
	if ctl:
		ctl.fx.afterimage(self)


func _tick_dodge(dt: float) -> void:
	var dur := 0.34
	if on_floor:
		if dodge_dir != 0.0:
			velocity.x = dodge_dir * lerpf(265.0, 40.0, state_t / dur)
		else:
			_apply_friction(dt, FRICTION * 2)
	else:
		velocity *= 0.92
	if state_t >= dur:
		set_state("idle" if on_floor else "air")


func _start_taunt() -> void:
	set_state("emote")
	var t: String = skin.get("taunt", "meow")
	match t:
		"hiss": AudioHub.play("hiss", -4.0)
		"lick": AudioHub.play("purr", -4.0)
		"loaf": AudioHub.play("purr", -4.0, 0.8)
		_: AudioHub.meow(1.0 + randf() * 0.2)


func _tick_hitstun(dt: float) -> void:
	hitstun -= dt
	# Directional influence: slight drift control while launched.
	velocity.x += input.move.x * 260.0 * dt
	if on_floor:
		_apply_friction(dt, FRICTION * 0.5)
	if hitstun <= 0.0:
		set_state("idle" if on_floor else "air")


func _tick_tumble(dt: float) -> void:
	hitstun -= dt
	velocity.x += input.move.x * 200.0 * dt
	if hitstun <= 0.0 and not on_floor:
		# Recover in the air: regain control.
		set_state("air")


func _tick_knockdown(dt: float) -> void:
	_apply_friction(dt, FRICTION)
	if state_t > 0.55 or (state_t > 0.2 and (input.just("jump") or input.just("dodge") or input.just("light") or absf(input.move.x) > 0.6)):
		set_state("getup")
		invuln = 0.3
		if absf(input.move.x) > 0.6:
			velocity.x = signf(input.move.x) * 180.0


func _tick_stunned(dt: float) -> void:
	hitstun -= dt
	_apply_friction(dt, FRICTION * (0.15 if state == "frozen" else 1.0))
	if state == "frozen" and not has_status("frozen"):
		set_state("air")
		return
	if hitstun <= 0.0 and state != "frozen":
		set_state("idle" if on_floor else "air")


func _tick_bubbled(dt: float) -> void:
	velocity = velocity.lerp(Vector2(input.move.x * 30.0, -38.0), 3.0 * dt)
	if not has_status("bubble"):
		set_state("air")


# ===================================================== weapons in paw

func give_weapon(id: String, ammo: int = -1) -> void:
	var d := WeaponDefs.get_def(id)
	if d.is_empty() and id != "fishobj":
		return
	if not weapon.is_empty():
		drop_weapon(false)
	weapon = {"id": id, "ammo": ammo if ammo >= 0 else int(d.get("ammo", -1)), "dur": int(d.get("dur", -1)), "hits": 0, "cd": 0.0}
	if puppet:
		_pup("on_pickup", [])


func drop_weapon(fling: bool, fling_dir: Vector2 = Vector2.ZERO) -> void:
	if weapon.is_empty() or ctl == null:
		weapon = {}
		return
	var w := weapon
	weapon = {}
	var v := Vector2(facing * 40.0, -60.0)
	if fling:
		v = fling_dir * 260.0 + Vector2(0, -160)
	ctl.spawn_item(w, center() + Vector2(facing * 6, 0), v, null if not fling else self, false)


func throw_weapon() -> void:
	if weapon.is_empty() or ctl == null:
		return
	var w := weapon
	weapon = {}
	var d := WeaponDefs.get_def(w.id)
	var wt: float = d.get("weight", 1.0)
	var aim := Vector2(facing, -0.12)
	if input.move.y < -0.55:
		aim = Vector2(facing * 0.25, -1.0)
	elif input.move.y > 0.55 and not on_floor:
		aim = Vector2(facing * 0.2, 1.0)
	var spd := 520.0 / (0.55 + wt * 0.35)
	var v := aim.normalized() * spd + Vector2(velocity.x * 0.4, 0)
	ctl.spawn_item(w, center() + Vector2(facing * 8, -2), v, self, true)
	stats.items_thrown += 1
	set_state("throwing")
	hitstun = 0.16
	AudioHub.play("throw", -4.0)
	if puppet:
		_pup("on_throw", [])


func use_ammo(n: int = 1) -> void:
	if weapon.is_empty():
		return
	if int(weapon.ammo) < 0:
		return
	weapon.ammo = int(weapon.ammo) - n
	if int(weapon.ammo) <= 0:
		# Out of ammo: the empty weapon is tossed away with a sad click.
		var w := weapon
		weapon = {}
		if ctl:
			w["empty"] = true
			ctl.spawn_item(w, center(), Vector2(-facing * 60.0, -120.0), null, false)
			ctl.fx.text(center() + Vector2(0, -14), "EMPTY", Pal.UI_DIM)
		AudioHub.play("ui_error", -10.0, 1.6)


func on_weapon_hit() -> void:
	if weapon.is_empty():
		return
	weapon.hits = int(weapon.get("hits", 0)) + 1
	if int(weapon.get("dur", -1)) > 0:
		weapon.dur = int(weapon.dur) - 1
		if int(weapon.dur) <= 0:
			var id: String = weapon.id
			weapon = {}
			if ctl:
				ctl.fx.burst(center() + Vector2(facing * 10, -2), Color("c8b090"), 10, 120.0)
				ctl.fx.text(center() + Vector2(0, -16), "BROKE!", Pal.UI_BAD)
			AudioHub.play("crate_break" if id != "plate" else "hit_glass", -4.0)


# ================================================================ damage

## Apply an incoming hit. Returns "hit", "block", "parry", "shield", "miss".
func receive_hit(h: Dictionary) -> String:
	if dead or fainting > 0.0 or is_invulnerable():
		return "miss"
	var attacker: CatFighter = h.get("attacker")
	var src: Vector2 = h.get("src", center())
	var dir: int = h.get("dir", 1)
	var facing_src := (src.x - global_position.x) * facing >= -2.0
	var can_block: bool = h.get("can_block", true)
	# Parry: block pressed just before the hit, facing the source.
	if can_block and ctl and ctl.time - last_block_press <= PARRY_WINDOW and facing_src and state in ["idle", "run", "air", "crouch", "block"]:
		return "parry"
	if has_status("shield"):
		status.erase("shield")
		if ctl:
			ctl.fx.ring(center(), Color("6ae0ff"), 18.0)
		AudioHub.play("hit_glass", -2.0, 1.3)
		invuln = 0.25
		return "shield"
	if state == "block" and can_block and facing_src:
		var chip: float = float(h.dmg) * 0.15
		guard -= float(h.dmg) * 2.4 + 4.0
		_apply_damage(chip, attacker, h.get("cause", "hit"))
		velocity.x = dir * minf(float(h.kb) * 0.3, 160.0)
		if guard <= 0.0:
			guard = 30.0
			set_state("stunned")
			stun_kind = "guardbreak"
			hitstun = 1.0
			velocity = Vector2(dir * 80.0, -140.0)
			AudioHub.play("guard_break", 0.0)
			if ctl:
				ctl.fx.text(center() + Vector2(0, -16), "GUARD BREAK!", Pal.UI_BAD)
			return "hit"
		hitstop = 0.05
		return "block"
	# Frozen targets shatter for bonus knockback.
	var kb: float = h.kb
	if state == "frozen":
		status.erase("frozen")
		kb *= 1.35
		if ctl:
			ctl.fx.burst(center(), Color("c8f0ff"), 14, 160.0)
		AudioHub.play("hit_glass", 0.0)
		set_state("air")
	if state == "bubbled":
		status.erase("bubble")
		AudioHub.play("bubble", 0.0, 0.7)
		if ctl:
			ctl.fx.ring(center(), Color("aef0ff"), 14.0)
	var dmg: float = h.dmg
	_apply_damage(dmg, attacker, h.get("cause", "hit"))
	if attacker != null and attacker != self:
		last_hit_by = attacker
		last_hit_time = ctl.time if ctl else 0.0
		last_hit_weapon = h.get("weapon", "")
	# Knockback grows as health drops and is reduced for big cats.
	var hurt := 1.0 + (1.0 - clampf(hp / max_hp, 0.0, 1.0)) * 1.25
	var weight := 1.0
	if has_status("giant") or has_status("tiger"):
		weight = 0.65
	var speed := kb * hurt * weight
	var ang := deg_to_rad(float(h.ang))
	var v := Vector2(cos(ang) * dir, -sin(ang)) * speed
	if h.get("pull", false):
		v.x = -v.x * 0.6
	# DI: holding perpendicular to the launch nudges it up to 12 degrees.
	if input.move.length() > 0.5 and speed > 120.0:
		var perp := v.normalized().orthogonal()
		var d := clampf(input.move.normalized().dot(perp), -1.0, 1.0)
		v = v.rotated(deg_to_rad(12.0) * d * -1.0)
	if on_floor and v.y > 0.0:
		v.y = -v.y * 0.6
	velocity = v
	combo_taken += 1
	combo_reset_t = 0.5
	var decay := maxf(0.35, 1.0 - 0.12 * float(combo_taken - 1))
	hitstun = minf(1.1, 0.12 + speed * 0.00095) * decay
	attack = {}
	if puppet:
		puppet.charge_glow = 0.0
	if speed > 300.0 or h.get("cause", "") == "explosion":
		set_state("tumble")
		bounce_count = 0
	else:
		set_state("hitstun")
	hitstop = float(h.get("hitstop", 0.05))
	if puppet:
		_pup("on_hurt", [dir, speed])
	# Strong hits disarm.
	if speed > 430.0 and not weapon.is_empty() and weapon_id() != "fishobj" and randf() < 0.65:
		drop_weapon(true, Vector2(dir, -0.3).normalized())
	elif weapon_id() == "fishobj" and speed > 220.0:
		drop_weapon(true, Vector2(dir, -0.3).normalized())
	if hp <= 0.0:
		faint(attacker, h.get("cause", "hit"))
	return "hit"


func _apply_damage(dmg: float, attacker: CatFighter, cause: String) -> void:
	if is_dummy and ctl and ctl.mode and ctl.mode.has_method("dummy_infinite") and ctl.mode.dummy_infinite():
		stats.damage_taken += dmg
		if attacker and attacker != self:
			attacker.stats.damage_dealt += dmg
		hp = maxf(1.0, hp - dmg)
		return
	hp -= dmg
	stats.damage_taken += dmg
	if attacker and attacker != self:
		attacker.stats.damage_dealt += dmg
	if ctl and bool(Settings.get_value("damage_numbers")) and dmg >= 1.0:
		ctl.fx.number(center() + Vector2(randf_range(-4, 4), -12), dmg)
	if hp <= 0.0 and cause in ["burn", "hazard"] and fainting <= 0.0 and not dead:
		faint(attacker, cause)


## Status effects delivered by weapons / hazards after a successful hit.
func apply_effect(eff: String, source: CatFighter) -> void:
	if dead or fainting > 0.0:
		return
	match eff:
		"burn":
			status["burn"] = 2.0
			status["burn_tick"] = 0.5
		"slow":
			status["slow"] = 1.6
		"paint":
			status["paint"] = 6.0
			paint_color = Pal.player_color(source.slot) if source else Color("ff7ab0")
		"freeze":
			status["frozen"] = 1.0
			set_state("frozen")
			attack = {}
			AudioHub.play("freeze", -2.0)
		"bubble":
			status["bubble"] = 1.4
			set_state("bubbled")
			attack = {}
			AudioHub.play("bubble", -2.0)
		"shock":
			set_state("stunned")
			stun_kind = "shock"
			hitstun = 0.35
			attack = {}


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)


## HP reached zero: the cat goes limp, then vanishes. KO is credited now.
func faint(killer: CatFighter, cause: String) -> void:
	if fainting > 0.0 or dead:
		return
	hp = 0.0
	fainting = 1.2
	set_state("tumble")
	hitstun = 2.0
	if velocity.length() < 200.0:
		velocity = Vector2(-facing * 160.0, -260.0)
	if not weapon.is_empty():
		drop_weapon(true, Vector2(-facing, -0.4))
	AudioHub.play("yowl", -2.0, randf_range(0.9, 1.2))
	if ctl:
		ctl.on_fighter_ko(self, killer, cause)


func _tick_faint(dt: float) -> void:
	fainting -= dt
	velocity.y = minf(velocity.y + GRAVITY * gravity_mult() * dt, MAX_FALL)
	if on_floor:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * dt)
		if velocity.y >= 0 and absf(prev_velocity.y) > 200.0:
			velocity.y = -absf(prev_velocity.y) * 0.4
	prev_velocity = velocity
	move_and_slide()
	on_floor = is_on_floor()
	if fainting <= 0.0:
		vanish()


## Remove from the arena (after fainting or a ring-out).
func vanish() -> void:
	dead = true
	fainting = 0.0
	visible = false
	velocity = Vector2.ZERO
	attack = {}
	status.clear()
	set_size(1.0)
	if ctl:
		ctl.fx.ko_effect(self)


## Ring-out: left the blast zone.
func ring_out(killer: CatFighter) -> void:
	if dead:
		return
	if not weapon.is_empty():
		weapon = {}
	if fainting <= 0.0:
		if ctl:
			ctl.on_fighter_ko(self, killer, "ringout")
	hp = 0.0
	vanish()


func respawn(pos: Vector2, with_invuln: bool = true) -> void:
	global_position = pos + Vector2(0, -60)
	velocity = Vector2.ZERO
	hp = max_hp
	dead = false
	fainting = 0.0
	visible = true
	guard = GUARD_MAX
	attack = {}
	weapon = {}
	status.clear()
	set_size(1.0)
	combo_taken = 0
	air_jumps = 1
	air_dodge_ready = true
	set_collision_mask_value(3, true)
	last_hit_by = null
	set_state("spawning")
	if with_invuln:
		status["spawn"] = 2.0
	if puppet:
		_pup("on_spawn", [])


# ================================================================= physics

func _physics_move(dt: float) -> void:
	var g := GRAVITY * gravity_mult()
	var max_fall := MAX_FALL
	if state == "dodge" and not on_floor:
		g *= 0.25
	if state == "air" and input.move.y > 0.6 and velocity.y > -40.0:
		max_fall = FAST_FALL
		g *= 1.6
	if state == "bubbled":
		g = 0.0
	if state == "attack" and attack.get("charging", false) and not on_floor:
		g *= 0.35
	if state in ["tumble", "hitstun"]:
		max_fall = 600.0
	velocity.y = minf(velocity.y + g * dt, max_fall)
	# Wall slide (cats cling to walls).
	if wall_dir != 0 and state == "air" and velocity.y > 0.0 and signf(input.move.x) == wall_dir:
		velocity.y = minf(velocity.y, 70.0)
	prev_velocity = velocity
	var conv := floor_speed if on_floor else 0.0
	velocity.x += conv
	was_on_floor = on_floor
	move_and_slide()
	velocity.x -= conv
	on_floor = is_on_floor()
	_scan_surfaces()
	if on_floor:
		coyote = COYOTE
		air_jumps = 2 if has_status("extra_jump") else 1
		air_dodge_ready = true
		if not was_on_floor:
			_on_land()
	# Walls
	wall_dir = 0
	if is_on_wall() and not on_floor:
		var n := get_wall_normal()
		wall_dir = -1 if n.x > 0 else 1
		if state == "tumble" and absf(prev_velocity.x) > 210.0 and bounce_count < 3:
			_tech_or_bounce(true)


func _scan_surfaces() -> void:
	floor_kind = ""
	floor_speed = 0.0
	if not on_floor:
		return
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y < -0.7:
			var col := c.get_collider()
			if col is Node:
				floor_kind = str((col as Node).get_meta("surface", ""))
				floor_speed = float((col as Node).get_meta("conveyor", 0.0))
			return


func _on_land() -> void:
	if state == "tumble":
		_tech_or_bounce(false)
		return
	if state == "spawning":
		set_state("idle")
	if puppet:
		_pup("squash", [clampf(prev_velocity.y / 900.0, 0.05, 0.35)])
	if prev_velocity.y > 200.0 and ctl:
		ctl.fx.dust(global_position, 4, 0)
		AudioHub.play("land", -10.0)


func _tech_or_bounce(wall: bool) -> void:
	if ctl and ctl.time - last_block_press <= TECH_WINDOW:
		# Tech: instant recovery with a short invulnerable roll.
		velocity = Vector2(input.move.x * 160.0, 0.0) if not wall else Vector2(-wall_dir * 120.0, -200.0)
		set_state("getup" if not wall else "air")
		invuln = 0.35
		hitstun = 0.0
		if ctl:
			ctl.fx.ring(global_position + Vector2(0, -6), Color.WHITE, 12.0)
			ctl.fx.text(center() + Vector2(0, -16), "TECH!", Color("aef0ff"))
			ctl.on_tech(self)
		AudioHub.play("dodge", -2.0, 1.3)
		return
	if wall:
		velocity.x = -prev_velocity.x * 0.5
		velocity.y = minf(prev_velocity.y, 0.0) * 0.6 - 40.0
		bounce_count += 1
		_apply_damage(2.0, recent_attacker(), "wall")
		if ctl:
			ctl.fx.dust(global_position + Vector2(-wall_dir * -6, -9), 5, wall_dir)
			ctl.fx.shake(2.0)
		AudioHub.play("thump", -2.0)
		if puppet:
			_pup("squash", [0.3])
		return
	if prev_velocity.y > 260.0 and bounce_count < 2:
		velocity.y = -prev_velocity.y * 0.42
		bounce_count += 1
		if ctl:
			ctl.fx.dust(global_position, 5, 0)
		AudioHub.play("thump", -4.0)
		if puppet:
			_pup("squash", [0.35])
	else:
		set_state("knockdown")
		if puppet:
			_pup("squash", [0.25])
		if ctl:
			ctl.fx.dust(global_position, 3, 0)


# ================================================================ end of round

func celebrate() -> void:
	attack = {}
	set_state("victory")


func mourn() -> void:
	attack = {}
	set_state("defeat")
