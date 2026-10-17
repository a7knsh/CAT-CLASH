extends Node
## Offline-first save system: profiles, statistics, custom cat presets,
## unlocks, achievements, daily challenges and mastery.
##
## Robustness: writes go to a temp file then replace the main file; the
## previous save is kept as save.json.bak and used automatically if the main
## file is unreadable. Manual backups can be exported/imported and the whole
## save can be reset from the Stats screen.

signal toast(text: String, color: Color)

const PATH := "user://save.json"
const BAK := "user://save.json.bak"
const BACKUP_DIR := "user://backups"
const VERSION := 1

const MASTERY_TITLES := ["ROOKIE", "SCRAPPER", "BRAWLER", "VETERAN", "CHAMPION", "LEGEND", "MYTHIC"]

var data: Dictionary = {}
var load_status := "ok"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_save()
	refresh_daily()


func default_data() -> Dictionary:
	return {
		"version": VERSION,
		"profiles": [_new_profile("PLAYER 1"), _new_profile("PLAYER 2")],
		"presets": [],
		"unlocked": {},
		"yarn": 0,
		"achievements": {},
		"progress": {},
		"seen": {"arenas": {}, "modes": {}, "weapons": {}},
		"daily": {"date": "", "items": []},
		"mastery": {},
		"last_setup": {},
	}


func _new_profile(pname: String) -> Dictionary:
	return {"id": "pr_%d_%d" % [Time.get_unix_time_from_system(), randi() % 100000], "name": pname, "stats": {}, "created": Time.get_datetime_string_from_system()}


# --------------------------------------------------------------- file I/O

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return parsed


func load_save() -> void:
	var d: Variant = _read_json(PATH)
	if d == null and FileAccess.file_exists(PATH):
		load_status = "recovered"
		d = _read_json(BAK)
		if d == null:
			load_status = "reset"
	if d == null:
		data = default_data()
		if load_status != "reset":
			load_status = "new"
		return
	data = _migrate(d)


func _migrate(d: Dictionary) -> Dictionary:
	var base := default_data()
	for k in base.keys():
		if not d.has(k) or typeof(d[k]) != typeof(base[k]):
			if not (typeof(base[k]) in [TYPE_INT, TYPE_FLOAT] and typeof(d.get(k)) in [TYPE_INT, TYPE_FLOAT]):
				d[k] = base[k]
	if d.profiles.is_empty():
		d.profiles = base.profiles
	for k in ["arenas", "modes", "weapons"]:
		if not d.seen.has(k):
			d.seen[k] = {}
	d.version = VERSION
	return d


func save() -> void:
	var text := JSON.stringify(data, "\t")
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("SaveData: cannot write save file (error %d)." % FileAccess.get_open_error())
		return
	f.store_string(text)
	f.close()
	var gp := ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(PATH):
		DirAccess.copy_absolute(gp, ProjectSettings.globalize_path(BAK))
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), gp)
	if err != OK:
		push_warning("SaveData: rename failed (%d)." % err)


func export_backup() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUP_DIR))
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := "%s/save_%s.json" % [BACKUP_DIR, stamp]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return ProjectSettings.globalize_path(path)


func list_backups() -> Array:
	var out: Array = []
	var dir := DirAccess.open(BACKUP_DIR)
	if dir == null:
		return out
	for fn in dir.get_files():
		if fn.ends_with(".json"):
			out.append(BACKUP_DIR + "/" + fn)
	out.sort()
	out.reverse()
	return out


func import_backup(path: String) -> bool:
	var d: Variant = _read_json(path)
	if d == null:
		return false
	data = _migrate(d)
	save()
	return true


func reset_all() -> void:
	data = default_data()
	refresh_daily()
	save()


# --------------------------------------------------------------- profiles

func profiles() -> Array:
	return data.profiles


func profile_name(idx: int) -> String:
	if idx < 0 or idx >= data.profiles.size():
		return "GUEST"
	return data.profiles[idx].name


func add_profile(pname: String) -> int:
	data.profiles.append(_new_profile(pname))
	save()
	return data.profiles.size() - 1


func rename_profile(idx: int, pname: String) -> void:
	if idx >= 0 and idx < data.profiles.size():
		data.profiles[idx].name = pname
		save()


func delete_profile(idx: int) -> void:
	if data.profiles.size() > 1 and idx >= 0 and idx < data.profiles.size():
		data.profiles.remove_at(idx)
		save()


func profile_stat(idx: int, key: String) -> float:
	if idx < 0 or idx >= data.profiles.size():
		return 0.0
	return float(data.profiles[idx].stats.get(key, 0))


func favorite_weapon(idx: int) -> String:
	if idx < 0 or idx >= data.profiles.size():
		return ""
	var wk: Dictionary = data.profiles[idx].stats.get("weapon_uses", {})
	var best := ""
	var bv := 0.0
	for k in wk.keys():
		if float(wk[k]) > bv:
			bv = float(wk[k])
			best = k
	return best


# ---------------------------------------------------------------- presets

func all_presets() -> Array:
	var out: Array = []
	for p in data.presets:
		out.append(p)
	for r in CosmeticDefs.ROSTER:
		var c: Dictionary = r.duplicate()
		c["builtin"] = true
		out.append(c)
	return out


func get_preset(id: String) -> Dictionary:
	for p in all_presets():
		if p.id == id:
			return Sprites.full_skin(p)
	return Sprites.full_skin(CosmeticDefs.ROSTER[0])


func save_preset(skin: Dictionary) -> String:
	var s := skin.duplicate()
	s.erase("builtin")
	if str(s.get("id", "")) == "" or _is_builtin(str(s.id)):
		s.id = "c_%d_%d" % [Time.get_unix_time_from_system(), randi() % 100000]
	for i in data.presets.size():
		if data.presets[i].id == s.id:
			data.presets[i] = s
			save()
			return s.id
	data.presets.insert(0, s)
	save()
	return s.id


func duplicate_preset(id: String) -> String:
	var s := get_preset(id).duplicate()
	s.id = ""
	s.name = (str(s.name) + " II").substr(0, 12)
	return save_preset(s)


func delete_preset(id: String) -> void:
	for i in data.presets.size():
		if data.presets[i].id == id:
			data.presets.remove_at(i)
			save()
			return


func _is_builtin(id: String) -> bool:
	for r in CosmeticDefs.ROSTER:
		if r.id == id:
			return true
	return false


# ---------------------------------------------------------------- mastery

func mastery_xp(preset_id: String) -> int:
	return int(data.mastery.get(preset_id, 0))


func mastery_level(preset_id: String) -> int:
	return int(sqrt(mastery_xp(preset_id) / 40.0))


func mastery_title(preset_id: String) -> String:
	return MASTERY_TITLES[mini(mastery_level(preset_id), MASTERY_TITLES.size() - 1)]


# ---------------------------------------------------------------- unlocks

func is_unlocked(cat: String, id: String) -> bool:
	var d: Dictionary = CosmeticDefs.category(cat).get(id, {})
	var u: String = d.get("unlock", "")
	if u == "":
		return true
	if data.unlocked.has(cat + ":" + id):
		return true
	if u.begins_with("ach:"):
		return data.achievements.has(u.substr(4))
	return false


func unlock_cost(cat: String, id: String) -> int:
	var d: Dictionary = CosmeticDefs.category(cat).get(id, {})
	var u: String = d.get("unlock", "")
	if u.begins_with("yarn:"):
		return int(u.substr(5))
	return -1


func unlock_hint(cat: String, id: String) -> String:
	var d: Dictionary = CosmeticDefs.category(cat).get(id, {})
	var u: String = d.get("unlock", "")
	if u.begins_with("yarn:"):
		return "BUY FOR %s YARN" % u.substr(5)
	if u.begins_with("ach:"):
		var a: Dictionary = AchievementDefs.ALL.get(u.substr(4), {})
		return "ACHIEVEMENT: " + str(a.get("name", "?"))
	return ""


func buy(cat: String, id: String) -> bool:
	var cost := unlock_cost(cat, id)
	if cost < 0 or is_unlocked(cat, id) or int(data.yarn) < cost:
		return false
	data.yarn = int(data.yarn) - cost
	data.unlocked[cat + ":" + id] = true
	_count_unlocks()
	save()
	return true


func _count_unlocks() -> void:
	var n := 0
	for u in CosmeticDefs.all_unlockables():
		if str(u[2].get("unlock", "")) != "" and is_unlocked(u[0], u[1]):
			n += 1
	data.progress["unlocked_count"] = n


# ----------------------------------------------------------- progression

func progress(stat: String) -> float:
	return float(data.progress.get(stat, 0))


func add_progress(stat: String, amount: float) -> void:
	data.progress[stat] = progress(stat) + amount


func max_progress(stat: String, value: float) -> void:
	data.progress[stat] = maxf(progress(stat), value)


func mark_seen(kind: String, id: String) -> void:
	if id == "":
		return
	data.seen[kind][id] = true
	data.progress[kind + "_seen"] = data.seen[kind].size()


## Check all achievements; returns ids newly earned (and grants yarn).
func check_achievements() -> Array:
	_count_unlocks()
	var new_ones: Array = []
	for id in AchievementDefs.ALL.keys():
		if data.achievements.has(id):
			continue
		var a: Dictionary = AchievementDefs.ALL[id]
		if progress(a.stat) >= float(a.target):
			data.achievements[id] = Time.get_datetime_string_from_system()
			data.yarn = int(data.yarn) + int(a.get("yarn", 0))
			new_ones.append(id)
			toast.emit("ACHIEVEMENT: " + str(a.name), Pal.UI_HILITE)
	if not new_ones.is_empty():
		_count_unlocks()
	return new_ones


func refresh_daily() -> void:
	var date := Time.get_date_string_from_system()
	if data.daily.get("date", "") == date and not data.daily.items.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(date)
	var pool: Array = AchievementDefs.DAILY_POOL.duplicate()
	var items: Array = []
	for i in 3:
		var idx := rng.randi_range(0, pool.size() - 1)
		var c: Dictionary = pool[idx]
		pool.remove_at(idx)
		items.append({"id": c.id, "desc": c.desc, "stat": c.stat, "target": c.target, "yarn": c.yarn, "start": progress(c.stat), "done": false})
	data.daily = {"date": date, "items": items}


func check_daily() -> Array:
	refresh_daily()
	var done: Array = []
	for it in data.daily.items:
		if it.done:
			continue
		if progress(it.stat) - float(it.start) >= float(it.target):
			it.done = true
			data.yarn = int(data.yarn) + int(it.yarn)
			done.append(it)
			toast.emit("DAILY DONE: +%d YARN" % int(it.yarn), Pal.UI_GOOD)
	return done


## Record a finished match. `summary` comes from MatchController.
## Returns {yarn, achievements, daily}.
func record_match(summary: Dictionary) -> Dictionary:
	var yarn_before := int(data.yarn)
	var mode_id: String = summary.get("mode", "")
	var arena_id: String = summary.get("arena", "")
	var training: bool = mode_id == "training"
	if not training:
		add_progress("matches", 1)
		mark_seen("modes", mode_id)
		mark_seen("arenas", arena_id)
	for p in summary.get("players", []):
		if p.get("bot", true):
			continue
		var st: Dictionary = p.get("stats", {})
		var won: bool = p.get("won", false)
		var prof_idx: int = p.get("profile", -1)
		if not training:
			add_progress("kos", st.get("kos", 0))
			add_progress("ringouts", st.get("ringouts", 0))
			add_progress("parries", st.get("parries", 0))
			add_progress("throw_hits", st.get("throw_hits", 0))
			add_progress("damage_dealt", st.get("damage_dealt", 0))
			add_progress("special_kos", st.get("special_kos", 0))
			add_progress("funny_kos", st.get("funny_kos", 0))
			add_progress("fish_caps", st.get("fish_caps", 0))
			max_progress("best_combo", st.get("best_combo", 0))
			if won:
				add_progress("wins", 1)
				add_progress("wins_" + arena_id, 1)
				add_progress("wins_" + mode_id, 1)
			for w in st.get("weapons", {}).keys():
				mark_seen("weapons", w)
		# Earn yarn: playing always pays a little; experimentation pays more.
		var earn := 6 + int(st.get("kos", 0)) * 2 + (10 if won else 0)
		if training:
			earn = 2
		data.yarn = int(data.yarn) + earn
		# Per-profile stats.
		if prof_idx >= 0 and prof_idx < data.profiles.size():
			var ps: Dictionary = data.profiles[prof_idx].stats
			if not training:
				ps["matches"] = int(ps.get("matches", 0)) + 1
				ps["wins"] = int(ps.get("wins", 0)) + (1 if won else 0)
				ps["losses"] = int(ps.get("losses", 0)) + (0 if won else 1)
			for k in ["kos", "falls", "damage_dealt", "damage_taken", "parries", "throw_hits", "ringouts", "hits"]:
				ps[k] = float(ps.get(k, 0)) + float(st.get(k, 0))
			ps["best_combo"] = maxi(int(ps.get("best_combo", 0)), int(st.get("best_combo", 0)))
			ps["playtime"] = float(ps.get("playtime", 0)) + float(summary.get("duration", 0))
			if not ps.has("weapon_uses"):
				ps["weapon_uses"] = {}
			for w in st.get("weapons", {}).keys():
				ps.weapon_uses[w] = int(ps.weapon_uses.get(w, 0)) + int(st.weapons[w])
			if not ps.has("modes"):
				ps["modes"] = {}
			ps.modes[mode_id] = int(ps.modes.get(mode_id, 0)) + 1
		# Mastery for the preset used.
		var pid: String = p.get("preset", "")
		if pid != "" and not training:
			var before := mastery_level(pid)
			data.mastery[pid] = mastery_xp(pid) + 10 + (15 if won else 0) + int(st.get("kos", 0)) * 3
			if mastery_level(pid) > before:
				toast.emit("MASTERY UP: %s" % mastery_title(pid), Pal.UI_ACCENT)
	for k in summary.get("extra_progress", {}).keys():
		var v: float = summary.extra_progress[k]
		if k.begins_with("max:"):
			max_progress(k.substr(4), v)
		else:
			add_progress(k, v)
	var achs := check_achievements()
	var daily := check_daily()
	save()
	return {"yarn": int(data.yarn) - yarn_before, "achievements": achs, "daily": daily}
