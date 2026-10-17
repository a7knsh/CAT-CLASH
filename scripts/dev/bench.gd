extends Node
## Performance check: runs a 4-bot Chaos match on a busy arena for ~40 s of
## real time and reports average / worst frame times.
##   godot --path . -- --bench        (with a renderer for real numbers)

var frames := 0
var total := 0.0
var worst := 0.0
var t0 := 0
var match_node: Node


func _ready() -> void:
	Router.session = Sessions.quick_session("chaos", "volcano", 4, true)
	Router.session.rules["item_rate"] = 3
	Router.session.rules["stocks"] = 99
	Router.session["smoke"] = true
	Router.goto("match", {}, false)
	t0 = Time.get_ticks_msec()


func _process(dt: float) -> void:
	frames += 1
	if frames < 120:
		return
	total += dt
	worst = maxf(worst, dt)
	if Time.get_ticks_msec() - t0 > 40000:
		var avg := total / maxf(1.0, frames - 120)
		var mc: Node = Router.current
		var nproj: int = mc.proj.list.size() if mc and "proj" in mc else 0
		print("BENCH: frames=%d avg=%.2fms (%.0f FPS) worst=%.2fms projectiles=%d" % [frames - 120, avg * 1000.0, 1.0 / avg, worst * 1000.0, nproj])
		get_tree().quit()
