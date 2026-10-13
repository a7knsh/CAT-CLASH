extends Node
## Screen router + session state. Screens are plain scripts instantiated in
## code (no .tscn per screen), swapped with a short pixel fade. Also hosts the
## global toast overlay (achievements, unlocks) and the optional FPS counter.

const SCREENS := {
	"title": "res://scripts/ui/title_screen.gd",
	"main_menu": "res://scripts/ui/main_menu.gd",
	"mode_select": "res://scripts/ui/mode_select.gd",
	"lobby": "res://scripts/ui/lobby.gd",
	"setup": "res://scripts/ui/match_setup.gd",
	"match": "res://scripts/gameplay/match_controller.gd",
	"results": "res://scripts/ui/results_screen.gd",
	"creator": "res://scripts/ui/cat_creator.gd",
	"collection": "res://scripts/ui/collection_screen.gd",
	"stats": "res://scripts/ui/stats_screen.gd",
	"settings": "res://scripts/ui/settings_screen.gd",
	"controls": "res://scripts/ui/controls_screen.gd",
	"credits": "res://scripts/ui/credits_screen.gd",
	"tournament": "res://scripts/ui/tournament_screen.gd",
}

var root: Node
var current: Node
var current_name := ""
var busy := false

## Current match configuration: {mode, arena, players:[...], rules:{...}}
var session: Dictionary = {}
## Active tournament state (empty when none).
var tournament: Dictionary = {}
## Last match summary (for the results screen).
var last_result: Dictionary = {}

var _layer: CanvasLayer
var _fade: ColorRect
var _overlay: Control
var _toasts: Array = []
var _fps_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 120
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.04, 0.02, 0.07, 0.0)
	_fade.size = Vector2(480, 270)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)
	_overlay = Control.new()
	_overlay.size = Vector2(480, 270)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	_layer.add_child(_overlay)
	SaveData.toast.connect(show_toast)


func goto(screen: String, params: Dictionary = {}, fade: bool = true) -> void:
	if busy:
		return
	busy = true
	if fade and current != null and DisplayServer.get_name() != "headless":
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", 1.0, 0.14)
		await tw.finished
	if current != null:
		current.queue_free()
		current = null
	get_tree().paused = false
	Engine.time_scale = 1.0
	var script: Script = load(SCREENS[screen])
	var node: Node = script.new()
	node.name = screen.capitalize().replace(" ", "")
	if node.has_method("setup"):
		node.setup(params)
	root.add_child(node)
	current = node
	current_name = screen
	InputHub.consume_menu()
	if fade and DisplayServer.get_name() != "headless":
		var tw2 := create_tween()
		tw2.tween_property(_fade, "color:a", 0.0, 0.18)
		await tw2.finished
	else:
		_fade.color.a = 0.0
	busy = false


func _input(event: InputEvent) -> void:
	# Global shortcuts: F11 or Alt+Enter toggles fullscreen.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			Settings.set_value("fullscreen", not bool(Settings.get_value("fullscreen")))
			get_viewport().set_input_as_handled()


func show_toast(text: String, color: Color = Pal.UI_HILITE) -> void:
	_toasts.append({"text": text, "color": color, "t": 3.0})
	AudioHub.play("coin", -4.0)


func _process(dt: float) -> void:
	for t in _toasts:
		t.t -= dt
	_toasts = _toasts.filter(func(t): return t.t > 0.0)
	_fps_t += dt
	_overlay.queue_redraw()


func _draw_overlay() -> void:
	var y := 4.0
	for i in mini(_toasts.size(), 4):
		var t: Dictionary = _toasts[i]
		var w := PixelFont.text_width(t.text) + 12
		var slide := clampf((3.0 - t.t) * 8.0, 0.0, 1.0) * clampf(t.t * 4.0, 0.0, 1.0)
		var x := 480 - (w + 4) * slide
		_overlay.draw_rect(Rect2(x, y, w, 13), Pal.UI_BORDER)
		_overlay.draw_rect(Rect2(x + 1, y + 1, w - 2, 11), Pal.UI_PANEL)
		_overlay.draw_rect(Rect2(x + 1, y + 1, 2, 11), t.color)
		PixelFont.draw_text(_overlay, Vector2(x + 7, y + 3), t.text, t.color)
		y += 15
	if bool(Settings.get_value("show_fps")):
		PixelFont.draw_text(_overlay, Vector2(476, 260), "%d FPS" % Engine.get_frames_per_second(), Pal.UI_GOOD, 1, 2)
