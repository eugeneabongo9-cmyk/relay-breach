extends Node
## Session, input, settings, and the QA control probe.
## Pause is a flag checked by gameplay. It does not call get_tree().paused,
## because that would freeze the pause UI as well.

const ACTIONS: Array[String] = [
	"move_left", "move_right", "move_forward", "move_back",
	"evade", "shock", "tether", "cycle_target", "pause_game",
]

var paused: bool = false
var settings: Dictionary = {}
var cam_forward: Vector3 = Vector3(0, 0, -1)
var cam_right: Vector3 = Vector3(1, 0, 0)
var qa_active: bool = false
var qa_actions: Dictionary = {}
var qa_override_on: bool = false
var qa_override: Vector3 = Vector3.ZERO
var touch_vec: Vector2 = Vector2.ZERO
var touch_evade: bool = false
var touch_shock: bool = false
var touch_tether: bool = false
var edge_evade: bool = false
var edge_shock: bool = false
var edge_tether: bool = false
var edge_cycle: bool = false
var edge_pause: bool = false
var listening_action: String = ""
var trauma: float = 0.0
var dev_overlay: bool = false

var _prev: Dictionary = {}
var _players: Dictionary = {}
var _streams: Dictionary = {}
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _audio_ready: bool = false


func _ready() -> void:
	var axes := CameraBasis.axes_from_offset()
	cam_forward = axes["forward"]
	cam_right = axes["right"]
	_ensure_buses()
	_build_streams()
	settings = SaveService.default_settings()
	var loaded := SaveService.load_settings()
	settings = loaded.get("data", settings)
	_install_default_actions()
	_apply_saved_bindings()
	apply_audio()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_consume_edges()
	var shake := 1.0 if bool(settings.get("shake", true)) else 0.0
	trauma = maxf(0.0, trauma - delta * 1.8) * (1.0 if shake > 0.0 else 0.0)
	_publish_web_probe()


func wish_dir() -> Vector3:
	if qa_override_on:
		return qa_override
	var x := 0.0
	var z := 0.0
	if _held("move_right"):
		x += 1.0
	if _held("move_left"):
		x -= 1.0
	if _held("move_forward"):
		z += 1.0
	if _held("move_back"):
		z -= 1.0
	if touch_vec.length() > 0.2 and not qa_active:
		x = touch_vec.x
		z = -touch_vec.y
	var wish := cam_right * x + cam_forward * z
	if wish.length() > 1.0:
		wish = wish.normalized()
	return wish


func set_qa_codes(codes: Array) -> void:
	qa_actions.clear()
	qa_override_on = false
	if codes.is_empty():
		qa_active = false
		return
	qa_active = true
	for raw in codes:
		var action := _code_action(str(raw))
		if action != "":
			qa_actions[action] = true


func set_touch(action: String, down: bool) -> void:
	if action == "evade":
		touch_evade = down
	elif action == "shock":
		touch_shock = down
	elif action == "tether":
		touch_tether = down


func clear_qa() -> void:
	qa_active = false
	qa_actions.clear()
	qa_override_on = false
	qa_override = Vector3.ZERO


func probe_yaw() -> float:
	var body := get_tree().get_first_node_in_group("player") as Node3D
	if body == null:
		return CameraBasis.yaw_of(cam_forward)
	var vel := Vector3.ZERO
	if body is CharacterBody3D:
		vel = (body as CharacterBody3D).velocity
	if Vector2(vel.x, vel.z).length() < 0.05:
		return CameraBasis.yaw_of(cam_forward)
	return CameraBasis.yaw_of(vel)


func probe_speed() -> float:
	var body := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if body == null:
		return 0.0
	return Vector2(body.velocity.x, body.velocity.z).length()


func add_trauma(amount: float) -> void:
	if not bool(settings.get("shake", true)):
		return
	trauma = clampf(trauma + amount, 0.0, 1.0)


func play_sfx(id: String) -> void:
	if not _streams.has(id):
		return
	var player := _players.get(id) as AudioStreamPlayer
	if player == null:
		return
	player.stream = _streams[id]
	player.play()


func start_music() -> void:
	if _music != null and not _music.playing:
		_music.play()
	if _ambience != null and not _ambience.playing:
		_ambience.play()


func apply_audio() -> void:
	_bus_volume("Master", float(settings.get("master", 0.85)))
	_bus_volume("Music", float(settings.get("music", 0.4)))
	_bus_volume("Effects", float(settings.get("effects", 0.8)))


func set_volume(bus_name: String, linear: float) -> void:
	var key := bus_name.to_lower()
	if key == "master" or key == "music" or key == "effects":
		settings[key] = clampf(linear, 0.0, 1.0)
	apply_audio()
	SaveService.save_settings(settings)


func set_flag(flag: String, value: bool) -> void:
	settings[flag] = value
	apply_audio()
	SaveService.save_settings(settings)


func set_ui_scale(value: float) -> void:
	settings["ui_scale"] = clampf(value, 0.8, 1.6)
	SaveService.save_settings(settings)


func reset_bindings() -> void:
	_install_default_actions()
	settings["bindings"] = []
	SaveService.save_settings(settings)


func rebind_physical(action: String, keycode: Key) -> void:
	if action not in ACTIONS:
		return
	if keycode == KEY_ESCAPE or keycode == KEY_F10:
		return
	var owner := _action_for_physical(keycode)
	var previous := _primary_physical(action)
	if owner != "" and owner != action and previous != KEY_NONE:
		_set_physical(owner, previous)
	_set_physical(action, keycode)
	_store_bindings()


func _store_bindings() -> void:
	var rows: Array = []
	for action in ACTIONS:
		var keycode := _primary_physical(action)
		if keycode != KEY_NONE:
			rows.append({"action": action, "key": int(keycode)})
	settings["bindings"] = rows
	SaveService.save_settings(settings)


func _apply_saved_bindings() -> void:
	var rows: Variant = settings.get("bindings", [])
	if typeof(rows) != TYPE_ARRAY:
		return
	for raw in rows:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw
		var action := str(row.get("action", ""))
		if action not in ACTIONS:
			continue
		_set_physical(action, int(row.get("key", 0)) as Key)


func _install_default_actions() -> void:
	var keys := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"evade": [KEY_SPACE],
		"shock": [KEY_J],
		"tether": [KEY_E],
		"cycle_target": [KEY_Q],
		"pause_game": [KEY_ESCAPE],
	}
	var joy := {
		"evade": JOY_BUTTON_A,
		"shock": JOY_BUTTON_X,
		"tether": JOY_BUTTON_B,
		"cycle_target": JOY_BUTTON_LEFT_SHOULDER,
		"pause_game": JOY_BUTTON_START,
	}
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for keycode in keys.get(action, []):
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action, ev)
		if joy.has(action):
			var button := InputEventJoypadButton.new()
			button.button_index = joy[action]
			InputMap.action_add_event(action, button)
	_add_stick("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_stick("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_stick("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_stick("move_back", JOY_AXIS_LEFT_Y, 1.0)


func _add_stick(action: String, axis: JoyAxis, value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.axis = axis
	motion.axis_value = value
	InputMap.action_add_event(action, motion)


func _set_physical(action: String, keycode: Key) -> void:
	var kept: Array[InputEvent] = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			continue
		kept.append(ev)
	InputMap.action_erase_events(action)
	for ev in kept:
		InputMap.action_add_event(action, ev)
	var key := InputEventKey.new()
	key.physical_keycode = keycode
	InputMap.action_add_event(action, key)


func _primary_physical(action: String) -> Key:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return (ev as InputEventKey).physical_keycode
	return KEY_NONE


func _action_for_physical(keycode: Key) -> String:
	for action in ACTIONS:
		if _primary_physical(action) == keycode:
			return action
	return ""


func _held(action: String) -> bool:
	if qa_active:
		return bool(qa_actions.get(action, false))
	if action == "evade" and touch_evade:
		return true
	if action == "shock" and touch_shock:
		return true
	if action == "tether" and touch_tether:
		return true
	return Input.is_action_pressed(action)


func _consume_edges() -> void:
	edge_evade = _pressed_now("evade") and not bool(_prev.get("evade", false))
	edge_shock = _pressed_now("shock") and not bool(_prev.get("shock", false))
	edge_tether = _pressed_now("tether") and not bool(_prev.get("tether", false))
	edge_cycle = _pressed_now("cycle_target") and not bool(_prev.get("cycle_target", false))
	edge_pause = _pressed_now("pause_game") and not bool(_prev.get("pause_game", false))
	for action in ["evade", "shock", "tether", "cycle_target", "pause_game"]:
		_prev[action] = _pressed_now(action)


func _pressed_now(action: String) -> bool:
	return _held(action)


func _code_action(code: String) -> String:
	match code:
		"KeyW", "ArrowUp":
			return "move_forward"
		"KeyS", "ArrowDown":
			return "move_back"
		"KeyA", "ArrowLeft":
			return "move_left"
		"KeyD", "ArrowRight":
			return "move_right"
		"Space":
			return "evade"
		"KeyJ":
			return "shock"
		"KeyE":
			return "tether"
		_:
			return ""


func _ensure_buses() -> void:
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
		AudioServer.set_bus_send(AudioServer.get_bus_index("Music"), "Master")
	if AudioServer.get_bus_index("Effects") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Effects")
		AudioServer.set_bus_send(AudioServer.get_bus_index("Effects"), "Master")


func _bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	if linear <= 0.001:
		AudioServer.set_bus_volume_db(idx, -80.0)
	else:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))


func _build_streams() -> void:
	_streams = AudioSynth.bank()
	for id in _streams.keys():
		var player := AudioStreamPlayer.new()
		player.bus = "Effects"
		player.stream = _streams[id]
		add_child(player)
		_players[id] = player
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.stream = AudioSynth.music_loop()
	add_child(_music)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Music"
	_ambience.volume_db = -8.0
	_ambience.stream = AudioSynth.ambience_loop()
	add_child(_ambience)
	_audio_ready = true


func _publish_web_probe() -> void:
	if not OS.has_feature("web"):
		return
	var raw: Variant = JavaScriptBridge.eval("JSON.stringify(window.__rbKeys||[])", true)
	if typeof(raw) == TYPE_STRING:
		var parsed: Variant = JSON.parse_string(str(raw))
		if typeof(parsed) == TYPE_ARRAY:
			set_qa_codes(parsed)
	JavaScriptBridge.eval(
		"window.__rbYaw=%s;window.__rbSpeed=%s;window.__rbFrames=(window.__rbFrames||0)+1;window.__relayReady=1;" % [probe_yaw(), probe_speed()],
		true
	)


func _input(event: InputEvent) -> void:
	if listening_action != "" and event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		listening_action = "" if key_event.physical_keycode == KEY_ESCAPE else listening_action
		if listening_action != "":
			rebind_physical(listening_action, key_event.physical_keycode)
			listening_action = ""
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_F10 and key_event.shift_pressed:
			reset_bindings()
			get_viewport().set_input_as_handled()
