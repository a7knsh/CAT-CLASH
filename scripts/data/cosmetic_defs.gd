class_name CosmeticDefs
extends RefCounted
## Every customization option. Cosmetics NEVER change hitboxes or stats.
## `unlock` values:  "" (always owned) | "yarn:N" (buy with yarn earned by
## playing) | "ach:ID" (reward for an achievement).

const FUR_COLORS := [
	"f4f0ea", "e8d8c0", "d8b080", "e8a050", "c87830", "a8581e", "7a4a2a", "4a3028",
	"2a2228", "151218", "8a8a92", "b8b8c4", "5a5a68", "e0c8a8", "f0e0d0", "c09070",
	"6a6a80", "9a7a5a", "ffd8a8", "ff9a6a", "c0b0e0", "a0d8f0", "ffb0d0", "8ad0a0",
]
const EYE_COLORS := ["7ad04a", "f0c030", "4ab0f0", "ff8a2a", "a060ff", "30d0b0", "ff5a6a", "e0e0e0", "6a4020", "40f080"]

const PATTERNS := {
	"solid": "SOLID", "tabby": "TABBY STRIPES", "spots": "SPOTS", "tuxedo": "TUXEDO",
	"calico": "CALICO", "siamese": "SIAMESE POINTS", "white_paws": "WHITE PAWS",
	"chest_patch": "CHEST PATCH", "points": "TWO-TONE",
}
const EYE_SHAPES := {"round": "ROUND", "big": "BIG & SHINY", "sleepy": "SLEEPY", "angry": "FIERCE", "slit": "SLIT PUPILS"}
const EARS := {"pointed": "POINTED", "round": "ROUNDED", "folded": "FOLDED", "big": "BIG", "tufted": "LYNX TUFTS"}
const TAILS := {"long": "LONG", "short": "BOBTAIL", "fluffy": "FLUFFY", "striped": "STRIPED", "curly": "CURLY"}
const WHISKERS := {"short": "SHORT", "long": "LONG", "curly": "CURLY", "none": "NONE"}
const EXPRESSIONS := {"neutral": "NEUTRAL", "happy": "HAPPY", "smug": "SMUG", "fierce": "FIERCE"}
const BODIES := {"slim": "SLIM", "normal": "NORMAL", "chonky": "CHONKY"}
const PERSONALITIES := {"tailflick": "TAIL FLICKER", "groom": "GROOMER", "loaf": "LOAF LOVER", "bounce": "BOUNCY", "stretch": "STRETCHER", "yawn": "SLEEPYHEAD"}

## Accessory catalogue: id -> {name, slot, unlock}
const ACCESSORIES := {
	"top_hat": {"name": "TOP HAT", "unlock": ""},
	"cap": {"name": "BALL CAP", "unlock": ""},
	"crown": {"name": "CROWN", "unlock": "ach:first_win"},
	"viking": {"name": "VIKING HELMET", "unlock": "yarn:120"},
	"santa_hat": {"name": "FESTIVE HAT", "unlock": "yarn:80"},
	"wizard_hat": {"name": "WIZARD HAT", "unlock": "ach:magic_user"},
	"headphones": {"name": "HEADPHONES", "unlock": ""},
	"bandana": {"name": "HEAD BANDANA", "unlock": ""},
	"flower_crown": {"name": "FLOWER CROWN", "unlock": "yarn:60"},
	"pumpkin": {"name": "PUMPKIN HEAD", "unlock": "yarn:150"},
	"propeller": {"name": "PROPELLER CAP", "unlock": "ach:air_time"},
	"chef_hat": {"name": "CHEF HAT", "unlock": "ach:sushi_master"},
	"sunglasses": {"name": "SUNGLASSES", "unlock": ""},
	"eyepatch": {"name": "EYEPATCH", "unlock": "ach:pirate"},
	"ninja_mask": {"name": "NINJA MASK", "unlock": "yarn:100"},
	"goggles": {"name": "GOGGLES", "unlock": ""},
	"monocle": {"name": "MONOCLE", "unlock": "yarn:90"},
	"clown_nose": {"name": "CLOWN NOSE", "unlock": "ach:silly"},
	"scarf": {"name": "SCARF", "unlock": ""},
	"collar": {"name": "COLLAR", "unlock": ""},
	"bell_collar": {"name": "BELL COLLAR", "unlock": ""},
	"neck_bandana": {"name": "NECK BANDANA", "unlock": "yarn:40"},
	"bowtie": {"name": "BOW TIE", "unlock": "yarn:50"},
	"cape": {"name": "HERO CAPE", "unlock": "ach:ten_wins"},
	"wings": {"name": "ANGEL WINGS", "unlock": "yarn:200"},
	"bat_wings": {"name": "BAT WINGS", "unlock": "ach:haunted"},
	"backpack": {"name": "BACKPACK", "unlock": ""},
	"armor": {"name": "KNIGHT ARMOR", "unlock": "ach:parry_master"},
	"jetpack": {"name": "JETPACK", "unlock": "ach:boss_slayer"},
	"earring": {"name": "EARRING", "unlock": ""},
	"ear_bow": {"name": "EAR BOW", "unlock": "yarn:40"},
	"antenna": {"name": "ROBO ANTENNA", "unlock": "ach:survivor"},
}

const WEAPON_SKINS := {
	"default": {"name": "STANDARD", "unlock": ""},
	"gold": {"name": "GOLDEN", "unlock": "ach:champion"},
	"neon": {"name": "NEON", "unlock": "yarn:150"},
	"candy": {"name": "CANDY", "unlock": "yarn:100"},
	"shadow": {"name": "SHADOW", "unlock": "ach:ko_100"},
	"ice": {"name": "FROST", "unlock": "yarn:120"},
	"lava": {"name": "MAGMA", "unlock": "ach:volcano"},
	"rainbow": {"name": "RAINBOW", "unlock": "ach:collector"},
}
const TRAILS := {
	"none": {"name": "NONE", "unlock": ""},
	"white": {"name": "SWOOSH", "unlock": ""},
	"fire": {"name": "FLAME", "unlock": "yarn:120"},
	"rainbow": {"name": "RAINBOW", "unlock": "ach:combo_master"},
	"sparkle": {"name": "SPARKLE", "unlock": "yarn:80"},
	"bubbles": {"name": "BUBBLES", "unlock": "yarn:60"},
	"shadow": {"name": "SHADOW", "unlock": "ach:ko_25"},
}
const VICTORY_POSES := {
	"bounce": {"name": "HAPPY BOUNCE", "unlock": ""},
	"flex": {"name": "FLEX", "unlock": ""},
	"spin": {"name": "TWIRL", "unlock": "yarn:60"},
	"sit": {"name": "DIGNIFIED SIT", "unlock": ""},
	"dance": {"name": "DANCE", "unlock": "ach:five_wins"},
	"wave": {"name": "WAVE", "unlock": "yarn:40"},
}
const ENTRANCES := {
	"drop": {"name": "DROP IN", "unlock": ""},
	"teleport": {"name": "TELEPORT", "unlock": "yarn:100"},
	"box": {"name": "CARDBOARD BOX", "unlock": "ach:first_match"},
	"smoke": {"name": "NINJA SMOKE", "unlock": "yarn:80"},
}
const KO_EFFECTS := {
	"ghost": {"name": "LITTLE GHOST", "unlock": ""},
	"stars": {"name": "SEEING STARS", "unlock": ""},
	"fishbone": {"name": "FISH BONES", "unlock": "yarn:60"},
	"confetti": {"name": "CONFETTI", "unlock": "ach:ko_25"},
	"poof": {"name": "POOF", "unlock": "yarn:40"},
}
const NAMEPLATES := {
	"classic": {"name": "CLASSIC", "unlock": "", "color": "2a2147"},
	"gold": {"name": "GOLD", "unlock": "ach:champion", "color": "8a6a10"},
	"neon": {"name": "NEON", "unlock": "yarn:80", "color": "6a1a8a"},
	"forest": {"name": "FOREST", "unlock": "yarn:40", "color": "1a5a3a"},
	"ocean": {"name": "OCEAN", "unlock": "", "color": "1a3a7a"},
	"cherry": {"name": "CHERRY", "unlock": "yarn:40", "color": "8a1a3a"},
}
const ICONS := {
	"paw": {"name": "PAW", "unlock": ""}, "fish": {"name": "FISH", "unlock": ""}, "yarn": {"name": "YARN", "unlock": ""},
	"crown": {"name": "CROWN", "unlock": "ach:first_win"}, "trophy": {"name": "TROPHY", "unlock": "ach:champion"},
	"skull": {"name": "SKULL", "unlock": "ach:ko_25"}, "star": {"name": "STAR", "unlock": "yarn:30"}, "heart": {"name": "HEART", "unlock": ""},
}
const TAUNTS := {
	"meow": {"name": "MEOW", "unlock": ""}, "hiss": {"name": "HISS", "unlock": ""},
	"lick": {"name": "PAW LICK", "unlock": ""}, "loaf": {"name": "LOAF", "unlock": "yarn:30"},
}

## Starter roster. Players can duplicate and edit these in the Cat Creator.
const ROSTER := [
	{"id": "whiskers", "name": "WHISKERS", "fur": "e8a050", "fur2": "a8581e", "fur3": "fff4e0", "pattern": "tabby", "eye_color": "7ad04a", "ears": "pointed", "tail": "striped", "body": "normal", "personality": "tailflick", "neck_acc": "bell_collar"},
	{"id": "sir_pounce", "name": "SIR POUNCE", "fur": "1e1a22", "fur2": "f4f0ea", "fur3": "f4f0ea", "pattern": "tuxedo", "eye_color": "f0c030", "ears": "pointed", "tail": "long", "body": "normal", "personality": "stretch", "neck_acc": "bowtie", "face_acc": "monocle"},
	{"id": "mochi", "name": "MOCHI", "fur": "e88a3a", "fur2": "2a2228", "fur3": "fff4e8", "pattern": "calico", "eye_color": "4ab0f0", "ears": "round", "tail": "fluffy", "body": "chonky", "personality": "loaf", "head_acc": "flower_crown"},
	{"id": "saffron", "name": "SAFFRON", "fur": "f0e0c8", "fur2": "4a3028", "fur3": "fff8f0", "pattern": "siamese", "eye_color": "4ab0f0", "eye_shape": "big", "ears": "big", "tail": "long", "body": "slim", "personality": "groom", "ear_acc": "earring"},
	{"id": "shadow", "name": "SHADOW", "fur": "1a161e", "fur2": "2e2834", "fur3": "3a3440", "pattern": "solid", "eye_color": "40f080", "eye_shape": "slit", "ears": "pointed", "tail": "long", "body": "slim", "personality": "tailflick", "face_acc": "ninja_mask"},
	{"id": "biscuit", "name": "BISCUIT", "fur": "f0a860", "fur2": "c87830", "fur3": "fff0d8", "pattern": "chest_patch", "eye_color": "f0c030", "ears": "round", "tail": "short", "body": "chonky", "personality": "bounce", "head_acc": "cap"},
	{"id": "meatball", "name": "MEATBALL", "fur": "8a8a96", "fur2": "5a5a68", "fur3": "e8e8f0", "pattern": "white_paws", "eye_color": "ff8a2a", "ears": "folded", "tail": "fluffy", "body": "chonky", "personality": "yawn", "neck_acc": "scarf"},
	{"id": "noodle", "name": "NOODLE", "fur": "f4ece4", "fur2": "e0b8b0", "fur3": "ffffff", "pattern": "points", "eye_color": "a060ff", "eye_shape": "big", "ears": "big", "tail": "long", "body": "slim", "personality": "bounce", "head_acc": "headphones"},
	{"id": "thor", "name": "THOR", "fur": "7a5a40", "fur2": "3a2a20", "fur3": "e8d8c0", "pattern": "tabby", "eye_color": "f0c030", "ears": "tufted", "tail": "fluffy", "body": "chonky", "personality": "stretch", "head_acc": "viking"},
	{"id": "ziggy", "name": "ZIGGY", "fur": "e0b060", "fur2": "4a3020", "fur3": "fff0d0", "pattern": "spots", "eye_color": "30d0b0", "ears": "pointed", "tail": "striped", "body": "slim", "personality": "bounce", "face_acc": "goggles"},
	{"id": "dumpling", "name": "DUMPLING", "fur": "c8c0d0", "fur2": "8a80a0", "fur3": "fff8ff", "pattern": "solid", "eye_color": "f0c030", "eye_shape": "big", "ears": "folded", "tail": "short", "body": "normal", "personality": "loaf", "ear_acc": "ear_bow"},
	{"id": "duchess", "name": "DUCHESS", "fur": "f8f4f0", "fur2": "d8c8c0", "fur3": "ffffff", "pattern": "solid", "eye_color": "4ab0f0", "eye_shape": "sleepy", "ears": "round", "tail": "fluffy", "body": "normal", "personality": "groom", "head_acc": "crown", "expression": "smug"},
]

## Enemy skins used by Survival and Boss modes.
const ENEMY_MOUSE := {"id": "_mouse", "name": "MECHA-MOUSE", "species": "mouse", "fur": "9aa0b0", "fur2": "5a6070", "fur3": "c8ccd8", "pattern": "points", "eye_color": "ff3a3a", "eye_shape": "angry", "ears": "mouse", "tail": "long", "body": "slim", "head_acc": "antenna", "expression": "fierce"}
const ENEMY_FERAL := {"id": "_feral", "name": "ALLEY CAT", "fur": "6a5a50", "fur2": "3a302a", "fur3": "9a8a7a", "pattern": "tabby", "eye_color": "ff5a6a", "eye_shape": "angry", "ears": "pointed", "tail": "short", "body": "normal", "face_acc": "eyepatch", "expression": "fierce"}


## Catalogue lookup for a category name used by the creator & collection.
static func category(cat: String) -> Dictionary:
	match cat:
		"accessory": return ACCESSORIES
		"weapon_skin": return WEAPON_SKINS
		"trail": return TRAILS
		"victory": return VICTORY_POSES
		"entrance": return ENTRANCES
		"ko_fx": return KO_EFFECTS
		"nameplate": return NAMEPLATES
		"icon": return ICONS
		"taunt": return TAUNTS
	return {}


static func accessories_for_slot(slot: String) -> Array:
	var out: Array = []
	for id in ACCESSORIES.keys():
		if SpriteArt.ACCESSORIES.has(id) and SpriteArt.ACCESSORIES[id].slot == slot:
			out.append(id)
	return out


## Every unlockable as [category, id, def] for the collection/shop screens.
static func all_unlockables() -> Array:
	var out: Array = []
	for cat in ["accessory", "weapon_skin", "trail", "victory", "entrance", "ko_fx", "nameplate", "icon", "taunt"]:
		var d := category(cat)
		for id in d.keys():
			out.append([cat, id, d[id]])
	return out
