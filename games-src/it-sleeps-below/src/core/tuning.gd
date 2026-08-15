class_name Tuning
## 모든 게임플레이 시작값. 스펙 §2~§10. 플레이테스트에서 이 파일만 만진다.

# ── 월드 ──
const TILE_PX := 16
const STRATA_BOUNDS := [40, 120, 240, 400]  # 표토<40 ≤암반<120 ≤균열대<240 ≤심층<400, 400=최심부
const RELIC_ROW_JITTER := 3
const JOURNAL_ROW_JITTER := 2
const PLACE_ROW_MAX := 395   # 일지·유품 배치 하한 (챔버 위)
const CHAMBER_TOP := 396     # 최심부 챔버 시작 행
const CHAMBER_X_MIN := 5
const CHAMBER_X_MAX := 10    # inclusive
const HEART_X := 8

# ── 이동/채굴 (초 단위, 타일당) ──
const WALK_TIME := 0.15
const CLIMB_TIME := 0.35
const FALL_TIME := 0.07
const DIG_TIME_BASE := [0.35, 0.55, 0.8, 1.1]  # 지층별 (곡괭이 보정 전)
const PICK_SPEED_MULT := [1.0, 0.85, 0.7, 0.55]  # 곡괭이 Lv1..4
const QUIET_GAP := 0.6      # 이 간격 이상 끊어 파면 조용한 채굴
const NOISE_LOUD := 1.0
const NOISE_QUIET := 0.35
const FALL_SAFE_BASE := 3   # 장화 Lv1

# ── 램프/기름 ──
const OIL_TANK := [60.0, 80.0, 100.0, 120.0]      # 램프 Lv1..4 (초)
const OIL_PICKUP_RATIO := 0.25
const LIGHT_STAGES := [[0.6, 4.5], [0.3, 3.5], [0.1, 2.5], [0.0, 1.5]]  # [잔량비 초과, 반경(타일)]
const LIGHT_OFF_RADIUS := 0.75   # 램프 오프/기름 소진 잔광

# ── 러커/디렉터 ──
const LURKER_SPEED := 2.2         # 타일/초 (어둠에서)
const LURKER_MIN_DEPTH := 240     # 실체 스폰 시작 (심층)
const DIRECTOR_BASE := {"hunt": 18.0, "retreat": 8.0, "silence": 30.0}
const DIRECTOR_SILENCE_MIN := 10.0
const DIRECTOR_DEPTH_SCALE := 0.05  # 100m당 침묵 -5초
const NOISE_ALERT_THRESHOLD := 0.5  # 이 소음 레벨 이상이면 러커가 목표를 갱신
const LIGHT_SENSE_INTERVAL := 1.2   # 램프가 켜져 있으면 이 간격마다 러커가 최후 목격 위치를 갱신

# ── 이코노미 ──
const ORE_VALUES := [5, 10, 25, 50, 100, 150, 300]
const BAG_SLOTS := [8, 12, 16, 20]
const MAX_HEARTS := [3, 4, 5]
const FALL_TOLERANCE := [3, 4, 5]
const OIL_BOTTLE_PRICE := 60
const OIL_BOTTLE_CARRY_MAX := 2
const UPGRADE_COSTS := {
	"pick": [150, 400, 900],
	"lamp": [120, 300, 700],
	"bag": [100, 250, 600],
	"boots": [150, 400],
	"helmet": [200, 500],
}

# ── 생성 밀도 (타일당 확률) ──
const ORE_CHANCE := [0.06, 0.07, 0.075, 0.08]     # 지층별
const OIL_CHANCE := [0.004, 0.005, 0.006, 0.007]
const CRACK_CHANCE := [0.0, 0.02, 0.035, 0.05]

# ── 피날레 ──
const FINALE_BLOCKS := 6
const FINALE_SHAFT_LIMIT := 12
const HEART_PULSE_SEC := 2.4
