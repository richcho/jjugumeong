extends Node

const STAGES_PATH: String = "res://data/stages/stages.json"
const AUTO_SAVE_INTERVAL: float = 3.0
const BASE_SPEED: float = 150.0
const SPEED_PER_LEVEL: float = 22.5
const BASE_CARRY: int = 1
const ALPHA_TEST_REWARD_MULTIPLIER: float = 25.0
const GOLDEN_DURATION: float = 10.0
const GOLDEN_MULTIPLIER: float = 5.0
const CLICK_BOOST_DURATION: float = 3.0
const CLICK_BOOST_MULTIPLIER: float = 1.8
const GOLDEN_EVENT_MIN_DELAY: float = 35.0
const GOLDEN_EVENT_MAX_DELAY: float = 65.0
const ESTIMATED_ONE_WAY_DISTANCE: float = 760.0

var cheese: float = 0.0
var total_cheese: float = 0.0
var mouse_count: int = 1
var speed_level: int = 0
var carry_level: int = 0
var hole_level: int = 1
var current_stage_index: int = 0
var tutorial_step: int = 0
var golden_remaining: float = 0.0
var click_boost_remaining: float = 0.0
var play_time_seconds: float = 0.0
var total_trips: int = 0
var total_click_boosts: int = 0
var total_golden_events: int = 0
var stages: Array[Dictionary] = []
var offline_reward: float = 0.0
var offline_seconds: int = 0

var _auto_save_elapsed: float = 0.0
var _next_golden_event: float = 45.0
var _is_ready: bool = false


func _ready() -> void:
	_load_stages()
	var loaded_data: Dictionary = SaveManager.load_game(_default_save_data())
	_apply_save_data(loaded_data)
	_calculate_offline_reward()
	_next_golden_event = randf_range(GOLDEN_EVENT_MIN_DELAY, GOLDEN_EVENT_MAX_DELAY)
	_is_ready = true
	save_now()
	if SaveManager.last_load_was_recovered:
		EventBus.save_status_changed.emit("저장 복구됨")
	else:
		EventBus.save_status_changed.emit("불러오기 완료")


func _process(delta: float) -> void:
	if not _is_ready:
		return
	play_time_seconds += delta
	_auto_save_elapsed += delta

	if golden_remaining > 0.0:
		golden_remaining = maxf(golden_remaining - delta, 0.0)
		EventBus.golden_cheese_changed.emit(golden_remaining > 0.0, golden_remaining)
	else:
		_next_golden_event -= delta
		if _next_golden_event <= 0.0:
			activate_golden_cheese()

	if click_boost_remaining > 0.0:
		click_boost_remaining = maxf(click_boost_remaining - delta, 0.0)
		EventBus.click_boost_changed.emit(click_boost_remaining > 0.0, click_boost_remaining)

	if _auto_save_elapsed >= AUTO_SAVE_INTERVAL:
		save_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()
		get_tree().quit()
	elif (
		what == NOTIFICATION_APPLICATION_PAUSED
		or what == NOTIFICATION_APPLICATION_FOCUS_OUT
	):
		save_now()


func collect_trip(base_amount: int) -> int:
	var reward: float = (
		float(base_amount)
		* get_stage_bonus()
		* ALPHA_TEST_REWARD_MULTIPLIER
	)
	if golden_remaining > 0.0:
		reward *= GOLDEN_MULTIPLIER
	var final_reward: int = maxi(1, roundi(reward))
	cheese += float(final_reward)
	total_cheese += float(final_reward)
	total_trips += 1
	_update_unlocked_stage()
	EventBus.game_state_changed.emit()
	return final_reward


func buy_speed_upgrade() -> bool:
	var cost: int = get_speed_upgrade_cost()
	if not _spend_cheese(cost):
		return false
	speed_level += 1
	EventBus.toast_requested.emit("이동속도가 빨라졌습니다!")
	EventBus.game_state_changed.emit()
	save_now()
	return true


func buy_carry_upgrade() -> bool:
	var cost: int = get_carry_upgrade_cost()
	if not _spend_cheese(cost):
		return false
	carry_level += 1
	EventBus.toast_requested.emit("운반량이 증가했습니다!")
	EventBus.game_state_changed.emit()
	save_now()
	return true


func buy_mouse() -> bool:
	var cost: int = get_mouse_cost()
	if not _spend_cheese(cost):
		return false
	mouse_count += 1
	EventBus.mouse_count_changed.emit(mouse_count)
	EventBus.toast_requested.emit("새로운 집쥐가 합류했습니다!")
	EventBus.game_state_changed.emit()
	save_now()
	return true


func expand_hole() -> bool:
	var cost: int = get_hole_upgrade_cost()
	if not _spend_cheese(cost):
		return false
	hole_level += 1
	EventBus.toast_requested.emit("쥐구멍이 %d레벨로 확장됐습니다!" % hole_level)
	EventBus.game_state_changed.emit()
	save_now()
	return true


func activate_click_boost() -> void:
	click_boost_remaining = CLICK_BOOST_DURATION
	total_click_boosts += 1
	EventBus.click_boost_changed.emit(true, click_boost_remaining)
	EventBus.game_state_changed.emit()


func activate_golden_cheese() -> void:
	golden_remaining = GOLDEN_DURATION
	total_golden_events += 1
	_next_golden_event = randf_range(GOLDEN_EVENT_MIN_DELAY, GOLDEN_EVENT_MAX_DELAY)
	EventBus.golden_cheese_changed.emit(true, golden_remaining)
	EventBus.toast_requested.emit("황금치즈 발견! 10초간 보상 5배!")
	EventBus.game_state_changed.emit()


func advance_tutorial() -> void:
	if tutorial_step >= 4:
		return
	tutorial_step += 1
	EventBus.tutorial_changed.emit(tutorial_step)
	EventBus.game_state_changed.emit()
	if tutorial_step >= 4:
		save_now()


func save_now() -> bool:
	if not _is_ready:
		return false
	_auto_save_elapsed = 0.0
	EventBus.save_status_changed.emit("저장 중...")
	var success: bool = SaveManager.save_game(_build_save_data())
	if success:
		if SaveManager.last_save_was_persistent:
			EventBus.save_status_changed.emit("저장됨")
		else:
			EventBus.save_status_changed.emit("Safari 저장 제한")
	else:
		EventBus.save_status_changed.emit("저장 실패")
	return success


func get_move_speed() -> float:
	var speed: float = BASE_SPEED + float(speed_level) * SPEED_PER_LEVEL
	if click_boost_remaining > 0.0:
		speed *= CLICK_BOOST_MULTIPLIER
	return speed


func get_carry_capacity() -> int:
	return BASE_CARRY + carry_level


func get_stage_bonus() -> float:
	if stages.is_empty():
		return 1.0
	var stage: Dictionary = stages[current_stage_index]
	return _dictionary_float(stage, "production_bonus", 1.0)


func get_current_stage() -> Dictionary:
	if stages.is_empty():
		return {
			"name": "낡은 부엌",
			"background_color": "#352a3b",
			"production_bonus": 1.0
		}
	return stages[current_stage_index]


func get_next_stage() -> Dictionary:
	var next_index: int = current_stage_index + 1
	if next_index >= stages.size():
		return {}
	return stages[next_index]


func get_expected_per_second() -> float:
	var round_trip_seconds: float = (ESTIMATED_ONE_WAY_DISTANCE * 2.0) / get_move_speed()
	var reward_per_trip: float = (
		float(get_carry_capacity())
		* get_stage_bonus()
		* ALPHA_TEST_REWARD_MULTIPLIER
	)
	if golden_remaining > 0.0:
		reward_per_trip *= GOLDEN_MULTIPLIER
	return reward_per_trip * float(mouse_count) / maxf(round_trip_seconds, 0.1)


func get_speed_upgrade_cost() -> int:
	return _scaled_cost(10, speed_level)


func get_carry_upgrade_cost() -> int:
	return _scaled_cost(25, carry_level)


func get_mouse_cost() -> int:
	return _scaled_cost(50, mouse_count - 1)


func get_hole_upgrade_cost() -> int:
	return _scaled_cost(100, hole_level - 1)


func get_tutorial_text() -> String:
	match tutorial_step:
		0:
			return "환영합니다! 쥐는 스스로 치즈를 찾아 왕복합니다."
		1:
			return "이동 구역을 클릭하면 3초간 쥐가 빨라집니다."
		2:
			return "아래 버튼으로 속도와 운반량을 강화할 수 있습니다."
		3:
			return "누적 치즈를 모으면 새로운 인간 세계가 열립니다."
		_:
			return ""


func _spend_cheese(amount: int) -> bool:
	if cheese < float(amount):
		EventBus.toast_requested.emit("치즈가 %d개 필요합니다." % amount)
		return false
	cheese -= float(amount)
	return true


func _scaled_cost(base_cost: int, purchased_levels: int) -> int:
	return roundi(float(base_cost) * pow(1.5, float(purchased_levels)))


func _update_unlocked_stage() -> void:
	var unlocked_index: int = current_stage_index
	for index: int in range(stages.size()):
		var threshold: float = _dictionary_float(stages[index], "unlock_total_cheese", 0.0)
		if total_cheese >= threshold:
			unlocked_index = index
	if unlocked_index != current_stage_index:
		current_stage_index = unlocked_index
		EventBus.stage_changed.emit(current_stage_index)
		EventBus.toast_requested.emit(
			"새 지역 개방: %s" % _dictionary_string(get_current_stage(), "name", "")
		)
		save_now()


func _calculate_offline_reward() -> void:
	var saved_unix: int = int(_loaded_last_saved_unix)
	offline_seconds = TimeManager.capped_offline_seconds(saved_unix)
	if offline_seconds <= 1:
		return
	offline_reward = get_expected_per_second() * float(offline_seconds)
	cheese += offline_reward
	total_cheese += offline_reward
	_update_unlocked_stage()


var _loaded_last_saved_unix: int = 0


func _default_save_data() -> Dictionary:
	return {
		"schema_version": SaveManager.CURRENT_SCHEMA_VERSION,
		"cheese": 0.0,
		"total_cheese": 0.0,
		"mouse_count": 1,
		"speed_level": 0,
		"carry_level": 0,
		"hole_level": 1,
		"current_stage_index": 0,
		"tutorial_step": 0,
		"play_time_seconds": 0.0,
		"total_trips": 0,
		"total_click_boosts": 0,
		"total_golden_events": 0,
		"last_saved_unix": 0
	}


func _apply_save_data(data: Dictionary) -> void:
	cheese = maxf(0.0, _dictionary_float(data, "cheese", 0.0))
	total_cheese = maxf(0.0, _dictionary_float(data, "total_cheese", cheese))
	mouse_count = maxi(1, _dictionary_int(data, "mouse_count", 1))
	speed_level = maxi(0, _dictionary_int(data, "speed_level", 0))
	carry_level = maxi(0, _dictionary_int(data, "carry_level", 0))
	hole_level = maxi(1, _dictionary_int(data, "hole_level", 1))
	current_stage_index = clampi(
		_dictionary_int(data, "current_stage_index", 0),
		0,
		maxi(0, stages.size() - 1)
	)
	tutorial_step = clampi(_dictionary_int(data, "tutorial_step", 0), 0, 4)
	play_time_seconds = maxf(0.0, _dictionary_float(data, "play_time_seconds", 0.0))
	total_trips = maxi(0, _dictionary_int(data, "total_trips", 0))
	total_click_boosts = maxi(0, _dictionary_int(data, "total_click_boosts", 0))
	total_golden_events = maxi(0, _dictionary_int(data, "total_golden_events", 0))
	_loaded_last_saved_unix = _dictionary_int(data, "last_saved_unix", 0)


func _build_save_data() -> Dictionary:
	return {
		"schema_version": SaveManager.CURRENT_SCHEMA_VERSION,
		"cheese": cheese,
		"total_cheese": total_cheese,
		"mouse_count": mouse_count,
		"speed_level": speed_level,
		"carry_level": carry_level,
		"hole_level": hole_level,
		"current_stage_index": current_stage_index,
		"tutorial_step": tutorial_step,
		"play_time_seconds": play_time_seconds,
		"total_trips": total_trips,
		"total_click_boosts": total_click_boosts,
		"total_golden_events": total_golden_events,
		"last_saved_unix": TimeManager.current_unix_time()
	}


func _load_stages() -> void:
	var stage_file: FileAccess = FileAccess.open(STAGES_PATH, FileAccess.READ)
	if stage_file == null:
		_use_fallback_stage()
		return
	var json_text: String = stage_file.get_as_text()
	stage_file.close()
	var parsed: Variant = JSON.parse_string(json_text)
	if not parsed is Array:
		_use_fallback_stage()
		return
	@warning_ignore("unsafe_cast")
	var raw_stages: Array = parsed as Array
	for raw_stage: Variant in raw_stages:
		if raw_stage is Dictionary:
			@warning_ignore("unsafe_cast")
			stages.append(raw_stage as Dictionary)
	if stages.is_empty():
		_use_fallback_stage()


func _use_fallback_stage() -> void:
	stages = [{
		"id": "old_kitchen",
		"name": "낡은 부엌",
		"unlock_total_cheese": 0,
		"production_bonus": 1.0,
		"background_color": "#352a3b"
	}]


func _dictionary_float(data: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = data.get(key, fallback)
	if value is float:
		return value
	if value is int:
		@warning_ignore("unsafe_call_argument")
		return float(value)
	return fallback


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
	if value is StringName:
		@warning_ignore("unsafe_call_argument")
		return String(value)
	return fallback
