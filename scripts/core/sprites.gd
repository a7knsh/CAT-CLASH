class_name Sprites
extends RefCounted
## Runtime pixel-art factory. Converts text grids into outlined textures and
## procedurally paints cat body parts from customization data (fur, pattern,
## ears...). Everything is cached; regenerate only when a skin changes.

static var _cache: Dictionary = {}

const WEAPON_SKINS := {
	"default": {},
	"gold": {"g": Color("fff0a0"), "s": Color("ffd23f"), "d": Color("c08a20"), "b": Color("ffd23f"), "n": Color("a0701a"), "x": Color("806010")},
	"neon": {"g": Color("aaffff"), "s": Color("40e0ff"), "d": Color("2050c0"), "b": Color("ff40c0"), "n": Color("8a2080"), "x": Color("301060")},
	"candy": {"g": Color("ffffff"), "s": Color("ff9ad0"), "d": Color("e05aa0"), "b": Color("fff0f8"), "n": Color("ff7ab0"), "x": Color("c04080")},
	"shadow": {"g": Color("8a7aa8"), "s": Color("4a3a68"), "d": Color("2a1e40"), "b": Color("3a2a50"), "n": Color("201830"), "x": Color("100818")},
	"ice": {"g": Color("ffffff"), "s": Color("c8f0ff"), "d": Color("6ab0e0"), "b": Color("a0d8f0"), "n": Color("5090c0"), "x": Color("305080")},
	"lava": {"g": Color("ffe080"), "s": Color("ff8a2a"), "d": Color("c03020"), "b": Color("5a2a20"), "n": Color("301010"), "x": Color("200808")},
}

const BODY_DIMS := {
	"slim": {"bw": 14, "bh": 7, "hw": 11, "hh": 9, "lw": 2, "r": 3},
	"normal": {"bw": 15, "bh": 8, "hw": 12, "hh": 10, "lw": 3, "r": 3},
	"chonky": {"bw": 18, "bh": 10, "hw": 13, "hh": 10, "lw": 3, "r": 4},
}

const EAR_GRIDS := {
	"pointed": ["..F..", ".FFF.", ".FaF.", "FFaFF"],
	"round": [".FFF.", "FFaFF", "FaaaF"],
	"folded": ["FFFF.", ".FFFF", "..FF."],
	"big": ["..F..", "..F..", ".FaF.", ".FaF.", "FFaFF", "FaaaF"],
	"tufted": [".F...", "..F..", ".FFF.", ".FaF.", "FFaFF"],
	"mouse": [".FFF.", "FaaaF", "FaaaF", "FaaaF", ".FFF."],
}

const TAIL_STYLES := {
	"long": {"segs": 7, "size": 2},
	"short": {"segs": 3, "size": 2},
	"fluffy": {"segs": 6, "size": 3},
	"striped": {"segs": 7, "size": 2},
	"curly": {"segs": 7, "size": 2},
	"thin": {"segs": 9, "size": 1},
}

const DEFAULT_SKIN := {
	"id": "", "name": "WHISKERS", "species": "cat",
	"fur": "e8a050", "fur2": "a8581e", "fur3": "fff4e0",
	"pattern": "tabby", "eye_color": "7ad04a", "eye_shape": "round",
	"ears": "pointed", "tail": "long", "whiskers": "short", "expression": "neutral",
	"body": "normal", "personality": "tailflick",
	"head_acc": "", "face_acc": "", "neck_acc": "", "back_acc": "", "ear_acc": "",
	"weapon_skin": "default", "trail": "none", "victory": "bounce", "entrance": "drop",
	"ko_fx": "ghost", "nameplate": "classic", "icon": "paw", "taunt": "meow",
}


static func full_skin(skin: Dictionary) -> Dictionary:
	var s := DEFAULT_SKIN.duplicate()
	for k in skin.keys():
		s[k] = skin[k]
	return s


static func col(v: Variant) -> Color:
	if v is Color:
		return v
	return Color(str(v))


static func _h(x: float, y: float, salt: float) -> float:
	return fposmod(sin(x * 12.9898 + y * 78.233 + salt * 37.719) * 43758.5453, 1.0)


static func _add_outline(img: Image, outline: Color = Pal.OUTLINE) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var marks: Array = []
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + o.x
				var ny: int = y + o.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and img.get_pixel(nx, ny).a > 0.5:
					marks.append(Vector2i(x, y))
					break
	for m in marks:
		img.set_pixelv(m, outline)


## Build (or fetch) an outlined texture from a text grid.
static func grid_texture(key: String, grid: Array, remap: Dictionary = {}, outline: bool = true, palette: Dictionary = SpriteArt.PALETTE) -> ImageTexture:
	var ck := "grid:" + key
	if _cache.has(ck):
		return _cache[ck]
	var gw := 0
	for row in grid:
		gw = maxi(gw, str(row).length())
	var gh := grid.size()
	var pad := 1 if outline else 0
	var img := Image.create(gw + pad * 2, gh + pad * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in gh:
		var row: String = grid[y]
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			var c: Color = remap.get(ch, palette.get(ch, Color.MAGENTA))
			img.set_pixel(x + pad, y + pad, c)
	if outline:
		_add_outline(img)
	var tex := ImageTexture.create_from_image(img)
	_cache[ck] = tex
	return tex


static func weapon_texture(id: String, skin: String = "default") -> ImageTexture:
	var art: Dictionary = SpriteArt.WEAPONS.get(id, SpriteArt.WEAPONS["stick"])
	var remap: Dictionary = WEAPON_SKINS.get(skin, {})
	if skin == "rainbow":
		remap = {}
		var hues := ["r", "o", "y", "e", "u", "v"]
		var i := 0
		for k in ["g", "s", "d", "b", "n"]:
			remap[k] = SpriteArt.PALETTE[hues[i % hues.size()]]
			i += 1
	return grid_texture("w:%s:%s" % [id, skin], art.grid, remap)


static func weapon_grip(id: String) -> Vector2:
	var art: Dictionary = SpriteArt.WEAPONS.get(id, SpriteArt.WEAPONS["stick"])
	return art.grip + Vector2(1, 1)


static func weapon_length(id: String) -> float:
	var art: Dictionary = SpriteArt.WEAPONS.get(id, SpriteArt.WEAPONS["stick"])
	var gw := 0
	for row in art.grid:
		gw = maxi(gw, str(row).length())
	return float(gw) - art.grip.x


static func accessory_texture(id: String) -> ImageTexture:
	if not SpriteArt.ACCESSORIES.has(id):
		return null
	return grid_texture("acc:" + id, SpriteArt.ACCESSORIES[id].grid)


static func icon_texture(id: String) -> ImageTexture:
	if not SpriteArt.ICONS.has(id):
		return null
	return grid_texture("icon:" + id, SpriteArt.ICONS[id].grid)


# ------------------------------------------------------------------ cats

static func _skin_key(s: Dictionary) -> String:
	return "%s|%s|%s|%s|%s|%s|%s|%s" % [s.fur, s.fur2, s.fur3, s.pattern, s.ears, s.tail, s.body, s.species]


## Colour of a fur pixel for `part` at local (x, y) inside a w x h region.
static func fur_color(s: Dictionary, part: String, x: int, y: int, w: int, h: int) -> Color:
	var fur := col(s.fur)
	var fur2 := col(s.fur2)
	var fur3 := col(s.fur3)
	var c := fur
	var salt := float(part.hash() % 97)
	var chest := part == "body" and x >= int(w * 0.6) and y >= int(h * 0.35)
	var belly := part == "body" and y >= h - 2 and x >= int(w * 0.3)
	var muzzle := part == "head" and x >= w - 5 and y >= h - 4
	var paw := part == "leg" and y >= h - 1
	match str(s.pattern):
		"tabby":
			if part == "body" and (x + y / 3) % 4 == 0 and not belly:
				c = fur2
			elif part == "head" and y <= 2 and x in [3, 5, 7] and not muzzle:
				c = fur2
			elif part == "head" and y == h - 5 and x <= 2:
				c = fur2
			elif part == "leg" and y % 2 == 1 and not paw:
				c = fur2
			elif part == "tail" and x % 2 == 1:
				c = fur2
		"spots":
			if not muzzle and _h(floor(x / 2.0), floor(y / 2.0), salt) < 0.28:
				c = fur2
		"tuxedo":
			if chest or belly or muzzle or paw:
				c = fur2
			elif part == "tail" and x == 0:
				c = fur2
		"calico":
			var r := _h(floor(x / 3.0), floor(y / 3.0), salt + 3.0)
			if r < 0.33:
				c = fur
			elif r < 0.6:
				c = fur2
			else:
				c = fur3
			if muzzle or paw:
				c = fur3
		"siamese":
			c = fur
			if part == "ear" or part == "tail" or (part == "leg" and y >= h - 3):
				c = fur2
			elif part == "head" and x >= w - 6 and y >= 3:
				c = fur.lerp(fur2, 0.75)
			elif part == "body" and x < 3:
				c = fur.lerp(fur2, 0.35)
		"white_paws":
			if paw or (part == "leg" and y >= h - 2):
				c = fur3
			if muzzle:
				c = fur3
		"chest_patch":
			if chest or muzzle:
				c = fur3
		"points":
			# Two-tone: darker back, lighter underside.
			if part == "body" and y <= 2:
				c = fur2
			elif part == "head" and y <= 1:
				c = fur2
		_:
			pass
	# Gentle shading for volume.
	if part == "body":
		if y == 0:
			c = c.lightened(0.1)
		elif y == h - 1:
			c = c.darkened(0.15)
		if belly and str(s.pattern) in ["solid", "tabby", "spots", "points"]:
			c = c.lightened(0.18)
	elif part == "head":
		if muzzle and str(s.pattern) in ["solid", "tabby", "spots", "points", "siamese"]:
			c = c.lightened(0.2)
		if y == 0:
			c = c.lightened(0.08)
	elif part == "leg" and y == 0:
		c = c.darkened(0.08)
	return c


static func _rr(x: int, y: int, w: int, h: int, r: float) -> bool:
	var p := Vector2(x + 0.5, y + 0.5)
	var cx := clampf(p.x, r, w - r)
	var cy := clampf(p.y, r, h - r)
	return p.distance_to(Vector2(cx, cy)) <= r + 0.05


static func cat_parts(skin: Dictionary) -> Dictionary:
	var s := full_skin(skin)
	var key := "cat:" + _skin_key(s)
	if _cache.has(key):
		return _cache[key]
	var dims: Dictionary = BODY_DIMS.get(str(s.body), BODY_DIMS["normal"])
	var bw: int = dims.bw
	var bh: int = dims.bh
	var hw: int = dims.hw
	var hh: int = dims.hh
	var lw: int = dims.lw
	var rad: float = dims.r
	# Very dark cats get a lighter outline so their silhouette stays readable.
	var line := Pal.OUTLINE
	if col(s.fur).get_luminance() < 0.12:
		line = Color("6a5a80")
	# Body
	var body := Image.create(bw + 2, bh + 2, false, Image.FORMAT_RGBA8)
	body.fill(Color(0, 0, 0, 0))
	for y in bh:
		for x in bw:
			if _rr(x, y, bw, bh, rad):
				body.set_pixel(x + 1, y + 1, fur_color(s, "body", x, y, bw, bh))
	_add_outline(body, line)
	# Head (rounded with slightly fuller cheeks)
	var head := Image.create(hw + 2, hh + 2, false, Image.FORMAT_RGBA8)
	head.fill(Color(0, 0, 0, 0))
	for y in hh:
		for x in hw:
			if _rr(x, y, hw, hh, 3.2):
				head.set_pixel(x + 1, y + 1, fur_color(s, "head", x, y, hw, hh))
	# Nose
	if str(s.species) == "mouse":
		head.set_pixel(hw, hh - 3, Color("ff5a8a"))
		head.set_pixel(hw - 1, hh - 3, Color("ff5a8a"))
	else:
		head.set_pixel(hw, hh - 4 + 1, Color("ff8aa8"))
	_add_outline(head, line)
	# Leg
	var lh := 4
	var leg := Image.create(lw + 2, lh + 2, false, Image.FORMAT_RGBA8)
	leg.fill(Color(0, 0, 0, 0))
	for y in lh:
		for x in lw:
			leg.set_pixel(x + 1, y + 1, fur_color(s, "leg", x, y, lw, lh))
	_add_outline(leg, line)
	# Ear
	var eg: Array = EAR_GRIDS.get(str(s.ears), EAR_GRIDS["pointed"])
	var ew := 0
	for row in eg:
		ew = maxi(ew, str(row).length())
	var ear := Image.create(ew + 2, eg.size() + 2, false, Image.FORMAT_RGBA8)
	ear.fill(Color(0, 0, 0, 0))
	for y in eg.size():
		var row: String = eg[y]
		for x in row.length():
			if row[x] == "F":
				ear.set_pixel(x + 1, y + 1, fur_color(s, "ear", x, y, ew, eg.size()))
			elif row[x] == "a":
				ear.set_pixel(x + 1, y + 1, Color("ffb0c8") if str(s.pattern) != "siamese" else col(s.fur2).lightened(0.25))
	_add_outline(ear, line)
	# Tail colours per segment
	var ts: Dictionary = TAIL_STYLES.get(str(s.tail), TAIL_STYLES["long"])
	var tail_cols: Array = []
	for i in int(ts.segs):
		var tc := fur_color(s, "tail", i, 0, int(ts.segs), 1)
		if str(s.tail) == "striped":
			tc = col(s.fur2) if i % 2 == 1 else col(s.fur)
		if str(s.species) == "mouse":
			tc = Color("ff9ab8")
		if i == int(ts.segs) - 1 and str(s.pattern) == "tuxedo":
			tc = col(s.fur2)
		tail_cols.append(tc)
	var res := {
		"body": ImageTexture.create_from_image(body),
		"head": ImageTexture.create_from_image(head),
		"leg": ImageTexture.create_from_image(leg),
		"ear": ImageTexture.create_from_image(ear),
		"bw": bw, "bh": bh, "hw": hw, "hh": hh, "lw": lw,
		"ear_w": ew, "ear_h": eg.size(),
		"tail_cols": tail_cols, "tail_size": int(ts.size), "tail_segs": int(ts.segs),
	}
	_cache[key] = res
	return res


static func clear_cache() -> void:
	_cache.clear()
