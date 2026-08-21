class_name Tuning
## 전 게임플레이 수치의 단일 정본. 스펙 §3~§5 시작값. 튜닝은 여기서만.

const VIEW_W := 270.0
const VIEW_H := 480.0

# 리듬 구조 — 섹션 = 인트로 1마디 + 패턴 8마디 + 징글 1마디
const BPM_STEPS := [96.0, 112.0, 128.0, 144.0, 160.0]
const BEATS_PER_BAR := 4
const INTRO_BEATS := 4.0
const NOTE_BEATS := 32.0
const SECTION_BEATS := 40.0
const CUE_LEAD_BEATS := 2.0     # 예비 동작·예비음이 정박보다 앞서는 박

# 판정 (초 — BPM 무관)
const PERFECT_WIN := 0.070
const GOOD_WIN := 0.140
const INPUT_OFFSET := 0.0       # 전역 입력 보정(웹 레이턴시) — 플레이테스트로 튜닝

# 그루브 게이지
const GROOVE_START := 60.0
const GROOVE_MAX := 100.0
const PERFECT_GAIN := 4.0
const GOOD_GAIN := 2.0
const MISS_LOSS := 15.0
const STRAY_LOSS := 5.0         # 노트 없는 헛스윙
const SECTION_RECOVER := 10.0

# 스코어
const SCORE_PERFECT := 100
const SCORE_GOOD := 50
const COMBO_MAX := 5
const SECTION_BONUS := 500

# 연출
const DEATH_SLOWMO := 0.25
const DEATH_SLOWMO_SEC := 0.5
