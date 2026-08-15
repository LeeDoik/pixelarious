class_name Scoring

static func hop_result(gauge_ratio: float, combo: int) -> Dictionary:
	if gauge_ratio <= Tuning.SWIFT_GAUGE:
		var new_combo := mini(combo + 1, Tuning.COMBO_MAX)
		return {"combo": new_combo, "bonus": Tuning.SWIFT_BONUS * new_combo}
	return {"combo": 1, "bonus": 0}

static func height_score(rise_px: float) -> int:
	return int(maxf(rise_px, 0.0) / Tuning.PX_PER_M)
