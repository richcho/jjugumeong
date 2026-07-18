extends Node

const SAVE_PATH: String = "user://savegame.json"
const BACKUP_PATH: String = "user://savegame.backup.json"
const TEMP_PATH: String = "user://savegame.tmp.json"
const CURRENT_SCHEMA_VERSION: int = 1

var last_load_used_backup: bool = false
var last_load_was_recovered: bool = false


func load_game(default_data: Dictionary) -> Dictionary:
	last_load_used_backup = false
	last_load_was_recovered = false

	var loaded_data: Dictionary = _read_and_validate(SAVE_PATH)
	if not loaded_data.is_empty():
		return _migrate_data(loaded_data, default_data)

	loaded_data = _read_and_validate(BACKUP_PATH)
	if not loaded_data.is_empty():
		last_load_used_backup = true
		last_load_was_recovered = true
		return _migrate_data(loaded_data, default_data)

	if FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH):
		last_load_was_recovered = true
	return default_data.duplicate(true)


func save_game(save_data: Dictionary) -> bool:
	var payload: Dictionary = save_data.duplicate(true)
	payload["schema_version"] = CURRENT_SCHEMA_VERSION
	var json_text: String = JSON.stringify(payload, "\t")

	var temp_file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if temp_file == null:
		return false
	temp_file.store_string(json_text)
	temp_file.flush()
	temp_file.close()

	if FileAccess.file_exists(SAVE_PATH):
		var current_text: String = _read_text(SAVE_PATH)
		if not current_text.is_empty():
			var backup_file: FileAccess = FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
			if backup_file != null:
				backup_file.store_string(current_text)
				backup_file.flush()
				backup_file.close()

	var temp_absolute: String = ProjectSettings.globalize_path(TEMP_PATH)
	var save_absolute: String = ProjectSettings.globalize_path(SAVE_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		var remove_error: Error = DirAccess.remove_absolute(save_absolute)
		if remove_error != OK:
			return false
	var rename_error: Error = DirAccess.rename_absolute(temp_absolute, save_absolute)
	return rename_error == OK


func _read_and_validate(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = _read_text(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {}
	@warning_ignore("unsafe_cast")
	var data: Dictionary = parsed as Dictionary
	if not _has_valid_core_types(data):
		return {}
	return data


func _read_text(path: String) -> String:
	var save_file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if save_file == null:
		return ""
	var text: String = save_file.get_as_text()
	save_file.close()
	return text


func _has_valid_core_types(data: Dictionary) -> bool:
	if data.has("cheese") and not data["cheese"] is float and not data["cheese"] is int:
		return false
	if data.has("mouse_count") and not data["mouse_count"] is float and not data["mouse_count"] is int:
		return false
	if data.has("last_saved_unix") and not data["last_saved_unix"] is float and not data["last_saved_unix"] is int:
		return false
	return true


func _migrate_data(data: Dictionary, default_data: Dictionary) -> Dictionary:
	var result: Dictionary = default_data.duplicate(true)
	var schema_version: int = _dictionary_int(data, "schema_version", 0)

	# Schema 0 was the pre-release shape. Its compatible keys can be copied as-is.
	if schema_version <= CURRENT_SCHEMA_VERSION:
		for key: Variant in result.keys():
			if data.has(key):
				result[key] = data[key]
	result["schema_version"] = CURRENT_SCHEMA_VERSION
	return result


func _dictionary_int(data: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = data.get(key, fallback)
	if value is int:
		return value
	if value is float:
		@warning_ignore("unsafe_call_argument")
		return int(value)
	return fallback
