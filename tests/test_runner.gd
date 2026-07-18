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
		print("JJUGUMEONG V0.3 tests: PASS")
		get_tree().quit(0)
	else:
		push_error("JJUGUMEONG V0.3 tests: %d failure(s)" % _failures)
		get_tree().quit(1)


func _test_time_cap() -> void:
	var now: int = TimeManager.current_unix_time()
	_expect_equal_int(TimeManager.capped_offline_seconds(now - 20_000), 14_400, "offline cap")
	_expect_equal_int(TimeManager.capped_offline_seconds(now + 100), 0, "future timestamp")


func _test_build_info() -> void:
	_expect_true(GameManager.display_name == "쥐구멍", "build display name")
	_expect_true(GameManager.product_name == "r4", "build product name")
	_expect_true(GameManager.build_version == "0.3.1", "build version")
	_expect_true(GameManager.build_phase == "V0.3 Alpha", "build phase")
	_expect_true(GameManager.get_build_label() == "r4 0.3.1", "build label")


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
		"next_region_event_unix": 0
	}
	var migrated_value: Variant = SaveManager.call("_migrate_data", legacy, defaults)
	_expect_true(migrated_value is Dictionary, "schema 1 migration result type")
	if migrated_value is Dictionary:
		@warning_ignore("unsafe_cast")
		var migrated: Dictionary = migrated_value as Dictionary
		_expect_equal_int(
			_dictionary_int(migrated, "schema_version", 0),
			2,
			"schema migration version"
		)
		_expect_equal_int(
			_dictionary_int(migrated, "selected_stage_index", -1),
			2,
			"schema migration selected stage"
		)
		_expect_dictionary_float(migrated, "cheese", 123.0, "schema migration cheese")


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
	GameManager.cheese = 0.0
	GameManager.total_cheese = 0.0
	GameManager.carry_level = 0
	GameManager.current_stage_index = 0
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

	GameManager.current_stage_index = 0
	GameManager.highest_unlocked_stage_index = 0
	GameManager.unlocked_stage_ids = ["old_kitchen"]
	GameManager.cheese = 0.0
	GameManager.total_cheese = 0.0
	GameManager.carry_level = 0
	GameManager.golden_remaining = 0.0
	GameManager.completed_region_event_ids.clear()
	GameManager.next_region_event_unix = 0
	var region_event: Dictionary = GameManager.get_current_region_event()
	var choices_value: Variant = region_event.get("choices", [])
	_expect_true(choices_value is Array, "region event choices type")
	if choices_value is Array:
		@warning_ignore("unsafe_cast")
		var choices: Array = choices_value as Array
		_expect_equal_int(choices.size(), 2, "region event has two choices")
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
	_expect_equal_int(game_ui.region_choice_buttons.size(), 2, "region event button count")
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


func _expect_true(actual: bool, label: String) -> void:
	if not actual:
		_fail("%s: expected true" % label)


func _fail(message: String) -> void:
	_failures += 1
	push_error(message)
