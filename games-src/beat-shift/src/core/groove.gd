class_name Groove
## 그루브 게이지 증감. 순수 static.

static func apply(gauge: float, event: String) -> float:
	var delta := 0.0
	match event:
		"perfect":
			delta = Tuning.PERFECT_GAIN
		"good":
			delta = Tuning.GOOD_GAIN
		"miss":
			delta = -Tuning.MISS_LOSS
		"stray":
			delta = -Tuning.STRAY_LOSS
	return clampf(gauge + delta, 0.0, Tuning.GROOVE_MAX)

static func recover(gauge: float) -> float:
	return clampf(gauge + Tuning.SECTION_RECOVER, 0.0, Tuning.GROOVE_MAX)

static func dead(gauge: float) -> bool:
	return gauge <= 0.0
