class_name Economy
## 광석 가치·업그레이드 커브·정산·지층 게이트 — 순수 함수.

static func ore_value(ore_id: int) -> int:
	return Tuning.ORE_VALUES[ore_id]

static func settle(bag: Array) -> int:
	var total := 0
	for ore_id in bag:
		total += ore_value(ore_id)
	return total

static func max_level(track: String) -> int:
	return Tuning.UPGRADE_COSTS[track].size() + 1

static func upgrade_cost(track: String, next_level: int) -> int:
	var costs: Array = Tuning.UPGRADE_COSTS[track]
	if next_level < 2 or next_level > costs.size() + 1:
		return -1
	return costs[next_level - 2]

static func bag_slots(level: int) -> int:
	return Tuning.BAG_SLOTS[level - 1]

static func walk_time(boots_level: int) -> float:
	return Tuning.WALK_TIME * Tuning.BOOTS_SPEED_MULT[boots_level - 1]

static func climb_time(boots_level: int) -> float:
	return Tuning.CLIMB_TIME * Tuning.BOOTS_SPEED_MULT[boots_level - 1]

static func glow_radius(helmet_level: int) -> float:
	# 램프를 껐거나 기름이 마른 상태의 잔광 — 헬멧 등급이 암흑 등반의 시야를 결정한다
	return Tuning.HELMET_GLOW[helmet_level - 1]

static func dig_allowed(pick_level: int, row: int) -> bool:
	var s := WorldGen.strata_of(row)
	if s >= 4:
		return true  # 최심부 챔버는 이미 뚫려 있음 (심장만 별도 처리)
	return pick_level >= s + 1

static func dig_time(pick_level: int, row: int) -> float:
	var s: int = mini(WorldGen.strata_of(row), 3)
	return Tuning.DIG_TIME_BASE[s] * Tuning.PICK_SPEED_MULT[pick_level - 1]
