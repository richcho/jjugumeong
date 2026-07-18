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

var speed_button: Button
var carry_button: Button
var mouse_button: Button
var hole_button: Button
var button_grid: GridContainer
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_update_responsive_layout()


func _build_interface() -> void:
	top_panel = PanelContainer.new()
	top_panel.name = "TopPanel"
	top_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.045, 0.075, 0.94), 12))
	add_child(top_panel)

	var top_margin: MarginContainer = MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 18)
	top_margin.add_theme_constant_override("margin_right", 18)
	top_margin.add_theme_constant_override("margin_top", 10)
	top_margin.add_theme_constant_override("margin_bottom", 10)
	top_panel.add_child(top_margin)

	var top_vbox: VBoxContainer = VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 5)
	top_margin.add_child(top_vbox)

	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 14)
	top_vbox.add_child(title_row)
	title_label = _make_label("쥐구멍  ALPHA 0.1.2", 25, Color("#ffd969"))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_label)
	save_label = _make_label("불러오는 중...", 14, Color("#afc9bd"))
	save_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_row.add_child(save_label)

	var info_row: HBoxContainer = HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 22)
	top_vbox.add_child(info_row)
	stage_label = _make_info_label()
	cheese_label = _make_info_label()
	production_label = _make_info_label()
	mouse_label = _make_info_label()
	for label: Label in [stage_label, cheese_label, production_label, mouse_label]:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_row.add_child(label)

	var event_row: HBoxContainer = HBoxContainer.new()
	event_row.add_theme_constant_override("separation", 18)
	top_vbox.add_child(event_row)
	golden_label = _make_label("", 14, Color("#ffe384"))
	golden_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	golden_label.clip_text = true
	golden_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	event_row.add_child(golden_label)
	boost_label = _make_label("이동 구역 클릭: 속도 부스트", 14, Color("#9edbff"))
	boost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_row.add_child(boost_label)
	next_stage_label = _make_label("", 14, Color("#d6c8e8"))
	next_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	next_stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_row.add_child(next_stage_label)

	bottom_panel = PanelContainer.new()
	bottom_panel.name = "BottomPanel"
	bottom_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.045, 0.075, 0.96), 12))
	add_child(bottom_panel)
	var bottom_margin: MarginContainer = MarginContainer.new()
	bottom_margin.add_theme_constant_override("margin_left", 12)
	bottom_margin.add_theme_constant_override("margin_right", 12)
	bottom_margin.add_theme_constant_override("margin_top", 12)
	bottom_margin.add_theme_constant_override("margin_bottom", 12)
	bottom_panel.add_child(bottom_margin)
	button_grid = GridContainer.new()
	button_grid.columns = 4
	button_grid.add_theme_constant_override("h_separation", 9)
	button_grid.add_theme_constant_override("v_separation", 9)
	bottom_margin.add_child(button_grid)

	speed_button = _make_button("", _on_speed_pressed, Color("#5d486f"))
	carry_button = _make_button("", _on_carry_pressed, Color("#5d486f"))
	mouse_button = _make_button("", _on_mouse_pressed, Color("#49695f"))
	hole_button = _make_button("", _on_hole_pressed, Color("#6d5341"))
	button_grid.add_child(speed_button)
	button_grid.add_child(carry_button)
	button_grid.add_child(mouse_button)
	button_grid.add_child(hole_button)
	button_grid.add_child(_make_button("통계", _show_stats, Color("#394b63")))
	button_grid.add_child(_make_button("수동 저장", _save_manually, Color("#3f625c")))
	button_grid.add_child(_make_button("탐험 (예정)", _show_future_message.bind("탐험"), Color("#303640")))
	button_grid.add_child(_make_button("건설·연구 (예정)", _show_future_message.bind("건설·연구"), Color("#303640")))

	toast_label = _make_label("", 20, Color("#fff4d4"))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.add_theme_stylebox_override("normal", _make_panel_style(Color(0.08, 0.06, 0.09, 0.92), 10))
	toast_label.hide()
	add_child(toast_label)

	_build_stats_panel()
	_build_tutorial_panel()
	_build_offline_panel()


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
	mouse_label.text = "쥐  %d마리" % GameManager.mouse_count
	speed_button.text = "속도 강화 Lv.%d\n치즈 %d" % [GameManager.speed_level, GameManager.get_speed_upgrade_cost()]
	carry_button.text = "운반량 %d → %d\n치즈 %d" % [
		GameManager.get_carry_capacity(),
		GameManager.get_carry_capacity() + 1,
		GameManager.get_carry_upgrade_cost()
	]
	mouse_button.text = "쥐 추가 (%d마리)\n치즈 %d" % [GameManager.mouse_count, GameManager.get_mouse_cost()]
	hole_button.text = "쥐구멍 확장 Lv.%d\n치즈 %d" % [GameManager.hole_level, GameManager.get_hole_upgrade_cost()]
	speed_button.disabled = GameManager.cheese < float(GameManager.get_speed_upgrade_cost())
	carry_button.disabled = GameManager.cheese < float(GameManager.get_carry_upgrade_cost())
	mouse_button.disabled = GameManager.cheese < float(GameManager.get_mouse_cost())
	hole_button.disabled = GameManager.cheese < float(GameManager.get_hole_upgrade_cost())

	var next_stage: Dictionary = GameManager.get_next_stage()
	if next_stage.is_empty():
		next_stage_label.text = "초기 지역 전체 개방"
	else:
		var needed: float = maxf(
			0.0,
			_dictionary_float(next_stage, "unlock_total_cheese", 0.0) - GameManager.total_cheese
		)
		next_stage_label.text = "다음: %s (누적 %s 남음)" % [
			_dictionary_string(next_stage, "name", ""),
			_format_number(needed)
		]
	_on_golden_changed(GameManager.golden_remaining > 0.0, GameManager.golden_remaining)
	_on_boost_changed(GameManager.click_boost_remaining > 0.0, GameManager.click_boost_remaining)


func _update_responsive_layout() -> void:
	var viewport_size: Vector2 = size
	var compact_layout: bool = viewport_size.x < 1000.0
	var side_margin: float = 28.0 if not compact_layout else 16.0
	top_panel.set_offsets_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_left = side_margin
	top_panel.offset_top = 18.0
	top_panel.offset_right = -side_margin
	top_panel.offset_bottom = 137.0 if not compact_layout else 158.0
	bottom_panel.set_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.offset_left = side_margin
	bottom_panel.offset_right = -side_margin
	bottom_panel.offset_top = -186.0 if not compact_layout else -328.0
	bottom_panel.offset_bottom = -18.0
	button_grid.columns = 4 if not compact_layout else 2

	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	var toast_width: float = minf(420.0, viewport_size.x - side_margin * 2.0)
	toast_label.position = Vector2(-toast_width * 0.5, top_panel.offset_bottom + 18.0)
	toast_label.size = Vector2(toast_width, 54.0)
	_place_modal(stats_panel, Vector2(430.0, 380.0))
	_place_modal(tutorial_panel, Vector2(480.0, 280.0))
	_place_modal(offline_panel, Vector2(480.0, 260.0))


func _place_modal(panel: Control, desired_size: Vector2) -> void:
	var actual_size: Vector2 = Vector2(
		minf(desired_size.x, maxf(280.0, size.x - 32.0)),
		minf(desired_size.y, maxf(220.0, size.y - 32.0))
	)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = -actual_size * 0.5
	panel.size = actual_size


func _make_info_label() -> Label:
	var label: Label = _make_label("", 16, Color("#f1e8dc"))
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
	button.custom_minimum_size = Vector2(150.0, 64.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _make_panel_style(color, 9))
	button.add_theme_stylebox_override("hover", _make_panel_style(color.lightened(0.12), 9))
	button.add_theme_stylebox_override("pressed", _make_panel_style(color.darkened(0.12), 9))
	button.add_theme_stylebox_override("disabled", _make_panel_style(Color("#29272e"), 9))
	button.pressed.connect(callback)
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


func _on_golden_changed(active: bool, remaining: float) -> void:
	if active:
		golden_label.text = "황금치즈 %.1f초 · 5배" % remaining
	else:
		golden_label.text = "ALPHA 보상 25배"


func _on_boost_changed(active: bool, remaining: float) -> void:
	if active:
		boost_label.text = "속도 부스트 %.1f초 · 1.8배" % remaining
	else:
		boost_label.text = "이동 구역 클릭: 3초 속도 부스트"


func _on_save_status_changed(message: String) -> void:
	save_label.text = message


func _on_tutorial_changed(_step: int) -> void:
	if tutorial_panel.visible:
		tutorial_text.text = GameManager.get_tutorial_text()


func _dictionary_float(data: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = data.get(key, fallback)
	if value is float:
		return value
	if value is int:
		@warning_ignore("unsafe_call_argument")
		return float(value)
	return fallback


func _dictionary_string(data: Dictionary, key: String, fallback: String) -> String:
	var value: Variant = data.get(key, fallback)
	if value is String:
		return value
	if value is StringName:
		@warning_ignore("unsafe_call_argument")
		return String(value)
	return fallback
