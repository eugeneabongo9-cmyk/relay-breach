class_name ContentValidator
extends RefCounted
## Authoring checks: ids, tuning references, and solvable required links.


static func validate(data: Dictionary) -> Array:
	var errors: Array = []
	if data.is_empty():
		errors.append("empty content")
		return errors
	var rooms: Dictionary = data.get("rooms", {})
	if typeof(rooms) != TYPE_DICTIONARY:
		errors.append("rooms missing")
		return errors
	var seen_up: Dictionary = {}
	for raw_u in data.get("upgrades", []):
		if typeof(raw_u) != TYPE_DICTIONARY:
			errors.append("upgrade is not an object")
			continue
		var uid := str((raw_u as Dictionary).get("id", ""))
		if uid == "" or seen_up.has(uid):
			errors.append("duplicate upgrade id %s" % uid)
		seen_up[uid] = true
	var enemies: Dictionary = data.get("enemies", {})
	for room_name in data.get("encounter_pool", []):
		if not rooms.has(str(room_name)):
			errors.append("encounter pool missing room %s" % str(room_name))
	var tether: Dictionary = data.get("tether", {})
	var reach: float = float(tether.get("range", 0.0))
	var pairs: Array = tether.get("pairs", [])
	if reach <= 0.0:
		errors.append("tether range must be positive")
	for room_id in rooms.keys():
		var room: Dictionary = rooms[room_id]
		errors.append_array(_room(str(room_id), room, enemies, reach, pairs))
	return errors


static func _room(room_id: String, room: Dictionary, enemies: Dictionary, reach: float, pairs: Array) -> Array:
	var errors: Array = []
	var ids: Dictionary = {}
	var by_type: Dictionary = {}
	for raw_ep in room.get("endpoints", []):
		if typeof(raw_ep) != TYPE_DICTIONARY:
			errors.append("%s endpoint is not an object" % room_id)
			continue
		var ep: Dictionary = raw_ep
		var id := str(ep.get("id", ""))
		if id == "" or ids.has(id):
			errors.append("%s duplicate endpoint %s" % [room_id, id])
		ids[id] = true
		var kind := str(ep.get("type", ""))
		if not by_type.has(kind):
			by_type[kind] = []
		(by_type[kind] as Array).append(ep)
	for raw_en in room.get("enemies", []):
		if typeof(raw_en) != TYPE_DICTIONARY:
			errors.append("%s enemy is not an object" % room_id)
			continue
		var arch := str((raw_en as Dictionary).get("archetype", ""))
		if not enemies.has(arch):
			errors.append("%s unknown archetype %s" % [room_id, arch])
	var obstacles: Array = room.get("obstacles", [])
	for raw_pair in pairs:
		if typeof(raw_pair) != TYPE_ARRAY or (raw_pair as Array).size() < 2:
			continue
		var pair: Array = raw_pair
		var type_a := str(pair[0])
		var type_b := str(pair[1])
		if not by_type.has(type_a) or not by_type.has(type_b):
			continue
		var ok := false
		for raw_a in by_type[type_a]:
			for raw_b in by_type[type_b]:
				var pa := _xz((raw_a as Dictionary).get("at", [0, 0]))
				var pb := _xz((raw_b as Dictionary).get("at", [0, 0]))
				if pa.distance_to(pb) > reach + 0.001:
					continue
				if _blocked(pa, pb, obstacles):
					continue
				ok = true
		if not ok:
			errors.append("%s unsolvable %s-%s" % [room_id, type_a, type_b])
	return errors


static func _xz(at: Variant) -> Vector3:
	if typeof(at) == TYPE_ARRAY and (at as Array).size() >= 2:
		var row: Array = at
		return Vector3(float(row[0]), 0.0, float(row[1]))
	return Vector3.ZERO


static func _blocked(a: Vector3, b: Vector3, obstacles: Array) -> bool:
	for raw in obstacles:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var ob: Dictionary = raw
		var center := _xz(ob.get("at", [0, 0]))
		var size: Variant = ob.get("size", [1, 1])
		var hx := 0.5
		var hz := 0.5
		if typeof(size) == TYPE_ARRAY and (size as Array).size() >= 1:
			var dims: Array = size
			hx = float(dims[0]) * 0.5
			hz = hx
			if dims.size() > 1:
				hz = float(dims[1]) * 0.5
		if _segment_hits_rect(a, b, center, hx + 0.35, hz + 0.35):
			return true
	return false


static func _segment_hits_rect(a: Vector3, b: Vector3, center: Vector3, hx: float, hz: float) -> bool:
	var dx := b.x - a.x
	var dz := b.z - a.z
	var tmin := 0.0
	var tmax := 1.0
	var slabs: Array = [
		[dx, a.x, center.x - hx, center.x + hx],
		[dz, a.z, center.z - hz, center.z + hz],
	]
	for raw in slabs:
		var slab: Array = raw
		var p: float = slab[0]
		var origin: float = slab[1]
		var mn: float = slab[2]
		var mx: float = slab[3]
		if absf(p) < 0.00001:
			if origin < mn or origin > mx:
				return false
			continue
		var t1 := (mn - origin) / p
		var t2 := (mx - origin) / p
		if t1 > t2:
			var swap := t1
			t1 = t2
			t2 = swap
		tmin = maxf(tmin, t1)
		tmax = minf(tmax, t2)
		if tmin > tmax:
			return false
	return true
