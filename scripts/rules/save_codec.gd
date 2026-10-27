class_name SaveCodec
extends RefCounted

const VERSION := 1


static func migrate(raw: Dictionary) -> Dictionary:
	var version := int(raw.get("version", 0))
	if version <= 0:
		return {
			"version": VERSION,
			"content_version": int(raw.get("content_version", 1)),
			"seed": int(raw.get("seed", 1)),
			"room_index": int(raw.get("room_index", 0)),
			"order": raw.get("order", []),
			"upgrades": raw.get("upgrades", []),
		}
	var data: Dictionary = raw.duplicate(true)
	data["version"] = VERSION
	return data


static func inspect(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "malformed", "data": {}}
	var body: Dictionary = raw
	if body.is_empty():
		return {"ok": false, "reason": "malformed", "data": {}}
	var version := int(body.get("version", 0))
	if body.has("version") and version > VERSION:
		return {"ok": false, "reason": "newer", "data": {}}
	if version <= 0 and not body.has("seed"):
		return {"ok": false, "reason": "malformed", "data": {}}
	var data := migrate(body)
	if typeof(data.get("upgrades")) != TYPE_ARRAY:
		return {"ok": false, "reason": "malformed", "data": {}}
	if typeof(data.get("order")) != TYPE_ARRAY:
		return {"ok": false, "reason": "malformed", "data": {}}
	if int(data.get("room_index", 0)) < 0:
		return {"ok": false, "reason": "malformed", "data": {}}
	return {"ok": true, "reason": "ok", "data": data}
