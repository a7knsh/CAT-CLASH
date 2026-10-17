class_name MenuList
extends RefCounted
## Reusable vertical menu: buttons and left/right option rows, navigable by
## any keyboard half, any gamepad, or the mouse. Screens feed it InputHub
## menu events and react to the returned action.
##
## Item fields: id, label, value (String shown on the right), kind
## ("button" | "choice"), disabled, hint, color.

var items: Array = []
var index := 0
var pos := Vector2(140, 60)
var width := 200.0
var line_h := 14.0
var scroll := 0
var max_visible := 12
var device_filter := ""
var _hover := -1
var _rects: Array = []


func add(id: String, label: String, kind: String = "button", value: String = "", extra: Dictionary = {}) -> Dictionary:
	var it := {"id": id, "label": label, "kind": kind, "value": value, "disabled": false, "hint": ""}
	for k in extra.keys():
		it[k] = extra[k]
	items.append(it)
	return it


func clear() -> void:
	items.clear()
	index = clampi(index, 0, 0)


func current() -> Dictionary:
	if items.is_empty():
		return {}
	return items[clampi(index, 0, items.size() - 1)]


func set_value(id: String, value: String) -> void:
	for it in items:
		if it.id == id:
			it.value = value


func _move(d: int) -> void:
	if items.is_empty():
		return
	for i in items.size():
		index = posmod(index + d, items.size())
		if not items[index].get("disabled", false) and items[index].get("kind", "") != "label":
			break
	if index < scroll:
		scroll = index
	elif index >= scroll + max_visible:
		scroll = index - max_visible + 1
	AudioHub.play("ui_move", -10.0)


## Process menu events; returns {} or {action: "activate"|"change"|"back", id, delta, device}.
func handle() -> Dictionary:
	for e in InputHub.menu_events:
		if device_filter != "" and e.device != device_filter:
			continue
		match e.action:
			"up":
				_move(-1)
			"down":
				_move(1)
			"left", "right":
				var it := current()
				if it.get("kind", "") == "choice" and not it.get("disabled", false):
					AudioHub.play("ui_move", -8.0)
					return {"action": "change", "id": it.id, "delta": -1 if e.action == "left" else 1, "device": e.device}
			"confirm":
				var it2 := current()
				if it2.is_empty():
					continue
				if it2.get("disabled", false):
					AudioHub.play("ui_error", -6.0)
					continue
				if it2.kind == "choice":
					AudioHub.play("ui_move", -8.0)
					return {"action": "change", "id": it2.id, "delta": 1, "device": e.device}
				AudioHub.play("ui_select", -4.0)
				return {"action": "activate", "id": it2.id, "device": e.device}
			"back":
				AudioHub.play("ui_back", -4.0)
				return {"action": "back", "device": e.device}
	return {}


## Mouse support: call from the owning Control's _gui_input / _input.
func mouse_event(ev: InputEvent, local_pos: Vector2) -> Dictionary:
	for i in _rects.size():
		var r: Rect2 = _rects[i][0]
		var idx: int = _rects[i][1]
		if r.has_point(local_pos):
			if ev is InputEventMouseMotion and index != idx and not items[idx].get("disabled", false):
				index = idx
				AudioHub.play("ui_move", -12.0)
			if ev is InputEventMouseButton and ev.pressed:
				var it: Dictionary = items[idx]
				if it.get("disabled", false):
					return {}
				index = idx
				if ev.button_index == MOUSE_BUTTON_LEFT:
					if it.kind == "choice":
						var right_half := local_pos.x > r.position.x + r.size.x * 0.5
						AudioHub.play("ui_move", -8.0)
						return {"action": "change", "id": it.id, "delta": 1 if right_half else -1, "device": "mouse"}
					AudioHub.play("ui_select", -4.0)
					return {"action": "activate", "id": it.id, "device": "mouse"}
				elif ev.button_index == MOUSE_BUTTON_RIGHT and it.kind == "choice":
					return {"action": "change", "id": it.id, "delta": -1, "device": "mouse"}
			return {}
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_UP:
		_move(-1)
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_move(1)
	return {}


func draw(ci: CanvasItem, t: float, fill: Color = Pal.UI_PANEL) -> void:
	_rects.clear()
	var y := pos.y
	var vis_end := mini(items.size(), scroll + max_visible)
	for i in range(scroll, vis_end):
		var it: Dictionary = items[i]
		var sel := i == index
		var r := Rect2(pos.x, y, width, line_h - 2)
		_rects.append([r, i])
		if it.kind == "label":
			PixelFont.draw_text(ci, Vector2(pos.x + 2, y + 2), it.label, Pal.UI_DIM)
			y += line_h
			continue
		var c: Color = it.get("color", Pal.UI_TEXT)
		if it.get("disabled", false):
			c = Pal.UI_LOCK
		if sel:
			var pulse := 0.5 + 0.5 * sin(t * 6.0)
			ci.draw_rect(r.grow(1), Pal.UI_HILITE.darkened(0.4 * pulse))
			ci.draw_rect(r, fill.lightened(0.15))
			PixelFont.draw_text(ci, Vector2(pos.x - 8 + sin(t * 8.0), y + 2), "►", Pal.UI_HILITE)
		else:
			ci.draw_rect(r, Color(fill, 0.75))
		PixelFont.draw_text(ci, Vector2(pos.x + 4, y + 2), it.label, Pal.UI_HILITE if sel else c)
		var v: String = it.get("value", "")
		if v != "":
			var vx := pos.x + width - 4
			if it.kind == "choice":
				PixelFont.draw_text(ci, Vector2(vx, y + 2), "◄ " + v + " ►" if sel else v, Pal.UI_TEXT if sel else Pal.UI_DIM, 1, 2)
			else:
				PixelFont.draw_text(ci, Vector2(vx, y + 2), v, Pal.UI_DIM, 1, 2)
		y += line_h
	if scroll > 0:
		PixelFont.draw_text(ci, Vector2(pos.x + width * 0.5, pos.y - 9), "▲", Pal.UI_DIM, 1, 1)
	if vis_end < items.size():
		PixelFont.draw_text(ci, Vector2(pos.x + width * 0.5, y), "▼", Pal.UI_DIM, 1, 1)
	var cur := current()
	if cur.get("hint", "") != "":
		var lines := PixelFont.wrap(cur.hint, 460)
		for li in lines.size():
			PixelFont.draw_text(ci, Vector2(240, 238 + li * 9), lines[li], Pal.UI_DIM, 1, 1)
