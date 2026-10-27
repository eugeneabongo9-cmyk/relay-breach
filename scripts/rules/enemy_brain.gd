class_name EnemyBrain
extends RefCounted
## Finite-state brain with no scene dependency.
## States: idle, chase, telegraph, attack, recover, sidestep.
## Perception is a distance gate supplied by the body. Stuck recovery fires
## when a move intent fails to displace the body for `stuck_time` seconds.

var state: String = "idle"
var state_time: float = 0.0
var stuck_time: float = 0.0
var side_sign: float = 1.0


func reset() -> void:
	state = "idle"
	state_time = 0.0
	stuck_time = 0.0
	side_sign = 1.0


func step(
	dt: float,
	kind: String,
	dist: float,
	moved: float,
	can_perceive: bool,
	should_heal: bool,
	suppressed: bool,
	tuning: Dictionary
) -> String:
	var telegraph: float = float(tuning.get("telegraph", 0.5))
	var attack: float = float(tuning.get("attack", 0.25))
	var recover: float = float(tuning.get("recover", 0.4))
	var stuck_limit: float = float(tuning.get("stuck_time", 1.35))
	var melee: float = float(tuning.get("melee", 2.15))
	var ranged: float = float(tuning.get("range", 13.5))
	state_time += dt

	if state == "sidestep":
		if state_time >= 0.45:
			_enter("chase")
			return "move"
		return "sidestep"

	if state == "telegraph":
		if state_time >= telegraph:
			_enter("attack")
			return _attack_intent(kind)
		return "telegraph"

	if state == "attack":
		if state_time >= attack:
			_enter("recover")
			return "recover"
		return _attack_intent(kind)

	if state == "recover":
		if state_time >= recover:
			_enter("idle")
		return "recover"

	if kind == "sentinel":
		if can_perceive and dist <= ranged:
			_enter("telegraph")
			return "telegraph"
		_enter("idle")
		return "idle"

	if kind == "support":
		if suppressed:
			stuck_time = 0.0
			_enter("idle")
			return "idle"
		if should_heal:
			_enter("telegraph")
			return "telegraph"
		if can_perceive and dist > 5.5:
			_enter_keep("chase")
			if _track_stuck(moved, dt, stuck_limit):
				return "sidestep"
			return "move"
		_enter("idle")
		return "idle"

	if not can_perceive:
		stuck_time = 0.0
		_enter("idle")
		return "idle"
	if dist > melee:
		_enter_keep("chase")
		if _track_stuck(moved, dt, stuck_limit):
			return "sidestep"
		return "move"
	_enter("telegraph")
	return "telegraph"


func _attack_intent(kind: String) -> String:
	if kind == "sentinel":
		return "shoot"
	if kind == "support":
		return "heal"
	return "lunge"


func _enter(next: String) -> void:
	if state != next:
		state = next
		state_time = 0.0


func _enter_keep(next: String) -> void:
	if state != next:
		state = next
		state_time = 0.0


func _track_stuck(moved: float, dt: float, limit: float) -> bool:
	if moved < 0.02:
		stuck_time += dt
	else:
		stuck_time = 0.0
	if stuck_time >= limit:
		stuck_time = 0.0
		side_sign = -side_sign
		state = "sidestep"
		state_time = 0.0
		return true
	return false
