extends CharacterBody3D

var archetype: String = "pursuer"
var enemy_id: String = ""
var health: float = 10.0
var max_health: float = 10.0
var speed: float = 0.0
var damage: float = 0.0
var tuning: Dictionary = {}
var brain: EnemyBrain = EnemyBrain.new()
var shielded: bool = false
var base_shielded: bool = false
var suppressed: bool = false
var facing: Vector3 = Vector3(1, 0, 0)
var session: Node = null
var dead: bool = false
var attack_dir: Vector3 = Vector3.ZERO
var heal_ready: float = 1.2
var _hit_done: bool = false
var _was_attack: bool = false
var last_pos: Vector3 = Vector3.ZERO
var visual: MeshInstance3D
var shield_mesh: MeshInstance3D
var ring: MeshInstance3D
var bang: Label3D


func setup(def: Dictionary, arch: Dictionary, owner: Node) -> void:
	archetype = str(def.get("archetype", "pursuer"))
	enemy_id = str(def.get("id", ""))
	tuning = arch
	health = float(arch.get("health", 40))
	max_health = health
	speed = float(arch.get("speed", 0))
	damage = float(arch.get("damage", arch.get("heal", 0)))
	base_shielded = bool(def.get("shielded", false))
	shielded = base_shielded
	session = owner
	last_pos = global_position
	_build_visual(str(arch.get("color", "#cccccc")))


func tick(dt: float) -> void:
	if dead:
		return
	heal_ready = maxf(0.0, heal_ready - dt)
	suppressed = archetype == "support" and session != null and bool(session.call("is_jammer_active"))
	if session != null and bool(session.call("is_shield_link_active")):
		shielded = false
	else:
		shielded = base_shielded
	if shield_mesh != null:
		shield_mesh.visible = shielded
	var target: Vector3 = session.call("player_position")
	var flat := Vector2(global_position.x - target.x, global_position.z - target.z)
	var dist := flat.length()
	var moved := Vector2(global_position.x - last_pos.x, global_position.z - last_pos.z).length()
	var perceive := dist <= float(tuning.get("perception", 16.0))
	var should_heal := archetype == "support" and heal_ready <= 0.0 and bool(session.call("ally_needs_heal"))
	var prev_state := brain.state
	var intent := brain.step(dt, archetype, dist, moved, perceive, should_heal, suppressed, tuning)
	var to := target - global_position
	to.y = 0.0
	if to.length() > 0.05 and intent != "sidestep":
		facing = to.normalized()
	if intent == "sidestep":
		var side := facing.cross(Vector3.UP).normalized() * brain.side_sign
		if side.length() < 0.1:
			side = Vector3(1, 0, 0) * brain.side_sign
		velocity = side * maxf(speed, 3.2)
	elif intent == "move":
		velocity = facing * speed
	elif intent == "lunge":
		velocity = attack_dir * 13.5
	else:
		velocity = velocity.move_toward(Vector3.ZERO, 40.0 * dt)
	velocity.y = 0.0
	move_and_slide()
	last_pos = global_position
	if brain.state == "attack" and prev_state != "attack":
		_on_attack_begin()
	if brain.state != "attack":
		_hit_done = false
	elif archetype == "pursuer" and not _hit_done and dist <= float(tuning.get("melee", 2.15)):
		session.call("damage_player", damage)
		_hit_done = true
		Game.add_trauma(0.16)
	_was_attack = brain.state == "attack"
	_update_ring(intent)
	if visual != null and facing.length() > 0.1:
		visual.look_at(visual.global_position + facing, Vector3.UP)


func hurt(amount: float) -> void:
	if dead or shielded or amount <= 0.0:
		return
	health -= amount
	Game.add_trauma(0.08)
	if health <= 0.0:
		health = 0.0
		dead = true
		visible = false
		collision_layer = 0
		collision_mask = 0


func _on_attack_begin() -> void:
	attack_dir = facing
	if archetype == "sentinel":
		var speed_p := float(tuning.get("projectile_speed", 11.5))
		session.call("spawn_projectile", global_position + Vector3(0, 0.8, 0), facing, speed_p, damage)
	elif archetype == "support":
		session.call("heal_allies", float(tuning.get("heal", 16)))
		heal_ready = float(tuning.get("pulse_cd", 4.4))
		Game.play_sfx("danger")


func _update_ring(intent: String) -> void:
	if ring == null:
		return
	var show := intent == "telegraph" or intent == "lunge" or intent == "shoot" or intent == "heal"
	ring.visible = show
	if bang != null:
		bang.visible = intent == "telegraph"
	if intent == "telegraph":
		var limit := maxf(float(tuning.get("telegraph", 0.5)), 0.05)
		var k := clampf(brain.state_time / limit, 0.0, 1.0)
		ring.scale = Vector3.ONE * lerpf(0.25, 1.15, k)


func _build_visual(hex: String) -> void:
	visual = MeshInstance3D.new()
	var mesh: Mesh
	if archetype == "sentinel":
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.18
		cyl.bottom_radius = 0.42
		cyl.height = 1.7
		mesh = cyl
	elif archetype == "support":
		var sphere := SphereMesh.new()
		sphere.radius = 0.42
		sphere.height = 0.9
		mesh = sphere
	else:
		var box := BoxMesh.new()
		box.size = Vector3(1.15, 0.62, 1.45)
		mesh = box
	visual.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.html(hex)
	mat.roughness = 0.55
	visual.material_override = mat
	visual.position = Vector3(0, 0.7, 0)
	add_child(visual)
	shield_mesh = MeshInstance3D.new()
	var shell := CylinderMesh.new()
	shell.top_radius = 0.72
	shell.bottom_radius = 0.72
	shell.height = 1.5
	shield_mesh.mesh = shell
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.45, 0.75, 1.0, 0.18)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shield_mesh.material_override = smat
	shield_mesh.position = Vector3(0, 0.8, 0)
	shield_mesh.visible = shielded
	add_child(shield_mesh)
	ring = MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.55
	tor.outer_radius = 0.72
	ring.mesh = tor
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.95, 0.55, 0.2)
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rmat
	ring.position = Vector3(0, 0.08, 0)
	ring.visible = false
	add_child(ring)
	bang = Label3D.new()
	bang.text = "!"
	bang.font_size = 96
	bang.position = Vector3(0, 2.0, 0)
	bang.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bang.modulate = Color(1, 0.85, 0.4)
	bang.visible = false
	add_child(bang)
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.3
	shape.shape = cap
	shape.position = Vector3(0, 0.7, 0)
	add_child(shape)
