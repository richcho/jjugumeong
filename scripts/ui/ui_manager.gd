class_name GameUI
extends Control

var title_label: Label
var stage_label: Label
var cheese_label: Label
var production_label: Label
var mouse_label: Label
var save_label: Label
var golden_label: Label
var boost_label: Label
var next_stage_label: Label
var toast_label: Label
var next_reward_panel: PanelContainer
var next_reward_title: Label
var next_reward_detail: Label
var next_reward_progress: ProgressBar
var discovery_panel: PanelContainer
var discovery_title: Label
var discovery_detail: Label

var speed_button: Button
var carry_button: Button
var mouse_button: Button
var hole_button: Button
var button_grid: GridContainer
var info_grid: GridContainer
var event_grid: GridContainer
var top_panel: PanelContainer
var bottom_panel: PanelContainer

var stats_panel: PanelContainer
var stats_text: Label
var tutorial_panel: PanelContainer
var tutorial_text: Label
var offline_panel: PanelContainer
var offline_text: Label

var _toast_remaining: float = 0.0
var _refresh_elapsed: float = 0.0
var _discovery_remaining: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_interface()
	_connect_events()
	_update_responsive_layout()
	_refresh_all()
	save_label.text = "저장 복구됨" if SaveManager.last_load_was_recovered else "불러오기 완료"
	if GameManager.tutorial_step < 4:
		_show_tutorial()
	if GameManager.offline_reward > 0.0:
		_show_offline_reward()


func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.15:
		_refresh_elapsed = 0.0
		_refresh_all()
	if _toast_remaining > 0.0:
		_toast_remaining = maxf(_toast_remaining - delta, 0.0)
		toast_label.modulate.a = minf(1.0, _toast_remaining * 2.0)
		if _toast_remaining <= 0.0:
			toast_label.hide()
	if _discovery_remaining > 0.0:
		_discovery_remaining = maxf(_discovery_remaining - delta, 0.0)
		discovery_panel.modulate.a = minf(1.0, _discovery_remaining * 1.5)
		if _discovery_remaining <= 0.0:
			discovery_panel.hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready() and top_panel != null:
		_update_responsive_layout()


func _build_interface() -> void:
	top_panel = PanelContainer.new()
	top_panel.name = "TopPanel"
	top_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.045, 0.075, 0.94), 12))
	add_child(top_panel)

	var top_margin: MarginContainer = MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 15)
	top_margin.add_theme_constant_override("margin_right", 15)
	top_margin.add_theme_constant_override("margin_top", 7)
	top_margin.add_theme_constant_override("margin_bottom", 7)
	top_panel.add_child(top_margin)

	var top_vbox: VBoxContainer = VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 3)
	top_margin.add_child(top_vbox)

	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 14)
	top_vbox.add_child(title_row)
	title_label = _make_label("쥐구멍  r4 0.2.5", 22, Color("#ffd969"))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_label)
	save_label = _make_label("불러오는 중...", 14, Color("#afc9bd"))
	save_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_row.add_child(save_label)

	info_grid = GridContainer.new()
	info_grid.columns = 4
	info_grid.add_theme_constant_override("h_separation", 16)
	info_grid.add_theme_constant_override("v_separation", 3)
	top_vbox.add_child(info_grid)
	stage_label = _make_info_label()
	cheese_label = _make_info_label()
	production_label = _make_info_label()
	mouse_label = _make_info_label()
	for label: Label in [stage_label, cheese_label, production_label, mouse_label]:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		info_grid.add_child(label)

	event_grid = GridContainer.new()
	event_grid.columns = 3
	event_grid.add_theme_constant_override("h_separation", 14)
	event_grid.add_theme_constant_override("v_separation", 3)
	top_vbox.add_child(event_grid)
	golden_label = _make_label("", 13, Color("#ffe384"))
	golden_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	golden_label.clip_text = true
	golden_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	event_grid.add_child(golden_label)
	boost_label = _make_label("이동 구역 클릭: 속도 부스트", 13, Color("#9edbff"))
	boost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boost_label.clip_text = true
	boost_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	event_grid.add_child(boost_label)
	next_stage_label = _make_label("", 13, Color("#d6c8e8"))
	next_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	next_stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_stage_label.clip_text = true
	next_stage_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	event_grid.add_child(next_stage_label)

	bottom_panel = PanelContainer.new()
	bottom_panel.name = "BottomPanel"
	bottom_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.045, 0.075, 0.96), 12))
	add_child(bottom_panel)
	var bottom_margin: MarginContainer = MarginContainer.new()
	bottom_margin.add_theme_constant_override("margin_left", 9)
	bottom_margin.add_theme_constant_override("margin_right", 9)
	bottom_margin.add_theme_constant_override("margin_top", 8)
	bottom_margin.add_theme_constant_override("margin_bottom", 8)
	bottom_panel.add_child(bottom_margin)
	var bottom_content: VBoxContainer = VBoxContainer.new()
	bottom_content.add_theme_constant_override("separation", 6)
	bottom_margin.add_child(bottom_content)
	button_grid = GridContainer.new()
	button_grid.columns = 4
	button_grid.add_theme_constant_override("h_separation", 7)
	button_grid.add_theme_constant_override("v_separation", 7)
	bottom_content.add_child(button_grid)

	speed_button = _make_button("", _on_speed_pressed, Color("#5d486f"))
	carry_button = _make_button("", _on_carry_pressed, Color("#5d486f"))
	mouse_button = _make_button("", _on_mouse_pressed, Color("#49695f"))
	hole_button = _make_button("", _on_hole_pressed, Color("#6d5341"))
	button_grid.add_child(speed_button)
	button_grid.add_child(carry_button)
	button_grid.add_child(mouse_button)
	button_grid.add_child(hole_button)
	var utility_row: HBoxContainer = HBoxContainer.new()
	utility_row.add_theme_constant_override("separation", 7)
	bottom_content.add_child(utility_row)
	utility_row.add_child(_make_utility_button("통계", _show_stats))
	utility_row.add_child(_make_utility_button("지금 저장", _save_manually))

	toast_label = _make_label("", 20, Color("#fff4d4"))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.clip_text = true
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.add_theme_stylebox_override("normal", _make_panel_style(Color(0.08, 0.06, 0.09, 0.92), 10))
	toast_label.hide()
	add_child(toast_label)

	_build_next_reward_panel()
	_build_discovery_panel()
	_build_stats_panel()
	_build_tutorial_panel()
	_build_offline_panel()


func _build_next_reward_panel() -> void:
	next_reward_panel = PanelContainer.new()
	next_reward_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.055, 0.045, 0.07, 0.9), 14)
	)
	add_child(next_reward_panel)
	var margin: MarginContainer = _make_margin(10)
	next_reward_panel.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	margin.add_child(content)
	next_reward_title = _make_label("", 16, Color("#ffe384"))
	next_reward_title.clip_text = true
	content.add_child(next_reward_title)
	next_reward_detail = _make_label("", 13, Color("#eee7f0"))
	next_reward_detail.clip_text = true
	content.add_child(next_reward_detail)
	next_reward_progress = ProgressBar.new()
	next_reward_progress.show_percentage = false
	next_reward_progress.custom_minimum_size = Vector2(0.0, 8.0)
	next_reward_progress.add_theme_stylebox_override(
		"background",
		_make_panel_style(Color(0.13, 0.12, 0.16, 0.95), 6)
	)
	next_reward_progress.add_theme_stylebox_override(
		"fill",
		_make_panel_style(Color("#e4af43"), 6)
	)
	content.add_child(next_reward_progress)


func _build_discovery_panel() -> void:
	discovery_panel = PanelContainer.new()
	discovery_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.055, 0.035, 0.07, 0.96), 18)
	)
	discovery_panel.hide()
	add_child(discovery_panel)
	var margin: MarginContainer = _make_margin(24)
	discovery_panel.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	discovery_title = _make_label("", 27, Color("#ffd969"))
	discovery_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discovery_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(discovery_title)
	discovery_detail = _make_label("", 17, Color("#f3e9d5"))
	discovery_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discovery_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(discovery_detail)


func _build_stats_panel() -> void:
	stats_panel = PanelContainer.new()
	stats_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.055, 0.045, 0.07, 0.98), 16))
	stats_panel.hide()
	add_child(stats_panel)
	var margin: MarginContainer = _make_margin(24)
	stats_panel.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var heading: Label = _make_label("쥐구멍 통계", 26, Color("#ffd969"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)
	stats_text = _make_label("", 18, Color("#eee7f0"))
	stats_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(stats_text)
	content.add_child(_make_button("닫기", _hide_stats, Color("#5d486f")))


func _build_tutorial_panel() -> void:
	tutorial_panel = PanelContainer.new()
	tutorial_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.07, 0.055, 0.09, 0.98), 16))
	tutorial_panel.hide()
	add_child(tutorial_panel)
	var margin: MarginContainer = _make_margin(24)
	tutorial_panel.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 15)
	margin.add_child(content)
	var heading: Label = _make_label("첫 쥐구멍 안내", 25, Color("#ffd969"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)
	tutorial_text = _make_label("", 19, Color("#f2eaf3"))
	tutorial_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tutorial_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(tutorial_text)
	content.add_child(_make_button("다음", _advance_tutorial, Color("#5f7954")))


func _build_offline_panel() -> void:
	offline_panel = PanelContainer.new()
	offline_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.07, 0.055, 0.09, 0.98), 16))
	offline_panel.hide()
	add_child(offline_panel)
	var margin: MarginContainer = _make_margin(24)
	offline_panel.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 15)
	margin.add_child(content)
	var heading: Label = _make_label("쥐들이 일하고 있었어요!", 24, Color("#ffd969"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)
	offline_text = _make_label("", 19, Color("#f2eaf3"))
	offline_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	offline_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	offline_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(offline_text)
	content.add_child(_make_button("보상 확인", _hide_offline_reward, Color("#5f7954")))


func _connect_events() -> void:
	EventBus.game_state_changed.connect(_refresh_all)
	EventBus.stage_changed.connect(_on_stage_changed)
	EventBus.golden_cheese_changed.connect(_on_golden_changed)
	EventBus.click_boost_changed.connect(_on_boost_changed)
	EventBus.save_status_changed.connect(_on_save_status_changed)
	EventBus.toast_requested.connect(_show_toast)
	EventBus.tutorial_changed.connect(_on_tutorial_changed)


func _refresh_all() -> void:
	var stage: Dictionary = GameManager.get_current_stage()
	stage_label.text = "지역  %s" % _dictionary_string(stage, "name", "낡은 부엌")
	cheese_label.text = "치즈  %s" % _format_number(GameManager.cheese)
	production_label.text = "예상 생산  %s/초" % _format_number(GameManager.get_expected_per_second())
	var visible_groups: int = mini(GameManager.mouse_count, 3)
	mouse_label.text = "쥐  %d마리 · 활동조 %d" % [
		GameManager.mouse_count,
		visible_groups
	]
	speed_button.text = "속도 Lv.%d  ·  치즈 %s" % [
		GameManager.speed_level,
		_format_number(float(GameManager.get_speed_upgrade_cost()))
	]
	carry_button.text = "운반 %d → %d  ·  치즈 %s" % [
		GameManager.get_carry_capacity(),
		GameManager.get_carry_capacity() + 1,
		_format_number(float(GameManager.get_carry_upgrade_cost()))
	]
	mouse_button.text = "동료 %d → %d  ·  치즈 %s" % [
		GameManager.mouse_count,
		GameManager.mouse_count + 1,
		_format_number(float(GameManager.get_mouse_cost()))
	]
	hole_button.text = "구멍 Lv.%d  ·  치즈 %s" % [
		GameManager.hole_level,
		_format_number(float(GameManager.get_hole_upgrade_cost()))
	]
	speed_button.disabled = GameManager.cheese < float(GameManager.get_speed_upgrade_cost())
	carry_button.disabled = GameManager.cheese < float(GameManager.get_carry_upgrade_cost())
	mouse_button.disabled = GameManager.cheese < float(GameManager.get_mouse_cost())
	hole_button.disabled = GameManager.cheese < float(GameManager.get_hole_upgrade_cost())

	var next_stage: Dictionary = GameManager.get_next_stage()
	if next_stage.is_empty():
		var colony_goal: Dictionary = GameManager.get_next_colony_goal()
		var target_level: int = _dictionary_int(
			colony_goal,
			"target_level",
			GameManager.hole_level + 1
		)
		var previous_level: int = _dictionary_int(colony_goal, "previous_level", 0)
		next_stage_label.text = "세계 소식 · %s" % GameManager.get_world_news()
		next_reward_title.text = "%s · 다음: %s" % [
			GameManager.get_colony_rank(),
			str(colony_goal.get("title", "쥐 사회 확장"))
		]
		next_reward_detail.text = "쥐구멍 Lv.%d / %d · %s" % [
			GameManager.hole_level,
			target_level,
			str(colony_goal.get("description", "새 생활 공간 발견"))
		]
		next_reward_progress.value = clampf(
			float(GameManager.hole_level - previous_level)
			/ float(maxi(1, target_level - previous_level))
			* 100.0,
			0.0,
			100.0
		)
	else:
		var current_threshold: float = _dictionary_float(stage, "unlock_total_cheese", 0.0)
		var target_threshold: float = _dictionary_float(next_stage, "unlock_total_cheese", 0.0)
		var needed: float = maxf(
			0.0,
			target_threshold - GameManager.total_cheese
		)
		next_stage_label.text = "다음: %s (누적 %s 남음)" % [
			_dictionary_string(next_stage, "name", ""),
			_format_number(needed)
		]
		next_reward_title.text = "다음 보상  ·  %s" % _dictionary_string(next_stage, "name", "")
		next_reward_detail.text = "%s / %s  ·  %s" % [
			_format_number(GameManager.total_cheese),
			_format_number(target_threshold),
			_get_stage_preview(GameManager.current_stage_index + 1)
		]
		next_reward_progress.value = clampf(
			(GameManager.total_cheese - current_threshold)
			/ maxf(1.0, target_threshold - current_threshold)
			* 100.0,
			0.0,
			100.0
		)
	_on_golden_changed(GameManager.golden_remaining > 0.0, GameManager.golden_remaining)
	_on_boost_changed(GameManager.click_boost_remaining > 0.0, GameManager.click_boost_remaining)


func _update_responsive_layout() -> void:
	var viewport_size: Vector2 = size
	var compact_layout: bool = viewport_size.x < 1000.0
	var side_margin: float = 28.0 if not compact_layout else 16.0
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_left = side_margin
	top_panel.offset_top = 18.0
	top_panel.offset_right = -side_margin
	top_panel.offset_bottom = 122.0 if not compact_layout else 205.0
	info_grid.columns = 4 if not compact_layout else 2
	event_grid.columns = 3 if not compact_layout else 1
	for event_label: Label in [golden_label, boost_label, next_stage_label]:
		event_label.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_LEFT
			if compact_layout
			else HORIZONTAL_ALIGNMENT_CENTER
		)
	bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.offset_left = side_margin
	bottom_panel.offset_right = -side_margin
	bottom_panel.offset_top = -118.0 if not compact_layout else -198.0
	bottom_panel.offset_bottom = -18.0
	button_grid.columns = 4 if not compact_layout else 2
	next_reward_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var reward_width: float = minf(350.0, viewport_size.x - side_margin * 2.0)
	next_reward_panel.position = Vector2(
		viewport_size.x - reward_width - side_margin,
		top_panel.offset_bottom + 12.0
	)
	var reward_height: float = maxf(
		82.0,
		next_reward_panel.get_combined_minimum_size().y
	)
	next_reward_panel.size = Vector2(reward_width, reward_height)

	toast_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var toast_width: float = minf(420.0, viewport_size.x - side_margin * 2.0)
	toast_label.position = Vector2(
		(viewport_size.x - toast_width) * 0.5,
		next_reward_panel.position.y + reward_height + 14.0
	)
	toast_label.size = Vector2(toast_width, 68.0 if compact_layout else 54.0)
	_place_modal(stats_panel, Vector2(430.0, 380.0))
	_place_modal(tutorial_panel, Vector2(480.0, 280.0))
	_place_modal(offline_panel, Vector2(480.0, 260.0))
	_place_modal(discovery_panel, Vector2(520.0, 150.0))


func _place_modal(panel: Control, desired_size: Vector2) -> void:
	var actual_size: Vector2 = Vector2(
		minf(desired_size.x, maxf(280.0, size.x - 32.0)),
		minf(desired_size.y, maxf(220.0, size.y - 32.0))
	)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = (size - actual_size) * 0.5
	panel.size = actual_size


func _make_info_label() -> Label:
	var label: Label = _make_label("", 15, Color("#f1e8dc"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_button(text_value: String, callback: Callable, color: Color) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(140.0, 46.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _make_panel_style(color, 9))
	button.add_theme_stylebox_override("hover", _make_panel_style(color.lightened(0.12), 9))
	button.add_theme_stylebox_override("pressed", _make_panel_style(color.darkened(0.12), 9))
	button.add_theme_stylebox_override("disabled", _make_panel_style(Color("#29272e"), 9))
	button.pressed.connect(callback)
	return button


func _make_utility_button(text_value: String, callback: Callable) -> Button:
	var button: Button = _make_button(text_value, callback, Color(0.14, 0.16, 0.2, 0.92))
	button.custom_minimum_size = Vector2(110.0, 28.0)
	button.add_theme_font_size_override("font_size", 12)
	return button


func _make_panel_style(color: Color, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _make_margin(amount: int) -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", amount)
	margin.add_theme_constant_override("margin_right", amount)
	margin.add_theme_constant_override("margin_top", amount)
	margin.add_theme_constant_override("margin_bottom", amount)
	return margin


func _format_number(value: float) -> String:
	var absolute_value: float = absf(value)
	if absolute_value >= 1_000_000_000.0:
		return "%.2fB" % (value / 1_000_000_000.0)
	if absolute_value >= 1_000_000.0:
		return "%.2fM" % (value / 1_000_000.0)
	if absolute_value >= 1_000.0:
		return "%.2fK" % (value / 1_000.0)
	if is_equal_approx(value, roundf(value)):
		return "%d" % int(value)
	return "%.2f" % value


func _on_speed_pressed() -> void:
	GameManager.buy_speed_upgrade()


func _on_carry_pressed() -> void:
	GameManager.buy_carry_upgrade()


func _on_mouse_pressed() -> void:
	GameManager.buy_mouse()


func _on_hole_pressed() -> void:
	GameManager.expand_hole()


func _show_stats() -> void:
	stats_text.text = (
		"누적 치즈: %s\n"
		+ "완료한 왕복: %d회\n"
		+ "플레이 시간: %s\n"
		+ "클릭 부스트: %d회\n"
		+ "황금치즈 사건: %d회\n"
		+ "현재 생산 보너스: %.2f배"
	) % [
		_format_number(GameManager.total_cheese),
		GameManager.total_trips,
		TimeManager.format_duration(int(GameManager.play_time_seconds)),
		GameManager.total_click_boosts,
		GameManager.total_golden_events,
		GameManager.get_stage_bonus()
	]
	stats_panel.show()
	stats_panel.move_to_front()


func _hide_stats() -> void:
	stats_panel.hide()


func _show_tutorial() -> void:
	tutorial_text.text = GameManager.get_tutorial_text()
	tutorial_panel.show()
	tutorial_panel.move_to_front()


func _advance_tutorial() -> void:
	GameManager.advance_tutorial()
	if GameManager.tutorial_step >= 4:
		tutorial_panel.hide()
	else:
		tutorial_text.text = GameManager.get_tutorial_text()


func _show_offline_reward() -> void:
	offline_text.text = "%s 동안\n치즈 %s개를 모았습니다." % [
		TimeManager.format_duration(GameManager.offline_seconds),
		_format_number(GameManager.offline_reward)
	]
	offline_panel.show()
	offline_panel.move_to_front()


func _hide_offline_reward() -> void:
	offline_panel.hide()


func _save_manually() -> void:
	if GameManager.save_now():
		_show_toast("저장됨")
	else:
		_show_toast("저장 실패 · Safari 설정 확인 필요")


func _show_future_message(feature_name: String) -> void:
	_show_toast("%s은 다음 개발 버전에서 열립니다." % feature_name)


func _show_toast(message: String) -> void:
	toast_label.text = message
	toast_label.modulate.a = 1.0
	toast_label.show()
	toast_label.move_to_front()
	_toast_remaining = 2.4


func _on_stage_changed(_stage_index: int) -> void:
	_refresh_all()
	var stage: Dictionary = GameManager.get_current_stage()
	discovery_title.text = "새 지역 발견  ·  %s" % _dictionary_string(stage, "name", "")
	discovery_detail.text = _get_stage_preview(GameManager.current_stage_index)
	discovery_panel.modulate.a = 1.0
	discovery_panel.show()
	discovery_panel.move_to_front()
	_discovery_remaining = 3.0


func _on_golden_changed(active: bool, remaining: float) -> void:
	if active:
		golden_label.text = "황금치즈  %.1f초  ·  보상 5배" % remaining
	else:
		golden_label.text = "ALPHA 보상 25배"


func _on_boost_changed(active: bool, remaining: float) -> void:
	if active:
		boost_label.text = "속도 부스트 %.1f초 · 자연 가속" % remaining
	else:
		boost_label.text = "이동 구역 클릭: 3초 속도 부스트"


func _on_save_status_changed(message: String) -> void:
	save_label.text = message


func _on_tutorial_changed(_step: int) -> void:
	if tutorial_panel.visible:
		tutorial_text.text = GameManager.get_tutorial_text()


func _get_stage_preview(stage_index: int) -> String:
	match stage_index:
		1:
			return "저장 공간 · 식료품 창고"
		2:
			return "야간 탐험 · 동네 편의점"
		3:
			return "전문 운반 · 대형 식당"
		4:
			return "기계 시대 · 치즈 공장"
		_:
			return "첫 동료 · 쥐구멍 강화"


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
	return fallback


func _dictionary_string(data: Dictionary, key: String, fallback: String) -> String:
	var value: Variant = data.get(key, fallback)
	if value is String:
		return value
	if value is StringName:
		@warning_ignore("unsafe_call_argument")
		return String(value)
	return fallback
