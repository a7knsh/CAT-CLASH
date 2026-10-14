extends Screen
## LAN party screen: host a game or join one on the local network (auto
## discovered via UDP broadcast, or by typing the host's IP address).

var editing := ""         # "", "name" or "ip"
var buf := ""
var status_text := ""
var status_col := Pal.UI_TEXT
var connecting_t := -1.0


func _build() -> void:
	if Net.active:
		Net.leave()
	Net.start_browsing()
	if Net.last_error != "":
		status_text = Net.last_error
		status_col = Pal.UI_BAD
		Net.last_error = ""
	Net.servers_changed.connect(_rebuild)
	Net.status.connect(_on_status)
	menu.pos = Vector2(30, 52)
	menu.width = 220
	menu.line_h = 15
	menu.max_visible = 11
	_rebuild()


func _exit_tree() -> void:
	Net.stop_browsing()
	if Net.servers_changed.is_connected(_rebuild):
		Net.servers_changed.disconnect(_rebuild)
	if Net.status.is_connected(_on_status):
		Net.status.disconnect(_on_status)


func _name() -> String:
	var n := str(Settings.get_value("player_name", ""))
	if n == "":
		n = "CAT%03d" % (randi() % 1000)
		Settings.set_value("player_name", n)
	return n


func _on_status(t: String) -> void:
	status_text = t
	status_col = Pal.UI_TEXT


func _rebuild() -> void:
	var keep := menu.index
	menu.clear()
	menu.add("name", "YOUR NAME", "button", _name(), {"hint": "Shown to other players. Press confirm, type, then Enter."})
	menu.add("host", "HOST A GAME", "button", "", {"color": Pal.UI_GOOD, "hint": "Others on your network can join. Up to 10 fighters across all devices."})
	menu.add("ip", "JOIN BY IP", "button", str(Settings.get_value("last_ip", "192.168.1.")), {"hint": "Type the host's IP address (shown on the host's screen), then Enter."})
	menu.add("", "- GAMES ON YOUR NETWORK -", "label")
	if Net.servers.is_empty():
		menu.add("", "  SEARCHING...", "label")
	for ip in Net.servers.keys():
		var sv: Dictionary = Net.servers[ip]
		var label := str(sv.get("name", "?")).substr(0, 12)
		var val := "%s %d/%d" % [str(sv.get("mode", "")).substr(0, 10), int(sv.get("players", 0)), int(sv.get("max", 10))]
		if sv.get("busy", false):
			val = "IN MATCH " + val
		menu.add("srv:" + str(ip), label, "button", val, {"hint": "Join %s at %s" % [label, ip]})
	menu.add("back", "BACK")
	menu.index = clampi(keep, 0, menu.items.size() - 1)
	if menu.items[menu.index].kind == "label":
		menu.index = 1


func _local_ips() -> Array:
	var out: Array = []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254"):
			out.append(a)
	return out


func _update(dt: float) -> void:
	if connecting_t >= 0.0:
		connecting_t += dt
		if connecting_t > 8.0 and Net.active and not Net.is_host:
			Net.leave()
			connecting_t = -1.0
			status_text = "NO RESPONSE FROM HOST"
			status_col = Pal.UI_BAD
	if editing != "":
		for e in InputHub.menu_events:
			if e.device.begins_with("pad") and e.action in ["confirm", "start", "back"]:
				_finish_edit(e.action != "back")
		return
	super._update(dt)


func _input(ev: InputEvent) -> void:
	if editing == "" or not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	if ev.keycode == KEY_BACKSPACE:
		buf = buf.substr(0, maxi(0, buf.length() - 1))
	elif ev.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		_finish_edit(true)
	elif ev.keycode == KEY_ESCAPE:
		_finish_edit(false)
	elif ev.unicode >= 32 and ev.unicode < 127:
		var ch := char(ev.unicode).to_upper()
		if editing == "ip":
			if (ch.is_valid_int() or ch == ".") and buf.length() < 15:
				buf += ch
		elif buf.length() < 12:
			buf += ch
	get_viewport().set_input_as_handled()
	InputHub.consume_menu()


func _finish_edit(ok: bool) -> void:
	var what := editing
	editing = ""
	InputHub.consume_menu()
	if not ok:
		return
	if what == "name" and buf.strip_edges() != "":
		Settings.set_value("player_name", buf.strip_edges())
	elif what == "ip" and buf.is_valid_ip_address():
		Settings.set_value("last_ip", buf)
		_join(buf)
	elif what == "ip":
		status_text = "THAT'S NOT A VALID IP ADDRESS"
		status_col = Pal.UI_BAD
	_rebuild()


func _join(ip: String) -> void:
	if Net.join(ip, _name()):
		connecting_t = 0.0
		status_text = "CONNECTING TO %s..." % ip
		status_col = Pal.UI_TEXT
	else:
		status_text = Net.last_error
		status_col = Pal.UI_BAD


func _on_menu(r: Dictionary) -> void:
	if r.action == "back":
		Router.goto("main_menu")
		return
	if r.action != "activate":
		return
	var id: String = r.id
	match id:
		"name":
			editing = "name"
			buf = ""
		"ip":
			editing = "ip"
			buf = str(Settings.get_value("last_ip", ""))
		"host":
			if Net.host(_name()):
				Router.session = {"mode": "ffa"}
				Router.goto("lobby")
			else:
				status_text = Net.last_error
				status_col = Pal.UI_BAD
		"back":
			Router.goto("main_menu")
		_:
			if id.begins_with("srv:"):
				_join(id.substr(4))


func _paint() -> void:
	UI.title(self, "LAN PARTY", 6)
	menu.draw(self, t)
	UI.panel(self, Rect2(266, 40, 200, 186))
	PixelFont.draw_text(self, Vector2(274, 48), "HOW IT WORKS", Pal.UI_HILITE)
	var lines := PixelFont.wrap("ONE PLAYER HOSTS. EVERYONE ELSE ON THE SAME WI-FI OR LAN PICKS THE GAME FROM THE LIST (OR TYPES THE HOST'S IP). EACH DEVICE CAN ADD SEVERAL PLAYERS WITH KEYBOARD HALVES AND GAMEPADS - UP TO 10 FIGHTERS IN TOTAL. THE HOST CHOOSES THE MODE, ARENA AND RULES.", 184)
	for i in lines.size():
		PixelFont.draw_text(self, Vector2(274, 62 + i * 10), lines[i], Pal.UI_TEXT)
	var ips := _local_ips()
	PixelFont.draw_text(self, Vector2(274, 178), "YOUR IP:", Pal.UI_DIM)
	PixelFont.draw_text(self, Vector2(274, 188), ", ".join(ips.slice(0, 2)) if not ips.is_empty() else "NO NETWORK FOUND", Pal.UI_GOOD if not ips.is_empty() else Pal.UI_BAD)
	PixelFont.draw_text(self, Vector2(274, 202), "PORTS: UDP %d + %d" % [Net.PORT, Net.BEACON_PORT], Pal.UI_DIM)
	if status_text != "":
		PixelFont.draw_text(self, Vector2(240, 234), status_text, status_col, 1, 1)
	if editing != "":
		draw_rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, 0.6))
		UI.panel(self, Rect2(120, 104, 240, 44))
		PixelFont.draw_text(self, Vector2(240, 110), "TYPE YOUR NAME" if editing == "name" else "TYPE THE HOST'S IP ADDRESS", Pal.UI_DIM, 1, 1)
		PixelFont.draw_text(self, Vector2(240, 124), buf + ("_" if int(t * 3.0) % 2 == 0 else " "), Pal.UI_HILITE, 2, 1)
		PixelFont.draw_text(self, Vector2(240, 140), "ENTER: OK · ESC: CANCEL", Pal.UI_DIM, 1, 1)
	UI.hints(self, "FIREWALL: ALLOW THE GAME ON PRIVATE NETWORKS IF NOBODY CAN JOIN")
