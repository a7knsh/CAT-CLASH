class_name Screen
extends Control
## Base for menu screens: full-viewport custom-drawn Control with a MenuList,
## animated background, keyboard/gamepad/mouse navigation.

var t := 0.0
var menu := MenuList.new()


func _ready() -> void:
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_build()


func _build() -> void:
	pass


func _process(dt: float) -> void:
	t += dt
	_update(dt)
	queue_redraw()


func _update(_dt: float) -> void:
	var r := menu.handle()
	if not r.is_empty():
		_on_menu(r)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton or ev is InputEventMouseMotion:
		var r := menu.mouse_event(ev, get_local_mouse_position())
		if not r.is_empty():
			_on_menu(r)
		_on_mouse(ev)


func _on_mouse(_ev: InputEvent) -> void:
	pass


func _on_menu(_r: Dictionary) -> void:
	pass


func _draw() -> void:
	UI.bg(self, t)
	_paint()


func _paint() -> void:
	pass


## Cycle helper for option arrays.
static func cycle(arr: Array, cur: Variant, d: int) -> Variant:
	if arr.is_empty():
		return cur
	var i := arr.find(cur)
	if i < 0:
		i = 0
	return arr[posmod(i + d, arr.size())]
