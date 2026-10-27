class_name TetherRules
extends RefCounted
## Pure tether checks. Callers supply positions and line of sight.


static func pair_allowed(pairs: Array, type_a: String, type_b: String) -> bool:
	for raw in pairs:
		if typeof(raw) != TYPE_ARRAY or (raw as Array).size() < 2:
			continue
		var row: Array = raw
		var a := str(row[0])
		var b := str(row[1])
		if (a == type_a and b == type_b) or (a == type_b and b == type_a):
			return true
	return false


static func validate(endpoint_a: Dictionary, endpoint_b: Dictionary, ctx: Dictionary) -> String:
	if endpoint_a.is_empty() or endpoint_b.is_empty():
		return "missing"
	if not bool(endpoint_a.get("alive", true)) or not bool(endpoint_b.get("alive", true)):
		return "missing"
	if str(endpoint_a.get("id", "")) == str(endpoint_b.get("id", "")):
		return "same"
	if not bool(endpoint_a.get("enabled", true)) or not bool(endpoint_b.get("enabled", true)):
		return "disabled"
	if bool(ctx.get("link_active", false)):
		return "busy"
	if float(ctx.get("cooldown_left", 0.0)) > 0.0001:
		return "cooldown"
	var pairs: Array = ctx.get("pairs", [])
	if not pair_allowed(pairs, str(endpoint_a.get("type", "")), str(endpoint_b.get("type", ""))):
		return "incompatible"
	var pos_a: Vector3 = endpoint_a.get("pos", Vector3.ZERO)
	var pos_b: Vector3 = endpoint_b.get("pos", Vector3.ZERO)
	if pos_a.distance_to(pos_b) > float(ctx.get("range", 0.0)) + 0.001:
		return "range"
	if bool(ctx.get("los_required", true)) and not bool(ctx.get("los_clear", false)):
		return "los"
	if float(ctx.get("energy", 0.0)) + 0.0001 < float(ctx.get("energy_cost", 0.0)):
		return "energy"
	return "ok"


static func reason_text(reason: String) -> String:
	match reason:
		"ok":
			return "Link ready"
		"same":
			return "Pick two different endpoints"
		"incompatible":
			return "These endpoints cannot be paired"
		"range":
			return "Out of tether range"
		"los":
			return "Line of sight blocked"
		"energy":
			return "Not enough energy"
		"cooldown":
			return "Tether recharging"
		"busy":
			return "A link is already active"
		"missing":
			return "Endpoint is gone"
		"disabled":
			return "Endpoint is disabled"
		_:
			return "Cannot link"
