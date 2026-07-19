extends Node

const SAVE_PATH: String = "user://savegame.json"
const BACKUP_PATH: String = "user://savegame.backup.json"
const TEMP_PATH: String = "user://savegame.tmp.json"
const WEB_STORAGE_KEY: String = "jjugumeong.save.v1"
const WEB_BACKUP_STORAGE_KEY: String = "jjugumeong.save.v1.backup"
const WEB_COOKIE_KEY: String = "jjugumeong_save"
const WEB_COOKIE_META_KEY: String = "jjugumeong_save_meta"
const WEB_COOKIE_CHUNK_PREFIX: String = "jjugumeong_save_"
const WEB_COOKIE_CHUNK_SIZE: int = 1500
const WEB_COOKIE_MAX_CHUNKS: int = 6
const CURRENT_SCHEMA_VERSION: int = 9

var last_load_used_backup: bool = false
var last_load_was_recovered: bool = false
var last_load_source: String = "default"
var last_save_was_persistent: bool = true
var last_web_local_saved: bool = false
var last_web_cookie_saved: bool = false
var _last_known_revision: int = 0


func load_game(default_data: Dictionary) -> Dictionary:
	last_load_used_backup = false
	last_load_was_recovered = false
	last_load_source = "default"

	var primary_data: Dictionary = _read_and_validate(SAVE_PATH)
	var backup_data: Dictionary = _read_and_validate(BACKUP_PATH)
	var loaded_data: Dictionary = primary_data
	var loaded_source: String = "primary"

	if _is_newer_save(backup_data, loaded_data):
		loaded_data = backup_data
		loaded_source = "backup"
	for web_entry: Dictionary in _read_web_storage_entries():
		var web_data: Dictionary = _dictionary_dictionary(web_entry, "data")
		if _is_newer_save(web_data, loaded_data):
			loaded_data = web_data
			loaded_source = _dictionary_string(web_entry, "source", "web")

	if not loaded_data.is_empty():
		last_load_used_backup = loaded_source == "backup"
		last_load_was_recovered = loaded_source != "primary"
		last_load_source = loaded_source
		_last_known_revision = _dictionary_int(loaded_data, "save_revision", 0)
		return _migrate_data(loaded_data, default_data)

	if FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH):
		last_load_was_recovered = true
	_last_known_revision = 0
	return default_data.duplicate(true)


func save_game(save_data: Dictionary) -> bool:
	var payload: Dictionary = save_data.duplicate(true)
	payload["schema_version"] = CURRENT_SCHEMA_VERSION
	_last_known_revision += 1
	payload["save_revision"] = _last_known_revision
	var json_text: String = JSON.stringify(payload)
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
		last_save_was_persistent = (
			web_backup_saved
			or (rename_error == OK and OS.is_userfs_persistent())
		)
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


func _read_web_storage_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not OS.has_feature("web"):
		return entries
	var key_literal: String = JSON.stringify(WEB_STORAGE_KEY)
	var backup_key_literal: String = JSON.stringify(WEB_BACKUP_STORAGE_KEY)
	var local_value: Variant = JavaScriptBridge.eval(
		(
			"(function(){try{return localStorage.getItem(%s) || '';}"
			+ "catch(error){return '';}})()"
		) % key_literal,
		true
	)
	var local_backup_value: Variant = JavaScriptBridge.eval(
		(
			"(function(){try{return localStorage.getItem(%s) || '';}"
			+ "catch(error){return '';}})()"
		) % backup_key_literal,
		true
	)
	_append_web_entry(entries, "web_local", local_value)
	_append_web_entry(entries, "web_local_backup", local_backup_value)

	var cookie_meta_literal: String = JSON.stringify("%s=" % WEB_COOKIE_META_KEY)
	var cookie_chunk_prefix_literal: String = JSON.stringify(
		WEB_COOKIE_CHUNK_PREFIX
	)
	var cookie_value: Variant = JavaScriptBridge.eval(
		(
			"(function(){try{const cookies=document.cookie.split('; ');"
			+ "const read=(name)=>{const prefix=name+'=';"
			+ "const item=cookies.find((row)=>row.startsWith(prefix));"
			+ "return item ? item.slice(prefix.length) : '';};"
			+ "const metaPrefix=%s;"
			+ "const metaItem=cookies.find((row)=>row.startsWith(metaPrefix));"
			+ "if(!metaItem)return '';"
			+ "const count=parseInt(metaItem.slice(metaPrefix.length),10);"
			+ "if(!Number.isInteger(count)||count<1||count>%d)return '';"
			+ "const chunkPrefix=%s;let encoded='';"
			+ "for(let i=0;i<count;i++){const chunk=read(chunkPrefix+i);"
			+ "if(!chunk)return '';encoded+=chunk;}"
			+ "return decodeURIComponent(encoded);"
			+ "}catch(error){return '';}})()"
		) % [
			cookie_meta_literal,
			WEB_COOKIE_MAX_CHUNKS,
			cookie_chunk_prefix_literal
		],
		true
	)
	_append_web_entry(entries, "web_cookie", cookie_value)

	var legacy_cookie_literal: String = JSON.stringify("%s=" % WEB_COOKIE_KEY)
	var legacy_cookie_value: Variant = JavaScriptBridge.eval(
		(
			"(function(){try{const prefix=%s;"
			+ "const item=document.cookie.split('; ').find("
			+ "(row)=>row.startsWith(prefix));"
			+ "return item ? decodeURIComponent(item.slice(prefix.length)) : '';}"
			+ "catch(error){return '';}})()"
		) % legacy_cookie_literal,
		true
	)
	_append_web_entry(entries, "web_legacy_cookie", legacy_cookie_value)
	return entries


func _write_web_storage(json_text: String) -> bool:
	last_web_local_saved = false
	last_web_cookie_saved = false
	if not OS.has_feature("web"):
		return true
	var key_literal: String = JSON.stringify(WEB_STORAGE_KEY)
	var backup_key_literal: String = JSON.stringify(WEB_BACKUP_STORAGE_KEY)
	var value_literal: String = JSON.stringify(json_text)
	var local_saved: Variant = JavaScriptBridge.eval(
		(
			"(function(){try{const current=localStorage.getItem(%s) || '';"
			+ "if(current && current!==%s){try{const parsed=JSON.parse(current);"
			+ "if(parsed && typeof parsed==='object')localStorage.setItem(%s,current);"
			+ "}catch(parseError){}}"
			+ "localStorage.setItem(%s,%s);"
			+ "return localStorage.getItem(%s) === %s;}"
			+ "catch(error){return false;}})()"
		) % [
			key_literal,
			value_literal,
			backup_key_literal,
			key_literal,
			value_literal,
			key_literal,
			value_literal
		],
		true
	)
	last_web_local_saved = local_saved is bool and local_saved

	var cookie_meta_key_literal: String = JSON.stringify(WEB_COOKIE_META_KEY)
	var cookie_chunk_prefix_literal: String = JSON.stringify(
		WEB_COOKIE_CHUNK_PREFIX
	)
	var cookie_result: Variant = JavaScriptBridge.eval(
		(
			"(function(){try{const value=%s;"
			+ "const encoded=encodeURIComponent(value);"
			+ "const chunkSize=%d;const maxChunks=%d;"
			+ "const count=Math.ceil(encoded.length/chunkSize);"
			+ "if(count<1||count>maxChunks)return false;"
			+ "const attrs='; Max-Age=31536000; Path=/; SameSite=Lax; Secure';"
			+ "const chunkPrefix=%s;const metaKey=%s;"
			+ "for(let i=0;i<count;i++){document.cookie=chunkPrefix+i+'='"
			+ "+encoded.slice(i*chunkSize,(i+1)*chunkSize)+attrs;}"
			+ "for(let i=count;i<maxChunks;i++){document.cookie=chunkPrefix+i"
			+ "+'=; Max-Age=0; Path=/; SameSite=Lax; Secure';}"
			+ "document.cookie=metaKey+'='+count+attrs;"
			+ "const cookies=document.cookie.split('; ');"
			+ "const read=(name)=>{const prefix=name+'=';"
			+ "const item=cookies.find((row)=>row.startsWith(prefix));"
			+ "return item ? item.slice(prefix.length) : '';};"
			+ "let restored='';for(let i=0;i<count;i++){"
			+ "const chunk=read(chunkPrefix+i);if(!chunk)return false;"
			+ "restored+=chunk;}"
			+ "return decodeURIComponent(restored)===value;"
			+ "}catch(error){return false;}})()"
		) % [
			value_literal,
			WEB_COOKIE_CHUNK_SIZE,
			WEB_COOKIE_MAX_CHUNKS,
			cookie_chunk_prefix_literal,
			cookie_meta_key_literal
		],
		true
	)
	last_web_cookie_saved = cookie_result is bool and cookie_result
	return last_web_local_saved or last_web_cookie_saved


func _is_newer_save(candidate: Dictionary, current: Dictionary) -> bool:
	if candidate.is_empty():
		return false
	if current.is_empty():
		return true
	var candidate_revision: int = _dictionary_int(candidate, "save_revision", 0)
	var current_revision: int = _dictionary_int(current, "save_revision", 0)
	if candidate_revision != current_revision:
		return candidate_revision > current_revision
	return (
		_dictionary_int(candidate, "last_saved_unix", 0)
		> _dictionary_int(current, "last_saved_unix", 0)
	)


func get_last_load_summary() -> String:
	match last_load_source:
		"primary":
			return "파일에서 불러옴"
		"backup":
			return "파일 백업에서 복구"
		"web_local":
			return "브라우저 저장에서 복구"
		"web_local_backup":
			return "브라우저 백업에서 복구"
		"web_cookie":
			return "쿠키 백업에서 복구"
		"web_legacy_cookie":
			return "기존 쿠키에서 복구"
	return "새 게임 시작"


func get_last_save_summary() -> String:
	if not OS.has_feature("web"):
		return "파일 저장 완료"
	if last_web_local_saved and last_web_cookie_saved:
		return "브라우저·쿠키 이중 저장 완료"
	if last_web_local_saved:
		return "브라우저 저장 완료"
	if last_web_cookie_saved:
		return "쿠키 백업 저장 완료"
	if last_save_was_persistent:
		return "Web 파일 저장 완료"
	return "브라우저 저장 제한"


func _append_web_entry(
	entries: Array[Dictionary],
	source: String,
	raw_value: Variant
) -> void:
	if not raw_value is String:
		return
	@warning_ignore("unsafe_cast")
	var data: Dictionary = _parse_and_validate(raw_value as String)
	if not data.is_empty():
		entries.append({"source": source, "data": data})


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

	# Schema 0 was the pre-release shape. Compatible keys are copied as-is.
	if schema_version <= CURRENT_SCHEMA_VERSION:
		for key: Variant in result.keys():
			if data.has(key):
				result[key] = data[key]
	if schema_version < 2:
		result["selected_stage_index"] = _dictionary_int(data, "current_stage_index", 0)
		result["unlocked_stage_ids"] = []
		result["completed_region_event_ids"] = []
		result["next_region_event_unix"] = 0
	if schema_version < 3:
		result["completed_field_action_ids"] = []
		result["next_field_action_unix"] = 0
	if schema_version < 4:
		result["region_progress"] = {}
	if schema_version < 5:
		result["nursery_level"] = 0
		result["nursery_pups"] = []
		result["total_raised_pups"] = 0
		result["next_pup_id"] = 1
	if schema_version < 6:
		result["role_assignments"] = {
			"gatherer": maxi(1, _dictionary_int(data, "mouse_count", 1)),
			"explorer": 0,
			"builder": 0
		}
	if schema_version < 7:
		result["selected_hero_id"] = ""
	if schema_version < 8:
		result["hero_bond_level"] = 0
		result["next_hero_mission_unix"] = 0
	if schema_version < 9:
		result["save_revision"] = 0
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


func _dictionary_string(data: Dictionary, key: String, fallback: String) -> String:
	var value: Variant = data.get(key, fallback)
	if value is String:
		return value
	return fallback


func _dictionary_dictionary(data: Dictionary, key: String) -> Dictionary:
	var value: Variant = data.get(key, {})
	if value is Dictionary:
		@warning_ignore("unsafe_cast")
		return value as Dictionary
	return {}
