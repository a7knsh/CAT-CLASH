extends Screen
## Collection: weapon encyclopedia, trophy cabinet, cosmetics shop (spend
## yarn earned by playing — never real money, never gameplay advantages)
## and challenges (daily, training milestones, cat mastery).

const TABS := ["WEAPONS", "TROPHIES", "SHOP", "CHALLENGES"]

var tab := 0
var widx := 0
var weapons: Array = []
var shop: Array = []
var sidx := 0
var aidx := 0
var msg := ""
var msg_t := 0.0


func _build() -> void:
	for id in WeaponDefs.ALL.keys():
		if WeaponDefs.ALL[id].cat != "prop":
			weapons.append(id)
	for id in WeaponDefs.ALL.keys():
		if WeaponDefs.ALL[id].cat == "prop":
			weapons.append(id)
	shop = CosmeticDefs.all_unlockables().filter(func(u): return str(u[2].get("unlock", "")) != "")


func _update(dt: float) -> void:
	msg_t -= dt
	for e in InputHub.menu_events:
		match e.action:
			"tab_l", "tab_r":
				tab = posmod(tab + (-1 if e.action == "tab_l" else 1), TABS.size())
				AudioHub.play("ui_move", -6.0)
			"back":
				AudioHub.play("ui_back")
				Router.goto("main_menu")
				return
			"left", "right", "up", "down":
				_nav(e.action)
			"confirm":
				if tab == 2:
					_buy()


func _nav(a: String) -> void:
	AudioHub.play("ui_move", -10.0)
	match tab:
		0:
			var cols := 8
			match a:
				"left": widx -= 1
				"right": widx += 1
				"up": widx -= cols
				"down": widx += cols
			widx = posmod(widx, weapons.size())
		1:
			var n := AchievementDefs.ALL.size()
			match a:
				"up", "left": aidx -= 1
				"down", "right": aidx += 1
			aidx = posmod(aidx, n)
		2:
			match a:
				"up", "left": sidx -= 1
				"down", "right": sidx += 1
			sidx = posmod(sidx, shop.size())
		3:
			if a in ["left", "right"]:
				tab = posmod(tab + (1 if a == "right" else -1), TABS.size())


func _buy() -> void:
	var u: Array = shop[sidx]
	if SaveData.is_unlocked(u[0], u[1]):
		msg = "ALREADY OWNED"
	elif SaveData.unlock_cost(u[0], u[1]) < 0:
		msg = SaveData.unlock_hint(u[0], u[1])
	elif SaveData.buy(u[0], u[1]):
		msg = "UNLOCKED " + str(u[2].name) + "!"
		AudioHub.play("powerup")
		AudioHub.meow(1.3)
		SaveData.check_achievements()
		SaveData.save()
	else:
		msg = "NOT ENOUGH YARN"
		AudioHub.play("ui_error")
	msg_t = 2.0


func _on_mouse(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var p := get_local_mouse_position()
		for i in TABS.size():
			if Rect2(20 + i * 112, 30, 108, 13).has_point(p):
				tab = i
				return
		if tab == 0:
			for i in weapons.size():
				if _wrect(i).has_point(p):
					widx = i
		elif tab == 2:
			for i in range(_shop_first(), mini(shop.size(), _shop_first() + 14)):
				if Rect2(20, 52 + (i - _shop_first()) * 13, 220, 12).has_point(p):
					if sidx == i:
						_buy()
					sidx = i


func _wrect(i: int) -> Rect2:
	return Rect2(20 + (i % 8) * 28, 52 + (i / 8) * 26, 26, 24)


func _shop_first() -> int:
	return clampi(sidx - 6, 0, maxi(0, shop.size() - 14))


func _paint() -> void:
	UI.title(self, "COLLECTION", 6)
	for i in TABS.size():
		var r := Rect2(20 + i * 112, 30, 108, 13)
		UI.panel(self, r, Pal.UI_PANEL2 if i == tab else Pal.UI_PANEL, Pal.UI_HILITE if i == tab else Pal.UI_EDGE, false)
		PixelFont.draw_text(self, r.position + Vector2(54, 3), TABS[i], Pal.UI_HILITE if i == tab else Pal.UI_DIM, 1, 1)
	UI.icon(self, "yarn", Vector2(436, 8), 1.0)
	PixelFont.draw_text(self, Vector2(472, 9), str(int(SaveData.data.yarn)), Pal.UI_ACCENT, 1, 2)
	match tab:
		0: _paint_weapons()
		1: _paint_trophies()
		2: _paint_shop()
		3: _paint_challenges()
	if msg_t > 0.0:
		PixelFont.draw_text(self, Vector2(240, 246), msg, Pal.UI_HILITE, 1, 1)
	UI.hints(self, "Q/E · LB/RB: TABS · ARROWS: BROWSE · CONFIRM: BUY · ESC/B: BACK")


func _paint_weapons() -> void:
	for i in weapons.size():
		var r := _wrect(i)
		var id: String = weapons[i]
		var d: Dictionary = WeaponDefs.ALL[id]
		var seen: bool = SaveData.data.seen.weapons.has(id)
		var rc: Color = Pal.RARITY_COLORS.get(d.rarity, Color.WHITE)
		draw_rect(r, Color(rc, 0.12) if i != widx else Color(Pal.UI_HILITE, 0.3))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(rc, 0.6))
		var tex := Sprites.weapon_texture(id)
		var sc := minf(1.0, 22.0 / tex.get_width())
		UI.weapon(self, id, r.get_center(), sc, "default", Color.WHITE if seen else Color(0.35, 0.35, 0.45))
	var id2: String = weapons[widx]
	var d2: Dictionary = WeaponDefs.ALL[id2]
	var px := 258.0
	UI.panel(self, Rect2(px - 6, 50, 220, 194))
	PixelFont.draw_text(self, Vector2(px, 56), d2.name, Pal.UI_HILITE, 1)
	PixelFont.draw_text(self, Vector2(px + 208, 56), str(d2.rarity).to_upper(), Pal.RARITY_COLORS.get(d2.rarity, Color.WHITE), 1, 2)
	PixelFont.draw_text(self, Vector2(px, 66), str(d2.cat).to_upper() + " · " + str(d2.arch).to_upper(), Pal.UI_DIM)
	UI.weapon(self, id2, Vector2(px + 104, 92), 2.0)
	var lines := PixelFont.wrap(d2.desc, 204)
	for i in lines.size():
		PixelFont.draw_text(self, Vector2(px, 112 + i * 9), lines[i], Pal.UI_TEXT)
	var bars := [["DAMAGE", float(d2.dmg) / 18.0], ["KNOCKBACK", float(d2.kb) / 480.0], ["SPEED", float(d2.speed) / 1.8], ["REACH", float(d2.reach) / 38.0], ["WEIGHT", float(d2.weight) / 3.0]]
	for i in bars.size():
		var y := 134 + i * 11
		PixelFont.draw_text(self, Vector2(px, y), bars[i][0], Pal.UI_DIM)
		UI.bar(self, Rect2(px + 66, y + 2, 140, 4), bars[i][1], Pal.UI_HILITE)
	var ammo := int(d2.get("ammo", -1))
	PixelFont.draw_text(self, Vector2(px, 192), "AMMO: UNLIMITED" if ammo < 0 else "AMMO: %d" % ammo, Pal.UI_DIM)
	PixelFont.draw_text(self, Vector2(px, 202), "+ " + str(d2.pros).to_upper(), Pal.UI_GOOD)
	PixelFont.draw_text(self, Vector2(px, 212), "- " + str(d2.cons).to_upper(), Pal.UI_BAD)
	var uses := 0
	for pr in SaveData.profiles():
		uses += int(pr.stats.get("weapon_uses", {}).get(id2, 0))
	PixelFont.draw_text(self, Vector2(px, 226), "USED %d TIMES" % uses if SaveData.data.seen.weapons.has(id2) else "NOT YET USED", Pal.UI_DIM)


func _paint_trophies() -> void:
	var ids: Array = AchievementDefs.ALL.keys()
	var first := clampi(aidx - 8, 0, maxi(0, ids.size() - 17))
	for i in range(first, mini(ids.size(), first + 17)):
		var a: Dictionary = AchievementDefs.ALL[ids[i]]
		var got: bool = SaveData.data.achievements.has(ids[i])
		var y := 50 + (i - first) * 11
		if i == aidx:
			draw_rect(Rect2(18, y - 2, 236, 11), Color(Pal.UI_HILITE, 0.2))
		UI.icon(self, "trophy", Vector2(22, y), 1.0, Color.WHITE if got else Color(0.3, 0.3, 0.35))
		PixelFont.draw_text(self, Vector2(32, y), str(a.name), Pal.UI_HILITE if got else Pal.UI_DIM)
	var sel: Dictionary = AchievementDefs.ALL[ids[aidx]]
	var got2: bool = SaveData.data.achievements.has(ids[aidx])
	UI.panel(self, Rect2(262, 50, 200, 120))
	PixelFont.draw_text(self, Vector2(270, 56), str(sel.name), Pal.UI_HILITE)
	var lines := PixelFont.wrap(sel.desc, 184)
	for i in lines.size():
		PixelFont.draw_text(self, Vector2(270, 70 + i * 9), lines[i], Pal.UI_TEXT)
	var prog := SaveData.progress(sel.stat)
	UI.bar(self, Rect2(270, 100, 180, 5), prog / float(sel.target), Pal.UI_GOOD if got2 else Pal.UI_HILITE)
	PixelFont.draw_text(self, Vector2(270, 110), "%d / %d" % [int(minf(prog, sel.target)), int(sel.target)], Pal.UI_DIM)
	PixelFont.draw_text(self, Vector2(270, 122), "REWARD: %d YARN" % int(sel.yarn), Pal.UI_ACCENT)
	var rewards: Array = []
	for u in CosmeticDefs.all_unlockables():
		if str(u[2].get("unlock", "")) == "ach:" + str(ids[aidx]):
			rewards.append(str(u[2].name))
	if not rewards.is_empty():
		PixelFont.draw_text(self, Vector2(270, 134), "UNLOCKS: " + ", ".join(rewards), Pal.UI_GOOD)
	PixelFont.draw_text(self, Vector2(270, 156), "EARNED!" if got2 else "LOCKED", Pal.UI_GOOD if got2 else Pal.UI_DIM)
	var total = SaveData.data.achievements.size()
	PixelFont.draw_text(self, Vector2(362, 184), "%d / %d TROPHIES" % [total, AchievementDefs.ALL.size()], Pal.UI_HILITE, 1, 1)
	for k in mini(total, 30):
		UI.icon(self, "trophy", Vector2(270 + (k % 15) * 12, 198 + (k / 15) * 10), 1.0)


func _paint_shop() -> void:
	var first := _shop_first()
	for i in range(first, mini(shop.size(), first + 14)):
		var u: Array = shop[i]
		var y := 52 + (i - first) * 13
		var owned := SaveData.is_unlocked(u[0], u[1])
		if i == sidx:
			draw_rect(Rect2(18, y - 2, 224, 12), Color(Pal.UI_HILITE, 0.2))
		var cost := SaveData.unlock_cost(u[0], u[1])
		PixelFont.draw_text(self, Vector2(22, y), str(u[2].name), Pal.UI_TEXT if owned else Pal.UI_DIM)
		var right := "OWNED" if owned else ("%d" % cost if cost >= 0 else "TROPHY")
		PixelFont.draw_text(self, Vector2(238, y), right, Pal.UI_GOOD if owned else (Pal.UI_ACCENT if cost >= 0 else Pal.UI_DIM), 1, 2)
	var sel: Array = shop[sidx]
	UI.panel(self, Rect2(262, 50, 200, 160))
	PixelFont.draw_text(self, Vector2(270, 56), str(sel[2].name), Pal.UI_HILITE)
	PixelFont.draw_text(self, Vector2(270, 66), str(sel[0]).replace("_", " ").to_upper(), Pal.UI_DIM)
	# Preview
	var cx := Vector2(362, 120)
	match sel[0]:
		"accessory":
			var s := Sprites.full_skin(CosmeticDefs.ROSTER[0])
			var slot: String = SpriteArt.ACCESSORIES[sel[1]].slot
			s[slot + "_acc"] = sel[1]
			CatPuppet.draw_head(self, cx, s, 4.0)
			if slot in ["neck", "back"]:
				var tex := Sprites.accessory_texture(sel[1])
				draw_set_transform(cx + Vector2(-20, 24), 0.0, Vector2(3, 3))
				draw_texture(tex, Vector2.ZERO)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"weapon_skin":
			UI.weapon(self, "sword", cx, 3.0, sel[1])
		"icon":
			UI.icon(self, sel[1], cx - Vector2(12, 12), 4.0)
		"nameplate":
			var c := Sprites.col(CosmeticDefs.NAMEPLATES[sel[1]].color)
			UI.panel(self, Rect2(cx - Vector2(50, 10), Vector2(100, 20)), c)
			PixelFont.draw_text(self, cx - Vector2(0, 4), "WHISKERS", Pal.UI_TEXT, 1, 1)
		_:
			PixelFont.draw_text(self, cx, "EQUIP IN CAT CREATOR", Pal.UI_DIM, 1, 1)
	var owned2 := SaveData.is_unlocked(sel[0], sel[1])
	var line := "OWNED - EQUIP IN CAT CREATOR" if owned2 else SaveData.unlock_hint(sel[0], sel[1])
	PixelFont.draw_text(self, Vector2(362, 188), line, Pal.UI_GOOD if owned2 else Pal.UI_ACCENT, 1, 1)
	if not owned2 and SaveData.unlock_cost(sel[0], sel[1]) >= 0:
		PixelFont.draw_text(self, Vector2(362, 198), "PRESS CONFIRM TO BUY", Pal.UI_TEXT, 1, 1)
	PixelFont.draw_text(self, Vector2(362, 220), "YARN IS EARNED BY PLAYING", Pal.UI_DIM, 1, 1)
	PixelFont.draw_text(self, Vector2(362, 229), "COSMETICS NEVER AFFECT GAMEPLAY", Pal.UI_DIM, 1, 1)


func _paint_challenges() -> void:
	UI.panel(self, Rect2(16, 50, 220, 90))
	PixelFont.draw_text(self, Vector2(24, 56), "TODAY'S CHALLENGES", Pal.UI_HILITE)
	var y := 70.0
	for it in SaveData.data.daily.get("items", []):
		var prog := SaveData.progress(it.stat) - float(it.start)
		PixelFont.draw_text(self, Vector2(24, y), ("✓ " if it.done else "") + str(it.desc).to_upper(), Pal.UI_GOOD if it.done else Pal.UI_TEXT)
		UI.bar(self, Rect2(24, y + 9, 150, 3), prog / float(it.target), Pal.UI_GOOD if it.done else Pal.UI_HILITE)
		PixelFont.draw_text(self, Vector2(226, y + 6), "+%d" % int(it.yarn), Pal.UI_ACCENT, 1, 2)
		y += 22
	UI.panel(self, Rect2(16, 148, 220, 96))
	PixelFont.draw_text(self, Vector2(24, 154), "TRAINING MILESTONES", Pal.UI_HILITE)
	var ty := 166.0
	for id in AchievementDefs.ALL.keys():
		var a: Dictionary = AchievementDefs.ALL[id]
		if not a.get("training", false):
			continue
		var got: bool = SaveData.data.achievements.has(id)
		PixelFont.draw_text(self, Vector2(24, ty), ("✓ " if got else "· ") + str(a.desc).to_upper().substr(0, 34), Pal.UI_GOOD if got else Pal.UI_TEXT)
		ty += 13
	UI.panel(self, Rect2(246, 50, 218, 194))
	PixelFont.draw_text(self, Vector2(254, 56), "CAT MASTERY", Pal.UI_HILITE)
	var my := 70.0
	var presets := SaveData.all_presets()
	for i in mini(presets.size(), 13):
		var p: Dictionary = presets[i]
		var xp := SaveData.mastery_xp(p.id)
		var lvl := SaveData.mastery_level(p.id)
		var next := (lvl + 1) * (lvl + 1) * 40
		var prev := lvl * lvl * 40
		CatPuppet.draw_head(self, Vector2(260, my + 4), p, 0.75)
		PixelFont.draw_text(self, Vector2(270, my), str(p.name).substr(0, 10), Pal.UI_TEXT)
		PixelFont.draw_text(self, Vector2(458, my), "LV%d %s" % [lvl, SaveData.mastery_title(p.id)], Pal.UI_DIM, 1, 2)
		UI.bar(self, Rect2(270, my + 9, 186, 1), float(xp - prev) / float(maxi(1, next - prev)), Pal.UI_ACCENT)
		my += 13
