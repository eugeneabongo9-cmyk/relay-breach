extends CharacterBody3D

var health: float = 100.0
var max_health: float = 100.0
var energy: float = 100.0
var max_energy: float = 100.0
var regen: float = 12.0
var move_speed: float = 7.4
var accel: float = 52.0
var friction: float = 40.0
var evade_speed: float = 16.0
var evade_time: float = 0.2
var evade_iframes: float = 0.18
var evade_cd_base: float = 0.9
var shock_damage: float = 13.0
var shock_range: float = 2.6
var shock_cd_base: float = 0.4
var iframe_left: float = 0.0
var evade_cd: float = 0.0
var shock_cd: float = 0.0
var evading: bool = false
var evade_t: float = 0.0
var evade_dir: Vector3 = Vector3.ZERO
var facing: Vector3 = Vector3(0, 0, -1)
var session: Node = null
var visual: MeshInstance3D
var _base_scale: Vector3 = Vector3.ONE


func configure(stats: Dictionary, picked: Array) -> void:
	max_health = float(stats.get("max_health", 100))
	max_energy = float(stats.get("max_energy", 100))
	regen = float(stats.get("energy_regen", 12))
	move_speed = float(stats.get("move_speed", 7.4))
	accel = float(stats.get("accel", 52))
	friction = float(stats.get("friction", 40))
	evade_speed = float(stats.get("evade_speed", 16))
	evade_time = float(stats.get("evade_time", 0.2))
	evade_iframes = float(stats.get("evade_iframes", 0.18))
	evade_cd_base = float(stats.get("evade_cooldown", 0.9))
	shock_damage = float(stats.get("shock_damage", 13))
	shock_range = float(stats.get("shock_range", 2.6))
	shock_cd_base = float(stats.get("shock_cooldown", 0.4))
	if picked.has("capacitor"):
		max_energy += 40.0
	if picked.has("phase_step"):
		evade_cd_base = maxf(0.2, evade_cd_base - 0.28)
	health = max_health
	energy = max_energy


func tick(dt: float) -> void:
	iframe_left = CombatRules.advance(iframe_left, dt, false)
	evade_cd = CombatRules.advance(evade_cd, dt, false)
	shock_cd = CombatRules.advance(shock_cd, dt, false)
	if not evading:
		energy = minf(max_energy, energy + regen * dt)
	var wish := Game.wish_dir()
	if wish.length() > 0.15:
		facing = wish.normalized()
	if Game.edge_evade and evade_cd <= 0.0 and not evading:
		evading = true
		evade_t = 0.0
		evade_cd = evade_cd_base
		iframe_left = maxf(iframe_left, evade_iframes)
		evade_dir = facing
		Game.play_sfx("evade")
	if Game.edge_shock and shock_cd <= 0.0:
		shock_cd = shock_cd_base
		Game.play_sfx("shock")
		if session != null:
			session.call("on_player_shock", global_position, shock_range, shock_damage)
	if evading:
		evade_t += dt
		velocity = evade_dir * evade_speed
		if evade_t >= evade_time:
			evading = false
	else:
		var rate := accel if wish.length() > 0.15 else friction
		var flat := Vector3(velocity.x, 0.0, velocity.z)
		flat = flat.move_toward(wish * move_speed, rate * dt)
		velocity = flat
	velocity.y = 0.0
	# move_and_slide travels by the engine physics delta, not this dt.
	# A headless tick loop would then depend on wall-clock frame time.
	_slide(dt)
	if visual != null and facing.length() > 0.1:
		visual.look_at(visual.global_position + Vector3(facing.x, 0.0, facing.z), Vector3.UP)
		var pulse := 1.0 + (0.18 if iframe_left > 0.0 else 0.0)
		visual.scale = _base_scale * pulse


func hurt(amount: float) -> bool:
	var result := CombatRules.apply_damage(health, amount, iframe_left)
	health = float(result["health"])
	if bool(result["hit"]):
		Game.play_sfx("hurt")
		Game.add_trauma(0.28)
		if session != null:
			session.call("on_player_hurt")
	return bool(result["hit"])


func _slide(dt: float) -> void:
	var motion := velocity * dt
	for _step in 4:
		if motion.length() < 0.0001:
			return
		var hit := move_and_collide(motion)
		if hit == null:
			return
		var normal := hit.get_normal()
		motion = hit.get_remainder().slide(normal)
		velocity = velocity.slide(normal)
		velocity.y = 0.0
