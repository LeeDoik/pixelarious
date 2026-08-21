class_name Scoring
## 판정 → 점수·콤보 배수. 성공은 현재 배수로 지불하고 배수를 올린다.

static func hit(result: String, mult: int) -> Dictionary:
	match result:
		"perfect":
			return {"points": Tuning.SCORE_PERFECT * mult, "mult": mini(mult + 1, Tuning.COMBO_MAX)}
		"good":
			return {"points": Tuning.SCORE_GOOD * mult, "mult": mini(mult + 1, Tuning.COMBO_MAX)}
	return {"points": 0, "mult": 1}

static func section_bonus(section_index: int) -> int:
	return Tuning.SECTION_BONUS * (section_index + 1)
