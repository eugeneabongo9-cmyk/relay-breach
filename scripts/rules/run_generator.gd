class_name RunGenerator
extends RefCounted
## Seeded room order. Cosmetic randomness must use `cosmetic_rng`, never this stream.


static func order_for(seed_value: int, pool: Array) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var items: Array = []
	for entry in pool:
		items.append(entry)
	for i in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp
	var out: Array = ["tutorial"]
	out.append_array(items)
	out.append("finale")
	return out


static func cosmetic_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	# Distinct stream so palette noise cannot change room order or upgrade rolls.
	rng.seed = int(seed_value) ^ 0x5A17C0DE
	return rng
