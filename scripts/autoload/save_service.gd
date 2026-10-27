extends Node
## Versioned settings and room-boundary run saves under user://.
## Writes go to a temp file, then replace the destination. A .bak of the previous
## good file is kept. Missing, malformed, and newer-version run saves are refused.

var run_path: String = "user://run_save.json"
var settings_path: String = "user://settings.json"


func save_run(body: Dictionary) -> bool:
	return _write_json(run_path, body)


func load_run() -> Dictionary:
	return _read_json(run_path, true)


func clear_run() -> void:
	_remove(run_path)


func save_settings(body: Dictionary) -> bool:
	return _write_json(settings_path, body)


func load_settings() -> Dictionary:
	var result := _read_json(settings_path, false)
	if not bool(result.get("ok", false)):
		return {"ok": false, "reason": str(result.get("reason", "missing")), "data": default_settings()}
	var body: Dictionary = result.get("data", {})
	var version := int(body.get("version", 0))
	if version > SaveCodec.VERSION:
		return {"ok": false, "reason": "newer", "data": default_settings()}
	return {"ok": true, "reason": "ok", "data": _merge_settings(body)}


func default_settings() -> Dictionary:
	return {
		"version": SaveCodec.VERSION,
		"master": 0.85,
		"music": 0.4,
		"effects": 0.8,
		"shake": true,
		"flash": true,
		"ui_scale": 1.0,
		"bindings": [],
	}


func _merge_settings(data: Dictionary) -> Dictionary:
	var merged := default_settings()
	for key in merged.keys():
		if data.has(key):
			merged[key] = data[key]
	merged["version"] = SaveCodec.VERSION
	return merged


func _read_json(path: String, migrate_run: bool) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "reason": "missing", "data": {}}
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges() == "":
		return {"ok": false, "reason": "truncated", "data": {}}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "malformed", "data": {}}
	if not migrate_run:
		return {"ok": true, "reason": "ok", "data": parsed}
	var inspected := SaveCodec.inspect(parsed)
	return inspected


func _write_json(path: String, body: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(body))
	file.flush()
	file.close()
	var dest := ProjectSettings.globalize_path(path)
	var temp_abs := ProjectSettings.globalize_path(tmp)
	if FileAccess.file_exists(path):
		var previous := FileAccess.get_file_as_string(path)
		var bak := FileAccess.open(path + ".bak", FileAccess.WRITE)
		if bak != null:
			bak.store_string(previous)
			bak.close()
		DirAccess.remove_absolute(dest)
	var err := DirAccess.rename_absolute(temp_abs, dest)
	return err == OK


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
