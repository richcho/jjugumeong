extends Node

var _failures: int = 0


func _ready() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_time_cap()
	_test_upgrade_costs()
	_test_golden_reward()
	_test_reward_text_bounds()
	_test_stage_backgrounds()
	_test_korean_font()
	_test_save_round_trip()
	await _test_ui_layout()
	await _test_mouse_round_trip()

	if _failures == 0:
		print("JJUGUMEONG V0.2 tests: PASS")
		get_tree().quit(0)
	else:
		push_error("JJUGUMEONG V0.2 tests: %d failure(s)" % _failures)
		get_tree().quit(1)


func _test_time_cap() -> void:
	var now: int = TimeManager.current_unix_time()
	_expect_equal_int(TimeManager.capped_offline_seconds(now - 20_000), 14_400, "offline cap")
	_expect_equal_int(TimeManager.capped_offline_seconds(now + 100), 0, "future timestamp")


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


func _test_golden_reward() -> void:
	GameManager.cheese = 0.0
	GameManager.total_cheese = 0.0
	GameManager.carry_level = 0
	GameManager.current_stage_index = 0
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
	_expect_true(upper_left_value is Vector2, "reward upper-left position type")
	_expect_true(lower_right_value is Vector2, "reward lower-right position type")
	if upper_left_value is Vector2 and lower_right_value is Vector2:
		@warning_ignore("unsafe_cast")
		var upper_left: Vector2 = upper_left_value as Vector2
		@warning_ignore("unsafe_cast")
		var lower_right: Vector2 = lower_right_value as Vector2
		_expect_true(upper_left.x >= 24.0 and upper_left.y >= 165.0, "reward upper-left bounds")
		_expect_true(lower_right.x <= 880.0, "reward right bound")
		_expect_true(lower_right.y <= 563.0, "reward bottom bound")
	world_view.free()


func _test_korean_font() -> void:
	var font_path: String = "res://assets/fonts/NotoSansKR-Subset.ttf"
	var configured_font_path: String = str(ProjectSettings.get_setting("gui/theme/custom_font", ""))
	_expect_true(configured_font_path == font_path, "Korean font is configured")
	var game_font: FontFile = load(font_path) as FontFile
	_expect_true(game_font != null, "Korean font loads")
	if game_font == null:
		return
	for character: String in "쥐구멍치즈황금저장":
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


func _test_save_round_trip() -> void:
	var payload: Dictionary = {
		"schema_version": SaveManager.CURRENT_SCHEMA_VERSION,
		"cheese": 321.0,
		"total_cheese": 654.0,
		"mouse_count": 4,
		"speed_level": 2,
		"carry_level": 3,
		"hole_level": 2,
		"current_stage_index": 1,
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
		game_ui.bottom_panel.position.y + game_ui.bottom_panel.size.y <= host.size.y,
		"portrait bottom panel bound"
	)
	_expect_true(game_ui.button_grid.columns == 2, "portrait action columns")
	_expect_true(
		game_ui.next_reward_panel.position.x + game_ui.next_reward_panel.size.x <= host.size.x,
		"portrait reward card right bound"
	)
	host.queue_free()
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
	mouse_node.queue_free()


func _expect_equal_int(actual: int, expected: int, label: String) -> void:
	if actual != expected:
		_fail("%s: expected %d, got %d" % [label, expected, actual])


func _expect_equal_float(actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		_fail("%s: expected %.3f, got %.3f" % [label, expected, actual])


func _expect_true(actual: bool, label: String) -> void:
	if not actual:
		_fail("%s: expected true" % label)


func _fail(message: String) -> void:
	_failures += 1
	push_error(message)
