extends Node

const STAGES_PATH: String = "res://data/stages/stages.json"
const BUILD_INFO_PATH: String = "res://data/build.json"
const HEROES_PATH: String = "res://data/mice/heroes.json"
const AUTO_SAVE_INTERVAL: float = 3.0
const BASE_SPEED: float = 115.0
const SPEED_LEVEL_CURVE: float = 32.0
const MAX_MOVE_SPEED: float = 245.0
const MAX_BOOSTED_MOVE_SPEED: float = 285.0
const BASE_CARRY: int = 1
const ALPHA_TEST_REWARD_MULTIPLIER: float = 25.0
const GOLDEN_DURATION: float = 10.0
const GOLDEN_MULTIPLIER: float = 5.0
const CLICK_BOOST_DURATION: float = 3.0
const CLICK_BOOST_MULTIPLIER: float = 1.25
const GOLDEN_EVENT_MIN_DELAY: float = 35.0
const GOLDEN_EVENT_MAX_DELAY: float = 65.0
const ESTIMATED_ONE_WAY_DISTANCE: float = 760.0
const REGION_EVENT_COOLDOWN_SECONDS: int = 30
const FIELD_ACTION_COOLDOWN_SECONDS: int = 20
const NURSERY_UNLOCK_HOLE_LEVEL: int = 10
const NURSERY_BUILD_COST: int = 500
const NURSERY_BASE_PUP_COST: int = 200
const NURSERY_GROWTH_SECONDS: int = 120
const NURSERY_CARE_REDUCTION_SECONDS: int = 15
const NURSERY_MAX_CARE: int = 3
const NURSERY_LEVEL_ONE_CAPACITY: int = 2
const ROLE_BOARD_UNLOCK_MOUSE_COUNT: int = 3
const ROLE_BONUS_PER_MOUSE: float = 0.1
const ROLE_BONUS_MAX_MICE: int = 3
const HERO_UNLOCK_MOUSE_COUNT: int = 5
const HERO_GATHER_MULTIPLIER: float = 1.1
const HERO_REGION_MULTIPLIER: float = 1.15
const HERO_CARE_REDUCTION_SECONDS: int = 20

var cheese: float = 0.0
var total_cheese: float = 0.0
var mouse_count: int = 1
var speed_level: int = 0
var carry_level: int = 0
var hole_level: int = 1
var current_stage_index: int = 0
var highest_unlocked_stage_index: int = 0
var unlocked_stage_ids: Array[String] = []
var completed_region_event_ids: Array[String] = []
var next_region_event_unix: int = 0
var completed_field_action_ids: Array[String] = []
var next_field_action_unix: int = 0
var region_progress: Dictionary = {}
var nursery_level: int = 0
var nursery_pups: Array[Dictionary] = []
var total_raised_pups: int = 0
var next_pup_id: int = 1
var role_assignments: Dictionary = {
	"gatherer": 1,
	"explorer": 0,
	"builder": 0
}
var selected_hero_id: String = ""
var tutorial_step: int = 0
var golden_remaining: float = 0.0
var click_boost_remaining: float = 0.0
var play_time_seconds: float = 0.0
var total_trips: int = 0
var total_click_boosts: int = 0
var total_golden_events: int = 0
var stages: Array[Dictionary] = []
var heroes: Array[Dictionary] = []
var offline_reward: float = 0.0
var offline_seconds: int = 0
var display_name: String = "쥐구멍"
var product_name: String = "r4"
var build_version: String = "0.2.7"
var build_phase: String = "V0.2 Alpha"

var _auto_save_elapsed: float = 0.0
var _next_golden_event: float = 45.0
var _is_ready: bool = false


func _ready() -> void:
	_load_build_info()
	_load_stages()
	_load_heroes()
	var loaded_data: Dictionary = SaveManager.load_game(_default_save_data())
	_apply_save_data(loaded_data)
	_reconcile_role_assignments()
	_reconcile_unlocked_stages()
	_reconcile_region_progress()
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


func collect_trip(
	base_amount: int,
	reward_multiplier: float = 1.0,
	include_gather_hero: bool = true
) -> int:
	var final_reward: int = _calculate_trip_reward(
		base_amount,
		reward_multiplier,
		include_gather_hero
	)
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
	_reconcile_role_assignments()
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


func is_nursery_unlocked() -> bool:
	return hole_level >= NURSERY_UNLOCK_HOLE_LEVEL


func get_nursery_capacity() -> int:
	return NURSERY_LEVEL_ONE_CAPACITY if nursery_level > 0 else 0


func get_nursery_build_cost() -> int:
	return NURSERY_BUILD_COST


func get_nursery_pup_cost() -> int:
	return _scaled_cost(NURSERY_BASE_PUP_COST, total_raised_pups)


func build_nursery() -> bool:
	if nursery_level > 0:
		EventBus.toast_requested.emit("보육실은 이미 운영 중입니다.")
		return false
	if not is_nursery_unlocked():
		EventBus.toast_requested.emit(
			"보육실은 쥐구멍 Lv.%d에 열립니다." % NURSERY_UNLOCK_HOLE_LEVEL
		)
		return false
	if not _spend_cheese(get_nursery_build_cost()):
		return false
	nursery_level = 1
	EventBus.toast_requested.emit("새끼쥐 보육실을 열었습니다!")
	EventBus.game_state_changed.emit()
	save_now()
	return true


func start_nursery_pup() -> bool:
	if nursery_level <= 0:
		EventBus.toast_requested.emit("보육실을 먼저 건설해야 합니다.")
		return false
	if nursery_pups.size() >= get_nursery_capacity():
		EventBus.toast_requested.emit("보육실 슬롯이 가득 찼습니다.")
		return false
	if not _spend_cheese(get_nursery_pup_cost()):
		return false
	nursery_pups.append({
		"id": next_pup_id,
		"ready_unix": TimeManager.current_unix_time() + get_nursery_growth_seconds(),
		"care_count": 0
	})
	next_pup_id += 1
	EventBus.toast_requested.emit("작은 새끼 점이 보육실에 들어왔습니다.")
	EventBus.game_state_changed.emit()
	save_now()
	return true


func get_nursery_pup_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	var now: int = TimeManager.current_unix_time()
	for pup: Dictionary in nursery_pups:
		var snapshot: Dictionary = pup.duplicate(true)
		var remaining: int = maxi(0, _dictionary_int(pup, "ready_unix", now) - now)
		snapshot["remaining_seconds"] = remaining
		snapshot["ready"] = remaining <= 0
		snapshots.append(snapshot)
	return snapshots


func care_for_pup(pup_id: int) -> bool:
	var now: int = TimeManager.current_unix_time()
	for index: int in range(nursery_pups.size()):
		var pup: Dictionary = nursery_pups[index]
		if _dictionary_int(pup, "id", 0) != pup_id:
			continue
		if _dictionary_int(pup, "ready_unix", now) <= now:
			EventBus.toast_requested.emit("성장이 끝났습니다. 성체로 합류시켜 주세요.")
			return false
		var care_count: int = _dictionary_int(pup, "care_count", 0)
		if care_count >= NURSERY_MAX_CARE:
			EventBus.toast_requested.emit("이 새끼는 돌봄을 모두 받았습니다.")
			return false
		pup["ready_unix"] = maxi(
			now,
			_dictionary_int(pup, "ready_unix", now) - get_nursery_care_reduction_seconds()
		)
		pup["care_count"] = care_count + 1
		nursery_pups[index] = pup
		EventBus.toast_requested.emit(
			"돌봄 완료 · 성장 %d초 단축" % get_nursery_care_reduction_seconds()
		)
		EventBus.game_state_changed.emit()
		save_now()
		return true
	EventBus.toast_requested.emit("해당 새끼를 찾지 못했습니다.")
	return false


func claim_grown_pup(pup_id: int) -> bool:
	var now: int = TimeManager.current_unix_time()
	for index: int in range(nursery_pups.size()):
		var pup: Dictionary = nursery_pups[index]
		if _dictionary_int(pup, "id", 0) != pup_id:
			continue
		if _dictionary_int(pup, "ready_unix", now + 1) > now:
			EventBus.toast_requested.emit("아직 성장 중입니다.")
			return false
		nursery_pups.remove_at(index)
		total_raised_pups += 1
		mouse_count += 1
		_reconcile_role_assignments()
		EventBus.mouse_count_changed.emit(mouse_count)
		EventBus.toast_requested.emit("보육실에서 자란 새 쥐가 군락에 합류했습니다!")
		EventBus.game_state_changed.emit()
		save_now()
		return true
	EventBus.toast_requested.emit("합류할 새끼를 찾지 못했습니다.")
	return false


func is_role_board_unlocked() -> bool:
	return mouse_count >= ROLE_BOARD_UNLOCK_MOUSE_COUNT


func get_role_count(role_id: String) -> int:
	return maxi(0, _dictionary_int(role_assignments, role_id, 0))


func get_gatherer_count() -> int:
	return maxi(1, get_role_count("gatherer"))


func get_explorer_reward_multiplier() -> float:
	var bonus_mice: int = mini(get_role_count("explorer"), ROLE_BONUS_MAX_MICE)
	return 1.0 + float(bonus_mice) * ROLE_BONUS_PER_MOUSE


func get_region_activity_multiplier() -> float:
	var hero_multiplier: float = (
		HERO_REGION_MULTIPLIER
		if selected_hero_id == "saebyeok"
		else 1.0
	)
	return get_explorer_reward_multiplier() * hero_multiplier


func get_gather_hero_multiplier() -> float:
	return HERO_GATHER_MULTIPLIER if selected_hero_id == "dandani" else 1.0


func get_nursery_care_reduction_seconds() -> int:
	return (
		HERO_CARE_REDUCTION_SECONDS
		if selected_hero_id == "boreum"
		else NURSERY_CARE_REDUCTION_SECONDS
	)


func get_builder_growth_multiplier() -> float:
	var bonus_mice: int = mini(get_role_count("builder"), ROLE_BONUS_MAX_MICE)
	return 1.0 - float(bonus_mice) * ROLE_BONUS_PER_MOUSE


func get_nursery_growth_seconds() -> int:
	return maxi(
		1,
		roundi(float(NURSERY_GROWTH_SECONDS) * get_builder_growth_multiplier())
	)


func assign_mouse_role(role_id: String) -> bool:
	_reconcile_role_assignments()
	if not is_role_board_unlocked():
		EventBus.toast_requested.emit(
			"역할 보드는 쥐 %d마리부터 열립니다." % ROLE_BOARD_UNLOCK_MOUSE_COUNT
		)
		return false
	if role_id == "gatherer":
		if get_role_count("builder") > 0:
			role_assignments["builder"] = get_role_count("builder") - 1
		elif get_role_count("explorer") > 0:
			role_assignments["explorer"] = get_role_count("explorer") - 1
		else:
			EventBus.toast_requested.emit("모든 쥐가 이미 채집 중입니다.")
			return false
		role_assignments["gatherer"] = get_role_count("gatherer") + 1
	elif role_id == "explorer" or role_id == "builder":
		if get_role_count("gatherer") <= 1:
			EventBus.toast_requested.emit("채집쥐 한 마리는 군락에 남아야 합니다.")
			return false
		role_assignments["gatherer"] = get_role_count("gatherer") - 1
		role_assignments[role_id] = get_role_count(role_id) + 1
	else:
		return false
	EventBus.mouse_count_changed.emit(mouse_count)
	EventBus.game_state_changed.emit()
	save_now()
	return true


func reset_mouse_roles() -> bool:
	_reconcile_role_assignments()
	if get_role_count("explorer") <= 0 and get_role_count("builder") <= 0:
		return false
	role_assignments = {
		"gatherer": mouse_count,
		"explorer": 0,
		"builder": 0
	}
	EventBus.mouse_count_changed.emit(mouse_count)
	EventBus.game_state_changed.emit()
	EventBus.toast_requested.emit("모든 쥐가 채집 역할로 복귀했습니다.")
	save_now()
	return true


func _reconcile_role_assignments() -> void:
	var explorer_count: int = clampi(
		get_role_count("explorer"),
		0,
		maxi(0, mouse_count - 1)
	)
	var builder_count: int = clampi(
		get_role_count("builder"),
		0,
		maxi(0, mouse_count - explorer_count - 1)
	)
	role_assignments = {
		"gatherer": mouse_count - explorer_count - builder_count,
		"explorer": explorer_count,
		"builder": builder_count
	}


func is_hero_selection_unlocked() -> bool:
	return mouse_count >= HERO_UNLOCK_MOUSE_COUNT


func get_hero_candidates() -> Array[Dictionary]:
	return heroes.duplicate(true)


func get_selected_hero() -> Dictionary:
	for hero: Dictionary in heroes:
		if _dictionary_string(hero, "id", "") == selected_hero_id:
			return hero.duplicate(true)
	return {}


func recruit_hero(hero_id: String) -> bool:
	if not is_hero_selection_unlocked():
		EventBus.toast_requested.emit(
			"첫 영웅은 쥐 %d마리부터 선택할 수 있습니다." % HERO_UNLOCK_MOUSE_COUNT
		)
		return false
	if not selected_hero_id.is_empty():
		EventBus.toast_requested.emit("첫 영웅은 이미 정해졌습니다.")
		return false
	var candidate_found: bool = false
	for hero: Dictionary in heroes:
		if _dictionary_string(hero, "id", "") == hero_id:
			candidate_found = true
			break
	if not candidate_found:
		return false
	selected_hero_id = hero_id
	var selected: Dictionary = get_selected_hero()
	EventBus.toast_requested.emit(
		"%s · %s이(가) 첫 영웅이 되었습니다!" % [
			_dictionary_string(selected, "name", "이름 없는 쥐"),
			_dictionary_string(selected, "title", "첫 영웅")
		]
	)
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
	var speed: float = minf(
		BASE_SPEED + sqrt(float(speed_level)) * SPEED_LEVEL_CURVE,
		MAX_MOVE_SPEED
	)
	if click_boost_remaining > 0.0:
		speed = minf(speed * CLICK_BOOST_MULTIPLIER, MAX_BOOSTED_MOVE_SPEED)
	return speed


func get_carry_capacity() -> int:
	return BASE_CARRY + carry_level


func get_stage_bonus() -> float:
	if stages.is_empty():
		return 1.0
	var stage: Dictionary = stages[current_stage_index]
	var bonus: float = _dictionary_float(stage, "production_bonus", 1.0)
	var state: Dictionary = get_region_state(_dictionary_string(stage, "id", ""))
	if _dictionary_bool(state, "route_unlocked", false):
		bonus *= 1.05
	return bonus


func get_region_state(stage_id: String) -> Dictionary:
	var value: Variant = region_progress.get(stage_id, {})
	if value is Dictionary:
		@warning_ignore("unsafe_cast")
		return (value as Dictionary).duplicate(true)
	return {}


func get_current_stage() -> Dictionary:
	if stages.is_empty():
		return {
			"name": "낡은 부엌",
			"background_color": "#352a3b",
			"production_bonus": 1.0
		}
	return stages[current_stage_index]


func get_next_stage() -> Dictionary:
	var next_index: int = highest_unlocked_stage_index + 1
	if next_index >= stages.size():
		return {}
	return stages[next_index]


func get_unlocked_stages() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(mini(highest_unlocked_stage_index + 1, stages.size())):
		result.append(stages[index])
	return result


func get_region_codex_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var unlocked_stages: Array[Dictionary] = get_unlocked_stages()
	for index: int in range(unlocked_stages.size()):
		var stage: Dictionary = unlocked_stages[index]
		var region_event: Dictionary = _dictionary_dictionary(stage, "choice_event")
		var event_id: String = _dictionary_string(region_event, "id", "")
		var field_action: Dictionary = _dictionary_dictionary(stage, "field_action")
		var action_id: String = _dictionary_string(field_action, "id", "")
		var stage_id: String = _dictionary_string(stage, "id", "")
		var region_state: Dictionary = get_region_state(stage_id)
		result.append({
			"stage_index": index,
			"stage_id": _dictionary_string(stage, "id", ""),
			"name": _dictionary_string(stage, "name", "지역"),
			"resource": _dictionary_string(stage, "resource", "미확인 자원"),
			"hazard": _dictionary_string(stage, "hazard", "미확인 위험"),
			"event_title": _dictionary_string(region_event, "title", "미확인 사건"),
			"discovered": completed_region_event_ids.has(event_id),
			"action_title": _dictionary_string(field_action, "title", ""),
			"action_completed": (
				not action_id.is_empty()
				and completed_field_action_ids.has(action_id)
			),
			"action_level": _dictionary_int(region_state, "action_level", 0),
			"risk_level": _dictionary_int(region_state, "risk_level", 2),
			"route_unlocked": _dictionary_bool(region_state, "route_unlocked", false),
			"current": index == current_stage_index
		})
	return result


func get_region_codex_progress() -> Dictionary:
	var entries: Array[Dictionary] = get_region_codex_entries()
	var discovered: int = 0
	for entry: Dictionary in entries:
		var discovered_value: Variant = entry.get("discovered", false)
		if discovered_value is bool and discovered_value:
			discovered += 1
	return {"discovered": discovered, "total": entries.size()}


func select_stage(stage_index: int) -> bool:
	if stage_index < 0 or stage_index > highest_unlocked_stage_index:
		return false
	if stage_index >= stages.size():
		return false
	if stage_index == current_stage_index:
		return true
	current_stage_index = stage_index
	EventBus.stage_changed.emit(current_stage_index)
	EventBus.toast_requested.emit(
		"지역 이동: %s" % _dictionary_string(get_current_stage(), "name", "")
	)
	EventBus.game_state_changed.emit()
	save_now()
	return true


func get_build_label() -> String:
	return "%s %s" % [product_name, build_version]


func get_world_news() -> String:
	var stage: Dictionary = get_current_stage()
	var news_items: Array = stage.get("world_events", [])
	var life_items: Array = stage.get("daily_life", [])
	var combined: Array[String] = []
	for item: Variant in news_items:
		if item is String:
			combined.append(item)
	for item: Variant in life_items:
		if item is String:
			combined.append(item)
	if combined.is_empty():
		return "정찰대가 다음 통로를 조사 중"
	var news_index: int = int(play_time_seconds / 12.0) % combined.size()
	return combined[news_index]


func get_current_region_event() -> Dictionary:
	var stage: Dictionary = get_current_stage()
	var event_value: Variant = stage.get("choice_event", {})
	if event_value is Dictionary:
		@warning_ignore("unsafe_cast")
		var region_event: Dictionary = (event_value as Dictionary).duplicate(true)
		var choices_value: Variant = region_event.get("choices", [])
		var expert_choice: Dictionary = _dictionary_dictionary(
			region_event,
			"expert_choice"
		).duplicate(true)
		if choices_value is Array and not expert_choice.is_empty():
			@warning_ignore("unsafe_cast")
			var choices: Array = (choices_value as Array).duplicate(true)
			var stage_id: String = _dictionary_string(stage, "id", "")
			var state: Dictionary = get_region_state(stage_id)
			var required_level: int = _dictionary_int(
				expert_choice,
				"requires_action_level",
				3
			)
			var current_level: int = _dictionary_int(state, "action_level", 0)
			expert_choice["locked"] = current_level < required_level
			expert_choice["lock_reason"] = "현장 행동 숙련 Lv.%d 필요" % required_level
			choices.append(expert_choice)
			region_event["choices"] = choices
		return region_event
	return {}


func get_region_event_cooldown() -> int:
	return maxi(0, next_region_event_unix - TimeManager.current_unix_time())


func resolve_region_event(choice_index: int) -> Dictionary:
	if get_region_event_cooldown() > 0:
		return {}
	var region_event: Dictionary = get_current_region_event()
	if region_event.is_empty():
		return {}
	var choices_value: Variant = region_event.get("choices", [])
	if not choices_value is Array:
		return {}
	@warning_ignore("unsafe_cast")
	var choices: Array = choices_value as Array
	if choice_index < 0 or choice_index >= choices.size():
		return {}
	var choice_value: Variant = choices[choice_index]
	if not choice_value is Dictionary:
		return {}
	@warning_ignore("unsafe_cast")
	var choice: Dictionary = choice_value as Dictionary
	if _dictionary_bool(choice, "locked", false):
		return {}
	var event_id: String = _dictionary_string(region_event, "id", "")
	var first_discovery: bool = (
		not event_id.is_empty()
		and not completed_region_event_ids.has(event_id)
	)
	var reward_trips: int = maxi(1, _dictionary_int(choice, "reward_trips", 1))
	var stage_id: String = _dictionary_string(get_current_stage(), "id", "")
	var region_state: Dictionary = get_region_state(stage_id)
	if _dictionary_bool(region_state, "route_unlocked", false):
		reward_trips += 1
	var first_reward_trips: int = 0
	if first_discovery:
		first_reward_trips = maxi(
			0,
			_dictionary_int(region_event, "first_discovery_reward_trips", 0)
		)
		completed_region_event_ids.append(event_id)
	var role_multiplier: float = get_region_activity_multiplier()
	var base_reward: int = _calculate_trip_reward(
		get_carry_capacity() * reward_trips,
		role_multiplier,
		false
	)
	var reward: int = collect_trip(
		get_carry_capacity() * (reward_trips + first_reward_trips),
		role_multiplier,
		false
	)
	var first_discovery_reward: int = maxi(0, reward - base_reward)
	var choice_effect: String = _dictionary_string(choice, "effect", "secure")
	if choice_effect == "rush":
		var boost_seconds: float = _dictionary_float(choice, "boost_seconds", 8.0)
		click_boost_remaining = maxf(click_boost_remaining, boost_seconds)
		total_click_boosts += 1
		EventBus.click_boost_changed.emit(true, click_boost_remaining)
	var default_risk_delta: int = 1 if choice_effect == "rush" else -1
	var risk_delta: int = _dictionary_int(choice, "risk_delta", default_risk_delta)
	region_state["risk_level"] = clampi(
		_dictionary_int(region_state, "risk_level", 2) + risk_delta,
		0,
		3
	)
	region_state["last_choice_id"] = _dictionary_string(
		choice,
		"id",
		"%s_%d" % [event_id, choice_index]
	)
	region_progress[stage_id] = region_state
	next_region_event_unix = TimeManager.current_unix_time() + REGION_EVENT_COOLDOWN_SECONDS
	EventBus.game_state_changed.emit()
	save_now()
	return {
		"event_id": event_id,
		"result": _dictionary_string(choice, "result", "원정대가 무사히 돌아왔습니다."),
		"reward": reward,
		"first_discovery": first_discovery,
		"first_discovery_reward": first_discovery_reward,
		"boosted": choice_effect == "rush",
		"region_state": region_state
	}


func is_current_region_event_discovered() -> bool:
	var region_event: Dictionary = get_current_region_event()
	var event_id: String = _dictionary_string(region_event, "id", "")
	return not event_id.is_empty() and completed_region_event_ids.has(event_id)


func get_current_field_action() -> Dictionary:
	var stage: Dictionary = get_current_stage()
	return _dictionary_dictionary(stage, "field_action").duplicate(true)


func get_field_action_cooldown() -> int:
	return maxi(0, next_field_action_unix - TimeManager.current_unix_time())


func is_current_field_action_completed() -> bool:
	var action: Dictionary = get_current_field_action()
	var action_id: String = _dictionary_string(action, "id", "")
	return not action_id.is_empty() and completed_field_action_ids.has(action_id)


func resolve_field_action(action_id: String, mistakes: int) -> Dictionary:
	if get_field_action_cooldown() > 0:
		return {}
	var action: Dictionary = get_current_field_action()
	if action.is_empty():
		return {}
	var current_action_id: String = _dictionary_string(action, "id", "")
	if action_id.is_empty() or action_id != current_action_id:
		return {}
	var stage_id: String = _dictionary_string(get_current_stage(), "id", "")
	var state: Dictionary = get_region_state(stage_id)
	var previous_level: int = _dictionary_int(state, "action_level", 0)
	var first_completion: bool = not completed_field_action_ids.has(action_id)
	var reward_trips: int = maxi(1, _dictionary_int(action, "reward_trips", 1))
	if previous_level >= 1:
		reward_trips += 1
	var first_reward_trips: int = 0
	if first_completion:
		first_reward_trips = maxi(
			0,
			_dictionary_int(action, "first_completion_reward_trips", 0)
		)
		completed_field_action_ids.append(action_id)
	state["action_level"] = mini(3, previous_level + 1)
	state["route_unlocked"] = true
	state["risk_level"] = maxi(0, _dictionary_int(state, "risk_level", 2) - 1)
	var flags: Array[String] = _dictionary_string_array(state, "flags")
	var result_flag: String = _dictionary_string(action, "result_flag", "")
	if not result_flag.is_empty() and not flags.has(result_flag):
		flags.append(result_flag)
	state["flags"] = flags
	var role_multiplier: float = get_region_activity_multiplier()
	var base_reward: int = _calculate_trip_reward(
		get_carry_capacity() * reward_trips,
		role_multiplier,
		false
	)
	var reward: int = collect_trip(
		get_carry_capacity() * (reward_trips + first_reward_trips),
		role_multiplier,
		false
	)
	region_progress[stage_id] = state
	next_field_action_unix = (
		TimeManager.current_unix_time() + FIELD_ACTION_COOLDOWN_SECONDS
	)
	EventBus.game_state_changed.emit()
	save_now()
	return {
		"action_id": action_id,
		"title": _dictionary_string(action, "title", "현장 행동"),
		"reward": reward,
		"first_completion": first_completion,
		"first_completion_reward": maxi(0, reward - base_reward),
		"mistakes": maxi(0, mistakes),
		"region_state": state
	}


func get_colony_rank() -> String:
	if hole_level >= 35:
		return "지하 연맹"
	if hole_level >= 20:
		return "쥐구멍 도시"
	if hole_level >= 10:
		return "치즈 마을"
	if hole_level >= 5:
		return "작은 군락"
	return "첫 보금자리"


func get_next_colony_goal() -> Dictionary:
	var goals: Array[Dictionary] = [
		{"previous_level": 0, "target_level": 5, "title": "공동 식탁", "description": "식사와 휴식 공간"},
		{"previous_level": 5, "target_level": 10, "title": "새끼쥐 보육실", "description": "가족과 생활의 시작"},
		{"previous_level": 10, "target_level": 20, "title": "지하 시장", "description": "지역 자원 교환"},
		{"previous_level": 20, "target_level": 35, "title": "통로 의회", "description": "다섯 지역 대표 결성"},
		{"previous_level": 35, "target_level": 50, "title": "도시 아래 왕국", "description": "다음 세계 원정 준비"}
	]
	for goal: Dictionary in goals:
		if hole_level < _dictionary_int(goal, "target_level", hole_level + 1):
			return goal
	return {
		"previous_level": 50,
		"target_level": 75,
		"title": "심층 세계 탐사",
		"description": "미지의 지하 문명 발견"
	}


func get_next_reward_summary() -> Dictionary:
	var next_stage: Dictionary = get_next_stage()
	if next_stage.is_empty():
		var colony_goal: Dictionary = get_next_colony_goal()
		var target_level: int = _dictionary_int(
			colony_goal,
			"target_level",
			hole_level + 1
		)
		var previous_level: int = _dictionary_int(colony_goal, "previous_level", 0)
		var progress: float = clampf(
			float(hole_level - previous_level)
			/ float(maxi(1, target_level - previous_level))
			* 100.0,
			0.0,
			100.0
		)
		return {
			"kind": "colony",
			"title": "%s · 다음: %s" % [
				get_colony_rank(),
				_dictionary_string(colony_goal, "title", "쥐 사회 확장")
			],
			"detail": "쥐구멍 Lv.%d / %d · %s" % [
				hole_level,
				target_level,
				_dictionary_string(colony_goal, "description", "새 생활 공간 발견")
			],
			"status": "세계 소식 · %s" % get_world_news(),
			"current": float(hole_level),
			"target": float(target_level),
			"progress": progress
		}

	var stage: Dictionary = get_current_stage()
	var current_threshold: float = _dictionary_float(stage, "unlock_total_cheese", 0.0)
	var target_threshold: float = _dictionary_float(next_stage, "unlock_total_cheese", 0.0)
	var needed: float = maxf(0.0, target_threshold - total_cheese)
	var next_index: int = highest_unlocked_stage_index + 1
	return {
		"kind": "stage",
		"title": "다음 보상 · %s" % _dictionary_string(next_stage, "name", ""),
		"detail": "%s · %s" % [
			_dictionary_string(next_stage, "resource", "새 자원"),
			_dictionary_string(next_stage, "event", "새 발견")
		],
		"status": "다음: %s (누적 %s 남음)" % [
			_dictionary_string(next_stage, "name", ""),
			_format_compact_number(needed)
		],
		"current": total_cheese,
		"target": target_threshold,
		"progress": clampf(
			(total_cheese - current_threshold)
			/ maxf(1.0, target_threshold - current_threshold)
			* 100.0,
			0.0,
			100.0
		),
		"stage_index": next_index
	}


func get_expected_per_second() -> float:
	var round_trip_seconds: float = (ESTIMATED_ONE_WAY_DISTANCE * 2.0) / get_move_speed()
	var reward_per_trip: float = (
		float(get_carry_capacity())
		* get_stage_bonus()
		* ALPHA_TEST_REWARD_MULTIPLIER
	)
	if golden_remaining > 0.0:
		reward_per_trip *= GOLDEN_MULTIPLIER
	reward_per_trip *= get_gather_hero_multiplier()
	return reward_per_trip * float(get_gatherer_count()) / maxf(round_trip_seconds, 0.1)


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


func _calculate_trip_reward(
	base_amount: int,
	reward_multiplier: float = 1.0,
	include_gather_hero: bool = true
) -> int:
	var reward: float = (
		float(base_amount)
		* get_stage_bonus()
		* ALPHA_TEST_REWARD_MULTIPLIER
		* maxf(0.0, reward_multiplier)
	)
	if include_gather_hero:
		reward *= get_gather_hero_multiplier()
	if golden_remaining > 0.0:
		reward *= GOLDEN_MULTIPLIER
	return maxi(1, roundi(reward))


func _format_compact_number(value: float) -> String:
	var absolute_value: float = absf(value)
	if absolute_value >= 1_000_000_000.0:
		return "%.2fB" % (value / 1_000_000_000.0)
	if absolute_value >= 1_000_000.0:
		return "%.2fM" % (value / 1_000_000.0)
	if absolute_value >= 1_000.0:
		return "%.2fK" % (value / 1_000.0)
	return "%d" % roundi(value)


func _update_unlocked_stage() -> void:
	var unlocked_index: int = highest_unlocked_stage_index
	for index: int in range(stages.size()):
		var threshold: float = _dictionary_float(stages[index], "unlock_total_cheese", 0.0)
		if total_cheese >= threshold:
			unlocked_index = index
	if unlocked_index > highest_unlocked_stage_index:
		highest_unlocked_stage_index = unlocked_index
		_rebuild_unlocked_stage_ids()
		current_stage_index = unlocked_index
		EventBus.stage_changed.emit(current_stage_index)
		EventBus.stage_discovered.emit(current_stage_index)
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
		"selected_stage_index": 0,
		"unlocked_stage_ids": [],
		"completed_region_event_ids": [],
		"next_region_event_unix": 0,
		"completed_field_action_ids": [],
		"next_field_action_unix": 0,
		"region_progress": {},
		"nursery_level": 0,
		"nursery_pups": [],
		"total_raised_pups": 0,
		"next_pup_id": 1,
		"role_assignments": {
			"gatherer": 1,
			"explorer": 0,
			"builder": 0
		},
		"selected_hero_id": "",
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
		_dictionary_int(
			data,
			"selected_stage_index",
			_dictionary_int(data, "current_stage_index", 0)
		),
		0,
		maxi(0, stages.size() - 1)
	)
	unlocked_stage_ids = _dictionary_string_array(data, "unlocked_stage_ids")
	completed_region_event_ids = _dictionary_string_array(
		data,
		"completed_region_event_ids"
	)
	next_region_event_unix = maxi(
		0,
		_dictionary_int(data, "next_region_event_unix", 0)
	)
	completed_field_action_ids = _dictionary_string_array(
		data,
		"completed_field_action_ids"
	)
	next_field_action_unix = maxi(
		0,
		_dictionary_int(data, "next_field_action_unix", 0)
	)
	region_progress = _dictionary_dictionary(data, "region_progress").duplicate(true)
	nursery_level = clampi(_dictionary_int(data, "nursery_level", 0), 0, 1)
	nursery_pups.clear()
	var pups_value: Variant = data.get("nursery_pups", [])
	if pups_value is Array:
		@warning_ignore("unsafe_cast")
		var loaded_pups: Array = pups_value as Array
		for pup_value: Variant in loaded_pups:
			if pup_value is Dictionary:
				@warning_ignore("unsafe_cast")
				var pup: Dictionary = (pup_value as Dictionary).duplicate(true)
				var pup_id: int = _dictionary_int(pup, "id", 0)
				var ready_unix: int = _dictionary_int(pup, "ready_unix", 0)
				if pup_id > 0 and ready_unix > 0:
					pup["id"] = pup_id
					pup["ready_unix"] = ready_unix
					pup["care_count"] = clampi(
						_dictionary_int(pup, "care_count", 0),
						0,
						NURSERY_MAX_CARE
					)
					nursery_pups.append(pup)
	if nursery_level <= 0:
		nursery_pups.clear()
	elif nursery_pups.size() > get_nursery_capacity():
		nursery_pups.resize(get_nursery_capacity())
	total_raised_pups = maxi(0, _dictionary_int(data, "total_raised_pups", 0))
	next_pup_id = maxi(1, _dictionary_int(data, "next_pup_id", 1))
	for pup: Dictionary in nursery_pups:
		next_pup_id = maxi(next_pup_id, _dictionary_int(pup, "id", 0) + 1)
	role_assignments = _dictionary_dictionary(
		data,
		"role_assignments"
	).duplicate(true)
	selected_hero_id = _dictionary_string(data, "selected_hero_id", "")
	if get_selected_hero().is_empty():
		selected_hero_id = ""
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
		"selected_stage_index": current_stage_index,
		"unlocked_stage_ids": unlocked_stage_ids.duplicate(),
		"completed_region_event_ids": completed_region_event_ids.duplicate(),
		"next_region_event_unix": next_region_event_unix,
		"completed_field_action_ids": completed_field_action_ids.duplicate(),
		"next_field_action_unix": next_field_action_unix,
		"region_progress": region_progress.duplicate(true),
		"nursery_level": nursery_level,
		"nursery_pups": nursery_pups.duplicate(true),
		"total_raised_pups": total_raised_pups,
		"next_pup_id": next_pup_id,
		"role_assignments": role_assignments.duplicate(true),
		"selected_hero_id": selected_hero_id,
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


func _load_heroes() -> void:
	heroes.clear()
	var hero_file: FileAccess = FileAccess.open(HEROES_PATH, FileAccess.READ)
	if hero_file != null:
		var parsed: Variant = JSON.parse_string(hero_file.get_as_text())
		hero_file.close()
		if parsed is Array:
			@warning_ignore("unsafe_cast")
			var raw_heroes: Array = parsed as Array
			for raw_hero: Variant in raw_heroes:
				if raw_hero is Dictionary:
					@warning_ignore("unsafe_cast")
					heroes.append((raw_hero as Dictionary).duplicate(true))
	if heroes.is_empty():
		heroes = _fallback_heroes()


func _fallback_heroes() -> Array[Dictionary]:
	return [
		{
			"id": "dandani",
			"name": "단단이",
			"title": "첫 운반대장",
			"story": "가장 무거운 치즈를 끝까지 놓지 않고 돌아온 쥐.",
			"effect": "일반 채집과 예상 생산 +10%",
			"color": "#ffd969"
		},
		{
			"id": "saebyeok",
			"name": "새벽",
			"title": "틈길 길잡이",
			"story": "모두가 잠든 시간에 안전한 틈을 찾아낸 쥐.",
			"effect": "지역 사건·현장 행동 보상 +15%",
			"color": "#73d7ff"
		},
		{
			"id": "boreum",
			"name": "보름",
			"title": "보육실 지킴이",
			"story": "어린 점들의 작은 떨림을 먼저 알아차린 쥐.",
			"effect": "돌봄 1회 성장 단축 15초 → 20초",
			"color": "#df9cff"
		}
	]


func _reconcile_unlocked_stages() -> void:
	highest_unlocked_stage_index = 0
	for index: int in range(stages.size()):
		var threshold: float = _dictionary_float(stages[index], "unlock_total_cheese", 0.0)
		if total_cheese >= threshold:
			highest_unlocked_stage_index = index
	current_stage_index = clampi(
		current_stage_index,
		0,
		highest_unlocked_stage_index
	)
	_rebuild_unlocked_stage_ids()


func _rebuild_unlocked_stage_ids() -> void:
	unlocked_stage_ids.clear()
	for index: int in range(mini(highest_unlocked_stage_index + 1, stages.size())):
		var stage_id: String = _dictionary_string(stages[index], "id", "")
		if not stage_id.is_empty():
			unlocked_stage_ids.append(stage_id)


func _reconcile_region_progress() -> void:
	for stage: Dictionary in stages:
		var stage_id: String = _dictionary_string(stage, "id", "")
		if stage_id.is_empty():
			continue
		var state: Dictionary = get_region_state(stage_id)
		if state.is_empty():
			state = {
				"action_level": 0,
				"risk_level": 2,
				"route_unlocked": false,
				"flags": [],
				"last_choice_id": ""
			}
		region_progress[stage_id] = state


func _load_build_info() -> void:
	var build_file: FileAccess = FileAccess.open(BUILD_INFO_PATH, FileAccess.READ)
	if build_file == null:
		return
	var parsed: Variant = JSON.parse_string(build_file.get_as_text())
	build_file.close()
	if not parsed is Dictionary:
		return
	@warning_ignore("unsafe_cast")
	var build_info: Dictionary = parsed as Dictionary
	display_name = _dictionary_string(build_info, "display_name", display_name)
	product_name = _dictionary_string(build_info, "product_name", product_name)
	build_version = _dictionary_string(build_info, "version", build_version)
	build_phase = _dictionary_string(build_info, "phase", build_phase)


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


func _dictionary_bool(data: Dictionary, key: String, fallback: bool) -> bool:
	var value: Variant = data.get(key, fallback)
	if value is bool:
		return value
	return fallback


func _dictionary_dictionary(data: Dictionary, key: String) -> Dictionary:
	var value: Variant = data.get(key, {})
	if value is Dictionary:
		@warning_ignore("unsafe_cast")
		return value as Dictionary
	return {}


func _dictionary_string_array(data: Dictionary, key: String) -> Array[String]:
	var result: Array[String] = []
	var value: Variant = data.get(key, [])
	if not value is Array:
		return result
	@warning_ignore("unsafe_cast")
	var raw_values: Array = value as Array
	for item: Variant in raw_values:
		if item is String:
			result.append(item)
	return result
