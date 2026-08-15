class_name Oil
## 기름 = 시간 = 안전. 소모·빛 반경 단계 — 순수 함수.

static func tank(lamp_level: int) -> float:
	return Tuning.OIL_TANK[lamp_level - 1]

static func drain(oil: float, dt: float, lamp_on: bool) -> float:
	if not lamp_on:
		return oil
	return maxf(0.0, oil - dt)

static func radius(oil: float, tank_size: float, lamp_on: bool) -> float:
	if not lamp_on or oil <= 0.0:
		return Tuning.LIGHT_OFF_RADIUS
	var ratio := oil / tank_size
	for stage in Tuning.LIGHT_STAGES:
		if ratio > stage[0]:
			return stage[1]
	return Tuning.LIGHT_OFF_RADIUS
