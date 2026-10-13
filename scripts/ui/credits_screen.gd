extends Screen
## Scrolling credits.

const LINES := [
	["CAT CLASH: ULTIMATE ARENA", 2, "hi"],
	["", 1, ""],
	["A LOCAL MULTIPLAYER CAT BRAWLER", 1, ""],
	["", 1, ""],
	["DESIGN, CODE, PIXEL ART & AUDIO", 1, "dim"],
	["CAT CLASH DEVELOPMENT TEAM", 1, ""],
	["(BUILT WITH CLAUDE CODE)", 1, ""],
	["", 1, ""],
	["ENGINE", 1, "dim"],
	["GODOT ENGINE 4 (MIT LICENSE)", 1, ""],
	["GODOTENGINE.ORG", 1, ""],
	["", 1, ""],
	["ART", 1, "dim"],
	["ALL SPRITES ARE GENERATED IN CODE AT RUNTIME", 1, ""],
	["FROM TEXT PIXEL GRIDS AND PROCEDURAL PAINTERS", 1, ""],
	["", 1, ""],
	["AUDIO", 1, "dim"],
	["EVERY SOUND AND SONG IS SYNTHESIZED LIVE", 1, ""],
	["", 1, ""],
	["FONT", 1, "dim"],
	["ORIGINAL 5X7 PIXEL FONT", 1, ""],
	["", 1, ""],
	["SPECIAL THANKS", 1, "dim"],
	["EVERY CAT THAT EVER KNOCKED A GLASS OFF A TABLE", 1, ""],
	["", 1, ""],
	["NO CATS WERE HARMED.", 1, ""],
	["THEY WERE, HOWEVER, MILDLY INCONVENIENCED.", 1, ""],
	["", 1, ""],
	["THANKS FOR PLAYING! ♥", 2, "hi"],
]

var scroll := 0.0
var cats: Array = []


func _build() -> void:
	for i in 3:
		var p := CatPuppet.new()
		p.skin = Sprites.full_skin(CosmeticDefs.ROSTER[(i * 4) % CosmeticDefs.ROSTER.size()])
		p.preview_state = "run"
		p.scale = Vector2(2, 2)
		p.position = Vector2(-40 - i * 40, 250)
		add_child(p)
		cats.append(p)


func _update(dt: float) -> void:
	scroll += dt * 18.0
	for c in cats:
		c.position.x += 70.0 * dt
		if c.position.x > 520:
			c.position.x = -40
	for e in InputHub.menu_events:
		if e.action in ["back", "confirm", "start"]:
			Router.goto("main_menu")
			return


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		Router.goto("main_menu")


func _paint() -> void:
	var y := 270.0 - scroll
	for l in LINES:
		var c := Pal.UI_TEXT
		if l[2] == "hi":
			c = Pal.UI_HILITE
		elif l[2] == "dim":
			c = Pal.UI_DIM
		if y > -20 and y < 280:
			PixelFont.draw_text(self, Vector2(240, y), l[0], c, l[1], 1)
		y += 9 * l[1] + 4
	if y < 0:
		scroll = 0.0
