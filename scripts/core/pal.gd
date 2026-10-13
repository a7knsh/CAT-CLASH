class_name Pal
extends RefCounted
## Shared colour palette and player/team identity helpers.

const OUTLINE := Color("1a1220")
const SHADOW := Color(0.05, 0.03, 0.08, 0.55)
const UI_BG := Color("17122a")
const UI_PANEL := Color("2a2147")
const UI_PANEL2 := Color("3b2f66")
const UI_BORDER := Color("0b0814")
const UI_EDGE := Color("6b5aa8")
const UI_HILITE := Color("ffd84a")
const UI_TEXT := Color("f6efff")
const UI_DIM := Color("9a8fc0")
const UI_BAD := Color("ff5a6a")
const UI_GOOD := Color("6af08a")
const UI_ACCENT := Color("ff7ab8")
const UI_LOCK := Color("5a5070")

const PLAYER_COLORS := [Color("ff5d5d"), Color("4fa8ff"), Color("ffd23f"), Color("5fe07a"), Color("c37bff"), Color("ff9f43"), Color("3fe0e0"), Color("ff7ad0")]
## Okabe-Ito based colour-blind safe set.
const PLAYER_COLORS_CB := [Color("e69f00"), Color("56b4e9"), Color("f0e442"), Color("cc79a7"), Color("009e73"), Color("d55e00"), Color("0072b2"), Color("ffffff")]
const PLAYER_SHAPES := ["▲", "●", "■", "◆", "★", "♥", "¤", "×"]

const TEAM_COLORS := [Color("ff6a4a"), Color("4a9aff"), Color("ffd040"), Color("60e070")]
const TEAM_COLORS_CB := [Color("d55e00"), Color("0072b2"), Color("f0e442"), Color("009e73")]
const TEAM_NAMES := ["RED", "BLUE", "GOLD", "GREEN"]
const TEAM_SHAPES := ["▲", "●", "■", "◆"]

const RARITY_COLORS := {
	"common": Color("c8c0d8"),
	"rare": Color("5fb0ff"),
	"epic": Color("c27bff"),
	"legendary": Color("ffb43a"),
}


static func _cb() -> bool:
	var s := Engine.get_main_loop() as SceneTree
	if s and s.root.has_node("Settings"):
		return bool(s.root.get_node("Settings").get_value("colorblind"))
	return false


static func player_color(i: int) -> Color:
	var arr: Array = PLAYER_COLORS_CB if _cb() else PLAYER_COLORS
	return arr[posmod(i, arr.size())]


static func player_shape(i: int) -> String:
	return PLAYER_SHAPES[posmod(i, PLAYER_SHAPES.size())]


static func team_color(t: int) -> Color:
	var arr: Array = TEAM_COLORS_CB if _cb() else TEAM_COLORS
	return arr[posmod(t, arr.size())]


static func team_name(t: int) -> String:
	return TEAM_NAMES[posmod(t, TEAM_NAMES.size())]


static func team_shape(t: int) -> String:
	return TEAM_SHAPES[posmod(t, TEAM_SHAPES.size())]


static func hp_color(frac: float) -> Color:
	if frac > 0.6:
		return Color("6af08a")
	if frac > 0.3:
		return Color("ffd23f")
	return Color("ff5a6a")
