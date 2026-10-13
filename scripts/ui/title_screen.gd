extends Screen
## Animated title: rooftop night scene, bouncing pixel logo, two cats
## sparring in the background. Any button continues.

var cats: Array = []
var stars: Array = []
var _rng := RandomNumberGenerator.new()


func _build() -> void:
	_rng.randomize()
	for i in 60:
		stars.append(Vector2(_rng.randf_range(0, 480), _rng.randf_range(0, 150)))
	var roster: Array = CosmeticDefs.ROSTER
	var a := CatPuppet.new()
	a.skin = Sprites.full_skin(roster[0])
	a.preview_state = "attack"
	a.preview_weapon = "sword"
	a.preview_facing = 1
	a.position = Vector2(180, 222)
	a.scale = Vector2(2, 2)
	add_child(a)
	var b := CatPuppet.new()
	b.skin = Sprites.full_skin(roster[1])
	b.preview_state = "block"
	b.preview_weapon = "pan"
	b.preview_facing = -1
	b.position = Vector2(300, 222)
	b.scale = Vector2(2, 2)
	add_child(b)
	cats = [a, b]
	AudioHub.play_music("menu", {"tempo": 128, "root": 60, "scale": "major", "seed": 7})


func _update(_dt: float) -> void:
	# Swap the cats' moves now and then for a little choreography.
	var cyc := fmod(t, 4.0)
	cats[0].preview_state = "attack" if cyc < 2.0 else "idle"
	cats[1].preview_state = "block" if cyc < 2.0 else "attack"
	cats[1].preview_weapon = "pan"
	for e in InputHub.menu_events:
		if e.action in ["confirm", "start", "alt", "back"]:
			_continue()
			return


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		_continue()


func _continue() -> void:
	AudioHub.play("ui_select")
	AudioHub.meow(1.1)
	Router.goto("main_menu")


func _draw() -> void:
	# Night sky
	for i in 10:
		draw_rect(Rect2(0, i * 27, 480, 28), Color("0d1030").lerp(Color("4a2a6a"), i / 9.0))
	for s in stars:
		var tw := 0.5 + 0.5 * sin(t * 2.0 + s.x)
		draw_rect(Rect2(s, Vector2(1, 1)), Color(1, 1, 1, tw))
	draw_circle(Vector2(400, 50), 20, Color("fff4c0"))
	draw_circle(Vector2(393, 45), 18, Color("1a1840"))
	# Skyline
	var x := -20.0
	var i := 0
	while x < 500:
		var w := 26.0 + float((i * 37) % 30)
		var h := 50.0 + float((i * 53) % 70)
		draw_rect(Rect2(x - fmod(t * 6.0, 1.0), 230 - h, w, h + 40), Color("1c1a40"))
		for wy in range(int(240 - h), 225, 8):
			for wx in range(int(x + 4), int(x + w - 4), 7):
				if ((wx * 7 + wy * 13) % 5) == 0:
					draw_rect(Rect2(wx, wy, 2, 2), Color("ffd86a").darkened(0.3))
		x += w + 4
		i += 1
	# Rooftop
	draw_rect(Rect2(0, 222, 480, 48), Color("3c3650"))
	draw_rect(Rect2(0, 222, 480, 3), Color("5a5470"))
	for bx in range(0, 480, 8):
		draw_rect(Rect2(bx, 228 + (bx / 8 % 2) * 4, 7, 3), Color("34304a"))
	# Logo
	var title := "CAT CLASH"
	var lx := 240.0 - PixelFont.text_width(title, 4) * 0.5
	for k in title.length():
		var ch := title[k]
		var bounce := sin(t * 4.0 + k * 0.5) * 3.0
		var col := Color("ffd84a") if k < 3 else Color("ff7ab8")
		PixelFont.draw_text(self, Vector2(lx + k * 24, 40 + bounce), ch, col, 4, 0, true, Color("2a1030"))
	PixelFont.draw_text(self, Vector2(240, 80), "ULTIMATE ARENA", Color("6ae0ff"), 2, 1, true, Color("10203a"))
	# Paw underline
	for k in 7:
		UI.icon(self, "paw", Vector2(198 + k * 12, 98), 1.0, Color(1, 1, 1, 0.6))
	if int(t * 2.0) % 2 == 0:
		PixelFont.draw_text(self, Vector2(240, 150), "PRESS ANY BUTTON", Pal.UI_TEXT, 1, 1)
	PixelFont.draw_text(self, Vector2(476, 260), "V" + str(ProjectSettings.get_setting("application/config/version")), Pal.UI_DIM, 1, 2)
	PixelFont.draw_text(self, Vector2(4, 260), "1-4 PLAYERS · KEYBOARD + GAMEPADS", Pal.UI_DIM)
	if SaveData.load_status == "recovered":
		PixelFont.draw_text(self, Vector2(240, 166), "SAVE RESTORED FROM BACKUP", Pal.UI_BAD, 1, 1)
	elif SaveData.load_status == "reset":
		PixelFont.draw_text(self, Vector2(240, 166), "SAVE WAS UNREADABLE - STARTED FRESH", Pal.UI_BAD, 1, 1)
