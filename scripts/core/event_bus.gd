extends Node

signal game_state_changed
signal mouse_count_changed(mouse_count: int)
signal stage_changed(stage_index: int)
signal golden_cheese_changed(active: bool, remaining_seconds: float)
signal click_boost_changed(active: bool, remaining_seconds: float)
signal save_status_changed(message: String)
signal toast_requested(message: String)
signal tutorial_changed(step: int)
