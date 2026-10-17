class_name AchievementDefs
extends RefCounted
## Achievements and training milestones. Each checks a progress counter in
## SaveData.data.progress (summed across all local profiles) against `target`.
## `reward` is yarn (the unlock currency earned by playing) - cosmetic rewards
## are declared on the cosmetic itself with unlock "ach:<id>".

const ALL := {
	"first_match": {"name": "FIRST POUNCE", "desc": "Play your first match.", "stat": "matches", "target": 1, "yarn": 20},
	"first_win": {"name": "TOP CAT", "desc": "Win a match.", "stat": "wins", "target": 1, "yarn": 30},
	"five_wins": {"name": "ON A ROLL", "desc": "Win 5 matches.", "stat": "wins", "target": 5, "yarn": 40},
	"ten_wins": {"name": "HERO OF THE ALLEY", "desc": "Win 10 matches.", "stat": "wins", "target": 10, "yarn": 60},
	"ko_25": {"name": "NINE LIVES? EIGHT.", "desc": "Score 25 KOs.", "stat": "kos", "target": 25, "yarn": 40},
	"ko_100": {"name": "CAT-ASTROPHE", "desc": "Score 100 KOs.", "stat": "kos", "target": 100, "yarn": 100},
	"parry_master": {"name": "PURRFECT PARRY", "desc": "Parry 20 attacks.", "stat": "parries", "target": 20, "yarn": 50},
	"combo_master": {"name": "COMBO KITTY", "desc": "Land an 8-hit combo.", "stat": "best_combo", "target": 8, "yarn": 50},
	"magic_user": {"name": "ARCANE WHISKERS", "desc": "Score 5 KOs with special weapons.", "stat": "special_kos", "target": 5, "yarn": 40},
	"air_time": {"name": "FREQUENT FLYER", "desc": "Ring-out 30 opponents.", "stat": "ringouts", "target": 30, "yarn": 50},
	"sushi_master": {"name": "SUSHI CHEF", "desc": "Win 3 matches in the Sushi Restaurant.", "stat": "wins_sushi", "target": 3, "yarn": 40},
	"pirate": {"name": "SCALLYWAG", "desc": "Win on the Pirate Ship.", "stat": "wins_ship", "target": 1, "yarn": 30},
	"volcano": {"name": "HOT PAWS", "desc": "Win on the Volcano Arena.", "stat": "wins_volcano", "target": 1, "yarn": 30},
	"haunted": {"name": "GHOST BUSTER", "desc": "Win in the Haunted Mansion.", "stat": "wins_haunted", "target": 1, "yarn": 30},
	"silly": {"name": "CLOWN AROUND", "desc": "Score 10 KOs with funny weapons.", "stat": "funny_kos", "target": 10, "yarn": 40},
	"boss_slayer": {"name": "MOUSER SLAYER", "desc": "Defeat the Mecha-Mouser 9000.", "stat": "boss_wins", "target": 1, "yarn": 80},
	"survivor": {"name": "SURVIVOR", "desc": "Clear wave 5 in Survival.", "stat": "best_wave", "target": 5, "yarn": 50},
	"fisher": {"name": "MASTER ANGLER", "desc": "Capture 5 fish.", "stat": "fish_caps", "target": 5, "yarn": 40},
	"hill_king": {"name": "KING OF THE HILL", "desc": "Win a King of the Hill match.", "stat": "wins_koth", "target": 1, "yarn": 30},
	"champion": {"name": "CHAMPION", "desc": "Win a Tournament.", "stat": "tournaments", "target": 1, "yarn": 100},
	"thrower": {"name": "YEET", "desc": "Hit 25 cats with thrown weapons.", "stat": "throw_hits", "target": 25, "yarn": 40},
	"explorer": {"name": "WORLD TRAVELLER", "desc": "Play on 8 different arenas.", "stat": "arenas_seen", "target": 8, "yarn": 60},
	"mode_hopper": {"name": "MODE HOPPER", "desc": "Play 8 different game modes.", "stat": "modes_seen", "target": 8, "yarn": 60},
	"arsenal": {"name": "ARSENAL", "desc": "Use 20 different weapons.", "stat": "weapons_seen", "target": 20, "yarn": 60},
	"collector": {"name": "COLLECTOR", "desc": "Unlock 25 cosmetics.", "stat": "unlocked_count", "target": 25, "yarn": 100},
	# Training milestones
	"t_combo": {"name": "TRAINING: COMBO", "desc": "Land a 5-hit combo in Training.", "stat": "t_combo", "target": 5, "yarn": 15, "training": true},
	"t_parry": {"name": "TRAINING: PARRY", "desc": "Parry a dummy's attack in Training.", "stat": "t_parry", "target": 1, "yarn": 15, "training": true},
	"t_ringout": {"name": "TRAINING: RING-OUT", "desc": "Launch a dummy out of the arena.", "stat": "t_ringout", "target": 1, "yarn": 15, "training": true},
	"t_throw": {"name": "TRAINING: THROW", "desc": "Hit a dummy with a thrown weapon.", "stat": "t_throw", "target": 1, "yarn": 15, "training": true},
	"t_tech": {"name": "TRAINING: TECH", "desc": "Tech a landing (press block as you hit the ground).", "stat": "t_tech", "target": 1, "yarn": 15, "training": true},
}

## Rotating daily challenges (seeded by the local date).
const DAILY_POOL := [
	{"id": "d_kos", "desc": "Score 10 KOs", "stat": "kos", "target": 10, "yarn": 30},
	{"id": "d_wins", "desc": "Win 3 matches", "stat": "wins", "target": 3, "yarn": 30},
	{"id": "d_throws", "desc": "Hit 5 thrown weapons", "stat": "throw_hits", "target": 5, "yarn": 25},
	{"id": "d_parries", "desc": "Parry 5 attacks", "stat": "parries", "target": 5, "yarn": 25},
	{"id": "d_ringouts", "desc": "Ring-out 6 cats", "stat": "ringouts", "target": 6, "yarn": 25},
	{"id": "d_funny", "desc": "Score 3 KOs with funny weapons", "stat": "funny_kos", "target": 3, "yarn": 30},
	{"id": "d_matches", "desc": "Play 5 matches", "stat": "matches", "target": 5, "yarn": 20},
	{"id": "d_special", "desc": "Score 3 KOs with special weapons", "stat": "special_kos", "target": 3, "yarn": 30},
	{"id": "d_damage", "desc": "Deal 1000 damage", "stat": "damage_dealt", "target": 1000, "yarn": 30},
]
