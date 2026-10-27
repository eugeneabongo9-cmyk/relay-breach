extends Node3D
## Builds the station in code and runs the room loop.
## One active tether. Pause is Game.paused; this node simply stops simulating.

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4
const LAYER_ENDPOINT := 8
const EXTRACT_SECONDS := 4.0

var world: Node3D
var actors: Node3D
var cam: Camera3D
var hud: CanvasLayer
var player: CharacterBody3D
var enemies: Array = []
var projectiles: Array = []
var endpoints: Dictionary = {}
var obstacle_defs: Array = []
var beam: MeshInstance3D
var range_ring: MeshInstance3D
var mode: String = "menu"
var ui_return: String = "menu"
var seed_value: int = 1
var order: Array = []
var room_index: int = 0
var upgrades_picked: Array = []
var run_time: float = 0.0
var link_active: bool = false
var link_a: String = ""
var link_b: String = ""
var link_time: float = 0.0
var selected_id: String = ""
var cursor: int = 0
var cooldown_left: float = 0.0
var last_reason: String = ""
var door_open: bool = false
var extract_charge: float = 0.0
var exit_pos: Vector3 = Vector3.ZERO
var exit_open: bool = false
var tutorial_step: int = 0
var bolt_sent: bool = false
var transitioning: bool = false
var stress_mode: bool = false
var spawn_origin: Vector3 = Vector3.ZERO
var props: Node3D
var cosmetic: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_build_stage()
	var hud_script := load("res://scripts/game/hud.gd")
	hud = CanvasLayer.new()
	hud.set_script(hud_script)
	add_child(hud)
	hud.start_requested.connect(_on_start)
	hud.continue_requested.connect(_on_continue)
	hud.settings_requested.connect(_on_settings)
	hud.credits_requested.connect(func() -> void: hud.show_credits())
	hud.back_requested.connect(_on_back)
	hud.resume_requested.connect(_on_resume)
	hud.retry_requested.connect(_on_retry)
	hud.restart_run_requested.connect(_on_restart_run)
	hud.menu_requested.connect(_on_menu)
	hud.upgrade_requested.connect(_on_upgrade)
	hud.bind_requested.connect(_on_bind)
	_install_web_hooks()
	hud.apply_scale()
	hud.show_menu(_has_continue())


func _physics_process(delta: float) -> void:
	if mode != "play" or Game.paused:
		return
	_sim(minf(delta, 0.05))


func _process(_delta: float) -> void:
	_poll_host_start()
	_follow_camera()
	if mode == "play":
		_refresh_overlay()
	elif hud != null and hud.dev != null:
		hud.set_dev(_dev_text())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and OS.is_debug_build():
		var key := (event as InputEventKey).keycode
		if key == KEY_F3:
			Game.dev_overlay = not Game.dev_overlay
		elif key == KEY_F4 and mode == "play":
			restart_room()
		elif key == KEY_F6:
			start_stress()
		elif key == KEY_F8:
			DisplayServer.clipboard_set(bug_report())
	if mode != "play" or Game.paused:
		return
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if hud.is_blocking_mouse():
			return
		_click_world((event as InputEventMouseButton).position)
		Game.start_music()


func _sim(dt: float) -> void:
	run_time += dt
	cooldown_left = CombatRules.advance(cooldown_left, dt, false)
	if not link_active:
		extract_charge = maxf(0.0, extract_charge - dt * 0.45)
	_controller_tether()
	if player != null:
		player.tick(dt)
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.tick(dt)
	for shot in projectiles:
		if is_instance_valid(shot):
			shot.tick(dt)
	_tick_link(dt)
	_cleanup_dead()
	_tutorial(dt)
	_check_exit()
	if player != null and player.health <= 0.0 and mode == "play":
		_die()


func start_run(seed_in: int) -> void:
	stress_mode = false
	seed_value = seed_in
	var pool: Array = ContentDB.data.get("encounter_pool", [])
	order = RunGenerator.order_for(seed_value, pool)
	room_index = 0
	upgrades_picked = []
	run_time = 0.0
	_enter_play()


func start_stress() -> void:
	stress_mode = true
	seed_value = 1
	order = ["stress"]
	room_index = 0
	upgrades_picked = []
	run_time = 0.0
	_enter_play()


func restart_room() -> void:
	if order.is_empty():
		return
	Game.paused = false
	_build_room()
	mode = "play"
	if hud != null:
		hud.show_play()


func _enter_play() -> void:
	Game.paused = false
	Game.start_music()
	mode = "play"
	_build_room()
	if hud != null:
		hud.show_play()


func _build_room() -> void:
	_clear_actors()
	cosmetic = RunGenerator.cosmetic_rng(seed_value + room_index * 17)
	var room_id := str(order[room_index])
	var room: Dictionary = ContentDB.room(room_id)
	_paint_trim()
	var player_at := _xz(room.get("player", [4, 13]))
	spawn_origin = player_at
	exit_pos = _xz(room.get("exit", [23, 13]))
	_spawn_player(player_at)
	obstacle_defs = room.get("obstacles", [])
	for raw in obstacle_defs:
		_spawn_obstacle(raw)
	for raw in room.get("endpoints", []):
		_spawn_endpoint(raw)
	if stress_mode or room_id == "stress":
		for i in 24:
			var angle := TAU * float(i) / 24.0
			_spawn_enemy({
				"id": "stress_%d" % i,
				"archetype": "pursuer",
				"at": [13.0 + cos(angle) * 7.5, 13.0 + sin(angle) * 7.5],
			})
	else:
		for raw in room.get("enemies", []):
			_spawn_enemy(raw)
	_save_boundary()
	last_reason = ""
	selected_id = ""


func _clear_actors() -> void:
	var doomed: Array = actors.get_children()
	for child in doomed:
		actors.remove_child(child)
		child.free()
	_wipe_props()
	enemies.clear()
	projectiles.clear()
	endpoints.clear()
	player = null
	link_active = false
	link_a = ""
	link_b = ""
	link_time = 0.0
	selected_id = ""
	cooldown_left = 0.0
	door_open = false
	extract_charge = 0.0
	exit_open = false
	tutorial_step = 0
	bolt_sent = false
	transitioning = false


func _tick_link(dt: float) -> void:
	if not link_active:
		return
	if not endpoints.has(link_a) or not endpoints.has(link_b):
		_break_link("missing")
		return
	var sustain := float(ContentDB.tether().get("sustain_per_sec", 7.0))
	if player == null or player.energy < sustain * dt:
		_break_link("energy")
		return
	player.energy -= sustain * dt
	link_time += dt
	var max_duration := float(ContentDB.tether().get("max_duration", 6.0))
	var pair := _active_pair()
	if pair == "bus+door" and link_time >= 0.55:
		door_open = true
		if tutorial_step == 3:
			tutorial_step = 4
	elif pair == "bus+coil":
		var coil_id := _id_of_type("coil")
		var coil: Vector3 = endpoints[coil_id]["pos"]
		for enemy in enemies:
			if enemy.dead:
				continue
			if enemy.global_position.distance_to(coil) <= 3.4:
				enemy.hurt(26.0 * dt)
	elif pair == "extract+reactor":
		extract_charge += dt
		if extract_charge >= EXTRACT_SECONDS:
			_victory()
			return
	if link_active and link_time >= max_duration:
		_break_link("duration")


func select_endpoint(id: String) -> String:
	if not endpoints.has(id):
		last_reason = "missing"
		return last_reason
	if link_active:
		last_reason = "busy"
		Game.play_sfx("reject")
		return last_reason
	if selected_id == "":
		selected_id = id
		last_reason = ""
		Game.play_sfx("ui")
		return "ok"
	if selected_id == id:
		last_reason = "same"
		selected_id = ""
		return last_reason
	var reason := _validate_pair(selected_id, id)
	last_reason = reason
	if reason == "ok":
		_begin_link(selected_id, id)
		selected_id = ""
		Game.play_sfx("connect")
	else:
		Game.play_sfx("reject")
		if reason == "incompatible" and _room_id() == "tutorial" and tutorial_step == 2:
			tutorial_step = 3
	return reason


func _begin_link(a_id: String, b_id: String) -> void:
	var cost := float(ContentDB.tether().get("energy_cost", 18.0))
	player.energy -= cost
	link_active = true
	link_a = a_id
	link_b = b_id
	link_time = 0.0
	last_reason = "ok"


func _break_link(reason: String) -> void:
	link_active = false
	link_a = ""
	link_b = ""
	link_time = 0.0
	cooldown_left = float(ContentDB.tether().get("cooldown", 1.15))
	last_reason = reason
	if reason != "duration":
		Game.play_sfx("reject")


func _validate_pair(a_id: String, b_id: String) -> String:
	var tether: Dictionary = ContentDB.tether()
	var a: Dictionary = _endpoint_view(a_id)
	var b: Dictionary = _endpoint_view(b_id)
	var ctx := {
		"pairs": tether.get("pairs", []),
		"range": tether_range(),
		"energy": player.energy if player != null else 0.0,
		"energy_cost": float(tether.get("energy_cost", 18.0)),
		"cooldown_left": cooldown_left,
		"link_active": link_active,
		"los_required": bool(tether.get("los_required", true)),
		"los_clear": los_clear(a.get("pos", Vector3.ZERO), b.get("pos", Vector3.ZERO)),
	}
	return TetherRules.validate(a, b, ctx)


func tether_range() -> float:
	var reach := float(ContentDB.tether().get("range", 13.0))
	if upgrades_picked.has("arc_lens"):
		reach += 4.0
	return reach


func los_clear(a: Vector3, b: Vector3) -> bool:
	return not ContentValidator._blocked(a, b, obstacle_defs)


func is_shield_link_active() -> bool:
	return link_active and _active_pair() == "dump+shield_gen"


func is_jammer_active() -> bool:
	return link_active and _active_pair() == "bus+jammer"


func player_position() -> Vector3:
	if player == null:
		return Vector3.ZERO
	return player.global_position


func ally_needs_heal() -> bool:
	for enemy in enemies:
		if not enemy.dead and enemy.health < enemy.max_health - 0.5:
			return true
	return false


func damage_player(amount: float) -> void:
	if player == null or mode != "play":
		return
	player.hurt(amount)


func on_player_hurt() -> void:
	if hud != null:
		hud.pulse_flash()


func on_player_shock(origin: Vector3, reach: float, amount: float) -> void:
	for enemy in enemies:
		if enemy.dead:
			continue
		if enemy.global_position.distance_to(origin) <= reach:
			enemy.hurt(amount)
	Game.add_trauma(0.12)


func heal_allies(amount: float) -> void:
	for enemy in enemies:
		if enemy.dead:
			continue
		enemy.health = minf(enemy.max_health, enemy.health + amount)


func spawn_projectile(origin: Vector3, direction: Vector3, speed: float, amount: float) -> void:
	var shot := Node3D.new()
	shot.set_script(load("res://scripts/game/projectile.gd"))
	actors.add_child(shot)
	shot.setup(origin, direction, speed, amount, self)
	projectiles.append(shot)


func segment_hits_world(a: Vector3, b: Vector3) -> bool:
	if not los_clear(a, b):
		return true
	return b.x < 0.3 or b.x > 25.7 or b.z < 0.3 or b.z > 25.7


func living_enemies() -> int:
	var count := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead:
			count += 1
	return count


func bug_report() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", "0.9.0"))
	return "RELAY//BREACH %s\nseed=%d\nroom_index=%d\nroom=%s\norder=%s\nupgrades=%s\ncontent=%d\npaused=%s\nmode=%s\n" % [
		version, seed_value, room_index, _room_id(), str(order), str(upgrades_picked),
		ContentDB.version(), str(Game.paused), mode,
	]


func _controller_tether() -> void:
	var ids: Array = endpoints.keys()
	if ids.is_empty():
		return
	if Game.edge_cycle:
		cursor = (cursor + 1) % ids.size()
		Game.play_sfx("ui")
	if Game.edge_tether:
		if link_active:
			_break_link("cancel")
			return
		select_endpoint(str(ids[cursor % ids.size()]))


func _tutorial(_dt: float) -> void:
	if _room_id() != "tutorial" or player == null:
		return
	if tutorial_step == 0 and player.global_position.distance_to(spawn_origin) > 1.15:
		tutorial_step = 1
	if tutorial_step == 1 and not bolt_sent:
		bolt_sent = true
		var origin := player.global_position + Vector3(0, 0.4, 6.5)
		var dir := player.global_position - origin
		spawn_projectile(origin, dir, 9.0, 18.0)
	if tutorial_step == 1 and bolt_sent and projectiles.is_empty():
		tutorial_step = 2


func _check_exit() -> void:
	if mode != "play" or player == null or transitioning:
		return
	var kind := str(ContentDB.room(_room_id()).get("kind", ""))
	if kind == "finale":
		return
	if kind == "tutorial":
		exit_open = door_open
	else:
		exit_open = living_enemies() == 0
	if not exit_open:
		return
	if player.global_position.distance_to(exit_pos) > 1.45:
		return
	transitioning = true
	if kind == "clear" and not _remaining_upgrades().is_empty():
		mode = "upgrade"
		hud.show_upgrade(_remaining_upgrades())
		return
	_advance_room()


func _advance_room() -> void:
	room_index += 1
	if room_index >= order.size():
		_victory()
		return
	_build_room()
	mode = "play"
	if hud != null:
		hud.show_play()


func _die() -> void:
	mode = "dead"
	Game.paused = false
	Game.play_sfx("death")
	if hud != null:
		hud.show_dead("Hull failure in %s.\nRetry keeps this seed and your upgrades." % _room_id())


func _victory() -> void:
	if mode == "victory":
		return
	mode = "victory"
	link_active = false
	SaveService.clear_run()
	Game.play_sfx("victory")
	if hud != null:
		hud.show_victory("Extract held.\nSeed %d  ·  time %.0fs  ·  %s" % [seed_value, run_time, ", ".join(upgrades_picked)])


func _remaining_upgrades() -> Array:
	var left: Array = []
	for raw in ContentDB.upgrades():
		var row: Dictionary = raw
		if not upgrades_picked.has(str(row.get("id", ""))):
			left.append(row)
	return left.slice(0, 3)


func _save_boundary() -> void:
	if stress_mode:
		return
	SaveService.save_run({
		"version": SaveCodec.VERSION,
		"content_version": ContentDB.version(),
		"seed": seed_value,
		"room_index": room_index,
		"order": order.duplicate(),
		"upgrades": upgrades_picked.duplicate(),
	})


func _cleanup_dead() -> void:
	var next_enemies: Array = []
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead:
			if is_instance_valid(enemy):
				enemy.get_parent().remove_child(enemy)
				enemy.free()
		else:
			next_enemies.append(enemy)
	enemies = next_enemies
	var next_shots: Array = []
	for shot in projectiles:
		if not is_instance_valid(shot) or shot.dead:
			if is_instance_valid(shot):
				shot.get_parent().remove_child(shot)
				shot.free()
		else:
			next_shots.append(shot)
	projectiles = next_shots


func _refresh_overlay() -> void:
	if hud == null or player == null:
		return
	var charge := -1.0
	if _room_id() == "finale":
		charge = extract_charge / EXTRACT_SECONDS
	hud.set_bars(player.health, player.max_health, player.energy, player.max_energy, charge)
	hud.set_objective(_objective())
	var reason := last_reason
	if selected_id != "" and not link_active:
		reason = "First endpoint set. Pick a legal partner."
	hud.set_reason(TetherRules.reason_text(reason) if reason != "" and reason != "ok" else _status_line())
	hud.set_dev(_dev_text())
	_update_beam()


func _objective() -> String:
	var room: Dictionary = ContentDB.room(_room_id())
	var title := str(room.get("title", _room_id()))
	if _room_id() == "tutorial":
		match tutorial_step:
			0:
				return title + "\nMove with WASD. A is screen-left, D is screen-right."
			1:
				return title + "\nEvade the bolt with Space. You are briefly untouchable."
			2:
				return title + "\nTry to tether the bus to the dump. Read the rejection."
			3:
				return title + "\nTether the bus to the door and hold the link."
			_:
				return title + "\nDoor is open. Step onto the exit pad."
	if str(room.get("kind", "")) == "finale":
		return title + "\nHold reactor to extract. Shield and jammer still work."
	if str(room.get("kind", "")) == "clear":
		return title + "\nClear the bay, then take the exit."
	return title


func _status_line() -> String:
	if link_active:
		return "Link live  %.1fs" % link_time
	if cooldown_left > 0.0:
		return "Recharging"
	if exit_open:
		return "Exit open"
	return "Seed %d" % seed_value


func _dev_text() -> String:
	if not OS.is_debug_build() or not Game.dev_overlay:
		return ""
	var state := "-"
	if not enemies.is_empty():
		state = "%s:%s" % [enemies[0].enemy_id, enemies[0].brain.state]
	var frame := 1000.0 / maxf(float(Engine.get_frames_per_second()), 1.0)
	return "fps %d  %.2f ms\nenemies %d  shots %d\nseed %d  %s\n%s" % [
		Engine.get_frames_per_second(), frame, living_enemies(), projectiles.size(), seed_value, _room_id(), state,
	]


func _follow_camera() -> void:
	var focus := Vector3(13, 1.0, 13)
	if player != null:
		focus = player.global_position + Vector3(0, 1.0, 0)
	var shake := Vector3.ZERO
	if Game.trauma > 0.01 and bool(Game.settings.get("shake", true)):
		shake = Vector3(cosmetic.randf_range(-1, 1), 0, cosmetic.randf_range(-1, 1)) * Game.trauma * 0.22
	cam.global_position = focus + CameraBasis.OFFSET + shake
	cam.look_at(focus, Vector3.UP)


func _update_beam() -> void:
	beam.visible = false
	range_ring.visible = false
	if selected_id != "" and endpoints.has(selected_id):
		range_ring.visible = true
		range_ring.global_position = endpoints[selected_id]["pos"]
		var reach := tether_range()
		range_ring.scale = Vector3(reach / 13.0, 1, reach / 13.0)
	if link_active and endpoints.has(link_a) and endpoints.has(link_b):
		_place_beam(endpoints[link_a]["pos"], endpoints[link_b]["pos"], Color(0.55, 0.95, 1.0))
	elif selected_id != "" and endpoints.has(selected_id):
		var ids: Array = endpoints.keys()
		if not ids.is_empty():
			var other := str(ids[cursor % ids.size()])
			if other != selected_id:
				var preview_reason := _validate_pair(selected_id, other)
				var color := Color(0.4, 0.85, 0.9, 0.45) if preview_reason == "ok" else Color(0.9, 0.35, 0.25, 0.45)
				_place_beam(endpoints[selected_id]["pos"], endpoints[other]["pos"], color)


func _place_beam(a: Vector3, b: Vector3, color: Color) -> void:
	var mid := (a + b) * 0.5 + Vector3(0, 0.8, 0)
	var delta := b - a
	var length := maxf(delta.length(), 0.2)
	beam.visible = true
	beam.global_position = mid
	var dir := delta.normalized()
	var x := dir.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(dir).normalized()
	beam.global_transform = Transform3D(Basis(x, dir, z).orthonormalized(), mid)
	beam.scale = Vector3(0.08, length * 0.5, 0.08)
	var mat := beam.material_override as StandardMaterial3D
	if mat != null:
		mat.albedo_color = color
		mat.emission = color


func _build_stage() -> void:
	world = Node3D.new()
	add_child(world)
	props = Node3D.new()
	props.name = "Props"
	world.add_child(props)
	actors = Node3D.new()
	add_child(actors)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.06, 0.08)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.18, 0.2, 0.24)
	environment.ambient_light_energy = 0.7
	env.environment = environment
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 32, 0)
	sun.light_color = Color(0.75, 0.82, 0.9)
	sun.light_energy = 0.55
	add_child(sun)
	_omni(Vector3(8, 4.5, 6), Color(0.95, 0.55, 0.22), 1.4, 16.0)
	_omni(Vector3(18, 3.5, 18), Color(0.25, 0.75, 0.8), 0.9, 14.0)
	_spawn_floor()
	_spawn_wall(Vector3(-0.6, 1.4, 13), Vector3(1.2, 2.8, 28))
	_spawn_wall(Vector3(26.6, 1.4, 13), Vector3(1.2, 2.8, 28))
	_spawn_wall(Vector3(13, 1.4, -0.6), Vector3(28, 2.8, 1.2))
	_spawn_wall(Vector3(13, 1.4, 26.6), Vector3(28, 2.8, 1.2))
	cam = Camera3D.new()
	cam.current = true
	add_child(cam)
	var axes := CameraBasis.axes_from_offset()
	Game.cam_forward = axes["forward"]
	Game.cam_right = axes["right"]
	beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	beam.mesh = cyl
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.albedo_color = Color(0.5, 0.95, 1, 0.85)
	beam.material_override = bmat
	beam.visible = false
	add_child(beam)
	range_ring = MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 12.7
	tor.outer_radius = 13.0
	range_ring.mesh = tor
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color = Color(0.3, 0.8, 0.85, 0.35)
	range_ring.material_override = rmat
	range_ring.visible = false
	add_child(range_ring)


func _spawn_floor() -> void:
	var mesh_node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(28, 28)
	mesh_node.mesh = plane
	mesh_node.rotation.x = -PI / 2.0
	mesh_node.position = Vector3(13, 0, 13)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _floor_texture()
	mat.albedo_color = Color(0.55, 0.58, 0.62)
	mat.roughness = 0.92
	mesh_node.material_override = mat
	world.add_child(mesh_node)
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(28, 1, 28)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	body.add_child(shape)
	body.position = Vector3(13, 0, 13)
	world.add_child(body)


func _floor_texture() -> ImageTexture:
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var color := Color(0.10, 0.11, 0.13)
			if x % 16 == 0 or y % 16 == 0:
				color = Color(0.18, 0.22, 0.24)
			if y > 46 and y < 50:
				color = Color(0.42, 0.22, 0.1)
			if x > 8 and x < 12:
				color = Color(0.12, 0.28, 0.3)
			image.set_pixel(x, y, color)
	var texture := ImageTexture.create_from_image(image)
	return texture


func _wipe_props() -> void:
	if props == null:
		return
	var doomed: Array = props.get_children()
	for child in doomed:
		props.remove_child(child)
		child.free()


func _paint_trim() -> void:
	for i in 5:
		var box := MeshInstance3D.new()
		box.name = "prop_trim"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.6, 0.15 + cosmetic.randf() * 0.4, 0.6)
		box.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.22, 0.16, 0.12).lerp(Color(0.16, 0.22, 0.24), cosmetic.randf())
		box.material_override = mat
		box.position = Vector3(cosmetic.randf_range(2, 24), 0.1, cosmetic.randf_range(2, 24))
		props.add_child(box)


func _spawn_wall(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.14, 0.13)
	mat.roughness = 0.8
	mesh_node.material_override = mat
	world.add_child(mesh_node)


func _spawn_obstacle(raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var ob: Dictionary = raw
	var at := _xz(ob.get("at", [0, 0])) + Vector3(0, 0.9, 0)
	var dims: Array = ob.get("size", [1, 1])
	var size := Vector3(float(dims[0]), 1.8, float(dims[1] if dims.size() > 1 else dims[0]))
	var body := StaticBody3D.new()
	body.name = "Ob"
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	props.add_child(body)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.18, 0.14)
	mesh_node.material_override = mat
	props.add_child(mesh_node)


func _spawn_player(at: Vector3) -> void:
	var body := CharacterBody3D.new()
	body.set_script(load("res://scripts/game/player.gd"))
	body.position = at
	body.collision_layer = LAYER_PLAYER
	body.collision_mask = LAYER_WORLD
	body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	body.add_to_group("player")
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.15
	shape.shape = cap
	shape.position = Vector3(0, 0.7, 0)
	body.add_child(shape)
	var vis := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.32
	mesh.height = 1.1
	vis.mesh = mesh
	vis.position = Vector3(0, 0.7, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.84, 0.88)
	mat.roughness = 0.4
	vis.material_override = mat
	body.add_child(vis)
	actors.add_child(body)
	body.visual = vis
	body.session = self
	body.configure(ContentDB.player_stats(), upgrades_picked)
	player = body


func _spawn_enemy(raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var def: Dictionary = raw
	var arch := str(def.get("archetype", ""))
	var stats := ContentDB.enemy_stats(arch)
	if stats.is_empty():
		return
	var body := CharacterBody3D.new()
	body.set_script(load("res://scripts/game/enemy_actor.gd"))
	body.position = _xz(def.get("at", [0, 0]))
	body.collision_layer = LAYER_ENEMY
	body.collision_mask = LAYER_WORLD
	body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	actors.add_child(body)
	body.setup(def, stats, self)
	enemies.append(body)


func _spawn_endpoint(raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var def: Dictionary = raw
	var id := str(def.get("id", ""))
	var kind := str(def.get("type", "bus"))
	var pos := _xz(def.get("at", [0, 0])) + Vector3(0, 0.6, 0)
	var area := Area3D.new()
	area.collision_layer = LAYER_ENDPOINT
	area.collision_mask = 0
	area.position = pos
	area.set_meta("eid", id)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.75
	shape.shape = sphere
	area.add_child(shape)
	var mesh_node := MeshInstance3D.new()
	mesh_node.mesh = _endpoint_mesh(kind)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _endpoint_color(kind)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 0.45
	mesh_node.material_override = mat
	area.add_child(mesh_node)
	var label := Label3D.new()
	label.text = _endpoint_glyph(kind) + " " + kind
	label.font_size = 48
	label.position = Vector3(0, 1.15, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.92, 0.94, 0.95)
	area.add_child(label)
	actors.add_child(area)
	endpoints[id] = {"id": id, "type": kind, "pos": pos, "alive": true, "enabled": true, "node": area}


func _endpoint_mesh(kind: String) -> Mesh:
	match kind:
		"door":
			var box := BoxMesh.new()
			box.size = Vector3(0.3, 1.5, 1.1)
			return box
		"dump":
			var box := BoxMesh.new()
			box.size = Vector3(0.7, 0.7, 0.7)
			return box
		"shield_gen":
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.55
			cyl.bottom_radius = 0.55
			cyl.height = 0.35
			return cyl
		"coil":
			var tor := TorusMesh.new()
			tor.inner_radius = 0.28
			tor.outer_radius = 0.48
			return tor
		"jammer":
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.08
			cyl.bottom_radius = 0.28
			cyl.height = 1.3
			return cyl
		"reactor":
			var sphere := SphereMesh.new()
			sphere.radius = 0.55
			sphere.height = 1.1
			return sphere
		"extract":
			var tor := TorusMesh.new()
			tor.inner_radius = 0.45
			tor.outer_radius = 0.7
			return tor
		_:
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.28
			cyl.bottom_radius = 0.28
			cyl.height = 0.9
			return cyl


func _endpoint_color(kind: String) -> Color:
	match kind:
		"door":
			return Color("e39b3a")
		"dump":
			return Color("8a6a78")
		"shield_gen":
			return Color("6aa6ff")
		"coil":
			return Color("e25b48")
		"jammer":
			return Color("f0d060")
		"reactor":
			return Color("f4f1ea")
		"extract":
			return Color("3ec8c8")
		_:
			return Color("3ec8c8")


func _endpoint_glyph(kind: String) -> String:
	match kind:
		"door":
			return "▭"
		"dump":
			return "■"
		"shield_gen":
			return "⬡"
		"coil":
			return "◎"
		"jammer":
			return "↑"
		"reactor":
			return "●"
		"extract":
			return "◌"
		_:
			return "▮"


func _endpoint_view(id: String) -> Dictionary:
	if not endpoints.has(id):
		return {}
	var row: Dictionary = endpoints[id]
	return {
		"id": row["id"],
		"type": row["type"],
		"pos": row["pos"],
		"alive": row["alive"],
		"enabled": row["enabled"],
	}


func _click_world(screen: Vector2) -> void:
	var from := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 80.0)
	query.collision_mask = LAYER_ENDPOINT
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		selected_id = ""
		return
	var collider := hit.get("collider") as Node
	if collider != null and collider.has_meta("eid"):
		select_endpoint(str(collider.get_meta("eid")))


func _on_start() -> void:
	randomize()
	start_run(randi() % 100000 + 1)


func _on_continue() -> void:
	var loaded := SaveService.load_run()
	if not bool(loaded.get("ok", false)):
		return
	var data: Dictionary = loaded.get("data", {})
	if int(data.get("content_version", -1)) != ContentDB.version():
		SaveService.clear_run()
		hud.show_menu(false)
		return
	seed_value = int(data.get("seed", 1))
	order = data.get("order", [])
	room_index = int(data.get("room_index", 0))
	upgrades_picked = data.get("upgrades", [])
	if order.is_empty() or room_index < 0 or room_index >= order.size():
		return
	run_time = 0.0
	stress_mode = false
	_enter_play()


func _on_settings() -> void:
	ui_return = "pause" if Game.paused and mode == "play" else "menu"
	hud.show_settings()
	hud.refresh_binds()


func _on_back() -> void:
	if ui_return == "pause":
		hud.show_play()
		hud.show_pause()
	else:
		hud.show_menu(_has_continue())


func _on_resume() -> void:
	Game.paused = false
	hud.hide_pause()


func _on_retry() -> void:
	restart_room()


func _on_restart_run() -> void:
	_on_start()


func _on_menu() -> void:
	mode = "menu"
	Game.paused = false
	_clear_actors()
	hud.show_menu(_has_continue())


func _on_upgrade(id: String) -> void:
	if not upgrades_picked.has(id):
		upgrades_picked.append(id)
	Game.play_sfx("pickup")
	if player != null:
		player.configure(ContentDB.player_stats(), upgrades_picked)
	_advance_room()


func _on_bind(action: String) -> void:
	Game.listening_action = action
	hud.refresh_binds()


func _has_continue() -> bool:
	var loaded := SaveService.load_run()
	if not bool(loaded.get("ok", false)):
		return false
	var data: Dictionary = loaded.get("data", {})
	return int(data.get("content_version", -1)) == ContentDB.version()


func _poll_host_start() -> void:
	if not OS.has_feature("web"):
		return
	var flag: Variant = JavaScriptBridge.eval("(window.__rbStart||0)", true)
	if int(flag) == 1 and mode == "menu":
		JavaScriptBridge.eval("window.__rbStart=0;", true)
		_on_start()


func _install_web_hooks() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		window.__rbKeys = window.__rbKeys || [];
		window.__controlsTest = window.__controlsTest || {
			getYaw: function(){ return window.__rbYaw || 0; },
			getSpeed: function(){ return window.__rbSpeed || 0; },
			setKeys: function(codes){ window.__rbKeys = codes || []; }
		};
		try { if (window.parent && window.parent !== window) window.parent.__controlsTest = window.__controlsTest; } catch (e) {}
	""", true)


func _omni(at: Vector3, color: Color, energy: float, radius: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	add_child(light)


func _active_pair() -> String:
	if not link_active:
		return ""
	return _pair(str(endpoints[link_a]["type"]), str(endpoints[link_b]["type"]))


func _pair(a: String, b: String) -> String:
	if a <= b:
		return a + "+" + b
	return b + "+" + a


func _id_of_type(kind: String) -> String:
	for id in [link_a, link_b]:
		if endpoints.has(id) and str(endpoints[id]["type"]) == kind:
			return id
	return link_a


func _room_id() -> String:
	if order.is_empty():
		return ""
	return str(order[room_index])


func _xz(at: Variant) -> Vector3:
	if typeof(at) == TYPE_ARRAY and (at as Array).size() >= 2:
		var row: Array = at
		return Vector3(float(row[0]), 0.0, float(row[1]))
	return Vector3.ZERO


func remove_endpoint(id: String) -> void:
	if endpoints.has(id):
		var node: Node = endpoints[id]["node"]
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.free()
		endpoints.erase(id)
	if link_active and (link_a == id or link_b == id):
		_break_link("missing")
