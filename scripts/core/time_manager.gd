class_name TimeManager
extends RefCounted

const MAX_OFFLINE_SECONDS: int = 4 * 60 * 60


static func current_unix_time() -> int:
	return int(Time.get_unix_time_from_system())


static func capped_offline_seconds(last_saved_unix: int) -> int:
	if last_saved_unix <= 0:
		return 0
	var elapsed_seconds: int = current_unix_time() - last_saved_unix
	return clampi(elapsed_seconds, 0, MAX_OFFLINE_SECONDS)


static func format_duration(total_seconds: int) -> String:
	var hours: int = total_seconds / 3600
	var minutes: int = (total_seconds % 3600) / 60
	var seconds: int = total_seconds % 60
	if hours > 0:
		return "%d시간 %d분" % [hours, minutes]
	if minutes > 0:
		return "%d분 %d초" % [minutes, seconds]
	return "%d초" % seconds
