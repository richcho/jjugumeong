class_name VisualProgression
extends RefCounted


static func speed_tier(level: int) -> int:
	return _tier_from_level(maxi(0, level), [1, 3, 6])


static func carry_tier(level: int) -> int:
	return _tier_from_level(maxi(0, level), [1, 3, 6])


static func hole_tier(level: int) -> int:
	return _tier_from_level(maxi(1, level), [2, 3, 4, 5])


static func speed_name(level: int) -> String:
	var names: Array[String] = ["기본 보행", "목도리", "운동화", "숙련 질주"]
	return names[speed_tier(level)]


static func carry_name(level: int) -> String:
	var names: Array[String] = ["앞발 운반", "천 주머니", "배낭", "전문 운송"]
	return names[carry_tier(level)]


static func hole_name(level: int) -> String:
	var names: Array[String] = ["작은 틈", "보강 굴", "저장 굴", "마을 입구", "문명 관문"]
	return names[hole_tier(level)]


static func equipment_summary(speed_level: int, carry_level: int) -> String:
	return "%s · %s" % [speed_name(speed_level), carry_name(carry_level)]


static func _tier_from_level(level: int, thresholds: Array[int]) -> int:
	var tier: int = 0
	for threshold: int in thresholds:
		if level < threshold:
			break
		tier += 1
	return tier
