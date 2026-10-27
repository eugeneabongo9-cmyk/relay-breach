class_name CameraBasis
extends RefCounted
## Fixed isometric offset. Axes are cached from this offset so shake cannot
## change which way A and D strafe. Godot cameras look down -Z.

const OFFSET := Vector3(12, 16, 12)


static func axes_from_offset(offset: Vector3 = OFFSET) -> Dictionary:
	var cam := Camera3D.new()
	cam.look_at_from_position(offset, Vector3.ZERO, Vector3.UP)
	var basis := cam.transform.basis
	var right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
	var look := -basis.z
	var forward := Vector3(look.x, 0.0, look.z).normalized()
	cam.free()
	return {"forward": forward, "right": right}


static func yaw_of(velocity: Vector3) -> float:
	return atan2(-velocity.x, -velocity.z)
