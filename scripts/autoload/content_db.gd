extends Node
## Loads the single content document. Gameplay reads this; it does not parse JSON itself.

var data: Dictionary = {}
var load_error: String = ""


func _ready() -> void:
	reload_default()


func reload_default() -> void:
	load_path("res://data/content.json")


func load_path(path: String) -> void:
	if not FileAccess.file_exists(path):
		load_error = "missing"
		data = {}
		return
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		load_error = "malformed"
		data = {}
		return
	data = parsed
	load_error = ""


func version() -> int:
	return int(data.get("version", 0))


func tether() -> Dictionary:
	return data.get("tether", {})


func player_stats() -> Dictionary:
	return data.get("player", {})


func enemy_stats(archetype: String) -> Dictionary:
	var all: Dictionary = data.get("enemies", {})
	return all.get(archetype, {})


func upgrades() -> Array:
	return data.get("upgrades", [])


func rooms() -> Dictionary:
	return data.get("rooms", {})


func room(id: String) -> Dictionary:
	var all := rooms()
	return all.get(id, {})
