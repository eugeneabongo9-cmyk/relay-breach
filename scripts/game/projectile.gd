extends Node3D

var velocity: Vector3 = Vector3.ZERO
var damage: float = 0.0
var life: float = 2.8
var session: Node = null
var dead: bool = false


func setup(origin: Vector3, direction: Vector3, speed: float, amount: float, owner: Node) -> void:
	global_position = origin
	var dir := direction
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3(1, 0, 0)
	velocity = dir.normalized() * speed
	damage = amount
	session = owner
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.72, 0.25)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.15)
	mat.emission_energy_multiplier = 2.0
	mesh.material_override = mat
	add_child(mesh)


func tick(dt: float) -> void:
	if dead:
		return
	var next := global_position + velocity * dt
	if session != null and bool(session.call("segment_hits_world", global_position, next)):
		dead = true
		return
	global_position = next
	life -= dt
	if life <= 0.0:
		dead = true
		return
	var player_pos: Vector3 = session.call("player_position")
	if global_position.distance_to(player_pos) < 0.62:
		session.call("damage_player", damage)
		Game.play_sfx("danger")
		dead = true
