extends Node

var _failures: int = 0


func _ready() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_time_cap()
	_test_build_info()
	_test_save_schema_migration()
	_test_upgrade_costs()
	_test_natural_speed_curve()
	_test_visual_progression()
	_test_golden_reward()
	_test_colony_progression()
	_test_next_reward_summary()
	_test_region_selection()
	_test_region_codex()
	_test_region_events()
	_test_field_action_data()
	_test_field_action_resolution()
	_test_dot_action_input()
	_test_nursery_lifecycle()
	_test_nursery_view_input()
	_test_role_assignment()
	_test_role_board_input()
	_test_hero_data()
	_test_hero_selection()
	_test_hero_choice_input()
	_test_reward_text_bounds()
	_test_stage_backgrounds()
	_test_stage_choice_events()
	_test_background_anchor_alignment()
	_test_perspective_route()
	_test_mouse_sprites()
	_test_korean_font()
	_test_save_round_trip()
	await _test_ui_layout()
	await _test_mouse_round_trip()

	if _failures == 0:
		print("JJUGUMEONG V0.4.2 tests: PASS")
		get_tree().quit(0)
	else:
		push_error("JJUGUMEONG V0.4.2 tests: %d failure(s)" % _failures)
		get_tree().quit(1)


func _test_time_cap() -> void:
	var now: int = TimeManager.current_unix_time()
	_expect_equal_int(TimeManager.capped_offline_seconds(now - 20_000), 14_400, "offline cap")
	_expect_equal_int(TimeManager.capped_offline_seconds(now + 100), 0, "future timestamp")


func _test_build_info() -> void:
	_expect_true(GameManager.display_name == "쥐구멍", "build display name")
	_expect_true(GameManager.product_name == "r4", "build product name")
	_expect_true(GameManager.build_version == "0.4.2", "build version")
	_expect_true(GameManager.build_phase == "V0.4 Alpha", "build phase")
	_expect_true(GameManager.get_build_label() == "r4 0.4.2", "build label")


func _test_save_schema_migration() -> void:
	var legacy: Dictionary = {
		"schema_version": 1,
		"cheese": 123.0,
		"total_cheese": 600.0,
		"current_stage_index": 2
	}
	var defaults: Dictionary = {
		"schema_version": SaveManager.CURRENT_SCHEMA_VERSION,
		"cheese": 0.0,
		"total_cheese": 0.0,
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
		"selected_hero_id": ""
	}
	var migrated_value: Variant = SaveManager.call("_migrate_data", legacy, defaults)
	_expect_true(migrated_value is Dictionary, "schema 1 migration result type")
	if migrated_value is Dictionary:
		@warning_ignore("unsafe_cast")
		var migrated: Dictionary = migrated_value as Dictionary
		_expect_equal_int(
			_dictionary_int(migrated, "schema_version", 0),
			7,
			"schema migration version"
		)
		_expect_equal_int(
			_dictionary_int(migrated, "selected_stage_index", -1),
			2,
			"schema migration selected stage"
		)
		_expect_dictionary_float(migrated, "cheese", 123.0, "schema migration cheese")
		_expect_equal_int(
			_dictionary_array_size(migrated, "completed_field_action_ids"),
			0,
			"schema migration field actions"
		)
		_expect_equal_int(
			_dictionary_array_size(migrated, "nursery_pups"),
			0,
			"schema migration nursery pups"
		)
	var schema_two: Dictionary = {
		"schema_version": 2,
		"selected_stage_index": 1,
		"completed_region_event_ids": ["kitchen_cat_patrol"]
	}
	var schema_two_value: Variant = SaveManager.call(
		"_migrate_data",
		schema_two,
		defaults
	)
	_expect_true(schema_two_value is Dictionary, "schema 2 migration result type")
	if schema_two_value is Dictionary:
		@warning_ignore("unsafe_cast")
		var schema_two_migrated: Dictionary = schema_two_value as Dictionary
		_expect_equal_int(
			_dictionary_int(schema_two_migrated, "schema_version", 0),
			7,
			"schema 2 migration version"
		)
		_expect_equal_int(
			_dictionary_int(schema_two_migrated, "selected_stage_index", -1),
			1,
			"schema 2 selected stage preserved"
		)
		_expect_equal_int(
			_dictionary_array_size(schema_two_migrated, "completed_field_action_ids"),
			0,
			"schema 2 field actions initialized"
		)
	var schema_four: Dictionary = {
		"schema_version": 4,
		"region_progress": {
			"old_kitchen": {
				"action_level": 2,
				"risk_level": 1
			}
		}
	}
	var schema_four_value: Variant = SaveManager.call(
		"_migrate_data",
		schema_four,
		defaults
	)
	_expect_true(schema_four_value is Dictionary, "schema 4 migration result type")
	if schema_four_value is Dictionary:
		@warning_ignore("unsafe_cast")
		var schema_four_migrated: Dictionary = schema_four_value as Dictionary
		_expect_equal_int(
			_dictionary_int(schema_four_migrated, "schema_version", 0),
			7,
			"schema 4 migration version"
		)
		_expect_equal_int(
			_dictionary_array_size(schema_four_migrated, "nursery_pups"),
			0,
			"schema 4 nursery pups initialized"
		)
		_expect_equal_int(
			_dictionary_int(schema_four_migrated, "next_pup_id", 0),
			1,
			"schema 4 next pup id initialized"
		)
	var schema_five: Dictionary = {
		"schema_version": 5,
		"mouse_count": 4,
		"nursery_level": 1,
		"nursery_pups": []
	}
	var schema_five_value: Variant = SaveManager.call(
		"_migrate_data",
		schema_five,
		defaults
	)
	_expect_true(schema_five_value is Dictionary, "schema 5 migration result type")
	if schema_five_value is Dictionary:
		@warning_ignore("unsafe_cast")
		var schema_five_migrated: Dictionary = schema_five_value as Dictionary
		var roles: Dictionary = _dictionary_dictionary(
			schema_five_migrated,
			"role_assignments"
		)
		_expect_equal_int(
			_dictionary_int(roles, "gatherer", 0),
			4,
			"schema 5 mice migrate to gatherers"
		)
	var schema_six: Dictionary = {
		"schema_version": 6,
		"mouse_count": 5,
		"role_assignments": {
			"gatherer": 3,
			"explorer": 1,
			"builder": 1
		}
	}
	var schema_six_value: Variant = SaveManager.call(
		"_migrate_data",
		schema_six,
		defaults
	)
	_expect_true(schema_six_value is Dictionary, "schema 6 migration result type")
	if schema_six_value is Dictionary:
		@warning_ignore("unsafe_cast")
		var schema_six_migrated: Dictionary = schema_six_value as Dictionary
		_expect_true(
			_dictionary_string(schema_six_migrated, "selected_hero_id", "").is_empty(),
			"schema 6 hero initialized"
		)


func _test_nursery_lifecycle() -> void:
	var previous_cheese: float = GameManager.cheese
	var previous_mouse_count: int = GameManager.mouse_count
	var previous_hole_level: int = GameManager.hole_level
	var previous_nursery_level: int = GameManager.nursery_level
	var previous_pups: Array[Dictionary] = GameManager.nursery_pups.duplicate(true)
	var previous_total_raised: int = GameManager.total_raised_pups
	var previous_next_pup_id: int = GameManager.next_pup_id
	var previous_roles: Dictionary = GameManager.role_assignments.duplicate(true)

	GameManager.cheese = 10_000.0
	GameManager.hole_level = 9
	GameManager.nursery_level = 0
	GameManager.nursery_pups.clear()
	GameManager.total_raised_pups = 0
	GameManager.next_pup_id = 1
	GameManager.role_assignments = {
		"gatherer": GameManager.mouse_count,
		"explorer": 0,
		"builder": 0
	}
	_expect_true(not GameManager.build_nursery(), "nursery locked before hole level 10")
	GameManager.hole_level = 10
	var before_build_cheese: float = GameManager.cheese
	_expect_true(GameManager.build_nursery(), "nursery builds at hole level 10")
	_expect_equal_float(
		GameManager.cheese,
		before_build_cheese - 500.0,
		"nursery build cost"
	)
	_expect_true(GameManager.start_nursery_pup(), "nursery starts first pup")
	_expect_true(GameManager.start_nursery_pup(), "nursery starts second pup")
	_expect_true(not GameManager.start_nursery_pup(), "nursery capacity enforced")
	var first_id: int = _dictionary_int(GameManager.nursery_pups[0], "id", 0)
	var ready_before: int = _dictionary_int(
		GameManager.nursery_pups[0],
		"ready_unix",
		0
	)
	_expect_true(GameManager.care_for_pup(first_id), "nursery care applies")
	_expect_equal_int(
		_dictionary_int(GameManager.nursery_pups[0], "ready_unix", 0),
		ready_before - GameManager.NURSERY_CARE_REDUCTION_SECONDS,
		"nursery care time reduction"
	)
	_expect_true(GameManager.care_for_pup(first_id), "nursery second care")
	_expect_true(GameManager.care_for_pup(first_id), "nursery third care")
	_expect_true(not GameManager.care_for_pup(first_id), "nursery care maximum")
	_expect_true(not GameManager.claim_grown_pup(first_id), "nursery blocks early claim")
	GameManager.nursery_pups[0]["ready_unix"] = TimeManager.current_unix_time()
	var before_claim_mouse_count: int = GameManager.mouse_count
	_expect_true(GameManager.claim_grown_pup(first_id), "nursery grown pup joins")
	_expect_equal_int(
		GameManager.mouse_count,
		before_claim_mouse_count + 1,
		"nursery adult increases mouse count"
	)
	_expect_equal_int(GameManager.total_raised_pups, 1, "nursery raised total")
	_expect_equal_int(GameManager.nursery_pups.size(), 1, "nursery slot clears")

	GameManager.cheese = previous_cheese
	GameManager.mouse_count = previous_mouse_count
	GameManager.hole_level = previous_hole_level
	GameManager.nursery_level = previous_nursery_level
	GameManager.nursery_pups = previous_pups
	GameManager.total_raised_pups = previous_total_raised
	GameManager.next_pup_id = previous_next_pup_id
	GameManager.role_assignments = previous_roles


func _test_nursery_view_input() -> void:
	var nursery: NurseryView = NurseryView.new()
	nursery.size = Vector2(500.0, 250.0)
	var snapshots: Array[Dictionary] = [{
		"id": 7,
		"remaining_seconds": 60,
		"ready": false,
		"care_count": 0
	}]
	nursery.set_pups(snapshots)
	_expect_equal_int(
		nursery.submit_point(Vector2(-100.0, -100.0)),
		0,
		"nursery ignores distant input"
	)
	_expect_equal_int(
		nursery.submit_point(nursery.get_pup_position(0)),
		7,
		"nursery pup point input"
	)
	nursery.free()


func _test_role_assignment() -> void:
	var previous_mouse_count: int = GameManager.mouse_count
	var previous_roles: Dictionary = GameManager.role_assignments.duplicate(true)
	var previous_stage_index: int = GameManager.current_stage_index
	var previous_region_progress: Dictionary = GameManager.region_progress.duplicate(true)
	var previous_golden: float = GameManager.golden_remaining
	var previous_nursery_level: int = GameManager.nursery_level
	var previous_pups: Array[Dictionary] = GameManager.nursery_pups.duplicate(true)
	var previous_cheese: float = GameManager.cheese
	var previous_next_pup_id: int = GameManager.next_pup_id
	GameManager.mouse_count = 2
	GameManager.role_assignments = {
		"gatherer": 2,
		"explorer": 0,
		"builder": 0
	}
	_expect_true(not GameManager.assign_mouse_role("explorer"), "role board lock")
	GameManager.mouse_count = 4
	GameManager.role_assignments = {
		"gatherer": 4,
		"explorer": 0,
		"builder": 0
	}
	GameManager.current_stage_index = 0
	GameManager.region_progress = {}
	GameManager.golden_remaining = 0.0
	var base_production: float = GameManager.get_expected_per_second()
	_expect_true(GameManager.assign_mouse_role("explorer"), "assign explorer")
	_expect_equal_int(GameManager.get_role_count("gatherer"), 3, "explorer removes gatherer")
	_expect_equal_float(
		GameManager.get_explorer_reward_multiplier(),
		1.1,
		"explorer reward multiplier"
	)
	_expect_equal_float(
		GameManager.get_expected_per_second(),
		base_production * 0.75,
		"role assignment changes production"
	)
	_expect_true(GameManager.assign_mouse_role("builder"), "assign builder")
	_expect_equal_int(GameManager.get_nursery_growth_seconds(), 108, "builder growth time")
	GameManager.cheese = 10_000.0
	GameManager.nursery_level = 1
	GameManager.nursery_pups.clear()
	var growth_started_unix: int = TimeManager.current_unix_time()
	_expect_true(GameManager.start_nursery_pup(), "builder starts nursery pup")
	var assigned_ready_unix: int = _dictionary_int(
		GameManager.nursery_pups[0],
		"ready_unix",
		0
	)
	_expect_true(
		assigned_ready_unix - growth_started_unix >= 108
		and assigned_ready_unix - growth_started_unix <= 109,
		"builder bonus applies to new pup"
	)
	_expect_true(GameManager.assign_mouse_role("explorer"), "assign second explorer")
	_expect_true(not GameManager.assign_mouse_role("builder"), "minimum gatherer protected")
	_expect_true(GameManager.assign_mouse_role("gatherer"), "role returns to gatherer")
	_expect_equal_int(GameManager.get_role_count("builder"), 0, "builder returns first")
	_expect_true(GameManager.reset_mouse_roles(), "role reset")
	_expect_equal_int(GameManager.get_role_count("gatherer"), 4, "all gather after reset")
	_expect_equal_int(
		GameManager.get_role_count("gatherer")
		+ GameManager.get_role_count("explorer")
		+ GameManager.get_role_count("builder"),
		GameManager.mouse_count,
		"role assignment sum"
	)
	GameManager.mouse_count = previous_mouse_count
	GameManager.role_assignments = previous_roles
	GameManager.current_stage_index = previous_stage_index
	GameManager.region_progress = previous_region_progress
	GameManager.golden_remaining = previous_golden
	GameManager.cheese = previous_cheese
	GameManager.nursery_level = previous_nursery_level
	GameManager.nursery_pups = previous_pups
	GameManager.next_pup_id = previous_next_pup_id


func _test_role_board_input() -> void:
	var role_board: RoleBoardView = RoleBoardView.new()
	role_board.size = Vector2(500.0, 230.0)
	role_board.set_assignments({
		"gatherer": 2,
		"explorer": 1,
		"builder": 1
	})
	_expect_true(
		role_board.submit_point(Vector2(-100.0, -100.0)).is_empty(),
		"role board ignores distant input"
	)
	_expect_true(
		role_board.submit_point(role_board.get_role_position("builder")) == "builder",
		"role board builder point input"
	)
	role_board.free()


func _test_hero_data() -> void:
	var candidates: Array[Dictionary] = GameManager.get_hero_candidates()
	_expect_equal_int(candidates.size(), 3, "hero candidate count")
	var ids: Array[String] = []
	for candidate: Dictionary in candidates:
		var hero_id: String = _dictionary_string(candidate, "id", "")
		_expect_true(not hero_id.is_empty(), "hero candidate id")
		_expect_true(not ids.has(hero_id), "hero candidate id unique")
		ids.append(hero_id)
		_expect_true(
			not _dictionary_string(candidate, "name", "").is_empty(),
			"hero candidate name"
		)
		_expect_true(
			not _dictionary_string(candidate, "effect", "").is_empty(),
			"hero candidate effect"
		)


func _test_hero_selection() -> void:
	var previous_mouse_count: int = GameManager.mouse_count
	var previous_roles: Dictionary = GameManager.role_assignments.duplicate(true)
	var previous_hero_id: String = GameManager.selected_hero_id
	var previous_stage_index: int = GameManager.current_stage_index
	var previous_region_progress: Dictionary = GameManager.region_progress.duplicate(true)
	var previous_golden: float = GameManager.golden_remaining
	var previous_nursery_level: int = GameManager.nursery_level
	var previous_pups: Array[Dictionary] = GameManager.nursery_pups.duplicate(true)
	GameManager.mouse_count = 4
	GameManager.role_assignments = {
		"gatherer": 4,
		"explorer": 0,
		"builder": 0
	}
	GameManager.selected_hero_id = ""
	_expect_true(not GameManager.recruit_hero("dandani"), "hero selection locked")
	GameManager.mouse_count = 5
	GameManager.role_assignments = {
		"gatherer": 5,
		"explorer": 0,
		"builder": 0
	}
	_expect_true(not GameManager.recruit_hero("unknown"), "unknown hero rejected")
	var mouse_count_before: int = GameManager.mouse_count
	var roles_before: Dictionary = GameManager.role_assignments.duplicate(true)
	_expect_true(GameManager.recruit_hero("dandani"), "first hero recruited")
	_expect_true(not GameManager.recruit_hero("saebyeok"), "second hero rejected")
	_expect_equal_int(GameManager.mouse_count, mouse_count_before, "hero keeps mouse count")
	_expect_true(GameManager.role_assignments == roles_before, "hero keeps role assignments")
	GameManager.current_stage_index = 0
	GameManager.region_progress = {}
	GameManager.golden_remaining = 0.0
	_expect_equal_float(
		GameManager.get_gather_hero_multiplier(),
		1.1,
		"carrier hero multiplier"
	)
	var carrier_reward_value: Variant = GameManager.call(
		"_calculate_trip_reward",
		10,
		1.0,
		true
	)
	_expect_true(carrier_reward_value is int, "carrier reward type")
	if carrier_reward_value is int:
		@warning_ignore("unsafe_cast")
		var carrier_reward: int = carrier_reward_value as int
		_expect_equal_int(carrier_reward, 275, "carrier hero ordinary reward")
	var special_reward_value: Variant = GameManager.call(
		"_calculate_trip_reward",
		10,
		1.0,
		false
	)
	_expect_true(special_reward_value is int, "special reward type")
	if special_reward_value is int:
		@warning_ignore("unsafe_cast")
		var special_reward: int = special_reward_value as int
		_expect_equal_int(special_reward, 250, "carrier excluded from special reward")
	GameManager.selected_hero_id = "saebyeok"
	GameManager.role_assignments = {
		"gatherer": 4,
		"explorer": 1,
		"builder": 0
	}
	_expect_equal_float(
		GameManager.get_region_activity_multiplier(),
		1.265,
		"scout hero and explorer multiply"
	)
	GameManager.selected_hero_id = "boreum"
	_expect_equal_int(
		GameManager.get_nursery_care_reduction_seconds(),
		20,
		"caregiver hero care reduction"
	)
	GameManager.nursery_level = 1
	GameManager.nursery_pups = [{
		"id": 99,
		"ready_unix": TimeManager.current_unix_time() + 100,
		"care_count": 0
	}]
	var care_ready_before: int = _dictionary_int(
		GameManager.nursery_pups[0],
		"ready_unix",
		0
	)
	_expect_true(GameManager.care_for_pup(99), "caregiver hero applies care")
	_expect_equal_int(
		_dictionary_int(GameManager.nursery_pups[0], "ready_unix", 0),
		care_ready_before - 20,
		"caregiver hero actual time reduction"
	)
	GameManager.mouse_count = previous_mouse_count
	GameManager.role_assignments = previous_roles
	GameManager.selected_hero_id = previous_hero_id
	GameManager.current_stage_index = previous_stage_index
	GameManager.region_progress = previous_region_progress
	GameManager.golden_remaining = previous_golden
	GameManager.nursery_level = previous_nursery_level
	GameManager.nursery_pups = previous_pups


func _test_hero_choice_input() -> void:
	var hero_view: HeroChoiceView = HeroChoiceView.new()
	hero_view.size = Vector2(500.0, 290.0)
	hero_view.setup(GameManager.get_hero_candidates())
	_expect_true(
		hero_view.submit_point(Vector2(-100.0, -100.0)).is_empty(),
		"hero view ignores distant input"
	)
	_expect_true(
		hero_view.submit_point(hero_view.get_candidate_position(1)) == "saebyeok",
		"hero candidate point input"
	)
	_expect_true(hero_view.preview_hero_id == "saebyeok", "hero preview state")
	hero_view.free()


func _test_upgrade_costs() -> void:
	GameManager.speed_level = 0
	GameManager.carry_level = 0
	GameManager.mouse_count = 1
	GameManager.hole_level = 1
	_expect_equal_int(GameManager.get_speed_upgrade_cost(), 10, "base speed cost")
	_expect_equal_int(GameManager.get_carry_upgrade_cost(), 25, "base carry cost")
	_expect_equal_int(GameManager.get_mouse_cost(), 50, "base mouse cost")
	_expect_equal_int(GameManager.get_hole_upgrade_cost(), 100, "base hole cost")
	GameManager.speed_level = 1
	_expect_equal_int(GameManager.get_speed_upgrade_cost(), 15, "scaled speed cost")


func _test_natural_speed_curve() -> void:
	var previous_speed_level: int = GameManager.speed_level
	var previous_boost_remaining: float = GameManager.click_boost_remaining
	GameManager.click_boost_remaining = 0.0
	GameManager.speed_level = 0
	var base_speed: float = GameManager.get_move_speed()
	GameManager.speed_level = 1
	var first_upgrade_speed: float = GameManager.get_move_speed()
	GameManager.speed_level = 100
	var capped_speed: float = GameManager.get_move_speed()
	GameManager.click_boost_remaining = 1.0
	var boosted_speed: float = GameManager.get_move_speed()
	_expect_true(first_upgrade_speed > base_speed, "first speed upgrade has effect")
	_expect_true(capped_speed <= 245.0, "normal movement speed cap")
	_expect_true(boosted_speed <= 285.0, "boosted movement speed cap")
	GameManager.speed_level = previous_speed_level
	GameManager.click_boost_remaining = previous_boost_remaining


func _test_visual_progression() -> void:
	_expect_equal_int(VisualProgression.speed_tier(0), 0, "base speed visual tier")
	_expect_equal_int(VisualProgression.speed_tier(1), 1, "scarf visual tier")
	_expect_equal_int(VisualProgression.speed_tier(3), 2, "shoes visual tier")
	_expect_equal_int(VisualProgression.speed_tier(6), 3, "master speed visual tier")
	_expect_equal_int(VisualProgression.carry_tier(0), 0, "base carry visual tier")
	_expect_equal_int(VisualProgression.carry_tier(1), 1, "pouch visual tier")
	_expect_equal_int(VisualProgression.carry_tier(3), 2, "backpack visual tier")
	_expect_equal_int(VisualProgression.carry_tier(6), 3, "professional carry visual tier")
	_expect_equal_int(VisualProgression.hole_tier(1), 0, "base hole visual tier")
	_expect_equal_int(VisualProgression.hole_tier(2), 1, "reinforced hole visual tier")
	_expect_equal_int(VisualProgression.hole_tier(3), 2, "storage hole visual tier")
	_expect_equal_int(VisualProgression.hole_tier(4), 3, "village entrance visual tier")
	_expect_equal_int(VisualProgression.hole_tier(5), 4, "civilization gate visual tier")
	_expect_true(
		VisualProgression.equipment_summary(3, 3) == "운동화 · 배낭",
		"equipment summary"
	)


func _test_golden_reward() -> void:
	var previous_region_progress: Dictionary = GameManager.region_progress.duplicate(true)
	GameManager.cheese = 0.0
	GameManager.total_cheese = 0.0
	GameManager.carry_level = 0
	GameManager.current_stage_index = 0
	GameManager.region_progress = {}
	GameManager.highest_unlocked_stage_index = 0
	GameManager.golden_remaining = 0.0
	var normal_reward: int = GameManager.collect_trip(1)
	_expect_equal_int(normal_reward, 25, "alpha test multiplier")
	GameManager.cheese = 0.0
	GameManager.total_cheese = 0.0
	GameManager.golden_remaining = 1.0
	var reward: int = GameManager.collect_trip(1)
	_expect_equal_int(reward, 125, "alpha and golden cheese multipliers")
	_expect_equal_float(GameManager.cheese, 125.0, "golden cheese balance")
	GameManager.golden_remaining = 0.0
	GameManager.region_progress = previous_region_progress


func _test_colony_progression() -> void:
	var previous_hole_level: int = GameManager.hole_level
	GameManager.hole_level = 19
	_expect_true(GameManager.get_colony_rank() == "치즈 마을", "colony rank before city")
	var goal: Dictionary = GameManager.get_next_colony_goal()
	var target_value: Variant = goal.get("target_level", 0)
	_expect_true(target_value is int, "next colony milestone type")
	@warning_ignore("unsafe_call_argument")
	var target_level: int = int(target_value)
	_expect_equal_int(target_level, 20, "next colony milestone")
	GameManager.hole_level = 20
	_expect_true(GameManager.get_colony_rank() == "쥐구멍 도시", "colony city rank")
	_expect_true(not GameManager.get_world_news().is_empty(), "world news available")
	GameManager.hole_level = previous_hole_level


func _test_next_reward_summary() -> void:
	var previous_stage_index: int = GameManager.current_stage_index
	var previous_highest_index: int = GameManager.highest_unlocked_stage_index
	var previous_total_cheese: float = GameManager.total_cheese
	var previous_hole_level: int = GameManager.hole_level

	GameManager.current_stage_index = 0
	GameManager.highest_unlocked_stage_index = 0
	GameManager.total_cheese = 50.0
	var stage_reward: Dictionary = GameManager.get_next_reward_summary()
	_expect_true(str(stage_reward.get("kind", "")) == "stage", "stage reward kind")
	_expect_dictionary_float(stage_reward, "current", 50.0, "stage reward current")
	_expect_dictionary_float(stage_reward, "target", 100.0, "stage reward target")
	_expect_dictionary_float(stage_reward, "progress", 50.0, "stage reward progress")

	GameManager.current_stage_index = maxi(0, GameManager.stages.size() - 1)
	GameManager.highest_unlocked_stage_index = GameManager.current_stage_index
	GameManager.hole_level = 15
	var colony_reward: Dictionary = GameManager.get_next_reward_summary()
	_expect_true(str(colony_reward.get("kind", "")) == "colony", "colony reward kind")
	_expect_dictionary_float(colony_reward, "current", 15.0, "colony reward current")
	_expect_dictionary_float(colony_reward, "target", 20.0, "colony reward target")
	_expect_dictionary_float(colony_reward, "progress", 50.0, "colony reward progress")

	GameManager.current_stage_index = previous_stage_index
	GameManager.highest_unlocked_stage_index = previous_highest_index
	GameManager.total_cheese = previous_total_cheese
	GameManager.hole_level = previous_hole_level


func _test_region_selection() -> void:
	var previous_stage_index: int = GameManager.current_stage_index
	var previous_highest_index: int = GameManager.highest_unlocked_stage_index
	var previous_total_cheese: float = GameManager.total_cheese
	var previous_unlocked_ids: Array[String] = GameManager.unlocked_stage_ids.duplicate()

	GameManager.total_cheese = 600.0
	GameManager.call("_reconcile_unlocked_stages")
	_expect_equal_int(GameManager.highest_unlocked_stage_index, 2, "highest unlocked stage")
	_expect_equal_int(GameManager.get_unlocked_stages().size(), 3, "unlocked stage count")
	_expect_true(GameManager.select_stage(0), "select previous stage")
	_expect_equal_int(GameManager.current_stage_index, 0, "selected previous stage index")
	_expect_equal_int(GameManager.highest_unlocked_stage_index, 2, "selection keeps highest stage")
	_expect_true(
		str(GameManager.get_next_stage().get("id", "")) == "restaurant",
		"next reward uses highest stage"
	)
	_expect_true(not GameManager.select_stage(3), "locked stage cannot be selected")

	GameManager.current_stage_index = previous_stage_index
	GameManager.highest_unlocked_stage_index = previous_highest_index
	GameManager.total_cheese = previous_total_cheese
	GameManager.unlocked_stage_ids = previous_unlocked_ids


func _test_region_codex() -> void:
	var previous_stage_index: int = GameManager.current_stage_index
	var previous_highest_index: int = GameManager.highest_unlocked_stage_index
	var previous_total_cheese: float = GameManager.total_cheese
	var previous_unlocked_ids: Array[String] = GameManager.unlocked_stage_ids.duplicate()
	var previous_completed: Array[String] = GameManager.completed_region_event_ids.duplicate()

	GameManager.total_cheese = 600.0
	GameManager.call("_reconcile_unlocked_stages")
	GameManager.current_stage_index = 0
	GameManager.completed_region_event_ids = ["kitchen_cat_patrol"]
	var entries: Array[Dictionary] = GameManager.get_region_codex_entries()
	var progress: Dictionary = GameManager.get_region_codex_progress()
	_expect_equal_int(entries.size(), 3, "region codex unlocked entry count")
	_expect_equal_int(
		_dictionary_int(progress, "discovered", 0),
		1,
		"region codex discovered count"
	)
	_expect_equal_int(
		_dictionary_int(progress, "total", 0),
		3,
		"region codex total count"
	)
	if not entries.is_empty():
		var kitchen: Dictionary = entries[0]
		_expect_true(
			_dictionary_bool(kitchen, "discovered", false),
			"region codex discovery state"
		)
		_expect_true(
			_dictionary_bool(kitchen, "current", false),
			"region codex current state"
		)
		_expect_true(
			not _dictionary_string(kitchen, "resource", "").is_empty(),
			"region codex resource"
		)
		_expect_true(
			not _dictionary_string(kitchen, "hazard", "").is_empty(),
			"region codex hazard"
		)

	GameManager.current_stage_index = previous_stage_index
	GameManager.highest_unlocked_stage_index = previous_highest_index
	GameManager.total_cheese = previous_total_cheese
	GameManager.unlocked_stage_ids = previous_unlocked_ids
	GameManager.completed_region_event_ids = previous_completed


func _test_region_events() -> void:
	var previous_stage_index: int = GameManager.current_stage_index
	var previous_highest_index: int = GameManager.highest_unlocked_stage_index
	var previous_cheese: float = GameManager.cheese
	var previous_total_cheese: float = GameManager.total_cheese
	var previous_carry_level: int = GameManager.carry_level
	var previous_golden_remaining: float = GameManager.golden_remaining
	var previous_total_trips: int = GameManager.total_trips
	var previous_unlocked_ids: Array[String] = GameManager.unlocked_stage_ids.duplicate()
	var previous_completed: Array[String] = GameManager.completed_region_event_ids.duplicate()
	var previous_cooldown: int = GameManager.next_region_event_unix
	var previous_boost: float = GameManager.click_boost_remaining
	var previous_region_progress: Dictionary = GameManager.region_progress.duplicate(true)
	var previous_roles: Dictionary = GameManager.role_assignments.duplicate(true)
	var previous_hero_id: String = GameManager.selected_hero_id

	GameManager.current_stage_index = 0
	GameManager.highest_unlocked_stage_index = 0
	GameManager.unlocked_stage_ids = ["old_kitchen"]
	GameManager.cheese = 0.0
	GameManager.total_cheese = 0.0
	GameManager.carry_level = 0
	GameManager.golden_remaining = 0.0
	GameManager.completed_region_event_ids.clear()
	GameManager.next_region_event_unix = 0
	GameManager.role_assignments = {
		"gatherer": GameManager.mouse_count,
		"explorer": 0,
		"builder": 0
	}
	GameManager.selected_hero_id = ""
	GameManager.region_progress["old_kitchen"] = {
		"action_level": 0,
		"risk_level": 2,
		"route_unlocked": false,
		"flags": [],
		"last_choice_id": ""
	}
	var region_event: Dictionary = GameManager.get_current_region_event()
	var choices_value: Variant = region_event.get("choices", [])
	_expect_true(choices_value is Array, "region event choices type")
	if choices_value is Array:
		@warning_ignore("unsafe_cast")
		var choices: Array = choices_value as Array
		_expect_equal_int(choices.size(), 3, "region event includes expert choice")
	var result: Dictionary = GameManager.resolve_region_event(0)
	_expect_true(not result.is_empty(), "region event resolves")
	_expect_true(
		_dictionary_bool(result, "first_discovery", false),
		"first region event discovery result"
	)
	_expect_equal_int(
		_dictionary_int(result, "reward", 0),
		125,
		"first region event total reward"
	)
	_expect_equal_int(
		_dictionary_int(result, "first_discovery_reward", 0),
		75,
		"first region event bonus reward"
	)
	_expect_true(
		GameManager.completed_region_event_ids.has("kitchen_cat_patrol"),
		"region event discovery recorded"
	)
	_expect_true(GameManager.get_region_event_cooldown() > 0, "region event cooldown starts")
	_expect_true(GameManager.resolve_region_event(1).is_empty(), "cooldown blocks repeated event")

	GameManager.current_stage_index = 0
	GameManager.highest_unlocked_stage_index = 0
	GameManager.unlocked_stage_ids = ["old_kitchen"]
	GameManager.cheese = 0.0
	GameManager.total_cheese = 0.0
	GameManager.next_region_event_unix = 0
	var repeat_result: Dictionary = GameManager.resolve_region_event(0)
	_expect_true(
		not _dictionary_bool(repeat_result, "first_discovery", true),
		"repeat region event is not first discovery"
	)
	_expect_equal_int(
		_dictionary_int(repeat_result, "reward", 0),
		50,
		"repeat region event base reward"
	)
	_expect_equal_int(
		_dictionary_int(repeat_result, "first_discovery_reward", -1),
		0,
		"repeat region event has no discovery bonus"
	)
	GameManager.current_stage_index = 0
	GameManager.highest_unlocked_stage_index = 0
	GameManager.unlocked_stage_ids = ["old_kitchen"]
	GameManager.cheese = 0.0
	GameManager.total_cheese = 0.0
	GameManager.next_region_event_unix = 0
	GameManager.role_assignments = {
		"gatherer": maxi(1, GameManager.mouse_count - 1),
		"explorer": 1,
		"builder": 0
	}
	GameManager.selected_hero_id = ""
	var explorer_result: Dictionary = GameManager.resolve_region_event(0)
	_expect_equal_int(
		_dictionary_int(explorer_result, "reward", 0),
		55,
		"explorer increases region event reward"
	)
	GameManager.current_stage_index = 0
	GameManager.highest_unlocked_stage_index = 0
	GameManager.unlocked_stage_ids = ["old_kitchen"]
	GameManager.cheese = 0.0
	GameManager.total_cheese = 0.0
	GameManager.next_region_event_unix = 0
	GameManager.role_assignments = {
		"gatherer": GameManager.mouse_count,
		"explorer": 0,
		"builder": 0
	}
	GameManager.selected_hero_id = "saebyeok"
	var scout_result: Dictionary = GameManager.resolve_region_event(0)
	_expect_equal_int(
		_dictionary_int(scout_result, "reward", 0),
		57,
		"scout hero increases region event reward"
	)
	GameManager.current_stage_index = 0
	GameManager.highest_unlocked_stage_index = 0
	GameManager.unlocked_stage_ids = ["old_kitchen"]
	GameManager.next_region_event_unix = 0
	GameManager.role_assignments = {
		"gatherer": GameManager.mouse_count,
		"explorer": 0,
		"builder": 0
	}
	GameManager.region_progress["old_kitchen"] = {
		"action_level": 3,
		"risk_level": 1,
		"route_unlocked": true,
		"flags": ["thread_route"],
		"last_choice_id": ""
	}
	var expert_event: Dictionary = GameManager.get_current_region_event()
	var expert_choices_value: Variant = expert_event.get("choices", [])
	if expert_choices_value is Array:
		@warning_ignore("unsafe_cast")
		var expert_choices: Array = expert_choices_value as Array
		@warning_ignore("unsafe_cast")
		var expert_choice: Dictionary = expert_choices[2] as Dictionary
		_expect_true(
			not _dictionary_bool(expert_choice, "locked", true),
			"expert region choice unlocks at mastery 3"
		)
	var expert_result: Dictionary = GameManager.resolve_region_event(2)
	_expect_true(not expert_result.is_empty(), "expert region choice resolves")

	GameManager.current_stage_index = previous_stage_index
	GameManager.highest_unlocked_stage_index = previous_highest_index
	GameManager.cheese = previous_cheese
	GameManager.total_cheese = previous_total_cheese
	GameManager.carry_level = previous_carry_level
	GameManager.golden_remaining = previous_golden_remaining
	GameManager.total_trips = previous_total_trips
	GameManager.unlocked_stage_ids = previous_unlocked_ids
	GameManager.completed_region_event_ids = previous_completed
	GameManager.next_region_event_unix = previous_cooldown
	GameManager.click_boost_remaining = previous_boost
	GameManager.region_progress = previous_region_progress
	GameManager.role_assignments = previous_roles
	GameManager.selected_hero_id = previous_hero_id


func _test_field_action_data() -> void:
	var action_types: Array[String] = []
	var action_ids: Array[String] = []
	for stage_index: int in range(GameManager.stages.size()):
		var stage: Dictionary = GameManager.stages[stage_index]
		var action_value: Variant = stage.get("field_action", {})
		_expect_true(action_value is Dictionary, "field action data type")
		if not action_value is Dictionary:
			continue
		@warning_ignore("unsafe_cast")
		var action: Dictionary = action_value as Dictionary
		var action_id: String = _dictionary_string(action, "id", "")
		var action_type: String = _dictionary_string(action, "type", "")
		_expect_true(not action_id.is_empty(), "field action id")
		_expect_true(not action_ids.has(action_id), "field action id is unique")
		_expect_true(not action_types.has(action_type), "field action mechanic is unique")
		_expect_equal_int(
			_dictionary_int(action, "reward_trips", 0),
			3,
			"field action reward trips"
		)
		_expect_equal_int(
			_dictionary_int(action, "first_completion_reward_trips", 0),
			2,
			"field action first completion trips"
		)
		action_ids.append(action_id)
		action_types.append(action_type)
	_expect_equal_int(action_ids.size(), 5, "field action count")


func _test_field_action_resolution() -> void:
	var previous_stage_index: int = GameManager.current_stage_index
	var previous_highest_index: int = GameManager.highest_unlocked_stage_index
	var previous_cheese: float = GameManager.cheese
	var previous_total_cheese: float = GameManager.total_cheese
	var previous_carry_level: int = GameManager.carry_level
	var previous_golden_remaining: float = GameManager.golden_remaining
	var previous_total_trips: int = GameManager.total_trips
	var previous_unlocked_ids: Array[String] = GameManager.unlocked_stage_ids.duplicate()
	var previous_completed: Array[String] = GameManager.completed_field_action_ids.duplicate()
	var previous_cooldown: int = GameManager.next_field_action_unix
	var previous_region_progress: Dictionary = GameManager.region_progress.duplicate(true)
	var previous_roles: Dictionary = GameManager.role_assignments.duplicate(true)
	var previous_hero_id: String = GameManager.selected_hero_id

	GameManager.current_stage_index = 0
	GameManager.highest_unlocked_stage_index = 0
	GameManager.unlocked_stage_ids = ["old_kitchen"]
	GameManager.cheese = 0.0
	GameManager.total_cheese = 0.0
	GameManager.carry_level = 0
	GameManager.golden_remaining = 0.0
	GameManager.completed_field_action_ids.clear()
	GameManager.next_field_action_unix = 0
	GameManager.role_assignments = {
		"gatherer": GameManager.mouse_count,
		"explorer": 0,
		"builder": 0
	}
	GameManager.selected_hero_id = ""
	GameManager.region_progress["old_kitchen"] = {
		"action_level": 0,
		"risk_level": 2,
		"route_unlocked": false,
		"flags": [],
		"last_choice_id": ""
	}
	_expect_true(
		GameManager.resolve_field_action("wrong_action", 0).is_empty(),
		"wrong field action id is rejected"
	)
	var first_result: Dictionary = GameManager.resolve_field_action(
		"kitchen_thread_tangle",
		2
	)
	_expect_true(not first_result.is_empty(), "field action resolves")
	_expect_true(
		_dictionary_bool(first_result, "first_completion", false),
		"field action first completion"
	)
	_expect_equal_int(
		_dictionary_int(first_result, "reward", 0),
		125,
		"field action first reward"
	)
	_expect_equal_int(
		_dictionary_int(first_result, "first_completion_reward", 0),
		50,
		"field action first bonus"
	)
	_expect_equal_int(
		_dictionary_int(first_result, "mistakes", 0),
		2,
		"field action mistake result"
	)
	_expect_true(
		GameManager.completed_field_action_ids.has("kitchen_thread_tangle"),
		"field action completion recorded"
	)
	var first_state: Dictionary = _dictionary_dictionary(first_result, "region_state")
	_expect_true(
		_dictionary_bool(first_state, "route_unlocked", false),
		"field action opens safe route"
	)
	_expect_equal_int(
		_dictionary_int(first_state, "action_level", 0),
		1,
		"field action raises mastery"
	)
	_expect_true(GameManager.get_field_action_cooldown() > 0, "field action cooldown")
	_expect_true(
		GameManager.resolve_field_action("kitchen_thread_tangle", 0).is_empty(),
		"field action cooldown blocks repeat"
	)

	GameManager.current_stage_index = 0
	GameManager.highest_unlocked_stage_index = 0
	GameManager.unlocked_stage_ids = ["old_kitchen"]
	GameManager.cheese = 0.0
	GameManager.total_cheese = 0.0
	GameManager.next_field_action_unix = 0
	var repeat_result: Dictionary = GameManager.resolve_field_action(
		"kitchen_thread_tangle",
		0
	)
	_expect_true(
		not _dictionary_bool(repeat_result, "first_completion", true),
		"repeat field action is not first"
	)
	_expect_equal_int(
		_dictionary_int(repeat_result, "reward", 0),
		105,
		"repeat field action base reward"
	)

	GameManager.current_stage_index = previous_stage_index
	GameManager.highest_unlocked_stage_index = previous_highest_index
	GameManager.cheese = previous_cheese
	GameManager.total_cheese = previous_total_cheese
	GameManager.carry_level = previous_carry_level
	GameManager.golden_remaining = previous_golden_remaining
	GameManager.total_trips = previous_total_trips
	GameManager.unlocked_stage_ids = previous_unlocked_ids
	GameManager.completed_field_action_ids = previous_completed
	GameManager.next_field_action_unix = previous_cooldown
	GameManager.region_progress = previous_region_progress
	GameManager.role_assignments = previous_roles
	GameManager.selected_hero_id = previous_hero_id


func _test_dot_action_input() -> void:
	for action_type: String in ["untangle", "tower", "infinite", "timing", "route"]:
		var action_view: DotActionView = DotActionView.new()
		action_view.size = Vector2(500.0, 280.0)
		action_view.setup({
			"id": "test_%s" % action_type,
			"type": action_type
		})
		_expect_true(
			not action_view.submit_point(Vector2(-100.0, -100.0)),
			"dot action wrong input: %s" % action_type
		)
		_expect_equal_int(action_view.mistakes, 1, "dot action mistake count")
		var safety: int = 0
		while not action_view.finished and safety < 12:
			if action_type == "timing":
				action_view.elapsed = 0.0
			var target: Vector2 = action_view.get_active_target_position()
			_expect_true(target != Vector2.ZERO, "dot action target: %s" % action_type)
			_expect_true(
				action_view.submit_point(target),
				"dot action correct input: %s" % action_type
			)
			safety += 1
		_expect_true(action_view.finished, "dot action completion: %s" % action_type)
		_expect_equal_int(
			action_view.step,
			action_view.get_total_steps(),
			"dot action completed step count"
		)
		action_view.free()


func _test_reward_text_bounds() -> void:
	var world_view: WorldView = WorldView.new()
	var upper_left_value: Variant = world_view.call(
		"_clamp_reward_position",
		Vector2(-100.0, -100.0),
		120.0,
		Vector2(1024.0, 768.0)
	)
	var lower_right_value: Variant = world_view.call(
		"_clamp_reward_position",
		Vector2(2000.0, 2000.0),
		120.0,
		Vector2(1024.0, 768.0)
	)
	var portrait_value: Variant = world_view.call(
		"_clamp_reward_position",
		Vector2(-100.0, -100.0),
		160.0,
		Vector2(768.0, 1024.0)
	)
	_expect_true(upper_left_value is Vector2, "reward upper-left position type")
	_expect_true(lower_right_value is Vector2, "reward lower-right position type")
	_expect_true(portrait_value is Vector2, "reward portrait position type")
	if upper_left_value is Vector2 and lower_right_value is Vector2:
		@warning_ignore("unsafe_cast")
		var upper_left: Vector2 = upper_left_value as Vector2
		@warning_ignore("unsafe_cast")
		var lower_right: Vector2 = lower_right_value as Vector2
		_expect_true(upper_left.x >= 24.0 and upper_left.y >= 165.0, "reward upper-left bounds")
		_expect_true(lower_right.x <= 880.0, "reward right bound")
		_expect_true(lower_right.y <= 563.0, "reward bottom bound")
	if portrait_value is Vector2:
		@warning_ignore("unsafe_cast")
		var portrait_position: Vector2 = portrait_value as Vector2
		_expect_true(portrait_position.y >= 450.0, "portrait reward clears text panels")
	world_view.free()


func _test_korean_font() -> void:
	var font_path: String = "res://assets/fonts/NotoSansKR-Full.ttf"
	var configured_font_path: String = str(ProjectSettings.get_setting("gui/theme/custom_font", ""))
	_expect_true(configured_font_path == font_path, "Korean font is configured")
	var game_font: FontFile = load(font_path) as FontFile
	_expect_true(game_font != null, "Korean font loads")
	if game_font == null:
		return
	for character: String in "쥐구멍치즈황금저장세계소식기계실톱니길안전화완료대표결성":
		_expect_true(game_font.has_char(character.unicode_at(0)), "font glyph %s" % character)


func _test_stage_backgrounds() -> void:
	for path: String in [
		"res://assets/background/stages/old_kitchen.jpg",
		"res://assets/background/stages/food_storage.jpg",
		"res://assets/background/stages/convenience_store.jpg",
		"res://assets/background/stages/restaurant.jpg",
		"res://assets/background/stages/cheese_factory.jpg"
	]:
		var background: Texture2D = load(path) as Texture2D
		_expect_true(background != null, "stage background loads: %s" % path)


func _test_stage_choice_events() -> void:
	var event_ids: Array[String] = []
	for stage: Dictionary in GameManager.stages:
		var event_value: Variant = stage.get("choice_event", {})
		_expect_true(event_value is Dictionary, "stage choice event type")
		if not event_value is Dictionary:
			continue
		@warning_ignore("unsafe_cast")
		var region_event: Dictionary = event_value as Dictionary
		var event_id: String = str(region_event.get("id", ""))
		_expect_true(not event_id.is_empty(), "stage choice event id")
		_expect_true(not event_ids.has(event_id), "stage choice event id is unique")
		event_ids.append(event_id)
		_expect_equal_int(
			_dictionary_int(region_event, "first_discovery_reward_trips", 0),
			3,
			"stage first discovery reward trips"
		)
		var choices_value: Variant = region_event.get("choices", [])
		_expect_true(choices_value is Array, "stage choice options type")
		if choices_value is Array:
			@warning_ignore("unsafe_cast")
			var choices: Array = choices_value as Array
			_expect_equal_int(choices.size(), 2, "stage choice option count")


func _test_mouse_sprites() -> void:
	for path: String in [
		"res://assets/mouse/sprites/field_mouse-v2.png",
		"res://assets/mouse/sprites/field_mouse_carrying-v2.png"
	]:
		var mouse_texture: Texture2D = load(path) as Texture2D
		_expect_true(mouse_texture != null, "mouse sprite loads: %s" % path)


func _test_background_anchor_alignment() -> void:
	var world_view: WorldView = WorldView.new()
	var background: Texture2D = load(
		"res://assets/background/stages/old_kitchen.jpg"
	) as Texture2D
	var landscape_value: Variant = world_view.call(
		"_background_point_to_viewport",
		Vector2(205.0, 456.0),
		background,
		Vector2(1280.0, 720.0)
	)
	var ipad_value: Variant = world_view.call(
		"_background_point_to_viewport",
		Vector2(205.0, 456.0),
		background,
		Vector2(1024.0, 768.0)
	)
	_expect_true(landscape_value is Vector2, "landscape background anchor type")
	_expect_true(ipad_value is Vector2, "iPad background anchor type")
	if landscape_value is Vector2 and ipad_value is Vector2:
		@warning_ignore("unsafe_cast")
		var landscape_position: Vector2 = landscape_value as Vector2
		@warning_ignore("unsafe_cast")
		var ipad_position: Vector2 = ipad_value as Vector2
		_expect_true(landscape_position.y > 400.0, "landscape mouse stays on floor")
		_expect_true(ipad_position.y > 450.0, "iPad mouse stays on floor")
		_expect_true(ipad_position.x >= 44.0, "iPad cropped hole stays visible")
	world_view.free()


func _test_perspective_route() -> void:
	var world_view: WorldView = WorldView.new()
	var background: Texture2D = load(
		"res://assets/background/stages/restaurant.jpg"
	) as Texture2D
	var viewport_size: Vector2 = Vector2(1366.0, 1024.0)
	@warning_ignore("unsafe_cast")
	world_view.hole_position = world_view.call(
		"_background_point_to_viewport",
		Vector2(155.0, 495.0),
		background,
		viewport_size
	) as Vector2
	@warning_ignore("unsafe_cast")
	world_view.resource_position = world_view.call(
		"_background_point_to_viewport",
		Vector2(1110.0, 485.0),
		background,
		viewport_size
	) as Vector2
	var route_value: Variant = world_view.call(
		"_build_stage_route",
		3,
		background,
		viewport_size
	)
	_expect_true(route_value is PackedVector2Array, "perspective route type")
	if route_value is PackedVector2Array:
		@warning_ignore("unsafe_cast")
		var route: PackedVector2Array = route_value as PackedVector2Array
		_expect_equal_int(route.size(), 5, "perspective route control count")
		_expect_true(route[2].y < route[0].y, "perspective route enters distant floor")
		_expect_true(route[2].y < route[route.size() - 1].y, "perspective route returns foreground")
	world_view.free()


func _test_save_round_trip() -> void:
	var payload: Dictionary = {
		"schema_version": SaveManager.CURRENT_SCHEMA_VERSION,
		"cheese": 321.0,
		"total_cheese": 654.0,
		"mouse_count": 4,
		"speed_level": 2,
		"carry_level": 3,
		"hole_level": 2,
		"selected_stage_index": 1,
		"unlocked_stage_ids": ["old_kitchen", "food_storage"],
		"completed_region_event_ids": ["kitchen_cat_patrol"],
		"next_region_event_unix": 0,
		"completed_field_action_ids": ["kitchen_thread_tangle"],
		"next_field_action_unix": 0,
		"region_progress": {
			"old_kitchen": {
				"action_level": 1,
				"risk_level": 1,
				"route_unlocked": true,
				"flags": ["thread_route"],
				"last_choice_id": "kitchen_cat_patrol_0"
			}
		},
		"nursery_level": 1,
		"nursery_pups": [{
			"id": 4,
			"ready_unix": TimeManager.current_unix_time() + 60,
			"care_count": 2
		}],
		"total_raised_pups": 3,
		"next_pup_id": 5,
		"role_assignments": {
			"gatherer": 2,
			"explorer": 1,
			"builder": 1
		},
		"selected_hero_id": "saebyeok",
		"tutorial_step": 4,
		"play_time_seconds": 99.0,
		"total_trips": 12,
		"total_click_boosts": 2,
		"total_golden_events": 1,
		"last_saved_unix": TimeManager.current_unix_time()
	}
	var saved: bool = SaveManager.save_game(payload)
	_expect_true(saved, "save succeeds")
	_expect_true(SaveManager.last_save_was_persistent, "native save is persistent")
	var loaded: Dictionary = SaveManager.load_game(payload)
	var loaded_cheese: Variant = loaded.get("cheese", -1.0)
	if loaded_cheese is float:
		@warning_ignore("unsafe_call_argument")
		_expect_equal_float(loaded_cheese, 321.0, "save/load cheese")
	else:
		_fail("save/load cheese type")
	_expect_equal_int(
		_dictionary_array_size(loaded, "nursery_pups"),
		1,
		"save/load nursery pups"
	)
	_expect_equal_int(
		_dictionary_int(
			_dictionary_dictionary(loaded, "role_assignments"),
			"explorer",
			0
		),
		1,
		"save/load role assignments"
	)
	_expect_true(
		_dictionary_string(loaded, "selected_hero_id", "") == "saebyeok",
		"save/load selected hero"
	)


func _test_ui_layout() -> void:
	GameManager.tutorial_step = 4
	var host: Control = Control.new()
	host.size = Vector2(768.0, 1024.0)
	add_child(host)
	var game_ui: GameUI = GameUI.new()
	host.add_child(game_ui)
	await get_tree().process_frame
	_expect_true(game_ui.top_panel.position.x >= 0.0, "portrait top panel left bound")
	_expect_true(
		game_ui.top_panel.position.x + game_ui.top_panel.size.x <= host.size.x,
		"portrait top panel right bound"
	)
	_expect_true(
		game_ui.top_panel.size.x >= host.size.x - 40.0,
		"portrait top panel fills available width"
	)
	_expect_true(
		game_ui.bottom_panel.position.y + game_ui.bottom_panel.size.y <= host.size.y,
		"portrait bottom panel bound"
	)
	_expect_true(
		game_ui.bottom_panel.size.x >= host.size.x - 40.0,
		"portrait bottom panel fills available width"
	)
	_expect_true(game_ui.button_grid.columns == 2, "portrait action columns")
	_expect_true(
		game_ui.next_reward_panel.position.x + game_ui.next_reward_panel.size.x <= host.size.x,
		"portrait reward card right bound"
	)
	_expect_true(
		game_ui.next_reward_panel.position.x >= 0.0,
		"portrait reward card left bound"
	)
	game_ui.call("_on_golden_changed", true, 9.9)
	game_ui.call("_show_toast", "황금치즈 발견! 10초간 보상 5배!")
	await get_tree().process_frame
	var golden_rect: Rect2 = game_ui.golden_label.get_global_rect()
	var toast_rect: Rect2 = game_ui.toast_label.get_global_rect()
	var reward_rect: Rect2 = game_ui.next_reward_panel.get_global_rect()
	_expect_true(golden_rect.end.x <= host.size.x, "portrait golden text right bound")
	_expect_true(toast_rect.position.x >= 0.0, "portrait toast left bound")
	_expect_true(toast_rect.end.x <= host.size.x, "portrait toast right bound")
	_expect_true(toast_rect.position.y >= reward_rect.end.y, "toast clears reward card")
	var previous_cooldown: int = GameManager.next_region_event_unix
	GameManager.next_region_event_unix = 0
	game_ui.call("_show_region_event")
	await get_tree().process_frame
	_expect_true(game_ui.region_event_panel.visible, "portrait region event opens")
	_expect_equal_int(game_ui.region_choice_buttons.size(), 3, "region event button count")
	_expect_true(
		game_ui.region_choice_buttons[2].disabled,
		"expert region choice shows locked requirement"
	)
	_expect_true(
		game_ui.region_event_panel.get_global_rect().end.y <= host.size.y,
		"portrait region event bottom bound"
	)
	game_ui.call("_hide_region_event")
	game_ui.call("_show_regions")
	await get_tree().process_frame
	_expect_true(game_ui.region_panel.visible, "portrait region list opens")
	_expect_true(
		game_ui.region_panel.get_global_rect().end.x <= host.size.x,
		"portrait region list right bound"
	)
	_expect_true(
		game_ui.region_panel.get_global_rect().end.y <= host.size.y,
		"portrait region list bottom bound"
	)
	_expect_true(
		not game_ui.region_progress_label.text.is_empty(),
		"region codex progress text"
	)
	game_ui.call("_hide_regions")
	var previous_stage_index: int = GameManager.current_stage_index
	var previous_field_cooldown: int = GameManager.next_field_action_unix
	GameManager.current_stage_index = 0
	GameManager.next_field_action_unix = 0
	game_ui.call("_show_field_action")
	await get_tree().process_frame
	_expect_true(game_ui.field_action_panel.visible, "portrait field action opens")
	_expect_true(
		game_ui.field_action_panel.get_global_rect().end.y <= host.size.y,
		"portrait field action bottom bound"
	)
	_expect_true(
		game_ui.field_action_view.action_type == "untangle",
		"portrait field action mechanic"
	)
	game_ui.call("_hide_field_action")
	var previous_hole_level: int = GameManager.hole_level
	var previous_nursery_level: int = GameManager.nursery_level
	var previous_pups: Array[Dictionary] = GameManager.nursery_pups.duplicate(true)
	GameManager.hole_level = 10
	GameManager.nursery_level = 1
	GameManager.nursery_pups = [{
		"id": 99,
		"ready_unix": TimeManager.current_unix_time() + 60,
		"care_count": 0
	}]
	game_ui.call("_show_nursery")
	await get_tree().process_frame
	_expect_true(game_ui.nursery_panel.visible, "portrait nursery opens")
	_expect_true(
		game_ui.nursery_panel.get_global_rect().end.y <= host.size.y,
		"portrait nursery bottom bound"
	)
	_expect_equal_int(game_ui.nursery_view.pups.size(), 1, "nursery view receives pup")
	game_ui.call("_hide_nursery")
	GameManager.hole_level = previous_hole_level
	GameManager.nursery_level = previous_nursery_level
	GameManager.nursery_pups = previous_pups
	var previous_mouse_count: int = GameManager.mouse_count
	var previous_roles: Dictionary = GameManager.role_assignments.duplicate(true)
	GameManager.mouse_count = 4
	GameManager.role_assignments = {
		"gatherer": 2,
		"explorer": 1,
		"builder": 1
	}
	game_ui.call("_show_role_board")
	await get_tree().process_frame
	_expect_true(game_ui.role_panel.visible, "portrait role board opens")
	_expect_true(
		game_ui.role_panel.get_global_rect().end.y <= host.size.y,
		"portrait role board bottom bound"
	)
	_expect_equal_int(
		_dictionary_int(game_ui.role_view.assignments, "builder", 0),
		1,
		"role board receives assignments"
	)
	game_ui.call("_hide_role_board")
	GameManager.mouse_count = previous_mouse_count
	GameManager.role_assignments = previous_roles
	var previous_hero_id: String = GameManager.selected_hero_id
	GameManager.mouse_count = 5
	GameManager.selected_hero_id = ""
	game_ui.call("_show_hero_panel")
	await get_tree().process_frame
	_expect_true(game_ui.hero_panel.visible, "portrait hero panel opens")
	_expect_true(
		game_ui.hero_panel.get_global_rect().end.y <= host.size.y,
		"portrait hero panel bottom bound"
	)
	_expect_equal_int(game_ui.hero_view.candidates.size(), 3, "hero panel candidates")
	_expect_true(game_ui.hero_confirm_button.disabled, "hero confirm waits for preview")
	game_ui.call("_on_hero_candidate_pressed", "saebyeok")
	_expect_true(not game_ui.hero_confirm_button.disabled, "hero preview enables confirm")
	game_ui.call("_hide_hero_panel")
	GameManager.mouse_count = previous_mouse_count
	GameManager.selected_hero_id = previous_hero_id
	GameManager.current_stage_index = previous_stage_index
	GameManager.next_field_action_unix = previous_field_cooldown
	GameManager.next_region_event_unix = previous_cooldown
	host.queue_free()
	await get_tree().process_frame

	var landscape_host: Control = Control.new()
	landscape_host.size = Vector2(1366.0, 1024.0)
	add_child(landscape_host)
	var landscape_ui: GameUI = GameUI.new()
	landscape_host.add_child(landscape_ui)
	await get_tree().process_frame
	_expect_true(landscape_ui.info_grid.columns == 4, "landscape info columns")
	_expect_true(landscape_ui.event_grid.columns == 3, "landscape event columns")
	_expect_true(landscape_ui.button_grid.columns == 4, "landscape action columns")
	_expect_true(
		landscape_ui.top_panel.position.x + landscape_ui.top_panel.size.x
		<= landscape_host.size.x,
		"landscape top panel right bound"
	)
	_expect_true(
		landscape_ui.bottom_panel.position.y + landscape_ui.bottom_panel.size.y
		<= landscape_host.size.y,
		"landscape bottom panel bound"
	)
	landscape_host.queue_free()
	await get_tree().process_frame


func _test_mouse_round_trip() -> void:
	GameManager.cheese = 0.0
	GameManager.total_cheese = 0.0
	GameManager.speed_level = 0
	GameManager.carry_level = 0
	GameManager.current_stage_index = 0
	GameManager.golden_remaining = 0.0
	var mouse_scene: PackedScene = load("res://scenes/mouse/mouse.tscn") as PackedScene
	var mouse_node: GatheringMouse = mouse_scene.instantiate() as GatheringMouse
	add_child(mouse_node)
	mouse_node.configure(Vector2.ZERO, Vector2(10.0, 0.0), 0.0, 0)
	await get_tree().create_timer(0.3).timeout
	_expect_true(GameManager.cheese >= 1.0, "automatic mouse round trip")
	_expect_true(mouse_node.walk_phase > 0.0, "mouse walk animation advances")
	mouse_node.queue_free()


func _expect_equal_int(actual: int, expected: int, label: String) -> void:
	if actual != expected:
		_fail("%s: expected %d, got %d" % [label, expected, actual])


func _expect_equal_float(actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		_fail("%s: expected %.3f, got %.3f" % [label, expected, actual])


func _expect_dictionary_float(
	data: Dictionary,
	key: String,
	expected: float,
	label: String
) -> void:
	var value: Variant = data.get(key, -1.0)
	if value is float:
		@warning_ignore("unsafe_call_argument")
		_expect_equal_float(value, expected, label)
		return
	if value is int:
		@warning_ignore("unsafe_call_argument")
		_expect_equal_float(float(value), expected, label)
		return
	_fail("%s: expected numeric value" % label)


func _dictionary_int(data: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = data.get(key, fallback)
	if value is int:
		return value
	if value is float:
		@warning_ignore("unsafe_call_argument")
		return int(value)
	return fallback


func _dictionary_array_size(data: Dictionary, key: String) -> int:
	var value: Variant = data.get(key, [])
	if value is Array:
		@warning_ignore("unsafe_cast")
		var items: Array = value as Array
		return items.size()
	return -1


func _dictionary_bool(data: Dictionary, key: String, fallback: bool) -> bool:
	var value: Variant = data.get(key, fallback)
	if value is bool:
		return value
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


func _expect_true(actual: bool, label: String) -> void:
	if not actual:
		_fail("%s: expected true" % label)


func _fail(message: String) -> void:
	_failures += 1
	push_error(message)
