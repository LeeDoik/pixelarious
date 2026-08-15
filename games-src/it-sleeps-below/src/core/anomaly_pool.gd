class_name AnomalyPool
## 이상 현상·연출 조우 카탈로그 — 데이터 주도. 연출 실행은 AnomalyDirector(씬)가 담당.
## realized=true 항목은 오염(corruption) 3 이상에서만 — "학습된 안전감의 배신" (스펙 §7).

const CATALOG := [
	# ── 다이제틱 ──
	{"id": "lamp_blink", "kind": "diegetic", "min_depth": 40, "once": false, "realized": false},
	{"id": "tunnel_sealed", "kind": "diegetic", "min_depth": 120, "once": true, "realized": false},
	{"id": "echo_pick", "kind": "diegetic", "min_depth": 40, "once": true, "realized": false},
	{"id": "edge_silhouette", "kind": "diegetic", "min_depth": 120, "once": true, "realized": false},
	{"id": "ore_whisper", "kind": "diegetic", "min_depth": 120, "once": true, "realized": false},
	{"id": "merchant_gone", "kind": "diegetic", "min_depth": 240, "once": true, "realized": false},
	{"id": "side_tunnel", "kind": "diegetic", "min_depth": 120, "once": true, "realized": false},
	{"id": "rhythm_continues", "kind": "diegetic", "min_depth": 120, "once": true, "realized": false},
	{"id": "ore_resealed", "kind": "diegetic", "min_depth": 120, "once": true, "realized": false},
	{"id": "false_heartbeat", "kind": "diegetic", "min_depth": 240, "once": false, "realized": false},
	{"id": "black_sky", "kind": "diegetic", "min_depth": 240, "once": true, "realized": false},
	# ── 실체화 변형 (오염 3+) ──
	{"id": "lamp_blink_real", "kind": "diegetic", "min_depth": 240, "once": true, "realized": true},
	{"id": "tunnel_sealed_real", "kind": "diegetic", "min_depth": 240, "once": true, "realized": true},
	# ── 가벼운 메타 (캔버스 안 한정) ──
	{"id": "depth_999", "kind": "meta", "min_depth": 120, "once": true, "realized": false},
	{"id": "depth_rises", "kind": "meta", "min_depth": 240, "once": true, "realized": false},
	{"id": "gauge_zero", "kind": "meta", "min_depth": 240, "once": true, "realized": false},
	{"id": "black_ore", "kind": "meta", "min_depth": 240, "once": true, "realized": false},
	{"id": "pause_message", "kind": "meta", "min_depth": 240, "once": true, "realized": false},
	# ── 연출 조우 (러커) ──
	{"id": "back_turned", "kind": "encounter", "min_depth": 240, "once": true, "realized": false},
	{"id": "silent_mimic", "kind": "encounter", "min_depth": 240, "once": true, "realized": false},
	{"id": "parallel_steps", "kind": "encounter", "min_depth": 240, "once": true, "realized": false},
	{"id": "other_lamp", "kind": "encounter", "min_depth": 240, "once": true, "realized": false},
]

static func catalog() -> Array:
	return CATALOG

static func eligible(entry: Dictionary, flags: Array, depth_m: int, corruption: int) -> bool:
	if entry.once and flags.has(entry.id):
		return false
	if depth_m < entry.min_depth:
		return false
	if entry.realized and corruption < 3:
		return false
	return true

static func pick(flags: Array, depth_m: int, corruption: int, rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array = []
	for e in CATALOG:
		if eligible(e, flags, depth_m, corruption):
			pool.append(e)
	if pool.is_empty():
		return {}
	return pool[rng.randi_range(0, pool.size() - 1)]
