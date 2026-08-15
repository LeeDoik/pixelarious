class_name Lore
## 광부 일지 시리즈 — id는 text.json의 journals 키와 1:1.
## 저자: han(신중한 선배) / baek(탐욕에 먹힌 자) / seo(산을 연구한 학자)

const SERIES := [
	{"id": "han_1", "author": "han", "row": 50},
	{"id": "baek_1", "author": "baek", "row": 70},
	{"id": "han_2", "author": "han", "row": 100},
	{"id": "seo_1", "author": "seo", "row": 140},
	{"id": "baek_2", "author": "baek", "row": 170},
	{"id": "han_3", "author": "han", "row": 210},   # han의 마지막 — 미완
	{"id": "seo_2", "author": "seo", "row": 260},
	{"id": "baek_3", "author": "baek", "row": 300}, # baek의 마지막 — 미완
	{"id": "seo_3", "author": "seo", "row": 350},
	{"id": "seo_4", "author": "seo", "row": 390},   # seo의 마지막 — 심장 직전
]

static func series() -> Array:
	return SERIES

static func next_unfound(found: Array) -> Dictionary:
	for e in SERIES:
		if not found.has(e.id):
			return e
	return {}

static func collection_rate(found: Array) -> float:
	var n := 0
	for e in SERIES:
		if found.has(e.id):
			n += 1
	return float(n) / float(SERIES.size())
