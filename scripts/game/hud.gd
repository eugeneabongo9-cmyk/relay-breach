extends CanvasLayer

signal start_requested
signal continue_requested
signal settings_requested
signal credits_requested
signal back_requested
signal resume_requested
signal retry_requested
signal restart_run_requested
signal menu_requested
signal upgrade_requested(id: String)
signal bind_requested(action: String)

var root_ui: Control
var menu: Control
var play: Control
var pause: Control
var dead: Control
var victory: Control
var upgrade: Control
var settings: Control
var credits: Control
var continue_button: Button
var objective: Label
var bars: Label
var reason: Label
var dev: Label
var flash: ColorRect
var stick: Control
var _stick_pointer: int = -1
var _stick_origin: Vector2 = Vector2.ZERO
var upgrade_box: VBoxContainer
var settings_body: VBoxContainer
var bind_buttons: Dictionary = {}


func _ready() -> void:
	layer = 10
	root_ui = Control.new()
	root_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ui)
	flash = ColorRect.new()
	flash.color = Color(0.9, 0.25, 0.15, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(flash)
	menu = _panel()
	play = _play_layer()
	pause = _stack_panel("Paused", [
		["Resume", resume_requested],
		["Settings", settings_requested],
		["Retry room", retry_requested],
		["Restart run", restart_run_requested],
		["Title", menu_requested],
	])
	dead = _stack_panel("Link collapsed", [
		["Retry room", retry_requested],
		["Title", menu_requested],
	])
	victory = _stack_panel("Extract stable", [
		["Replay", restart_run_requested],
		["Title", menu_requested],
	])
	upgrade = _upgrade_panel()
	settings = _settings_panel()
	credits = _credits_panel()
	_build_menu()
	_build_touch()
	show_menu(false)


func show_menu(can_continue: bool) -> void:
	_show_only(menu)
	continue_button.visible = can_continue
	continue_button.disabled = not can_continue
	_focus_first(menu)


func show_play() -> void:
	_show_only(play)
	play.mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_pause() -> void:
	pause.visible = true
	_focus_first(pause)


func hide_pause() -> void:
	pause.visible = false


func show_dead(text: String) -> void:
	_set_title(dead, text)
	_show_only(dead)
	_focus_first(dead)


func show_victory(text: String) -> void:
	_set_title(victory, text)
	_show_only(victory)
	_focus_first(victory)


func show_upgrade(options: Array) -> void:
	_show_only(upgrade)
	for child in upgrade_box.get_children():
		child.queue_free()
	for raw in options:
		var row: Dictionary = raw
		var button := Button.new()
		button.text = "%s — %s" % [str(row.get("name", "")), str(row.get("desc", ""))]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var id := str(row.get("id", ""))
		button.pressed.connect(func() -> void: upgrade_requested.emit(id))
		upgrade_box.add_child(button)
	_focus_first(upgrade)


func show_settings() -> void:
	_show_only(settings)
	_refresh_bind_labels()
	_focus_first(settings)


func show_credits() -> void:
	_show_only(credits)
	_focus_first(credits)


func set_objective(text: String) -> void:
	objective.text = text


func set_bars(health: float, health_max: float, energy: float, energy_max: float, charge: float) -> void:
	bars.text = "HULL %s   ENERGY %s   %s" % [
		_pips(health, health_max, 10),
		_pips(energy, energy_max, 10),
		("EXTRACT %d%%" % int(clampf(charge, 0.0, 1.0) * 100.0)) if charge >= 0.0 else "",
	]


func set_reason(text: String) -> void:
	reason.text = text


func set_dev(text: String) -> void:
	dev.text = text
	dev.visible = text != ""


func pulse_flash() -> void:
	if not bool(Game.settings.get("flash", true)):
		return
	flash.color.a = 0.28


func apply_scale() -> void:
	var size := int(round(16.0 * float(Game.settings.get("ui_scale", 1.0))))
	_walk(self, size)


func is_blocking_mouse() -> bool:
	for panel in [menu, pause, dead, victory, upgrade, settings, credits]:
		if panel.visible:
			return true
	return false


func _process(delta: float) -> void:
	if flash.color.a > 0.0:
		flash.color.a = maxf(0.0, flash.color.a - delta * 1.4)
	if Game.listening_action != "":
		_refresh_bind_labels()


func _build_menu() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -280
	box.offset_right = 280
	box.offset_top = -220
	box.offset_bottom = 220
	box.add_theme_constant_override("separation", 10)
	menu.add_child(box)
	var title := Label.new()
	title.text = "RELAY//BREACH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Redirect one live link.\nShields, coils, and the extract all answer to it."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var start := Button.new()
	start.text = "Start"
	start.pressed.connect(func() -> void: start_requested.emit())
	box.add_child(start)
	continue_button = Button.new()
	continue_button.text = "Continue"
	continue_button.pressed.connect(func() -> void: continue_requested.emit())
	box.add_child(continue_button)
	var settings_button := Button.new()
	settings_button.text = "Settings"
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	box.add_child(settings_button)
	var credits_button := Button.new()
	credits_button.text = "Credits"
	credits_button.pressed.connect(func() -> void: credits_requested.emit())
	box.add_child(credits_button)
	var hint := Label.new()
	hint.text = "WASD strafe relative to the camera. Space evade. J shock. E or click two endpoints to tether.\nController: stick, A evade, X shock, LB cycle, B confirm, Start pause. Shift+F10 resets keys."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(520, 70)
	box.add_child(hint)


func _play_layer() -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(layer)
	objective = Label.new()
	objective.position = Vector2(24, 18)
	objective.size = Vector2(900, 70)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layer.add_child(objective)
	bars = Label.new()
	bars.position = Vector2(24, 88)
	bars.size = Vector2(900, 30)
	layer.add_child(bars)
	reason = Label.new()
	reason.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	reason.offset_top = -78
	reason.offset_bottom = -36
	reason.offset_left = -360
	reason.offset_right = 360
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(reason)
	dev = Label.new()
	dev.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dev.offset_left = -420
	dev.offset_top = 16
	dev.offset_right = -16
	dev.offset_bottom = 180
	dev.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dev.visible = false
	layer.add_child(dev)
	return layer


func _build_touch() -> void:
	stick = Control.new()
	stick.position = Vector2(28, 520)
	stick.custom_minimum_size = Vector2(150, 150)
	stick.size = Vector2(150, 150)
	stick.mouse_filter = Control.MOUSE_FILTER_STOP
	var base := ColorRect.new()
	base.color = Color(0.15, 0.2, 0.22, 0.45)
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick.add_child(base)
	stick.gui_input.connect(_on_stick)
	play.add_child(stick)
	_touch_button("Evade", Vector2(1040, 560), "evade")
	_touch_button("Shock", Vector2(1160, 480), "shock")
	_touch_button("Tether", Vector2(1160, 600), "tether")


func _touch_button(text: String, at: Vector2, action: String) -> void:
	var button := Button.new()
	button.text = text
	button.position = at
	button.custom_minimum_size = Vector2(96, 64)
	button.focus_mode = Control.FOCUS_NONE
	button.button_down.connect(func() -> void: Game.set_touch(action, true))
	button.button_up.connect(func() -> void: Game.set_touch(action, false))
	play.add_child(button)


func _on_stick(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_stick_pointer = touch.index
			_stick_origin = touch.position
			Game.touch_vec = Vector2.ZERO
		elif touch.index == _stick_pointer:
			_stick_pointer = -1
			Game.touch_vec = Vector2.ZERO
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _stick_pointer:
		var drag := (event as InputEventScreenDrag).position - _stick_origin
		Game.touch_vec = drag.limit_length(70.0) / 70.0
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			_stick_pointer = 0
			_stick_origin = mouse.position
		else:
			_stick_pointer = -1
			Game.touch_vec = Vector2.ZERO
	elif event is InputEventMouseMotion and _stick_pointer == 0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var drag := (event as InputEventMouseMotion).position - _stick_origin
		Game.touch_vec = drag.limit_length(70.0) / 70.0


func _upgrade_panel() -> Control:
	var panel := _panel()
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -340
	box.offset_right = 340
	box.offset_top = -180
	box.offset_bottom = 180
	panel.add_child(box)
	var title := Label.new()
	title.text = "Choose one upgrade"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	upgrade_box = VBoxContainer.new()
	box.add_child(upgrade_box)
	return panel


func _settings_panel() -> Control:
	var panel := _panel()
	settings_body = VBoxContainer.new()
	settings_body.set_anchors_preset(Control.PRESET_CENTER)
	settings_body.offset_left = -320
	settings_body.offset_right = 320
	settings_body.offset_top = -260
	settings_body.offset_bottom = 260
	panel.add_child(settings_body)
	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_body.add_child(title)
	_slider("Master", "master")
	_slider("Music", "music")
	_slider("Effects", "effects")
	_slider("UI scale", "ui_scale")
	_check("Camera shake", "shake")
	_check("Damage flash", "flash")
	for action in ["move_left", "move_right", "move_forward", "move_back", "evade", "shock", "tether", "cycle_target", "pause_game"]:
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func() -> void: bind_requested.emit(action))
		settings_body.add_child(button)
		bind_buttons[action] = button
	var reset := Button.new()
	reset.text = "Reset bindings"
	reset.pressed.connect(func() -> void: Game.reset_bindings())
	settings_body.add_child(reset)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func() -> void: back_requested.emit())
	settings_body.add_child(back)
	return panel


func _credits_panel() -> Control:
	var panel := _panel()
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -360
	box.offset_right = 360
	box.offset_top = -180
	box.offset_bottom = 180
	panel.add_child(box)
	var text := Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.text = "RELAY//BREACH\n\nAll meshes, textures, and audio in this slice are procedural and generated in-engine. No third-party art packs.\n\nEngine: Godot 4.7.2 (MIT License).\n\nShift+F10 restores default controls if a remap gets stuck."
	box.add_child(text)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func() -> void: back_requested.emit())
	box.add_child(back)
	return panel


func _slider(label_text: String, key: String) -> void:
	var label := Label.new()
	label.text = label_text
	settings_body.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0 if key != "ui_scale" else 0.8
	slider.max_value = 1.0 if key != "ui_scale" else 1.6
	slider.step = 0.05
	slider.value = float(Game.settings.get(key, 1.0))
	slider.value_changed.connect(func(v: float) -> void:
		if key == "ui_scale":
			Game.set_ui_scale(v)
			apply_scale()
		else:
			Game.set_volume(key, v)
	)
	settings_body.add_child(slider)


func _check(label_text: String, key: String) -> void:
	var check := CheckButton.new()
	check.text = label_text
	check.button_pressed = bool(Game.settings.get(key, true))
	check.toggled.connect(func(v: bool) -> void: Game.set_flag(key, v))
	settings_body.add_child(check)


func refresh_binds() -> void:
	_refresh_bind_labels()


func _refresh_bind_labels() -> void:
	for action in bind_buttons.keys():
		var button: Button = bind_buttons[action]
		var keycode := KEY_NONE
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				keycode = (ev as InputEventKey).physical_keycode
				break
		var suffix := OS.get_keycode_string(keycode)
		if Game.listening_action == action:
			suffix = "press a key"
		button.text = "%s: %s" % [action, suffix]


func _stack_panel(title_text: String, rows: Array) -> Control:
	var panel := _panel()
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -260
	box.offset_right = 260
	box.offset_top = -160
	box.offset_bottom = 180
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.name = "Title"
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	for row in rows:
		var button := Button.new()
		button.text = row[0]
		var sig: Signal = row[1]
		button.pressed.connect(func() -> void: sig.emit())
		box.add_child(button)
	return panel


func _panel() -> Control:
	var panel := ColorRect.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.color = Color(0.04, 0.05, 0.07, 0.92)
	panel.visible = false
	root_ui.add_child(panel)
	return panel


func _show_only(which: Control) -> void:
	for panel in [menu, play, pause, dead, victory, upgrade, settings, credits]:
		panel.visible = panel == which
	if which == play:
		play.visible = true


func _set_title(panel: Control, text: String) -> void:
	var title := panel.find_child("Title", true, false) as Label
	if title != null:
		title.text = text


func _focus_first(panel: Control) -> void:
	var button := panel.find_child("*", true, false)
	var buttons := panel.find_children("*", "Button", true, false)
	if buttons.size() > 0:
		(buttons[0] as Button).grab_focus()
	else:
		button = button


func _pips(value: float, maximum: float, count: int) -> String:
	var filled := 0
	if maximum > 0.0:
		filled = int(round(clampf(value / maximum, 0.0, 1.0) * float(count)))
	var text := ""
	for i in count:
		text += "█" if i < filled else "░"
	return text


func _walk(node: Node, size: int) -> void:
	if node is Label:
		(node as Label).add_theme_font_size_override("font_size", size)
	elif node is Button:
		(node as Button).add_theme_font_size_override("font_size", size)
	for child in node.get_children():
		_walk(child, size)
