class_name ArenaDefs
extends RefCounted
## Arena layouts. Coordinates are world pixels; (0,0) is the top-left of the
## arena's design area (`size`). Fighters falling past the blast zone (size
## grown by `blast`) are KO'd. Add an arena by adding an entry here; the
## builder handles collision, art, spawns, hazards and music.
##
##   solids     Rect2 blocks you cannot pass (top surface walkable)
##   platforms  one-way Rect2 (jump through from below, drop with down+jump)
##   moving     {rect, move: Vector2 offset, period: s} one-way moving platforms
##   ice        indices of solids/platform rects with slippery friction
##   conveyor   {rect, speed} surfaces that carry fighters
##   hazards    {type, ...} see Hazard.gd
##   spawns     fighter spawn points (feet), at least 4
##   items      x positions where weapons drop in
##   powerups   power-up spawn points
##   props      improvised weapon ids that occasionally appear here
##   style      backdrop painter id; theme colours below
##   music      procedural chiptune seed {tempo, root, scale, seed}

const ORDER := ["rooftop", "sushi", "neon", "ship", "frozen", "volcano", "castle", "arcade", "junkyard", "haunted", "space", "garden"]

const ALL := {
	"rooftop": {
		"name": "ROOFTOP RUMBLE", "desc": "Night-time rooftops with a deadly gap and a window-washer lift.",
		"tags": "MOBILITY · PIT", "size": Vector2(640, 360), "blast": Vector2(150, 140), "gravity": 1.0,
		"solids": [Rect2(30, 262, 240, 98), Rect2(372, 252, 238, 108), Rect2(96, 232, 40, 30), Rect2(470, 222, 56, 30)],
		"platforms": [Rect2(160, 212, 64, 6), Rect2(520, 160, 60, 6), Rect2(40, 180, 54, 6)],
		"moving": [{"rect": Rect2(262, 226, 56, 6), "move": Vector2(66, 0), "period": 5.0}],
		"hazards": [{"type": "vent", "rect": Rect2(236, 250, 24, 12), "power": 520}, {"type": "vent", "rect": Rect2(384, 240, 24, 12), "power": 520}],
		"spawns": [Vector2(70, 262), Vector2(570, 252), Vector2(200, 262), Vector2(440, 252), Vector2(116, 232), Vector2(497, 222), Vector2(192, 212), Vector2(550, 160)],
		"items": [80, 200, 300, 440, 560], "powerups": [Vector2(290, 150), Vector2(67, 160)], "props": [],
		"style": "city", "sky": [Color("0d1030"), Color("3a2a6a")], "far": Color("1c1a40"), "mid": Color("2a2650"),
		"ground": [Color("5a5470"), Color("3c3650"), Color("26223a")], "plat": Color("8a7aa0"), "accent": Color("ffd86a"),
		"music": {"tempo": 132, "root": 57, "scale": "minor", "seed": 11},
	},
	"sushi": {
		"name": "SUSHI RESTAURANT", "desc": "Fight over the conveyor belt. Mind the hot stove!",
		"tags": "CLOSE COMBAT · HAZARD", "size": Vector2(640, 360), "blast": Vector2(150, 140), "gravity": 1.0,
		"solids": [Rect2(20, 290, 600, 70), Rect2(560, 250, 60, 40)],
		"platforms": [Rect2(220, 222, 200, 6), Rect2(60, 242, 64, 6), Rect2(450, 242, 64, 6), Rect2(282, 160, 76, 6)],
		"moving": [],
		"conveyor": [{"rect": Rect2(220, 222, 200, 6), "speed": 45.0}],
		"hazards": [{"type": "flame", "rect": Rect2(566, 236, 48, 14), "period": 6.0, "on": 2.0}],
		"spawns": [Vector2(70, 290), Vector2(520, 290), Vector2(200, 290), Vector2(400, 290), Vector2(92, 242), Vector2(482, 242), Vector2(260, 222), Vector2(380, 222)],
		"items": [100, 220, 320, 420, 520], "powerups": [Vector2(320, 140)], "props": ["plate"],
		"style": "restaurant", "sky": [Color("3a1a20"), Color("6a3028")], "far": Color("5a2a24"), "mid": Color("7a3a2a"),
		"ground": [Color("c89060"), Color("8a5a38"), Color("5a3a24")], "plat": Color("d8b080"), "accent": Color("ff5a4a"),
		"music": {"tempo": 118, "root": 62, "scale": "pentatonic", "seed": 23},
	},
	"neon": {
		"name": "NEON DOJO", "desc": "A floating futuristic dojo. Clean edges, glowing signs.",
		"tags": "COMPETITIVE · PLATFORMS", "size": Vector2(640, 360), "blast": Vector2(160, 150), "gravity": 1.0,
		"solids": [Rect2(100, 262, 440, 30)],
		"platforms": [Rect2(150, 202, 90, 6), Rect2(400, 202, 90, 6), Rect2(275, 146, 90, 6)],
		"moving": [{"rect": Rect2(20, 220, 50, 6), "move": Vector2(0, -70), "period": 4.0}, {"rect": Rect2(570, 220, 50, 6), "move": Vector2(0, -70), "period": 4.0}],
		"hazards": [],
		"spawns": [Vector2(140, 262), Vector2(500, 262), Vector2(250, 262), Vector2(390, 262), Vector2(195, 202), Vector2(445, 202), Vector2(320, 146), Vector2(320, 262)],
		"items": [150, 250, 320, 390, 490], "powerups": [Vector2(320, 120)], "props": [],
		"style": "neon", "sky": [Color("08061a"), Color("2a0a40")], "far": Color("1a0a3a"), "mid": Color("2a1050"),
		"ground": [Color("40e0ff"), Color("2a2050"), Color("161030")], "plat": Color("ff4ad0"), "accent": Color("40e0ff"),
		"music": {"tempo": 140, "root": 52, "scale": "minor", "seed": 37},
	},
	"ship": {
		"name": "PIRATE SHIP", "desc": "A swaying deck, a crow's nest and a cranky cannon.",
		"tags": "RANGED · HAZARD · PIT", "size": Vector2(640, 360), "blast": Vector2(150, 140), "gravity": 1.0,
		"solids": [Rect2(60, 272, 520, 40), Rect2(450, 232, 130, 40), Rect2(60, 252, 60, 20)],
		"platforms": [Rect2(272, 136, 56, 6), Rect2(230, 192, 140, 6), Rect2(150, 222, 60, 6)],
		"moving": [],
		"hazards": [{"type": "cannon", "y": 262.0, "period": 9.0, "from_right": true}],
		"spawns": [Vector2(100, 252), Vector2(520, 232), Vector2(220, 272), Vector2(400, 272), Vector2(300, 192), Vector2(180, 222), Vector2(300, 136), Vector2(340, 272)],
		"items": [120, 220, 300, 380, 500], "powerups": [Vector2(300, 110)], "props": [],
		"style": "sea", "sky": [Color("4a8ad0"), Color("a8d8f0")], "far": Color("6aa0c8"), "mid": Color("2a5a90"),
		"ground": [Color("b07040"), Color("7a4a28"), Color("4a2a18")], "plat": Color("c08a50"), "accent": Color("ffe08a"),
		"music": {"tempo": 126, "root": 55, "scale": "dorian", "seed": 41},
	},
	"frozen": {
		"name": "FROZEN LAKE", "desc": "Slippery ice, falling icicles and soft snow banks.",
		"tags": "MOBILITY · ICE", "size": Vector2(640, 360), "blast": Vector2(150, 140), "gravity": 1.0,
		"solids": [Rect2(110, 282, 420, 78), Rect2(20, 252, 92, 108), Rect2(528, 252, 92, 108)],
		"platforms": [Rect2(180, 216, 70, 6), Rect2(390, 216, 70, 6), Rect2(285, 166, 70, 6)],
		"ice": [0, 3, 4, 5], "moving": [],
		"hazards": [{"type": "icicles", "period": 5.0, "x_min": 130.0, "x_max": 510.0}],
		"spawns": [Vector2(60, 252), Vector2(580, 252), Vector2(200, 282), Vector2(440, 282), Vector2(215, 216), Vector2(425, 216), Vector2(320, 166), Vector2(320, 282)],
		"items": [140, 240, 320, 400, 500], "powerups": [Vector2(320, 140)], "props": [],
		"style": "snow", "sky": [Color("8ab0e0"), Color("e0f0ff")], "far": Color("b8d0f0"), "mid": Color("9ab8e0"),
		"ground": [Color("f4fbff"), Color("a8d8f0"), Color("6aa0d0")], "plat": Color("c8f0ff"), "accent": Color("ffffff"),
		"music": {"tempo": 112, "root": 64, "scale": "major", "seed": 53},
	},
	"volcano": {
		"name": "VOLCANO ARENA", "desc": "Lava rises without mercy. Get to high ground!",
		"tags": "HAZARD · SHIFTING SAFE ZONES", "size": Vector2(640, 360), "blast": Vector2(150, 140), "gravity": 1.0,
		"solids": [Rect2(40, 300, 560, 60), Rect2(100, 230, 80, 16), Rect2(460, 230, 80, 16), Rect2(280, 182, 80, 16)],
		"platforms": [Rect2(196, 142, 50, 6), Rect2(394, 142, 50, 6)],
		"moving": [],
		"hazards": [{"type": "lava", "base_y": 330.0, "rise_y": 262.0, "period": 16.0, "warn": 3.0, "hold": 5.0}],
		"spawns": [Vector2(140, 230), Vector2(500, 230), Vector2(320, 182), Vector2(220, 300), Vector2(420, 300), Vector2(80, 300), Vector2(560, 300), Vector2(221, 142)],
		"items": [140, 220, 320, 420, 500], "powerups": [Vector2(320, 150)], "props": [],
		"style": "volcano", "sky": [Color("2a0a0a"), Color("8a2a10")], "far": Color("4a1a14"), "mid": Color("3a1410"),
		"ground": [Color("6a4a40"), Color("3a2826"), Color("221616")], "plat": Color("8a6a5a"), "accent": Color("ff8a2a"),
		"music": {"tempo": 150, "root": 50, "scale": "harmonic", "seed": 67},
	},
	"castle": {
		"name": "CAT CASTLE", "desc": "Towers, battlements and a trapdoor over the moat.",
		"tags": "HAZARD · TOWERS", "size": Vector2(640, 360), "blast": Vector2(150, 140), "gravity": 1.0,
		"solids": [Rect2(20, 290, 248, 70), Rect2(372, 290, 248, 70), Rect2(30, 200, 56, 90), Rect2(554, 200, 56, 90)],
		"platforms": [Rect2(132, 222, 70, 6), Rect2(438, 222, 70, 6), Rect2(285, 170, 70, 6)],
		"moving": [],
		"hazards": [{"type": "trapdoor", "rect": Rect2(268, 290, 104, 10), "period": 12.0, "open": 3.0}],
		"spawns": [Vector2(58, 200), Vector2(582, 200), Vector2(180, 290), Vector2(460, 290), Vector2(167, 222), Vector2(473, 222), Vector2(320, 170), Vector2(320, 290)],
		"items": [140, 240, 320, 400, 500], "powerups": [Vector2(320, 140), Vector2(58, 170)], "props": ["torch"],
		"style": "castle", "sky": [Color("2a3a6a"), Color("e09a7a")], "far": Color("5a5a80"), "mid": Color("4a4a6a"),
		"ground": [Color("a8a0b8"), Color("6a6480"), Color("3a3650")], "plat": Color("8a8098"), "accent": Color("ffb04a"),
		"music": {"tempo": 120, "root": 57, "scale": "dorian", "seed": 79},
	},
	"arcade": {
		"name": "ARCADE ARENA", "desc": "Retro cabinets and a sweeping high-score laser.",
		"tags": "PLATFORMS · HAZARD", "size": Vector2(640, 360), "blast": Vector2(150, 140), "gravity": 1.0,
		"solids": [Rect2(60, 290, 520, 70), Rect2(96, 248, 38, 42), Rect2(506, 248, 38, 42)],
		"platforms": [Rect2(196, 216, 84, 6), Rect2(360, 216, 84, 6), Rect2(270, 160, 100, 6)],
		"moving": [{"rect": Rect2(296, 250, 48, 6), "move": Vector2(0, -60), "period": 3.5}],
		"hazards": [{"type": "laser", "y": 276.0, "period": 11.0, "warn": 1.5, "x_min": 60.0, "x_max": 580.0}],
		"spawns": [Vector2(115, 248), Vector2(525, 248), Vector2(220, 290), Vector2(420, 290), Vector2(238, 216), Vector2(402, 216), Vector2(320, 160), Vector2(320, 290)],
		"items": [150, 240, 320, 400, 490], "powerups": [Vector2(320, 130)], "props": [],
		"style": "arcade", "sky": [Color("100828"), Color("301050")], "far": Color("2a1048"), "mid": Color("3a1a60"),
		"ground": [Color("ff4ad0"), Color("3a2070"), Color("1e1040")], "plat": Color("40e0ff"), "accent": Color("ffe84a"),
		"music": {"tempo": 146, "root": 60, "scale": "major", "seed": 83},
	},
	"junkyard": {
		"name": "JUNKYARD", "desc": "Scrap piles, a wrecked car and a hydraulic crusher.",
		"tags": "CLOSE COMBAT · HAZARD", "size": Vector2(640, 360), "blast": Vector2(150, 140), "gravity": 1.0,
		"solids": [Rect2(30, 278, 170, 82), Rect2(200, 300, 240, 60), Rect2(440, 268, 170, 92), Rect2(250, 262, 92, 38)],
		"platforms": [Rect2(90, 220, 60, 6), Rect2(490, 210, 60, 6)],
		"moving": [{"rect": Rect2(220, 170, 60, 6), "move": Vector2(160, 0), "period": 7.0}],
		"hazards": [{"type": "crusher", "rect": Rect2(360, 120, 60, 24), "floor": 300.0, "period": 10.0, "warn": 1.6}],
		"spawns": [Vector2(70, 278), Vector2(570, 268), Vector2(160, 278), Vector2(480, 268), Vector2(296, 262), Vector2(120, 220), Vector2(520, 210), Vector2(400, 300)],
		"items": [100, 220, 300, 400, 520], "powerups": [Vector2(250, 150)], "props": ["pipe"],
		"style": "junk", "sky": [Color("5a4a3a"), Color("c0a070")], "far": Color("7a6a50"), "mid": Color("5a4a38"),
		"ground": [Color("8a7a6a"), Color("5a4a40"), Color("3a3028")], "plat": Color("9a8a70"), "accent": Color("e0a040"),
		"music": {"tempo": 128, "root": 52, "scale": "blues", "seed": 97},
	},
	"haunted": {
		"name": "HAUNTED MANSION", "desc": "Floating books, a creaky chandelier and grumpy ghosts.",
		"tags": "HAZARD · VERTICAL", "size": Vector2(640, 360), "blast": Vector2(150, 140), "gravity": 1.0,
		"solids": [Rect2(20, 290, 600, 70)],
		"platforms": [Rect2(60, 242, 80, 6), Rect2(140, 200, 80, 6), Rect2(420, 200, 80, 6), Rect2(500, 242, 80, 6), Rect2(280, 140, 80, 6)],
		"moving": [{"rect": Rect2(236, 220, 40, 6), "move": Vector2(0, -50), "period": 5.0}, {"rect": Rect2(364, 170, 40, 6), "move": Vector2(0, 50), "period": 5.0}],
		"hazards": [{"type": "haunt", "period": 8.0}],
		"spawns": [Vector2(70, 290), Vector2(570, 290), Vector2(200, 290), Vector2(440, 290), Vector2(100, 242), Vector2(540, 242), Vector2(180, 200), Vector2(460, 200)],
		"items": [120, 240, 320, 400, 520], "powerups": [Vector2(320, 110)], "props": ["broom"],
		"style": "haunted", "sky": [Color("0a0a18"), Color("2a1a3a")], "far": Color("1a1428"), "mid": Color("2a2038"),
		"ground": [Color("6a5070"), Color("40304a"), Color("241a2a")], "plat": Color("8a6a50"), "accent": Color("9aff9a"),
		"music": {"tempo": 104, "root": 50, "scale": "harmonic", "seed": 101},
	},
	"space": {
		"name": "SPACE STATION", "desc": "Low gravity! Huge jumps, floaty fights, endless void.",
		"tags": "LOW GRAVITY · PIT", "size": Vector2(640, 360), "blast": Vector2(170, 170), "gravity": 0.55,
		"solids": [Rect2(150, 272, 340, 26), Rect2(30, 222, 92, 18), Rect2(518, 222, 92, 18)],
		"platforms": [Rect2(246, 196, 148, 6)],
		"moving": [{"rect": Rect2(150, 140, 52, 6), "move": Vector2(290, 0), "period": 9.0}],
		"hazards": [],
		"spawns": [Vector2(180, 272), Vector2(460, 272), Vector2(76, 222), Vector2(564, 222), Vector2(280, 196), Vector2(360, 196), Vector2(260, 272), Vector2(380, 272)],
		"items": [180, 260, 320, 380, 460], "powerups": [Vector2(320, 110), Vector2(76, 190), Vector2(564, 190)], "props": [],
		"style": "space", "sky": [Color("02020a"), Color("10102a")], "far": Color("2a2a4a"), "mid": Color("3a3a5a"),
		"ground": [Color("c0c8d8"), Color("7a8298"), Color("4a5068")], "plat": Color("6ae0ff"), "accent": Color("ff6a6a"),
		"music": {"tempo": 100, "root": 55, "scale": "lydian", "seed": 113},
	},
	"garden": {
		"name": "GARDEN DOJO", "desc": "Peaceful stones and bamboo. No hazards — pure skill.",
		"tags": "COMPETITIVE · NO HAZARDS", "size": Vector2(640, 360), "blast": Vector2(160, 150), "gravity": 1.0,
		"solids": [Rect2(90, 270, 460, 90)],
		"platforms": [Rect2(150, 210, 80, 6), Rect2(410, 210, 80, 6), Rect2(280, 158, 80, 6)],
		"moving": [],
		"hazards": [],
		"spawns": [Vector2(140, 270), Vector2(500, 270), Vector2(240, 270), Vector2(400, 270), Vector2(190, 210), Vector2(450, 210), Vector2(320, 158), Vector2(320, 270)],
		"items": [150, 250, 320, 390, 490], "powerups": [Vector2(320, 130)], "props": [],
		"style": "garden", "sky": [Color("ffb0a0"), Color("ffe0c0")], "far": Color("e09090"), "mid": Color("6a9a6a"),
		"ground": [Color("7ac060"), Color("6a5a48"), Color("4a3a30")], "plat": Color("a0a090"), "accent": Color("ff7ab0"),
		"music": {"tempo": 96, "root": 62, "scale": "pentatonic", "seed": 127},
	},
}


static func get_def(id: String) -> Dictionary:
	return ALL.get(id, ALL["garden"])
