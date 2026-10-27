class_name CombatRules
extends RefCounted
## Damage and timer rules. Pause freezes these timers.
## Hit-stop / trauma is not an input: presentation must not call this.


static func apply_damage(health: float, amount: float, iframe_left: float) -> Dictionary:
	if iframe_left > 0.0 or amount <= 0.0:
		return {"health": health, "hit": false}
	return {"health": maxf(0.0, health - amount), "hit": true}


static func advance(remaining: float, dt: float, paused: bool) -> float:
	if paused or dt <= 0.0:
		return remaining
	return maxf(0.0, remaining - dt)
