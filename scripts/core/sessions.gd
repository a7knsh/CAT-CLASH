class_name Sessions
extends RefCounted
## Helpers that build match session dictionaries:
##   {mode, arena, rules: {...}, players: [player_cfg...]}
## player_cfg = {slot, name, device, bot, bot_level, team, skin, preset, profile}


static func player_cfg(slot: int, device: String, preset_id: String, team: int, profile: int, bot: bool, bot_level: int = 1) -> Dictionary:
	var skin := SaveData.get_preset(preset_id)
	var pname := "P%d" % (slot + 1)
	if bot:
		pname = "CPU"
	elif profile >= 0:
		pname = SaveData.profile_name(profile)
	return {"slot": slot, "name": pname, "device": device, "bot": bot, "bot_level": bot_level,
		"team": team, "skin": skin, "preset": preset_id, "profile": profile}


static func random_preset_id(rng: RandomNumberGenerator, exclude: Array = []) -> String:
	var ids: Array = []
	for p in SaveData.all_presets():
		if not (p.id in exclude):
			ids.append(p.id)
	if ids.is_empty():
		return CosmeticDefs.ROSTER[0].id
	return ids[rng.randi_range(0, ids.size() - 1)]


## Build an all-bot (or one keyboard human + bots) session for quick testing.
static func quick_session(mode: String, arena: String, count: int, all_bots: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var md := ModeDefs.get_def(mode)
	count = clampi(count, int(md.min), int(md.max))
	var players: Array = []
	var used: Array = []
	for i in count:
		var pid := random_preset_id(rng, used)
		used.append(pid)
		var human := not all_bots and i == 0
		var team := i % 2 if md.teams in ["forced", "optional"] else (0 if md.teams == "coop" else i)
		players.append(player_cfg(i, "kb0" if human else "", pid, team, 0 if human else -1, not human, int(Settings.get_value("bot_difficulty"))))
	var rules := ModeDefs.default_rules(mode)
	rules["bot_level"] = int(Settings.get_value("bot_difficulty"))
	return {"mode": mode, "arena": arena, "rules": rules, "players": players}
