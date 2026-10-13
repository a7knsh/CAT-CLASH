class_name WeaponDefs
extends RefCounted
## Data-driven weapon catalogue. Add a weapon by adding an entry here plus a
## sprite in SpriteArt.WEAPONS - the moveset is generated from `arch` and stats.
##
## Fields
##   name, cat (melee/ranged/special/funny/prop), arch (move archetype),
##   dmg, kb (base knockback px/s), speed (attack speed mult), reach (px),
##   weight (1 = normal; heavier = slower walking, stronger throws),
##   material (impact sound), rarity (spawn weight + glow colour; cosmetic only),
##   ammo / proj / proj_speed / grav / rate for shooters, effect (status effect),
##   dur (durability for improvised props), pros / cons for the collection screen.

const RARITY_WEIGHT := {"common": 10.0, "rare": 6.0, "epic": 3.0, "legendary": 1.5}

const ALL := {
	# ---------------------------------------------------------------- melee
	"sword": {"name": "SWORD", "cat": "melee", "arch": "blade", "dmg": 8, "kb": 230, "speed": 1.0, "reach": 22, "weight": 1.2, "material": "metal", "rarity": "common",
		"desc": "A trusty blade. Good at everything, best at nothing.", "pros": "Balanced reach & speed", "cons": "No special tricks"},
	"katana": {"name": "KATANA", "cat": "melee", "arch": "blade", "dmg": 9, "kb": 190, "speed": 1.25, "reach": 24, "weight": 1.0, "material": "metal", "rarity": "rare",
		"desc": "Lightning-fast slashes for precise kitties.", "pros": "Fast, long combos", "cons": "Low knockback"},
	"dagger": {"name": "DAGGER", "cat": "melee", "arch": "blade", "dmg": 5, "kb": 140, "speed": 1.6, "reach": 13, "weight": 0.6, "material": "metal", "rarity": "common", "throw_dmg": 14,
		"desc": "Tiny, quick, and deadly when thrown.", "pros": "Fastest attacks, strong throw", "cons": "Very short reach"},
	"axe": {"name": "AXE", "cat": "melee", "arch": "blade", "dmg": 12, "kb": 300, "speed": 0.75, "reach": 20, "weight": 1.8, "material": "metal", "rarity": "rare",
		"desc": "Chop chop. Hits like a falling tree.", "pros": "Heavy damage", "cons": "Slow recovery"},
	"hammer": {"name": "WAR HAMMER", "cat": "melee", "arch": "blunt", "dmg": 13, "kb": 360, "speed": 0.65, "reach": 18, "weight": 2.2, "material": "metal", "rarity": "rare",
		"desc": "Sends cats into orbit.", "pros": "Huge knockback", "cons": "Very slow, heavy"},
	"spear": {"name": "SPEAR", "cat": "melee", "arch": "pierce", "dmg": 8, "kb": 220, "speed": 0.95, "reach": 32, "weight": 1.4, "material": "wood", "rarity": "common",
		"desc": "Keep annoying cats at a respectful distance.", "pros": "Long reach", "cons": "Weak up close"},
	"lance": {"name": "LANCE", "cat": "melee", "arch": "pierce", "dmg": 11, "kb": 320, "speed": 0.7, "reach": 36, "weight": 2.4, "material": "metal", "rarity": "epic", "lunge": 1.6,
		"desc": "A jousting lance. Heavy attacks charge forward.", "pros": "Charging lunge", "cons": "Heavy, slow"},
	"scythe": {"name": "SCYTHE", "cat": "melee", "arch": "blade", "dmg": 10, "kb": 260, "speed": 0.8, "reach": 30, "weight": 1.6, "material": "metal", "rarity": "epic", "effect": "pull",
		"desc": "Heavy swings reap enemies TOWARD you.", "pros": "Pulling heavy, wide arc", "cons": "Slow startup"},
	"bat": {"name": "BASEBALL BAT", "cat": "melee", "arch": "blunt", "dmg": 9, "kb": 340, "speed": 0.9, "reach": 20, "weight": 1.3, "material": "wood", "rarity": "common",
		"desc": "Charged heavy swings are home runs.", "pros": "Great horizontal launch", "cons": "Mediocre air game"},
	"pan": {"name": "FRYING PAN", "cat": "melee", "arch": "blunt", "dmg": 8, "kb": 280, "speed": 1.0, "reach": 16, "weight": 1.2, "material": "pan", "rarity": "common", "effect": "reflect",
		"desc": "BONK. Swings reflect projectiles.", "pros": "Reflects shots", "cons": "Short reach"},
	"stick": {"name": "WOODEN STICK", "cat": "melee", "arch": "blunt", "dmg": 5, "kb": 160, "speed": 1.2, "reach": 18, "weight": 0.7, "material": "wood", "rarity": "common",
		"desc": "Found it on the ground. Still counts.", "pros": "Light and quick", "cons": "Weak"},
	"gloves": {"name": "BOXING GLOVES", "cat": "melee", "arch": "fist", "dmg": 6, "kb": 230, "speed": 1.4, "reach": 13, "weight": 0.8, "material": "soft", "rarity": "common",
		"desc": "Float like a butterfly, bap like a cat.", "pros": "Fast combos, strong uppercut", "cons": "Short reach"},
	"claws": {"name": "STEEL CLAWS", "cat": "melee", "arch": "fist", "dmg": 4, "kb": 120, "speed": 1.8, "reach": 13, "weight": 0.6, "material": "metal", "rarity": "rare", "multi": true,
		"desc": "Every swipe scratches twice.", "pros": "Multi-hits, fast", "cons": "Low knockback"},
	"chain": {"name": "CHAIN WHIP", "cat": "melee", "arch": "chain", "dmg": 7, "kb": 220, "speed": 0.9, "reach": 38, "weight": 1.0, "material": "chain", "rarity": "rare",
		"desc": "Sweet spot at the tip deals bonus damage.", "pros": "Huge reach, tipper bonus", "cons": "Weak up close"},
	"mallet": {"name": "GIANT MALLET", "cat": "melee", "arch": "blunt", "dmg": 18, "kb": 480, "speed": 0.45, "reach": 26, "weight": 3.0, "material": "soft", "rarity": "legendary",
		"desc": "A ridiculous novelty mallet. Absolutely devastating.", "pros": "Biggest hits in the game", "cons": "Painfully slow"},
	# --------------------------------------------------------------- ranged
	"bow": {"name": "BOW", "cat": "ranged", "arch": "bow", "dmg": 8, "kb": 200, "speed": 1.0, "reach": 14, "weight": 0.9, "material": "wood", "rarity": "common",
		"ammo": 8, "proj": "arrow", "proj_speed": 520, "grav": 280, "rate": 0.45,
		"desc": "Arcing arrows. Heavy fires a piercing power shot.", "pros": "Long range, pierce shot", "cons": "Arrows drop over distance"},
	"crossbow": {"name": "CROSSBOW", "cat": "ranged", "arch": "bow", "dmg": 12, "kb": 260, "speed": 0.8, "reach": 14, "weight": 1.3, "material": "wood", "rarity": "rare",
		"ammo": 5, "proj": "bolt", "proj_speed": 720, "grav": 50, "rate": 0.9,
		"desc": "Slow reload, hard-hitting flat bolts.", "pros": "Fast, flat, strong", "cons": "Slow reload"},
	"slingshot": {"name": "SLINGSHOT", "cat": "ranged", "arch": "gun", "dmg": 4, "kb": 130, "speed": 1.2, "reach": 12, "weight": 0.5, "material": "wood", "rarity": "common",
		"ammo": 15, "proj": "pebble", "proj_speed": 480, "grav": 420, "rate": 0.25,
		"desc": "Pebbles! Annoying and plentiful.", "pros": "Lots of ammo", "cons": "Low damage"},
	"blaster": {"name": "BLASTER", "cat": "ranged", "arch": "gun", "dmg": 5, "kb": 140, "speed": 1.0, "reach": 12, "weight": 1.0, "material": "energy", "rarity": "common",
		"ammo": 14, "proj": "laser", "proj_speed": 540, "grav": 0, "rate": 0.18,
		"desc": "Pew pew. Rapid straight shots.", "pros": "Rapid fire", "cons": "Easy to block"},
	"pistol": {"name": "ENERGY PISTOL", "cat": "ranged", "arch": "gun", "dmg": 6, "kb": 160, "speed": 1.0, "reach": 10, "weight": 0.7, "material": "energy", "rarity": "rare",
		"ammo": 12, "proj": "energy", "proj_speed": 620, "grav": 0, "rate": 0.28, "burst": 3,
		"desc": "Heavy fires a three-shot burst.", "pros": "Burst fire", "cons": "Burst eats ammo"},
	"snowgun": {"name": "SNOWBALL LAUNCHER", "cat": "ranged", "arch": "gun", "dmg": 4, "kb": 150, "speed": 1.0, "reach": 12, "weight": 1.1, "material": "soft", "rarity": "common",
		"ammo": 12, "proj": "snowball", "proj_speed": 420, "grav": 360, "rate": 0.3, "effect": "slow",
		"desc": "Snowballs slow down whoever they splat.", "pros": "Slows targets", "cons": "Lobbed arc"},
	"paintgun": {"name": "PAINTBALL GUN", "cat": "ranged", "arch": "gun", "dmg": 3, "kb": 90, "speed": 1.2, "reach": 12, "weight": 0.9, "material": "soft", "rarity": "common",
		"ammo": 30, "proj": "paint", "proj_speed": 540, "grav": 140, "rate": 0.1, "effect": "paint",
		"desc": "Splatter opponents in your colour.", "pros": "Very fast fire", "cons": "Tiny damage"},
	"wand": {"name": "MAGIC WAND", "cat": "ranged", "arch": "gun", "dmg": 6, "kb": 170, "speed": 1.0, "reach": 12, "weight": 0.5, "material": "magic", "rarity": "rare",
		"ammo": 8, "proj": "star", "proj_speed": 280, "grav": 0, "rate": 0.4, "effect": "homing",
		"desc": "Homing stars seek the nearest foe.", "pros": "Homing shots", "cons": "Slow projectiles"},
	# -------------------------------------------------------------- special
	"boomerang": {"name": "BOOMERANG", "cat": "special", "arch": "boomerang", "dmg": 8, "kb": 220, "speed": 1.0, "reach": 14, "weight": 0.6, "material": "wood", "rarity": "common",
		"proj": "boomerang", "proj_speed": 380,
		"desc": "It always comes back. Usually.", "pros": "Hits twice, infinite use", "cons": "Unarmed while it flies"},
	"rocket": {"name": "ROCKET LAUNCHER", "cat": "special", "arch": "gun", "dmg": 15, "kb": 400, "speed": 0.7, "reach": 14, "weight": 2.0, "material": "metal", "rarity": "epic",
		"ammo": 3, "proj": "rocket", "proj_speed": 260, "grav": 0, "rate": 1.0, "effect": "explode", "radius": 36,
		"desc": "Explosive splash damage. Mind your whiskers.", "pros": "Splash knockback", "cons": "Only 3 rockets, self damage"},
	"freezegun": {"name": "FREEZE RAY", "cat": "special", "arch": "gun", "dmg": 3, "kb": 60, "speed": 1.0, "reach": 12, "weight": 1.1, "material": "energy", "rarity": "rare",
		"ammo": 6, "proj": "ice", "proj_speed": 460, "grav": 0, "rate": 0.5, "effect": "freeze",
		"desc": "Encases targets in ice. Smash them while frozen!", "pros": "Freezes", "cons": "Low damage"},
	"gravgun": {"name": "GRAVITY GUN", "cat": "special", "arch": "gravity", "dmg": 3, "kb": 420, "speed": 1.0, "reach": 12, "weight": 1.3, "material": "energy", "rarity": "epic",
		"ammo": 8, "rate": 0.5,
		"desc": "Light pulls a cat in, heavy blasts everything away.", "pros": "Pull and push control", "cons": "Little damage"},
	"lightning": {"name": "LIGHTNING STAFF", "cat": "special", "arch": "beam", "dmg": 7, "kb": 180, "speed": 0.9, "reach": 26, "weight": 1.2, "material": "energy", "rarity": "epic",
		"ammo": 6, "rate": 0.6, "effect": "shock",
		"desc": "Instant bolts that chain between cats.", "pros": "Instant hit, chains", "cons": "Limited charges"},
	"firewand": {"name": "FIRE WAND", "cat": "special", "arch": "gun", "dmg": 5, "kb": 160, "speed": 1.0, "reach": 12, "weight": 0.6, "material": "magic", "rarity": "rare",
		"ammo": 8, "proj": "fireball", "proj_speed": 360, "grav": 250, "rate": 0.4, "effect": "burn",
		"desc": "Lobbed fireballs set foes ablaze.", "pros": "Burn damage over time", "cons": "Arcing shots"},
	"bubblegun": {"name": "BUBBLE CANNON", "cat": "special", "arch": "gun", "dmg": 2, "kb": 40, "speed": 1.0, "reach": 12, "weight": 1.0, "material": "soft", "rarity": "rare",
		"ammo": 8, "proj": "bubble", "proj_speed": 170, "grav": -30, "rate": 0.45, "effect": "bubble",
		"desc": "Traps cats in floating bubbles.", "pros": "Traps targets", "cons": "Very slow bubbles"},
	"blackhole": {"name": "VOID ORB", "cat": "special", "arch": "gun", "dmg": 6, "kb": 300, "speed": 1.0, "reach": 10, "weight": 0.8, "material": "magic", "rarity": "legendary",
		"ammo": 1, "proj": "voidorb", "proj_speed": 200, "grav": 0, "rate": 1.0, "effect": "blackhole",
		"desc": "A tiny black hole that sucks in cats and items.", "pros": "Area control", "cons": "Single use"},
	"potion": {"name": "TIGER POTION", "cat": "special", "arch": "potion", "dmg": 0, "kb": 0, "speed": 1.0, "reach": 10, "weight": 0.4, "material": "glass", "rarity": "epic",
		"ammo": 1, "effect": "transform",
		"desc": "Drink to become a giant tiger for 8 seconds.", "pros": "Huge, strong, tough", "cons": "Temporary"},
	# ---------------------------------------------------------------- funny
	"fish": {"name": "GIANT FISH", "cat": "funny", "arch": "blunt", "dmg": 10, "kb": 380, "speed": 0.75, "reach": 22, "weight": 1.6, "material": "fish", "rarity": "rare",
		"desc": "The legendary fish slap.", "pros": "Huge slap knockback", "cons": "Slow, smells"},
	"baguette": {"name": "BAGUETTE", "cat": "funny", "arch": "blade", "dmg": 6, "kb": 200, "speed": 1.1, "reach": 20, "weight": 0.8, "material": "bread", "rarity": "common",
		"desc": "Crunchy. Leaves crumbs everywhere.", "pros": "Quick and long", "cons": "Moderate damage"},
	"chicken": {"name": "RUBBER CHICKEN", "cat": "funny", "arch": "blunt", "dmg": 2, "kb": 130, "speed": 1.6, "reach": 16, "weight": 0.4, "material": "squeak", "rarity": "rare", "effect": "squeak",
		"desc": "Every 5th hit is a MEGA SQUEAK that launches.", "pros": "Fast, mega launch", "cons": "Barely hurts"},
	"toysword": {"name": "FOAM SWORD", "cat": "funny", "arch": "blade", "dmg": 3, "kb": 260, "speed": 1.3, "reach": 22, "weight": 0.4, "material": "soft", "rarity": "common",
		"desc": "Harmless? Big knockback though.", "pros": "Fast, pushy", "cons": "Tiny damage"},
	"spoon": {"name": "GIANT SPOON", "cat": "funny", "arch": "blunt", "dmg": 7, "kb": 300, "speed": 0.9, "reach": 22, "weight": 1.3, "material": "pan", "rarity": "common",
		"desc": "Here comes the airplane!", "pros": "Solid launch", "cons": "Average speed"},
	"fishhammer": {"name": "FISH HAMMER", "cat": "funny", "arch": "blunt", "dmg": 12, "kb": 360, "speed": 0.7, "reach": 18, "weight": 1.9, "material": "fish", "rarity": "epic",
		"desc": "Half fish, half hammer, all business.", "pros": "Heavy hitter", "cons": "Slow"},
	# --------------------------------------------- improvised arena props
	"pipe": {"name": "SCRAP PIPE", "cat": "prop", "arch": "blunt", "dmg": 7, "kb": 230, "speed": 0.95, "reach": 18, "weight": 1.4, "material": "metal", "rarity": "common", "dur": 8, "spawn": 0,
		"desc": "Junkyard special. Bends after a few hits.", "pros": "Free weapon", "cons": "Breaks"},
	"plate": {"name": "SUSHI PLATE", "cat": "prop", "arch": "blunt", "dmg": 3, "kb": 140, "speed": 1.3, "reach": 12, "weight": 0.5, "material": "glass", "rarity": "common", "dur": 3, "throw_dmg": 10, "spawn": 0,
		"desc": "Throw it like a frisbee.", "pros": "Great throw", "cons": "Shatters fast"},
	"torch": {"name": "CASTLE TORCH", "cat": "prop", "arch": "blade", "dmg": 5, "kb": 180, "speed": 1.0, "reach": 18, "weight": 0.9, "material": "wood", "rarity": "common", "dur": 10, "effect": "burn", "spawn": 0,
		"desc": "Hot! Sets foes alight.", "pros": "Burns", "cons": "Breaks"},
	"broom": {"name": "HAUNTED BROOM", "cat": "prop", "arch": "pierce", "dmg": 5, "kb": 260, "speed": 1.0, "reach": 26, "weight": 0.9, "material": "wood", "rarity": "common", "dur": 10, "spawn": 0,
		"desc": "Sweep the competition.", "pros": "Long reach", "cons": "Breaks"},
}

const SETS := {
	"all": "ALL WEAPONS",
	"melee": "MELEE ONLY",
	"ranged": "RANGED + SPECIAL",
	"funny": "FUNNY WEAPONS",
	"classic": "CLASSIC SET",
	"none": "NO WEAPONS (PAWS)",
}

const CLASSIC := ["sword", "spear", "bat", "bow", "pan", "gloves", "dagger", "blaster"]


static func get_def(id: String) -> Dictionary:
	return ALL.get(id, {})


static func spawn_weight(id: String) -> float:
	var d: Dictionary = ALL.get(id, {})
	if d.has("spawn"):
		return float(d.spawn)
	return RARITY_WEIGHT.get(d.get("rarity", "common"), 5.0)


static func in_set(id: String, set_id: String) -> bool:
	var d: Dictionary = ALL.get(id, {})
	if d.is_empty() or d.cat == "prop":
		return false
	match set_id:
		"all": return true
		"melee": return d.cat == "melee"
		"ranged": return d.cat == "ranged" or d.cat == "special"
		"funny": return d.cat == "funny"
		"classic": return id in CLASSIC
		"none": return false
	return true


static func pick_random(set_id: String, rng: RandomNumberGenerator) -> String:
	var ids: Array = []
	var total := 0.0
	for id in ALL.keys():
		if in_set(id, set_id):
			ids.append(id)
			total += spawn_weight(id)
	if ids.is_empty():
		return ""
	var r := rng.randf() * total
	for id in ids:
		r -= spawn_weight(id)
		if r <= 0.0:
			return id
	return ids[-1]


static func throw_damage(d: Dictionary) -> float:
	if d.has("throw_dmg"):
		return float(d.throw_dmg)
	return 5.0 + float(d.get("weight", 1.0)) * 3.5


static func is_ranged(d: Dictionary) -> bool:
	return d.get("arch", "") in ["bow", "gun", "beam", "gravity"]
