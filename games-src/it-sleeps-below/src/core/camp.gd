class_name Camp
## 거점 화면이 띄우는 요약 정보 — 순수 함수.
## 갱도에 들고 갈 것(장비·기름)과 두고 온 것(유품·일지)을 내려가기 전에 한눈에 본다.

const GEAR_ORDER := ["pick", "lamp", "bag", "boots", "helmet"]
const GEAR_LABELS := {"pick": "PICK", "lamp": "LAMP", "bag": "BAG", "boots": "BOOT", "helmet": "HELM"}

static func group_digits(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" + out) if n < 0 else out

static func miner_tag(miner_no: int) -> String:
	return "MINER #%d" % miner_no

static func best_depth_tag(best_depth: int) -> String:
	return "BEST %dm" % best_depth

static func gold_tag(gold: int) -> String:
	return "%s G" % group_digits(gold)

static func journal_tag(found: Array) -> String:
	return "JOURNAL %d/%d" % [found.size(), Lore.series().size()]

static func oil_tag(bottles: int) -> String:
	return "OIL x%d" % bottles

static func gear_pips(upgrades: Dictionary) -> Array:
	## [{label, level, max}] — 상점과 같은 순서. 칸이 다 차면 그 트랙은 만렙이다.
	var out: Array = []
	for track: String in GEAR_ORDER:
		out.append({
			"label": GEAR_LABELS[track],
			"level": int(upgrades.get(track, 1)),
			"max": Economy.max_level(track),
		})
	return out

static func relic_tag(relic: Dictionary) -> String:
	## 유품이 남아 있으면 그 깊이. 없으면 빈 문자열 — 표식 자체를 띄우지 않는다.
	if not relic.has("row"):
		return ""
	return "RELIC %dm" % int(relic.row)
