extends Node

const SAVE_PATH: String = "user://savegame.json"
const BACKUP_PATH: String = "user://savegame.backup.json"
const TEMP_PATH: String = "user://savegame.tmp.json"
const WEB_STORAGE_KEY: String = "jjugumeong.save.v1"
const WEB_COOKIE_KEY: String = "jjugumeong_save"
const WEB_COOKIE_MAX_SIZE: int = 2500
const CURRENT_SCHEMA_VERSION: int = 1

var last_load_used_backup: bool = false
var last_load_was_recovered: bool = false
var last_save_was_persistent: bool = true


func load_game(default_data: Dictionary) -> Dictionary:
	last_load_used_backup = false
	last_load_was_recovered = false

	var primary_data: Dictionary = _read_and_validate(SAVE_PATH)
	var backup_data: Dictionary = _read_and_validate(BACKUP_PATH)
	var web_data: Dictionary = _read_web_storage()
	var loaded_data: Dictionary = primary_data
	var loaded_source: String = "primary"

	if _is_newer_save(backup_data, loaded_data):
		loaded_data = backup_data
		loaded_source = "backup"
	if _is_newer_save(web_data, loaded_data):
		loaded_data = web_data
		loaded_source = "web"

	if not loaded_data.is_empty():
		last_load_used_backup = loaded_source == "backup"
		last_load_was_recovered = loaded_source != "primary"
		return _migrate_data(loaded_data, default_data)

	if FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH):
		last_load_was_recovered = true
	return default_data.duplicate(true)


func save_game(save_data: Dictionary) -> bool:
	var payload: Dictionary = save_data.duplicate(true)
	payload["schema_version"] = CURRENT_SCHEMA_VERSION
	var json_text: String = JSON.stringify(payload, "\t")
	var web_backup_saved: bool = _write_web_storage(json_text)

	var temp_file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if temp_file == null:
		last_save_was_persistent = web_backup_saved
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
			last_save_was_persistent = web_backup_saved
			return false
	var rename_error: Error = DirAccess.rename_absolute(temp_absolute, save_absolute)
	if OS.has_feature("web"):
		JavaScriptBridge.force_fs_sync()
		last_save_was_persistent = web_backup_saved or OS.is_userfs_persistent()
	else:
		last_save_was_persistent = rename_error == OK
	return rename_error == OK or web_backup_saved


func _read_and_validate(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = _read_text(path)
	return _parse_and_validate(text)


func _parse_and_validate(text: String) -> Dictionary:
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


func _read_web_storage() -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	var key_literal: String = JSON.stringify(WEB_STORAGE_KEY)
	var local_value: Variant = JavaScriptBridge.eval(
		(
			"(function(){try{return localStorage.getItem(%s) || '';}"
			+ "catch(error){return '';}})()"
		) % key_literal,
		true
	)
	var cookie_name_literal: String = JSON.stringify("%s=" % WEB_COOKIE_KEY)
	var cookie_value: Variant = JavaScriptBridge.eval(
		(
			"(function(){try{const prefix=%s;"
			+ "const item=document.cookie.split('; ').find("
			+ "(row)=>row.startsWith(prefix));"
			+ "return item ? decodeURIComponent(item.slice(prefix.length)) : '';}"
			+ "catch(error){return '';}})()"
		) % cookie_name_literal,
		true
	)
	var local_data: Dictionary = {}
	var cookie_data: Dictionary = {}
	if local_value is String:
		@warning_ignore("unsafe_cast")
		local_data = _parse_and_validate(local_value as String)
	if cookie_value is String:
		@warning_ignore("unsafe_cast")
		cookie_data = _parse_and_validate(cookie_value as String)
	if _is_newer_save(cookie_data, local_data):
		return cookie_data
	return local_data


func _write_web_storage(json_text: String) -> bool:
	if not OS.has_feature("web"):
		return true
	var key_literal: String = JSON.stringify(WEB_STORAGE_KEY)
	var value_literal: String = JSON.stringify(json_text)
	var local_saved: Variant = JavaScriptBridge.eval(
		(
			"(function(){try{localStorage.setItem(%s,%s);"
			+ "return localStorage.getItem(%s) === %s;}"
			+ "catch(error){return false;}})()"
		) % [key_literal, value_literal, key_literal, value_literal],
		true
	)
	var cookie_saved: bool = false
	if json_text.length() <= WEB_COOKIE_MAX_SIZE:
		var cookie_name_literal: String = JSON.stringify("%s=" % WEB_COOKIE_KEY)
		var cookie_result: Variant = JavaScriptBridge.eval(
			(
				"(function(){try{const prefix=%s;"
				+ "document.cookie=prefix+encodeURIComponent(%s)"
				+ "+'; Max-Age=31536000; Path=/; SameSite=Lax; Secure';"
				+ "return document.cookie.split('; ').some("
				+ "(row)=>row.startsWith(prefix));}"
				+ "catch(error){return false;}})()"
			) % [cookie_name_literal, value_literal],
			true
		)
		cookie_saved = cookie_result is bool and cookie_result
	return (local_saved is bool and local_saved) or cookie_saved


func _is_newer_save(candidate: Dictionary, current: Dictionary) -> bool:
	if candidate.is_empty():
		return false
	if current.is_empty():
		return true
	return (
		_dictionary_int(candidate, "last_saved_unix", 0)
		> _dictionary_int(current, "last_saved_unix", 0)
	)


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
