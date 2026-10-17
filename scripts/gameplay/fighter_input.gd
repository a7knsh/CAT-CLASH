class_name FighterInput
extends RefCounted
## One fighter's input frame. Human fighters copy it from InputHub every tick;
## bots write into it via BotBrain. The fighter only ever reads this object,
## so humans and AI share exactly the same rules.

var device := ""
var move := Vector2.ZERO
var _held: Dictionary = {}
var _just: Dictionary = {}
var enabled := true


func pull_from_hub() -> void:
	if device == "" or not enabled:
		return
	if device.begins_with("net:"):
		# Remote player on another device (host side of a LAN game).
		var r: Dictionary = Net.remote_frame(device)
		if r.is_empty():
			move = Vector2.ZERO
			_held.clear()
			_just.clear()
			return
		move = r.move
		_held = r.held
		_just = r.just
		return
	move = InputHub.move_vector(device)
	for a in InputHub.ACTIONS:
		_held[a] = InputHub.held(device, a)
		_just[a] = InputHub.just_pressed(device, a)


func held(a: String) -> bool:
	return enabled and _held.get(a, false)


func just(a: String) -> bool:
	return enabled and _just.get(a, false)


## Bot helpers -----------------------------------------------------------
func bot_press(a: String) -> void:
	_just[a] = true
	_held[a] = true


func bot_hold(a: String, on: bool) -> void:
	_held[a] = on


func end_tick() -> void:
	if device == "":
		_just.clear()


func clear() -> void:
	move = Vector2.ZERO
	_held.clear()
	_just.clear()
