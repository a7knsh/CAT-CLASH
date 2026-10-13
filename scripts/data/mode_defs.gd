class_name ModeDefs
extends RefCounted
## Game mode catalogue + shared rule definitions. A mode is a script that
## extends BaseMode; this file describes its menu presence and which rule
## rows the setup screen shows. Add a mode = add an entry + a script.

const ORDER := ["ffa", "team", "duel", "stock", "timed", "roulette", "koth", "capture", "survival", "boss", "chaos", "training", "tournament"]

const ALL := {
	"ffa": {"name": "FREE-FOR-ALL", "short": "FFA", "script": "res://scripts/gameplay/modes/mode_ffa.gd", "min": 2, "max": 4, "teams": "none",
		"desc": "Every cat for themselves. Last cat standing wins the round.",
		"rules": ["rounds", "hp", "items", "item_rate", "weapon_set", "start_weapon", "powerups", "hazards", "bot_level"], "defaults": {"rounds": 3}},
	"team": {"name": "2V2 TEAM BATTLE", "short": "TEAMS", "script": "res://scripts/gameplay/modes/mode_ffa.gd", "min": 2, "max": 4, "teams": "forced",
		"desc": "Two teams brawl. Last team standing wins the round.",
		"rules": ["rounds", "hp", "friendly_fire", "items", "item_rate", "weapon_set", "start_weapon", "powerups", "hazards", "bot_level"], "defaults": {"rounds": 3}},
	"duel": {"name": "1V1 DUEL", "short": "DUEL", "script": "res://scripts/gameplay/modes/mode_ffa.gd", "min": 2, "max": 2, "teams": "none",
		"desc": "A fair duel. Both cats start with the same weapon each round.",
		"rules": ["rounds", "hp", "items", "weapon_set", "hazards", "bot_level"], "defaults": {"rounds": 3, "start_weapon": "same", "item_rate": 0, "powerups": false}},
	"stock": {"name": "STOCK BATTLE", "short": "STOCK", "script": "res://scripts/gameplay/modes/mode_stock.gd", "min": 2, "max": 4, "teams": "optional",
		"desc": "Everyone has lives. Lose them all and you're out.",
		"rules": ["stocks", "hp", "teams_on", "friendly_fire", "items", "item_rate", "weapon_set", "start_weapon", "powerups", "hazards", "bot_level"], "defaults": {"stocks": 3}},
	"timed": {"name": "TIMED BATTLE", "short": "TIMED", "script": "res://scripts/gameplay/modes/mode_timed.gd", "min": 2, "max": 4, "teams": "optional",
		"desc": "+1 per KO, -1 per self-destruct. Most points when time runs out wins.",
		"rules": ["time", "hp", "teams_on", "friendly_fire", "items", "item_rate", "weapon_set", "powerups", "hazards", "bot_level"], "defaults": {"time": 120}},
	"roulette": {"name": "WEAPON ROULETTE", "short": "ROULETTE", "script": "res://scripts/gameplay/modes/mode_roulette.gd", "min": 2, "max": 4, "teams": "optional",
		"desc": "Everyone gets a random weapon every few seconds. Adapt or perish!",
		"rules": ["stocks", "roulette_time", "weapon_set", "teams_on", "friendly_fire", "hazards", "bot_level"], "defaults": {"stocks": 3, "items": false}},
	"koth": {"name": "KING OF THE HILL", "short": "KOTH", "script": "res://scripts/gameplay/modes/mode_koth.gd", "min": 2, "max": 4, "teams": "optional",
		"desc": "Hold the glowing zone alone to score. The zone moves!",
		"rules": ["hill_target", "time", "teams_on", "items", "item_rate", "weapon_set", "powerups", "hazards", "bot_level"], "defaults": {"hill_target": 60, "time": 180}},
	"capture": {"name": "CAPTURE THE FISH", "short": "FISH", "script": "res://scripts/gameplay/modes/mode_capture.gd", "min": 2, "max": 4, "teams": "forced",
		"desc": "Grab the golden fish and carry it to your team's basket. Throw it to pass!",
		"rules": ["fish_target", "time", "items", "item_rate", "weapon_set", "powerups", "hazards", "bot_level"], "defaults": {"fish_target": 3, "time": 240}},
	"survival": {"name": "SURVIVAL", "short": "SURVIVE", "script": "res://scripts/gameplay/modes/mode_survival.gd", "min": 1, "max": 4, "teams": "coop",
		"desc": "Fight waves of mecha-mice and alley cats. Co-op or compete for kills.",
		"rules": ["waves", "survival_rule", "stocks", "items", "item_rate", "weapon_set", "powerups", "hazards", "bot_level"], "defaults": {"waves": 10, "stocks": 3, "item_rate": 2}},
	"boss": {"name": "BOSS BATTLE", "short": "BOSS", "script": "res://scripts/gameplay/modes/mode_boss.gd", "min": 1, "max": 4, "teams": "coop",
		"desc": "Team up against the colossal MECHA-MOUSER 9000. Two phases of pain.",
		"rules": ["stocks", "items", "item_rate", "weapon_set", "powerups", "hazards", "bot_level"], "defaults": {"stocks": 3, "item_rate": 2, "arena": "neon"}},
	"chaos": {"name": "CHAOS MODE", "short": "CHAOS", "script": "res://scripts/gameplay/modes/mode_chaos.gd", "min": 2, "max": 4, "teams": "optional",
		"desc": "Random modifiers: low gravity, giant weapons, slippery floors and worse.",
		"rules": ["stocks", "chaos_interval", "teams_on", "friendly_fire", "item_rate", "weapon_set", "bot_level"], "defaults": {"stocks": 3, "item_rate": 2}},
	"training": {"name": "TRAINING", "short": "TRAIN", "script": "res://scripts/gameplay/modes/mode_training.gd", "min": 1, "max": 4, "teams": "none",
		"desc": "Practice on dummies with weapon racks, combo counter and frame data.",
		"rules": ["dummy_count", "dummy_ai", "hazards"], "defaults": {"items": false, "powerups": false, "hazards": false, "arena": "garden"}},
	"tournament": {"name": "TOURNAMENT", "short": "CUP", "script": "res://scripts/gameplay/modes/mode_ffa.gd", "min": 1, "max": 8, "teams": "none",
		"desc": "A knockout bracket of duels. Bots fill empty seats. Crown a champion!",
		"rules": ["bracket", "match_format", "hp", "items", "weapon_set", "hazards", "bot_level"], "defaults": {"bracket": 4, "match_format": "stock2"}},
}

## Rule rows: options + display labels.
const RULES := {
	"rounds": {"label": "ROUNDS TO WIN", "values": [1, 2, 3, 4, 5], "default": 3},
	"stocks": {"label": "LIVES", "values": [1, 2, 3, 4, 5, 7, 9], "default": 3},
	"time": {"label": "TIME LIMIT", "values": [60, 90, 120, 180, 240, 300, 0], "default": 120},
	"hp": {"label": "CAT HEALTH", "values": [50, 100, 150, 200], "default": 100},
	"items": {"label": "WEAPON DROPS", "values": [true, false], "default": true},
	"item_rate": {"label": "DROP RATE", "values": [0, 1, 2, 3], "labels": ["LOW", "NORMAL", "HIGH", "CHAOS"], "default": 1},
	"weapon_set": {"label": "WEAPON SET", "values": ["all", "melee", "ranged", "funny", "classic", "none"], "default": "all"},
	"start_weapon": {"label": "START WEAPON", "values": ["none", "random", "same"], "labels": ["NONE", "RANDOM EACH", "SAME FOR ALL"], "default": "none"},
	"powerups": {"label": "POWER-UPS", "values": [true, false], "default": true},
	"hazards": {"label": "STAGE HAZARDS", "values": [true, false], "default": true},
	"friendly_fire": {"label": "FRIENDLY FIRE", "values": [false, true], "default": false},
	"teams_on": {"label": "TEAMS", "values": [false, true], "default": false},
	"bot_level": {"label": "BOT DIFFICULTY", "values": [0, 1, 2, 3], "labels": ["EASY", "NORMAL", "HARD", "MASTER"], "default": 1},
	"hill_target": {"label": "POINTS TO WIN", "values": [30, 45, 60, 90, 120], "default": 60},
	"fish_target": {"label": "FISH TO WIN", "values": [1, 2, 3, 5], "default": 3},
	"waves": {"label": "WAVES", "values": [5, 10, 15], "default": 10},
	"survival_rule": {"label": "SURVIVAL RULES", "values": ["coop", "compete"], "labels": ["CO-OP", "COMPETE FOR KOS"], "default": "coop"},
	"chaos_interval": {"label": "CHAOS EVERY", "values": [10, 15, 20, 30], "labels": ["10S", "15S", "20S", "30S"], "default": 15},
	"roulette_time": {"label": "SWAP EVERY", "values": [6, 8, 10, 15], "labels": ["6S", "8S", "10S", "15S"], "default": 8},
	"dummy_count": {"label": "DUMMIES", "values": [1, 2, 3], "default": 1},
	"dummy_ai": {"label": "DUMMY BEHAVIOUR", "values": ["stand", "walk", "jump", "block", "cpu"], "labels": ["STAND", "WALK", "JUMP", "BLOCK", "FIGHT BACK"], "default": "stand"},
	"bracket": {"label": "BRACKET SIZE", "values": [4, 8], "default": 4},
	"match_format": {"label": "MATCH FORMAT", "values": ["stock2", "stock3", "rounds2"], "labels": ["2 LIVES", "3 LIVES", "BEST OF 3"], "default": "stock2"},
}


static func get_def(id: String) -> Dictionary:
	return ALL.get(id, ALL["ffa"])


static func default_rules(mode_id: String) -> Dictionary:
	var r := {}
	for k in RULES.keys():
		r[k] = RULES[k].default
	var md := get_def(mode_id)
	for k in md.get("defaults", {}).keys():
		r[k] = md.defaults[k]
	return r


static func rule_label(rule: String, value: Variant) -> String:
	var rd: Dictionary = RULES.get(rule, {})
	if rd.has("labels"):
		var idx: int = rd.values.find(value)
		if idx >= 0:
			return rd.labels[idx]
	if typeof(value) == TYPE_BOOL:
		return "ON" if value else "OFF"
	if rule == "time":
		if int(value) == 0:
			return "INFINITE"
		return "%d:%02d" % [int(value) / 60, int(value) % 60]
	if rule == "weapon_set":
		return WeaponDefs.SETS.get(value, str(value))
	return str(value).to_upper()
