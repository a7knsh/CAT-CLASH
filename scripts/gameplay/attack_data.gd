class_name AttackData
extends RefCounted
## Generates movesets from weapon data. Every fighter move is a dictionary:
##   startup / active / recovery   seconds (anticipation, impact, follow-through)
##   dmg, kb, ang                  damage, knockback speed, launch angle (deg, up = +)
##   box                           hitbox Rect2 in fighter space (facing right, feet origin)
##   arc                           weapon angle animation (deg, negative = up) from -> to
##   lunge / lift                  self velocity applied when the active frames start
##   chain                         next combo move if attack pressed again after a hit
##   charge                        heavy moves can be held to power up
##   kind                          melee / shoot / beam / gravity_pull / gravity_push / boomerang / potion

const UNARMED_REACH := 12.0

static var _cache: Dictionary = {}


static func moveset(weapon_id: String) -> Dictionary:
	var key := weapon_id if weapon_id != "" else "_paws"
	if _cache.has(key):
		return _cache[key]
	var ms: Dictionary
	if weapon_id == "" or WeaponDefs.get_def(weapon_id).is_empty():
		ms = _paws()
	else:
		ms = _weapon(weapon_id, WeaponDefs.get_def(weapon_id))
	_cache[key] = ms
	return ms


static func _mv(id: String, startup: float, active: float, recovery: float, dmg: float, kb: float, ang: float, box: Rect2, arc: Vector2) -> Dictionary:
	return {
		"id": id, "startup": startup, "active": active, "recovery": recovery,
		"dmg": dmg, "kb": kb, "ang": ang, "box": box, "arc": arc,
		"lunge": 0.0, "lift": 0.0, "chain": "", "charge": false, "kind": "melee",
		"multi": 0.0, "hitstop": clampf(0.03 + dmg * 0.006, 0.03, 0.14), "sfx": "swing_light",
		"landing_lag": 0.08, "tipper": false, "pull": false, "effect": "", "air": false,
	}


static func _fwd(reach: float, h: float = 14.0, y: float = -17.0) -> Rect2:
	return Rect2(2, y, reach + 5, h)


static func _paws() -> Dictionary:
	var r := UNARMED_REACH
	var m := {}
	m.light1 = _mv("light1", 0.05, 0.06, 0.13, 3, 80, 20, _fwd(r, 10, -14), Vector2(-20, 10))
	m.light1.chain = "light2"
	m.light2 = _mv("light2", 0.05, 0.06, 0.13, 3, 90, 25, _fwd(r, 10, -14), Vector2(10, -25))
	m.light2.chain = "light3"
	m.light3 = _mv("light3", 0.08, 0.07, 0.24, 5, 200, 35, _fwd(r + 2, 12, -15), Vector2(-60, 30))
	m.light3.lunge = 90.0
	m.heavy = _mv("heavy", 0.2, 0.1, 0.3, 9, 300, 32, _fwd(r + 4, 14, -16), Vector2(-30, 0))
	m.heavy.charge = true
	m.heavy.lunge = 190.0
	m.heavy.sfx = "swing_heavy"
	m.up = _mv("up", 0.08, 0.08, 0.2, 5, 240, 85, Rect2(-6, -32, 18, 18), Vector2(20, -100))
	m.low = _mv("low", 0.06, 0.07, 0.18, 4, 150, 12, Rect2(2, -7, r + 7, 7), Vector2(30, 40))
	m.nair = _mv("nair", 0.06, 0.14, 0.15, 5, 180, 45, Rect2(-12, -22, 26, 22), Vector2(-120, 180))
	m.nair.air = true
	m.dair = _mv("dair", 0.1, 0.14, 0.2, 7, 250, -60, Rect2(-7, -6, 16, 14), Vector2(60, 100))
	m.dair.air = true
	m.dair.lift = 260.0
	m.uair = _mv("uair", 0.07, 0.1, 0.15, 6, 230, 80, Rect2(-10, -34, 22, 18), Vector2(40, -130))
	m.uair.air = true
	m.air_heavy = _mv("air_heavy", 0.12, 0.1, 0.26, 9, 300, 30, _fwd(r + 4, 14, -18), Vector2(-40, 20))
	m.air_heavy.air = true
	m.air_heavy.lunge = 150.0
	m.air_heavy.sfx = "swing_heavy"
	return m


static func _weapon(id: String, d: Dictionary) -> Dictionary:
	var arch: String = d.get("arch", "blade")
	var sp: float = maxf(0.2, float(d.get("speed", 1.0)))
	var dmg: float = d.get("dmg", 6)
	var kb: float = d.get("kb", 200)
	var reach: float = d.get("reach", 18)
	var m := {}
	match arch:
		"blade", "blunt", "pierce", "fist", "chain":
			m = _melee(arch, dmg, kb, reach, sp, d)
		"bow", "gun":
			m = _shooter(arch, dmg, kb, sp, d)
		"beam":
			m = _shooter(arch, dmg, kb, sp, d)
			for k in m.keys():
				if m[k].kind == "shoot":
					m[k].kind = "beam"
		"gravity":
			m = _shooter(arch, dmg, kb, sp, d)
			m.light1.kind = "gravity_pull"
			m.heavy.kind = "gravity_push"
			m.heavy.charge = false
		"boomerang":
			m = _melee("blunt", dmg * 0.6, kb * 0.7, reach, sp, d)
			for k in ["light1", "heavy"]:
				m[k].kind = "boomerang"
				m[k].startup = 0.1
				m[k].active = 0.04
				m[k].recovery = 0.2
				m[k].chain = ""
			m.heavy.charge = true
			m.light1.dmg = dmg
			m.light1.kb = kb
			m.heavy.dmg = dmg * 1.3
			m.heavy.kb = kb * 1.2
		"potion":
			m = _paws()
			m.light1 = _mv("light1", 0.25, 0.05, 0.3, 0, 0, 0, Rect2(), Vector2(-80, -110))
			m.light1.kind = "potion"
			m.heavy = m.light1.duplicate()
			m.heavy.id = "heavy"
	var eff: String = d.get("effect", "")
	for k in m.keys():
		if m[k].effect == "":
			m[k].effect = eff
	return m


static func _melee(arch: String, dmg: float, kb: float, reach: float, sp: float, d: Dictionary) -> Dictionary:
	var m := {}
	var t := func(x: float) -> float: return x / sp
	var lungem: float = d.get("lunge", 1.0)
	match arch:
		"blade":
			m.light1 = _mv("light1", t.call(0.07), t.call(0.07), t.call(0.16), dmg * 0.6, kb * 0.45, 22, _fwd(reach), Vector2(-70, 40))
			m.light1.chain = "light2"
			m.light2 = _mv("light2", t.call(0.06), t.call(0.07), t.call(0.16), dmg * 0.6, kb * 0.5, 28, _fwd(reach), Vector2(50, -60))
			m.light2.chain = "light3"
			m.light3 = _mv("light3", t.call(0.09), t.call(0.08), t.call(0.26), dmg * 0.95, kb * 0.85, 35, _fwd(reach + 2, 16, -19), Vector2(-100, 45))
			m.light3.lunge = 110.0
			m.heavy = _mv("heavy", t.call(0.2), t.call(0.1), t.call(0.32), dmg * 1.6, kb * 1.15, 38, Rect2(-2, -30, reach + 9, 30), Vector2(-130, 50))
		"blunt":
			m.light1 = _mv("light1", t.call(0.09), t.call(0.08), t.call(0.2), dmg * 0.7, kb * 0.55, 30, _fwd(reach), Vector2(-80, 40))
			m.light1.chain = "light2"
			m.light2 = _mv("light2", t.call(0.1), t.call(0.08), t.call(0.28), dmg * 1.0, kb * 0.9, 40, _fwd(reach + 2, 16, -19), Vector2(40, -80))
			m.light2.lunge = 80.0
			m.heavy = _mv("heavy", t.call(0.24), t.call(0.1), t.call(0.36), dmg * 1.7, kb * 1.3, 36, Rect2(-2, -28, reach + 9, 28), Vector2(-140, 40))
		"pierce":
			m.light1 = _mv("light1", t.call(0.08), t.call(0.08), t.call(0.18), dmg * 0.7, kb * 0.55, 18, Rect2(4, -14, reach + 4, 6), Vector2(-5, -5))
			m.light1.chain = "light2"
			m.light1.lunge = 60.0
			m.light2 = _mv("light2", t.call(0.08), t.call(0.08), t.call(0.24), dmg * 0.9, kb * 0.8, 25, Rect2(4, -15, reach + 6, 7), Vector2(-10, 0))
			m.light2.lunge = 90.0
			m.heavy = _mv("heavy", t.call(0.22), t.call(0.16), t.call(0.34), dmg * 1.6, kb * 1.2, 22, Rect2(4, -16, reach + 8, 9), Vector2(-5, 0))
			m.heavy.lunge = 260.0 * lungem
		"fist":
			m.light1 = _mv("light1", t.call(0.05), t.call(0.06), t.call(0.12), dmg * 0.6, kb * 0.35, 18, _fwd(reach, 10, -14), Vector2(0, 0))
			m.light1.chain = "light2"
			m.light2 = _mv("light2", t.call(0.05), t.call(0.06), t.call(0.12), dmg * 0.6, kb * 0.4, 20, _fwd(reach, 10, -14), Vector2(0, 0))
			m.light2.chain = "light3"
			m.light3 = _mv("light3", t.call(0.07), t.call(0.07), t.call(0.22), dmg * 1.0, kb * 0.9, 40, _fwd(reach + 2, 12, -16), Vector2(10, -20))
			m.light3.lunge = 80.0
			m.heavy = _mv("heavy", t.call(0.18), t.call(0.1), t.call(0.3), dmg * 1.6, kb * 1.25, 70, Rect2(0, -30, reach + 6, 26), Vector2(30, -80))
			m.heavy.lunge = 70.0
		"chain":
			m.light1 = _mv("light1", t.call(0.1), t.call(0.09), t.call(0.22), dmg * 0.8, kb * 0.6, 25, Rect2(4, -16, reach + 4, 10), Vector2(-60, 10))
			m.light1.tipper = true
			m.light1.chain = "light2"
			m.light2 = _mv("light2", t.call(0.1), t.call(0.09), t.call(0.26), dmg * 1.0, kb * 0.85, 35, Rect2(4, -18, reach + 4, 12), Vector2(40, -20))
			m.light2.tipper = true
			m.heavy = _mv("heavy", t.call(0.24), t.call(0.12), t.call(0.34), dmg * 1.5, kb * 1.2, 40, Rect2(-4, -30, reach + 8, 30), Vector2(-150, 30))
			m.heavy.tipper = true
	m.heavy.charge = true
	m.heavy.sfx = "swing_heavy"
	if not m.heavy.has("lunge") or m.heavy.lunge == 0.0:
		m.heavy.lunge = 70.0
	if d.get("effect", "") == "pull":
		m.heavy.pull = true
	m.up = _mv("up", t.call(0.09), t.call(0.09), t.call(0.22), dmg * 0.85, kb * 0.95, 82, Rect2(-8, -20 - reach, 20, reach + 6), Vector2(40, -120))
	m.low = _mv("low", t.call(0.07), t.call(0.08), t.call(0.2), dmg * 0.7, kb * 0.6, 12, Rect2(2, -8, reach + 6, 8), Vector2(40, 60))
	m.nair = _mv("nair", t.call(0.07), t.call(0.16), t.call(0.16), dmg * 0.8, kb * 0.75, 45, Rect2(-reach * 0.7 - 4, -24, reach * 1.4 + 12, 26), Vector2(-150, 210))
	m.nair.air = true
	m.dair = _mv("dair", t.call(0.1), t.call(0.14), t.call(0.22), dmg * 1.0, kb * 0.95, -62, Rect2(-7, -8, 16, 10 + reach * 0.5), Vector2(80, 95))
	m.dair.air = true
	m.dair.lift = 280.0
	m.uair = _mv("uair", t.call(0.08), t.call(0.1), t.call(0.16), dmg * 0.85, kb * 0.9, 80, Rect2(-10, -20 - reach * 0.9, 24, reach * 0.9 + 6), Vector2(60, -150))
	m.uair.air = true
	m.air_heavy = _mv("air_heavy", t.call(0.14), t.call(0.1), t.call(0.28), dmg * 1.3, kb * 1.1, 30, Rect2(-2, -28, reach + 9, 28), Vector2(-140, 50))
	m.air_heavy.air = true
	m.air_heavy.sfx = "swing_heavy"
	if d.get("multi", false):
		for k in ["light1", "light2", "light3", "nair"]:
			if m.has(k):
				m[k].multi = m[k].active * 0.5
	return m


static func _shooter(arch: String, dmg: float, kb: float, sp: float, d: Dictionary) -> Dictionary:
	# Shooters: attack buttons fire; directional variants aim. The paw bash
	# remains for low/air moves so ranged cats are not helpless up close.
	var m := _paws()
	var rate: float = d.get("rate", 0.3)
	var s := _mv("light1", 0.04, 0.03, maxf(0.06, rate - 0.07), dmg, kb, 15, Rect2(), Vector2(0, 0))
	s.kind = "shoot"
	s.aim = 0.0
	s.hitstop = 0.0
	m.light1 = s
	var u := s.duplicate()
	u.id = "up"
	u.aim = -60.0
	u.arc = Vector2(-60, -60)
	m.up = u
	var h := _mv("heavy", 0.16, 0.04, maxf(0.2, rate + 0.1), dmg * 1.6, kb * 1.3, 18, Rect2(), Vector2(0, 0))
	h.kind = "shoot"
	h.aim = 0.0
	h.charge = arch == "bow"
	h.power = true
	h.hitstop = 0.0
	h.sfx = "swing_heavy"
	m.heavy = h
	var a := s.duplicate()
	a.id = "nair"
	a.air = true
	m.nair = a
	var da := s.duplicate()
	da.id = "dair"
	da.aim = 70.0
	da.arc = Vector2(70, 70)
	da.air = true
	m.dair = da
	var ua := u.duplicate()
	ua.id = "uair"
	ua.air = true
	m.uair = ua
	var ah := h.duplicate()
	ah.id = "air_heavy"
	ah.air = true
	m.air_heavy = ah
	return m
