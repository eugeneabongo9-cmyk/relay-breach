extends SceneTree
## Headless rules, lifecycle, and a scripted playthrough. No "win now" shortcut.

var failed: int = 0
var passed: int = 0
var _save
var _game


func _initialize() -> void:
	_save = root.get_node("SaveService")
	_game = root.get_node("Game")
	_rules()
	await _scene()
	print("RESULT passed=%d failed=%d" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _rules() -> void:
	var tether: Dictionary = {
		"pairs": [["shield_gen", "dump"], ["bus", "door"], ["reactor", "extract"]],
		"range": 13.0,
		"energy_cost": 18.0,
		"los_required": true,
	}
	var bus := {"id": "a", "type": "bus", "pos": Vector3(0, 0, 0), "alive": true, "enabled": true}
	var door := {"id": "b", "type": "door", "pos": Vector3(6, 0, 0), "alive": true, "enabled": true}
	var dump := {"id": "c", "type": "dump", "pos": Vector3(1, 0, 0), "alive": true, "enabled": true}
	var far := {"id": "d", "type": "door", "pos": Vector3(40, 0, 0), "alive": true, "enabled": true}
	var ctx := {
		"pairs": tether["pairs"], "range": 13.0, "energy": 100.0, "energy_cost": 18.0,
		"cooldown_left": 0.0, "link_active": false, "los_required": true, "los_clear": true,
	}
	_eq(TetherRules.validate(bus, door, ctx), "ok", "compatible link")
	_eq(TetherRules.validate(bus, bus, ctx), "same", "same endpoint")
	_eq(TetherRules.validate(bus, dump, ctx), "incompatible", "incompatible pair")
	_eq(TetherRules.validate(bus, far, ctx), "range", "range boundary")
	var broke: Dictionary = ctx.duplicate()
	broke["los_clear"] = false
	_eq(TetherRules.validate(bus, door, broke), "los", "blocked sight")
	broke = ctx.duplicate()
	broke["energy"] = 17.9
	_eq(TetherRules.validate(bus, door, broke), "energy", "energy below cost")
	broke["energy"] = 18.0
	_eq(TetherRules.validate(bus, door, broke), "ok", "energy exact cost")
	broke = ctx.duplicate()
	broke["cooldown_left"] = 0.01
	_eq(TetherRules.validate(bus, door, broke), "cooldown", "cooldown boundary")
	broke = ctx.duplicate()
	broke["link_active"] = true
	_eq(TetherRules.validate(bus, door, broke), "busy", "one active link")
	var gone := door.duplicate()
	gone["alive"] = false
	_eq(TetherRules.validate(bus, gone, ctx), "missing", "endpoint gone")
	var off := door.duplicate()
	off["enabled"] = false
	_eq(TetherRules.validate(bus, off, ctx), "disabled", "endpoint disabled")

	var iframe := CombatRules.advance(0.01, 0.02, false)
	_ok(is_zero_approx(iframe), "iframe expires on the boundary")
	_ok(is_equal_approx(CombatRules.advance(0.01, 0.02, true), 0.01), "pause holds timers")
	var blocked: Dictionary = CombatRules.apply_damage(100, 10, 0.01)
	_ok(not bool(blocked["hit"]), "iframe blocks damage")
	var hit: Dictionary = CombatRules.apply_damage(100, 10, 0.0)
	_ok(is_equal_approx(float(hit["health"]), 90.0), "damage applies at zero iframe")

	var tuning := {"telegraph": 0.5, "attack": 0.28, "recover": 0.48, "melee": 2.15, "stuck_time": 1.35, "range": 13.5}
	var brain := EnemyBrain.new()
	var intent := brain.step(0.1, "pursuer", 1.0, 1.0, true, false, false, tuning)
	_eq(brain.state, "telegraph", "pursuer telegraphs in melee")
	_eq(intent, "telegraph", "telegraph intent")
	brain.step(0.5, "pursuer", 1.0, 1.0, true, false, false, tuning)
	_eq(brain.state, "attack", "telegraph reaches attack")
	brain.step(0.28, "pursuer", 1.0, 1.0, true, false, false, tuning)
	_eq(brain.state, "recover", "attack reaches recover")
	var stuck := EnemyBrain.new()
	var saw := false
	for _i in 100:
		intent = stuck.step(1.0 / 60.0, "pursuer", 6.0, 0.0, true, false, false, tuning)
		if intent == "sidestep" or stuck.state == "sidestep":
			saw = true
			break
	_ok(saw, "unreachable pursuer sidesteps")
	var sentinel := EnemyBrain.new()
	sentinel.step(0.1, "sentinel", 4.0, 0.0, true, false, false, tuning)
	_eq(sentinel.state, "telegraph", "sentinel winds up in range")
	var support := EnemyBrain.new()
	var suppressed := support.step(0.1, "support", 3.0, 0.0, true, true, true, tuning)
	_eq(suppressed, "idle", "suppressed support does not heal")

	var pool := ["shield", "coil", "support", "mixed"]
	var first := RunGenerator.order_for(7, pool)
	var cosmetic := RunGenerator.cosmetic_rng(7)
	var sample := cosmetic.randf()
	var again := RunGenerator.order_for(7, pool)
	_eq(str(first), str(again), "seed repeats")
	var reroll := RunGenerator.cosmetic_rng(7)
	_ok(is_equal_approx(reroll.randf(), sample), "cosmetic stream ignores room rng")
	var distinct := {}
	for s in range(1, 33):
		var order := RunGenerator.order_for(s, pool)
		_eq(str(order[0]), "tutorial", "seed %d starts in tutorial" % s)
		_eq(str(order[order.size() - 1]), "finale", "seed %d ends in finale" % s)
		_eq(order.size(), 6, "seed %d room count" % s)
		distinct[str(order)] = true
		var seen := {}
		for room_id in order:
			_ok(not seen.has(room_id), "no duplicate room in seed %d" % s)
			seen[room_id] = true
	_ok(distinct.size() > 1, "seeds change order")

	var v0: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/fixtures/save_v0.json"))
	var migrated := SaveCodec.inspect(v0)
	_ok(bool(migrated["ok"]), "v0 migrates")
	_eq(int(migrated["data"]["version"]), 1, "migrated version")
	_eq(int(migrated["data"]["seed"]), 42, "migrated seed")
	_ok((migrated["data"]["upgrades"] as Array).has("capacitor"), "migrated upgrade")
	var newer := SaveCodec.inspect({"version": 9, "seed": 1})
	_eq(str(newer["reason"]), "newer", "newer save refused")
	_eq(str(SaveCodec.inspect("nope")["reason"]), "malformed", "malformed save")
	_eq(str(SaveCodec.inspect({})["reason"]), "malformed", "empty save")

	var good: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
	var good_errors: Array = ContentValidator.validate(good)
	_ok(good_errors.is_empty(), "content solvable: %s" % str(good_errors))
	var bad: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/fixtures/invalid_room.json"))
	var bad_errors: Array = ContentValidator.validate(bad)
	_ok(bad_errors.size() >= 3, "invalid fixture is rejected")
	var blob := str(bad_errors)
	_ok(blob.find("duplicate") >= 0, "duplicate ids reported")
	_ok(blob.find("not_real") >= 0 or blob.find("archetype") >= 0, "unknown archetype reported")
	_ok(blob.find("missing_room") >= 0, "missing room reported")
	_ok(blob.find("unsolvable") >= 0, "unsolvable link reported")

	var axes := CameraBasis.axes_from_offset(Vector3(12, 16, 12))
	var forward: Vector3 = axes["forward"]
	var right: Vector3 = axes["right"]
	var yaw_w := CameraBasis.yaw_of(forward)
	var yaw_a := CameraBasis.yaw_of((forward - right).normalized())
	var yaw_d := CameraBasis.yaw_of((forward + right).normalized())
	_ok(_wrap(yaw_a - yaw_w) > 0.05, "A increases yaw")
	_ok(_wrap(yaw_d - yaw_w) < -0.05, "D decreases yaw")

	_save.run_path = "user://test_run.json"
	_save.settings_path = "user://test_settings.json"
	_unlink("user://test_run.json")
	_unlink("user://test_settings.json")
	var missing: Dictionary = _save.load_run()
	_eq(str(missing["reason"]), "missing", "missing run")
	var payload := {"version": 1, "content_version": 1, "seed": 3, "room_index": 2, "order": ["tutorial", "finale"], "upgrades": ["arc_lens"]}
	_ok(_save.save_run(payload), "save writes")
	var second: Dictionary = payload.duplicate()
	second["seed"] = 8
	_ok(_save.save_run(second), "atomic replace")
	_ok(FileAccess.file_exists("user://test_run.json.bak"), "previous save kept as bak")
	var loaded: Dictionary = _save.load_run()
	_eq(int(loaded["data"]["seed"]), 8, "round trip seed")
	_eq(int(loaded["data"]["room_index"]), 2, "round trip room")
	var settings_ok: bool = _save.save_settings(_save.default_settings())
	_ok(settings_ok, "settings write")
	var settings_loaded: Dictionary = _save.load_settings()
	_ok(bool(settings_loaded["ok"]), "settings load")
	_ok(is_equal_approx(float(settings_loaded["data"]["music"]), 0.4), "settings default music")
	var corrupt := FileAccess.open("user://test_run.json", FileAccess.WRITE)
	corrupt.store_string("{{{")
	corrupt.close()
	_eq(str(_save.load_run()["reason"]), "malformed", "corrupt run refused")


func _scene() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: Node3D = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.set_physics_process(false)
	_ok(main.cam != null, "camera exists")
	main.start_run(4)
	_game.set_qa_codes(["KeyW"])
	for _i in 45:
		main._sim(1.0 / 60.0)
	_ok(_game.probe_speed() > 0.4, "W moves the engineer")
	var yaw_before: float = _game.probe_yaw()
	_game.set_qa_codes(["KeyW", "KeyA"])
	for _i in 25:
		main._sim(1.0 / 60.0)
	_ok(_wrap(_game.probe_yaw() - yaw_before) > 0.05, "held A strafes screen-left")
	yaw_before = _game.probe_yaw()
	_game.set_qa_codes(["KeyW", "KeyD"])
	for _i in 25:
		main._sim(1.0 / 60.0)
	_ok(_wrap(_game.probe_yaw() - yaw_before) < -0.05, "held D strafes screen-right")
	_game.clear_qa()

	main.start_run(9)
	_eq(main._room_id(), "tutorial", "run starts on tutorial")
	_drive(main, main.spawn_origin + _game.cam_forward * 3.4, 90)
	for _i in 200:
		main._sim(1.0 / 60.0)
		if main.tutorial_step >= 2:
			break
	_ok(main.tutorial_step >= 2, "tutorial teaches the bolt")
	_eq(main.select_endpoint("tut_bus"), "ok", "select bus")
	_eq(main.select_endpoint("tut_dump"), "incompatible", "dump is rejected")
	_eq(main.tutorial_step, 3, "rejection advances the lesson")
	_eq(main.select_endpoint("tut_door"), "ok", "door link accepted")
	for _i in 50:
		main._sim(1.0 / 60.0)
	_ok(main.door_open, "door opens by holding the link")
	_drive(main, main.exit_pos, 520)
	var advanced: bool = int(main.room_index) >= 1 or str(main.mode) == "upgrade"
	_ok(advanced, "tutorial exit enters the run (idx %s mode %s)" % [str(main.room_index), str(main.mode)])

	main.stress_mode = false
	main.order = ["shield"]
	main.room_index = 0
	main.upgrades_picked = []
	main.restart_room()
	_eq(main._room_id(), "shield", "shield room")
	var shield_before := _node_count()
	main.player.energy = main.player.max_energy
	_eq(main.select_endpoint("s_gen"), "ok", "select generator")
	_eq(main.select_endpoint("s_dump"), "ok", "shield link")
	main._sim(1.0 / 60.0)
	var sentinel: Node = _enemy(main, "s_sent")
	_ok(sentinel != null and not sentinel.shielded, "shield link exposes the sentinel")
	var hp := float(sentinel.health)
	sentinel.hurt(12.0)
	_ok(float(sentinel.health) < hp, "exposed sentinel takes damage")
	main._break_link("cancel")
	main._sim(1.0 / 60.0)
	_ok(sentinel.shielded, "shield returns when the link drops")
	hp = float(sentinel.health)
	sentinel.hurt(12.0)
	_ok(is_equal_approx(float(sentinel.health), hp), "shield blocks shock")
	main.remove_endpoint("s_dump")
	_ok(not main.link_active, "missing endpoint cancels the link")

	for _i in 10:
		main.restart_room()
	var shield_after := _node_count()
	_ok(abs(shield_after - shield_before) < 8, "restart does not leak nodes (%d -> %d props %d)" % [shield_before, shield_after, main.props.get_child_count()])

	main.cooldown_left = 1.25
	_game.paused = true
	main._physics_process(0.5)
	_ok(is_equal_approx(main.cooldown_left, 1.25), "paused tree does not tick cooldown")
	_game.paused = false

	main.order = ["finale"]
	main.room_index = 0
	main.restart_room()
	_silence(main)
	main.player.energy = 400.0
	main.player.max_energy = 400.0
	main.select_endpoint("f_reactor")
	var linked: String = main.select_endpoint("f_extract")
	_eq(linked, "ok", "finale extract link")
	for _i in 280:
		if main.player != null:
			main.player.energy = 400.0
		main._sim(1.0 / 60.0)
		if main.mode == "victory":
			break
	_eq(main.mode, "victory", "holding the extract wins")

	main.order = ["stress"]
	main.room_index = 0
	main.stress_mode = true
	main.restart_room()
	_ok(main.living_enemies() == 24, "stress yard spawns 24")
	var samples: Array = []
	for _i in 120:
		var t0 := Time.get_ticks_usec()
		main._sim(1.0 / 60.0)
		samples.append(Time.get_ticks_usec() - t0)
	samples.sort()
	var median: int = samples[samples.size() / 2]
	var p95: int = samples[int(samples.size() * 0.95)]
	var p99: int = samples[mini(samples.size() - 1, int(samples.size() * 0.99))]
	print("LOGIC_STRESS n=24 ticks=120 median_us=%d p95_us=%d p99_us=%d" % [median, p95, p99])
	_ok(median < 8000, "stress logic tick stays interactive in this headless run")
	_game.clear_qa()


func _drive(main: Node, target: Vector3, frames: int) -> void:
	for _i in frames:
		if main.player == null:
			return
		var delta: Vector3 = target - main.player.global_position
		delta.y = 0.0
		if delta.length() < 0.8:
			_game.qa_override_on = false
			return
		_game.qa_override = delta.normalized()
		_game.qa_override_on = true
		main._sim(1.0 / 60.0)
	_game.qa_override_on = false


func _silence(main: Node) -> void:
	var doomed: Array = main.enemies.duplicate()
	for enemy in doomed:
		enemy.dead = true
	main._cleanup_dead()


func _enemy(main: Node, id: String) -> Node:
	for enemy in main.enemies:
		if str(enemy.enemy_id) == id:
			return enemy
	return null


func _node_count() -> int:
	var count := 0
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		count += 1
		for child in node.get_children():
			stack.append(child)
	return count


func _unlink(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _wrap(angle: float) -> float:
	return atan2(sin(angle), cos(angle))


func _ok(cond: bool, label: String) -> void:
	if cond:
		passed += 1
		print("ok - %s" % label)
	else:
		failed += 1
		push_error("not ok - %s" % label)
		print("not ok - %s" % label)


func _eq(got: Variant, want: Variant, label: String) -> void:
	if got == want:
		_ok(true, label)
	else:
		_ok(false, "%s (got %s want %s)" % [label, str(got), str(want)])
