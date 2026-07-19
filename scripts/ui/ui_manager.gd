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
var region_panel: PanelContainer
var region_list: VBoxContainer
var region_progress_label: Label
var region_event_panel: PanelContainer
var region_event_title: Label
var region_event_description: Label
var region_choice_buttons: Array[Button] = []
var region_event_button: Button
var field_action_panel: PanelContainer
var field_action_title: Label
var field_action_description: Label
var field_action_status: Label
var field_action_view: DotActionView
var field_action_button: Button
var nursery_panel: PanelContainer
var nursery_summary: Label
var nursery_view: NurseryView
var nursery_primary_button: Button
var nursery_claim_button: Button
var nursery_button: Button
var role_panel: PanelContainer
var role_summary: Label
var role_view: RoleBoardView
var role_reset_button: Button
var role_button: Button
var hero_panel: PanelContainer
var hero_summary: Label
var hero_view: HeroChoiceView
var hero_confirm_button: Button
var hero_button: Button

var _preview_hero_id: String = ""

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
	title_label = _make_label(
		"%s  %s" % [GameManager.display_name, GameManager.get_build_label()],
		22,
		Color("#ffd969")
	)
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
	utility_row.add_child(_make_utility_button("지역", _show_regions))
	region_event_button = _make_utility_button("지역 사건", _show_region_event)
	utility_row.add_child(region_event_button)
	field_action_button = _make_utility_button("현장 행동", _show_field_action)
	utility_row.add_child(field_action_button)
	nursery_button = _make_utility_button("보육실", _show_nursery)
	utility_row.add_child(nursery_button)
	role_button = _make_utility_button("역할", _show_role_board)
	utility_row.add_child(role_button)
	hero_button = _make_utility_button("영웅", _show_hero_panel)
	utility_row.add_child(hero_button)
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
	_build_region_panel()
	_build_region_event_panel()
	_build_field_action_panel()
	_build_nursery_panel()
	_build_role_panel()
	_build_hero_panel()
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


func _build_region_panel() -> void:
	region_panel = PanelContainer.new()
	region_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.055, 0.045, 0.07, 0.98), 16)
	)
	region_panel.hide()
	add_child(region_panel)
	var margin: MarginContainer = _make_margin(20)
	region_panel.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	var heading: Label = _make_label("지역 도감 · 이동", 24, Color("#ffd969"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)
	region_progress_label = _make_label("", 14, Color("#c8d9cf"))
	region_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(region_progress_label)
	region_list = VBoxContainer.new()
	region_list.add_theme_constant_override("separation", 6)
	region_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(region_list)
	content.add_child(_make_button("닫기", _hide_regions, Color("#5d486f")))


func _build_region_event_panel() -> void:
	region_event_panel = PanelContainer.new()
	region_event_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.055, 0.04, 0.065, 0.98), 16)
	)
	region_event_panel.hide()
	add_child(region_event_panel)
	var margin: MarginContainer = _make_margin(20)
	region_event_panel.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	region_event_title = _make_label("", 24, Color("#ffd969"))
	region_event_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(region_event_title)
	region_event_description = _make_label("", 17, Color("#eee7f0"))
	region_event_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	region_event_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(region_event_description)
	for choice_index: int in range(3):
		var choice_button: Button = _make_button(
			"",
			_resolve_region_event.bind(choice_index),
			Color("#4e6755")
		)
		content.add_child(choice_button)
		region_choice_buttons.append(choice_button)
	content.add_child(_make_button("나중에 결정", _hide_region_event, Color("#5d486f")))


func _build_field_action_panel() -> void:
	field_action_panel = PanelContainer.new()
	field_action_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.035, 0.03, 0.055, 0.99), 16)
	)
	field_action_panel.hide()
	add_child(field_action_panel)
	var margin: MarginContainer = _make_margin(18)
	field_action_panel.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	field_action_title = _make_label("", 24, Color("#ffd969"))
	field_action_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(field_action_title)
	field_action_description = _make_label("", 15, Color("#e6e1ed"))
	field_action_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	field_action_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(field_action_description)
	field_action_view = DotActionView.new()
	field_action_view.custom_minimum_size = Vector2(0.0, 280.0)
	field_action_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_action_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field_action_view.status_changed.connect(_on_field_action_status_changed)
	field_action_view.action_completed.connect(_resolve_field_action)
	content.add_child(field_action_view)
	field_action_status = _make_label("", 14, Color("#bcd8d4"))
	field_action_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	field_action_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(field_action_status)
	content.add_child(_make_button("현장에서 나가기", _hide_field_action, Color("#5d486f")))


func _build_nursery_panel() -> void:
	nursery_panel = PanelContainer.new()
	nursery_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.065, 0.04, 0.06, 0.99), 16)
	)
	nursery_panel.hide()
	add_child(nursery_panel)
	var margin: MarginContainer = _make_margin(18)
	nursery_panel.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	var heading: Label = _make_label("새끼쥐 보육실", 24, Color("#ffd969"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)
	nursery_summary = _make_label("", 14, Color("#f0e4e9"))
	nursery_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nursery_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(nursery_summary)
	nursery_view = NurseryView.new()
	nursery_view.custom_minimum_size = Vector2(0.0, 250.0)
	nursery_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nursery_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nursery_view.pup_pressed.connect(_on_nursery_pup_pressed)
	content.add_child(nursery_view)
	nursery_primary_button = _make_button("", _on_nursery_primary_pressed, Color("#73525f"))
	content.add_child(nursery_primary_button)
	nursery_claim_button = _make_button("성체 합류", _on_nursery_claim_pressed, Color("#4e765f"))
	content.add_child(nursery_claim_button)
	content.add_child(_make_button("보육실 나가기", _hide_nursery, Color("#5d486f")))


func _build_role_panel() -> void:
	role_panel = PanelContainer.new()
	role_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.035, 0.045, 0.07, 0.99), 16)
	)
	role_panel.hide()
	add_child(role_panel)
	var margin: MarginContainer = _make_margin(18)
	role_panel.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)
	var heading: Label = _make_label("군락 역할 보드", 24, Color("#ffd969"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)
	role_summary = _make_label("", 14, Color("#e8edf7"))
	role_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(role_summary)
	role_view = RoleBoardView.new()
	role_view.custom_minimum_size = Vector2(0.0, 230.0)
	role_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	role_view.role_pressed.connect(_on_role_pressed)
	content.add_child(role_view)
	role_reset_button = _make_button(
		"전체 채집 복귀",
		_on_role_reset_pressed,
		Color("#4d6478")
	)
	content.add_child(role_reset_button)
	content.add_child(_make_button("역할 보드 닫기", _hide_role_board, Color("#5d486f")))


func _build_hero_panel() -> void:
	hero_panel = PanelContainer.new()
	hero_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.045, 0.03, 0.065, 0.99), 16)
	)
	hero_panel.hide()
	add_child(hero_panel)
	var margin: MarginContainer = _make_margin(18)
	hero_panel.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	var heading: Label = _make_label("군락의 첫 영웅", 24, Color("#ffd969"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)
	hero_summary = _make_label("", 14, Color("#eee7f3"))
	hero_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hero_summary)
	hero_view = HeroChoiceView.new()
	hero_view.custom_minimum_size = Vector2(0.0, 290.0)
	hero_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero_view.candidate_pressed.connect(_on_hero_candidate_pressed)
	content.add_child(hero_view)
	hero_confirm_button = _make_button(
		"후보 점을 먼저 선택하세요",
		_on_hero_confirm_pressed,
		Color("#705274")
	)
	content.add_child(hero_confirm_button)
	content.add_child(_make_button("영웅 기록 닫기", _hide_hero_panel, Color("#5d486f")))


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
	EventBus.stage_discovered.connect(_on_stage_discovered)
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
	mouse_label.text = "쥐 %d · 채집 %d · 탐험 %d · 건설 %d" % [
		GameManager.mouse_count,
		GameManager.get_role_count("gatherer"),
		GameManager.get_role_count("explorer"),
		GameManager.get_role_count("builder")
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
	var event_cooldown: int = GameManager.get_region_event_cooldown()
	region_event_button.text = (
		"지역 사건 %d초" % event_cooldown
		if event_cooldown > 0
		else "지역 사건"
	)
	region_event_button.disabled = event_cooldown > 0
	var field_action: Dictionary = GameManager.get_current_field_action()
	var field_cooldown: int = GameManager.get_field_action_cooldown()
	if field_action.is_empty():
		field_action_button.text = "현장 행동 없음"
		field_action_button.disabled = true
	elif field_cooldown > 0:
		field_action_button.text = "현장 행동 %d초" % field_cooldown
		field_action_button.disabled = true
	else:
		field_action_button.text = (
			"현장 행동 · 재도전"
			if GameManager.is_current_field_action_completed()
			else "현장 행동 · 새 발견"
		)
		field_action_button.disabled = false
	nursery_button.text = (
		"보육실 %d/%d" % [
			GameManager.nursery_pups.size(),
			GameManager.get_nursery_capacity()
		]
		if GameManager.nursery_level > 0
		else "보육실 · Lv.%d" % GameManager.NURSERY_UNLOCK_HOLE_LEVEL
	)
	if nursery_panel.visible:
		_refresh_nursery_panel()
	role_button.text = (
		"역할 · %d마리" % GameManager.mouse_count
		if GameManager.is_role_board_unlocked()
		else "역할 · 쥐 %d" % GameManager.ROLE_BOARD_UNLOCK_MOUSE_COUNT
	)
	if role_panel.visible:
		_refresh_role_panel()
	var selected_hero: Dictionary = GameManager.get_selected_hero()
	hero_button.text = (
		"영웅 · %s" % _dictionary_string(selected_hero, "name", "")
		if not selected_hero.is_empty()
		else (
			"영웅 · 선택 가능"
			if GameManager.is_hero_selection_unlocked()
			else "영웅 · 쥐 %d" % GameManager.HERO_UNLOCK_MOUSE_COUNT
		)
	)
	if hero_panel.visible:
		_refresh_hero_panel()

	var reward: Dictionary = GameManager.get_next_reward_summary()
	var reward_current: float = _dictionary_float(reward, "current", 0.0)
	var reward_target: float = _dictionary_float(reward, "target", 1.0)
	next_stage_label.text = _dictionary_string(reward, "status", "")
	next_reward_title.text = _dictionary_string(reward, "title", "다음 보상")
	next_reward_detail.text = "%s / %s · %s" % [
		_format_number(reward_current),
		_format_number(reward_target),
		_dictionary_string(reward, "detail", "")
	]
	next_reward_progress.value = _dictionary_float(reward, "progress", 0.0)
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
	_place_modal(region_panel, Vector2(540.0, 500.0))
	_place_modal(region_event_panel, Vector2(560.0, 390.0))
	_place_modal(field_action_panel, Vector2(620.0, 620.0))
	_place_modal(nursery_panel, Vector2(600.0, 620.0))
	_place_modal(role_panel, Vector2(600.0, 540.0))
	_place_modal(hero_panel, Vector2(600.0, 620.0))
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
	button.custom_minimum_size = Vector2(78.0, 28.0)
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
		+ "발견한 지역 사건: %d개\n"
		+ "완료한 현장 행동: %d개\n"
		+ "보육실 출신 성체: %d마리\n"
		+ "역할 배치: 채집 %d · 탐험 %d · 건설 %d\n"
		+ "첫 영웅: %s\n"
		+ "현재 생산 보너스: %.2f배"
	) % [
		_format_number(GameManager.total_cheese),
		GameManager.total_trips,
		TimeManager.format_duration(int(GameManager.play_time_seconds)),
		GameManager.total_click_boosts,
		GameManager.total_golden_events,
		GameManager.completed_region_event_ids.size(),
		GameManager.completed_field_action_ids.size(),
		GameManager.total_raised_pups,
		GameManager.get_role_count("gatherer"),
		GameManager.get_role_count("explorer"),
		GameManager.get_role_count("builder"),
		_dictionary_string(GameManager.get_selected_hero(), "name", "미선택"),
		GameManager.get_stage_bonus()
	]
	stats_panel.show()
	stats_panel.move_to_front()


func _hide_stats() -> void:
	stats_panel.hide()


func _show_regions() -> void:
	for child: Node in region_list.get_children():
		child.queue_free()
	var progress: Dictionary = GameManager.get_region_codex_progress()
	region_progress_label.text = "발견 %d / %d · 해금된 지역만 표시" % [
		_dictionary_int(progress, "discovered", 0),
		_dictionary_int(progress, "total", 0)
	]
	var entries: Array[Dictionary] = GameManager.get_region_codex_entries()
	for entry: Dictionary in entries:
		var index: int = _dictionary_int(entry, "stage_index", 0)
		var discovered: bool = _dictionary_bool(entry, "discovered", false)
		var current: bool = _dictionary_bool(entry, "current", false)
		var event_text: String = (
			"사건: %s · 발견" % _dictionary_string(entry, "event_title", "")
			if discovered
			else "사건: 미발견"
		)
		var action_title: String = _dictionary_string(entry, "action_title", "")
		var action_text: String = ""
		if not action_title.is_empty():
			action_text = " · 행동 Lv.%d / 위험 %d%s" % [
				_dictionary_int(entry, "action_level", 0),
				_dictionary_int(entry, "risk_level", 2),
				" / 길 개방" if _dictionary_bool(entry, "route_unlocked", false) else ""
			]
		var button: Button = _make_button(
			"%s%s · 자원 %s / 위험 %s\n%s%s" % [
				"[현재] " if current else "",
				_dictionary_string(entry, "name", "지역"),
				_dictionary_string(entry, "resource", "미확인"),
				_dictionary_string(entry, "hazard", "미확인"),
				event_text,
				action_text
			],
			_select_region.bind(index),
			Color("#49695f") if not current else Color("#6d5341")
		)
		button.custom_minimum_size.y = 52.0
		button.disabled = current
		region_list.add_child(button)
	region_panel.show()
	region_panel.move_to_front()


func _hide_regions() -> void:
	region_panel.hide()


func _select_region(stage_index: int) -> void:
	if GameManager.select_stage(stage_index):
		region_panel.hide()


func _show_region_event() -> void:
	var cooldown: int = GameManager.get_region_event_cooldown()
	if cooldown > 0:
		_show_toast("다음 지역 사건까지 %d초" % cooldown)
		return
	var region_event: Dictionary = GameManager.get_current_region_event()
	if region_event.is_empty():
		_show_toast("이 지역에는 아직 사건이 없습니다.")
		return
	region_event_title.text = _dictionary_string(region_event, "title", "지역 사건")
	region_event_description.text = _dictionary_string(
		region_event,
		"description",
		"원정대의 대응을 선택하세요."
	)
	var choices_value: Variant = region_event.get("choices", [])
	if not choices_value is Array:
		return
	@warning_ignore("unsafe_cast")
	var choices: Array = choices_value as Array
	if choices.size() < 2 or choices.size() > region_choice_buttons.size():
		return
	for button: Button in region_choice_buttons:
		button.hide()
	for index: int in range(choices.size()):
		var choice_value: Variant = choices[index]
		if choice_value is Dictionary:
			@warning_ignore("unsafe_cast")
			var choice: Dictionary = choice_value as Dictionary
			var locked: bool = _dictionary_bool(choice, "locked", false)
			region_choice_buttons[index].text = "%s%s" % [
				_dictionary_string(
					choice,
					"label",
					"선택"
				),
				"\n🔒 %s" % _dictionary_string(
					choice,
					"lock_reason",
					"조건 부족"
				) if locked else ""
			]
			region_choice_buttons[index].disabled = locked
			region_choice_buttons[index].show()
	region_event_panel.show()
	region_event_panel.move_to_front()


func _hide_region_event() -> void:
	region_event_panel.hide()


func _resolve_region_event(choice_index: int) -> void:
	var result: Dictionary = GameManager.resolve_region_event(choice_index)
	if result.is_empty():
		_show_toast("지금은 사건을 해결할 수 없습니다.")
		return
	region_event_panel.hide()
	var first_discovery: bool = _dictionary_bool(result, "first_discovery", false)
	var first_prefix: String = "첫 발견! " if first_discovery else ""
	_show_toast(
		"%s%s · 치즈 +%s" % [
			first_prefix,
			_dictionary_string(result, "result", "원정 완료"),
			_format_number(_dictionary_float(result, "reward", 0.0))
		]
	)


func _show_field_action() -> void:
	var cooldown: int = GameManager.get_field_action_cooldown()
	if cooldown > 0:
		_show_toast("다음 현장 행동까지 %d초" % cooldown)
		return
	var action: Dictionary = GameManager.get_current_field_action()
	if action.is_empty():
		_show_toast("이 지역의 현장 행동은 다음 버전에서 열립니다.")
		return
	field_action_title.text = _dictionary_string(action, "title", "현장 행동")
	field_action_description.text = _dictionary_string(
		action,
		"description",
		"점의 움직임을 따라 상황을 해결하세요."
	)
	field_action_view.setup(action)
	field_action_status.text = field_action_view.get_status_text()
	field_action_panel.show()
	field_action_panel.move_to_front()


func _hide_field_action() -> void:
	field_action_panel.hide()


func _show_nursery() -> void:
	_refresh_nursery_panel()
	nursery_panel.show()
	nursery_panel.move_to_front()


func _hide_nursery() -> void:
	nursery_panel.hide()


func _refresh_nursery_panel() -> void:
	var snapshots: Array[Dictionary] = GameManager.get_nursery_pup_snapshots()
	nursery_view.set_pups(snapshots)
	if GameManager.nursery_level <= 0:
		nursery_summary.text = (
			"쥐구멍 Lv.%d에서 해금 · 건설 비용 치즈 %s\n"
			+ "건설 후 작은 점을 눌러 직접 돌봅니다."
		) % [
			GameManager.NURSERY_UNLOCK_HOLE_LEVEL,
			_format_number(float(GameManager.get_nursery_build_cost()))
		]
		nursery_primary_button.text = "보육실 건설 · 치즈 %s" % _format_number(
			float(GameManager.get_nursery_build_cost())
		)
		nursery_primary_button.disabled = (
			not GameManager.is_nursery_unlocked()
			or GameManager.cheese < float(GameManager.get_nursery_build_cost())
		)
		nursery_claim_button.disabled = true
		return

	var lines: PackedStringArray = []
	for snapshot: Dictionary in snapshots:
		var pup_id: int = _dictionary_int(snapshot, "id", 0)
		var ready: bool = _dictionary_bool(snapshot, "ready", false)
		var care_count: int = _dictionary_int(snapshot, "care_count", 0)
		lines.append(
			"새끼 점 %d · %s · 돌봄 %d/%d" % [
				pup_id,
				"성장 완료" if ready else TimeManager.format_duration(
					_dictionary_int(snapshot, "remaining_seconds", 0)
				),
				care_count,
				GameManager.NURSERY_MAX_CARE
			]
		)
	if lines.is_empty():
		lines.append("빈 보호 원이 새끼 점을 기다립니다.")
	nursery_summary.text = (
		"슬롯 %d/%d · 점을 누르면 성장 %d초 단축\n%s"
	) % [
		snapshots.size(),
		GameManager.get_nursery_capacity(),
		GameManager.get_nursery_care_reduction_seconds(),
		"\n".join(lines)
	]
	nursery_primary_button.text = "새끼 보육 시작 · 치즈 %s" % _format_number(
		float(GameManager.get_nursery_pup_cost())
	)
	nursery_primary_button.disabled = (
		snapshots.size() >= GameManager.get_nursery_capacity()
		or GameManager.cheese < float(GameManager.get_nursery_pup_cost())
	)
	nursery_claim_button.disabled = _first_ready_pup_id(snapshots) <= 0


func _on_nursery_primary_pressed() -> void:
	if GameManager.nursery_level <= 0:
		GameManager.build_nursery()
	else:
		GameManager.start_nursery_pup()
	_refresh_nursery_panel()


func _on_nursery_pup_pressed(pup_id: int) -> void:
	GameManager.care_for_pup(pup_id)
	_refresh_nursery_panel()


func _on_nursery_claim_pressed() -> void:
	var pup_id: int = _first_ready_pup_id(GameManager.get_nursery_pup_snapshots())
	if pup_id > 0:
		GameManager.claim_grown_pup(pup_id)
	_refresh_nursery_panel()


func _first_ready_pup_id(snapshots: Array[Dictionary]) -> int:
	for snapshot: Dictionary in snapshots:
		if _dictionary_bool(snapshot, "ready", false):
			return _dictionary_int(snapshot, "id", 0)
	return 0


func _show_role_board() -> void:
	_refresh_role_panel()
	role_panel.show()
	role_panel.move_to_front()


func _hide_role_board() -> void:
	role_panel.hide()


func _refresh_role_panel() -> void:
	role_view.set_assignments(GameManager.role_assignments)
	var unlocked: bool = GameManager.is_role_board_unlocked()
	if not unlocked:
		role_summary.text = (
			"쥐 %d마리부터 역할 변경 가능 · 현재 %d마리\n"
			+ "보육실에서 성체를 합류시키거나 동료를 늘려 주세요."
		) % [
			GameManager.ROLE_BOARD_UNLOCK_MOUSE_COUNT,
			GameManager.mouse_count
		]
	else:
		role_summary.text = (
			"채집 %d · 실제 생산 담당\n"
			+ "탐험 %d · 지역 보상 +%d%%\n"
			+ "건설 %d · 다음 새끼 성장 %d초\n"
			+ "왼쪽 채집 · 가운데 탐험 · 오른쪽 건설\n"
			+ "전문 역할점을 누르면 이동 · 채집점을 누르면 복귀"
		) % [
			GameManager.get_role_count("gatherer"),
			GameManager.get_role_count("explorer"),
			roundi((GameManager.get_explorer_reward_multiplier() - 1.0) * 100.0),
			GameManager.get_role_count("builder"),
			GameManager.get_nursery_growth_seconds()
		]
	role_view.mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if unlocked
		else Control.MOUSE_FILTER_IGNORE
	)
	role_reset_button.disabled = (
		not unlocked
		or (
			GameManager.get_role_count("explorer") <= 0
			and GameManager.get_role_count("builder") <= 0
		)
	)


func _on_role_pressed(role_id: String) -> void:
	GameManager.assign_mouse_role(role_id)
	_refresh_role_panel()


func _on_role_reset_pressed() -> void:
	GameManager.reset_mouse_roles()
	_refresh_role_panel()


func _show_hero_panel() -> void:
	_preview_hero_id = GameManager.selected_hero_id
	_refresh_hero_panel()
	hero_panel.show()
	hero_panel.move_to_front()


func _hide_hero_panel() -> void:
	hero_panel.hide()


func _refresh_hero_panel() -> void:
	var candidates: Array[Dictionary] = GameManager.get_hero_candidates()
	var selected: Dictionary = GameManager.get_selected_hero()
	hero_view.setup(candidates, _preview_hero_id)
	if not selected.is_empty():
		hero_summary.text = "%s · %s\n%s\n효과: %s" % [
			_dictionary_string(selected, "name", "첫 영웅"),
			_dictionary_string(selected, "title", ""),
			_dictionary_string(selected, "story", ""),
			_dictionary_string(selected, "effect", "")
		]
		hero_confirm_button.text = "첫 영웅 선택 완료"
		hero_confirm_button.disabled = true
		hero_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	if not GameManager.is_hero_selection_unlocked():
		hero_summary.text = (
			"쥐 %d마리에서 첫 영웅 선택 · 현재 %d마리\n"
			+ "후보는 군락의 기존 쥐이며 선택해도 전체 인구는 변하지 않습니다."
		) % [
			GameManager.HERO_UNLOCK_MOUSE_COUNT,
			GameManager.mouse_count
		]
		hero_confirm_button.text = "아직 영웅 선택 잠김"
		hero_confirm_button.disabled = true
		hero_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	hero_view.mouse_filter = Control.MOUSE_FILTER_STOP
	var preview: Dictionary = _find_hero_candidate(candidates, _preview_hero_id)
	if preview.is_empty():
		hero_summary.text = (
			"세 후보 점 중 하나를 눌러 이름, 이야기와 영구 효과를 확인하세요.\n"
			+ "확정한 첫 영웅은 V0.4.2에서 교체할 수 없습니다."
		)
		hero_confirm_button.text = "후보 점을 먼저 선택하세요"
		hero_confirm_button.disabled = true
		return
	hero_summary.text = "%s · %s\n%s\n효과: %s" % [
		_dictionary_string(preview, "name", "후보"),
		_dictionary_string(preview, "title", ""),
		_dictionary_string(preview, "story", ""),
		_dictionary_string(preview, "effect", "")
	]
	hero_confirm_button.text = "%s을(를) 첫 영웅으로 선택" % _dictionary_string(
		preview,
		"name",
		"이 후보"
	)
	hero_confirm_button.disabled = false


func _on_hero_candidate_pressed(hero_id: String) -> void:
	if not GameManager.selected_hero_id.is_empty():
		return
	_preview_hero_id = hero_id
	_refresh_hero_panel()


func _on_hero_confirm_pressed() -> void:
	if _preview_hero_id.is_empty():
		return
	GameManager.recruit_hero(_preview_hero_id)
	_refresh_hero_panel()


func _find_hero_candidate(candidates: Array[Dictionary], hero_id: String) -> Dictionary:
	for candidate: Dictionary in candidates:
		if _dictionary_string(candidate, "id", "") == hero_id:
			return candidate
	return {}


func _on_field_action_status_changed(status_text: String) -> void:
	field_action_status.text = status_text


func _resolve_field_action(action_id: String, mistakes: int) -> void:
	var result: Dictionary = GameManager.resolve_field_action(action_id, mistakes)
	if result.is_empty():
		field_action_status.text = "완료 기록 실패 · 잠시 뒤 다시 시도하세요."
		return
	var first_completion: bool = _dictionary_bool(result, "first_completion", false)
	var region_state: Dictionary = _dictionary_dictionary(result, "region_state")
	field_action_status.text = "%s완료 · 치즈 +%s\n안전 경로 개방 · 숙련 Lv.%d · 위험 %d" % [
		"첫 발견! " if first_completion else "",
		_format_number(_dictionary_float(result, "reward", 0.0)),
		_dictionary_int(region_state, "action_level", 0),
		_dictionary_int(region_state, "risk_level", 0)
	]
	_show_toast(
		"%s 완료 · 치즈 +%s" % [
			_dictionary_string(result, "title", "현장 행동"),
			_format_number(_dictionary_float(result, "reward", 0.0))
		]
	)


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
	field_action_panel.hide()
	_refresh_all()


func _on_stage_discovered(_stage_index: int) -> void:
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
