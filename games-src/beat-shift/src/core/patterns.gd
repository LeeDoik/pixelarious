class_name Patterns
## 대장간 패턴 데이터. 패턴 = 8박(2마디) 프레이즈 내 비트 오프셋 배열.
## 데이터 규칙: 0.0으로 시작, 오프셋 [0, 6.5], 최소 간격 0.5박 —
## 마지막 노트(≤6.5)와 다음 프레이즈 첫 노트(8.0) 사이도 1.5박 이상 벌어진다.

const TIERS := [
	[  # tier 0 — 정박 4분음
		[0.0, 2.0, 4.0, 6.0],
		[0.0, 2.0, 4.0],
		[0.0, 4.0, 6.0],
		[0.0, 2.0, 6.0],
	],
	[  # tier 1 — 정박 조밀
		[0.0, 1.0, 2.0, 4.0, 6.0],
		[0.0, 2.0, 3.0, 4.0, 6.0],
		[0.0, 2.0, 4.0, 5.0, 6.0],
		[0.0, 1.0, 4.0, 5.0],
	],
	[  # tier 2 — 엇박 등장
		[0.0, 1.5, 2.0, 4.0, 6.0],
		[0.0, 2.0, 2.5, 4.0, 6.0],
		[0.0, 0.5, 2.0, 4.0, 4.5, 6.0],
		[0.0, 2.0, 3.5, 4.0, 6.0],
	],
	[  # tier 3 — 조밀 + 엇박
		[0.0, 1.0, 1.5, 2.0, 4.0, 5.5, 6.0],
		[0.0, 0.5, 1.0, 2.5, 4.0, 4.5, 6.0],
		[0.0, 1.5, 2.5, 4.0, 5.0, 5.5, 6.5],
		[0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
	],
]

const PHRASE_BEATS := 8.0
const PHRASES_PER_SECTION := 4

static func tier_for_section(section: int) -> int:
	return mini(section, TIERS.size() - 1)

static func section_notes(tier: int, rng: RandomNumberGenerator) -> Array:
	var pool: Array = TIERS[mini(tier, TIERS.size() - 1)]
	var notes: Array = []
	for phrase in range(PHRASES_PER_SECTION):
		var pattern: Array = pool[rng.randi_range(0, pool.size() - 1)]
		for b in pattern:
			notes.append(float(b) + PHRASE_BEATS * float(phrase))
	return notes
