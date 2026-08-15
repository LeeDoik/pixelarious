class_name Tuning
## 전 게임플레이 수치의 단일 정본. 스펙 §3~§6 시작값. 튜닝은 여기서만.

const VIEW_W := 270.0
const VIEW_H := 480.0
const WALL_MIN_X := 10.0
const WALL_MAX_X := 260.0
const WALL_DAMPING := 0.9

const GRAVITY := 240.0          # px/s^2 (하방)
const LAUNCH_SPEED := 260.0     # px/s (접선)
const KILL_MARGIN := 20.0       # 카메라 하단 밖 사망 여유
const CAM_LEAD := 40.0          # 플레이어를 화면 중앙보다 위에 두는 오프셋

const SWIFT_GAUGE := 0.30
const COMBO_MAX := 5
const SWIFT_BONUS := 25
const DWARF_BONUS := 50
const PX_PER_M := 10.0

const STAR_TYPES := {
	"standard": {"sprite": "star_standard", "size": 32.0, "orbit_r": 28.0, "ang_vel": 2.4, "collapse": 3.5},
	"dwarf": {"sprite": "star_dwarf", "size": 16.0, "orbit_r": 16.0, "ang_vel": 3.6, "collapse": 2.0},
	"giant": {"sprite": "star_giant", "size": 48.0, "orbit_r": 44.0, "ang_vel": 1.6, "collapse": 6.0},
}

# 난이도 커브 (h = 시작점 기준 상승 px)
const GAP_BASE := 90.0
const GAP_RANGE := 50.0
const RAMP_H := 10000.0             # 1000m에서 간격·확률 커브 최대
const DWARF_P_BASE := 0.10
const DWARF_P_RANGE := 0.35
const GIANT_P_BASE := 0.25
const GIANT_P_RANGE := -0.15
const COLLAPSE_MULT_RANGE := 0.5    # 최대 1.5배 빨리 붕괴
const COLLAPSE_RAMP_H := 12000.0
const ASTEROID_START_H := 3000.0    # 300m부터 소행성
const ASTEROID_P_BASE := 0.15
const ASTEROID_P_RANGE := 0.25
const ASTEROID_RAMP_H := 12000.0
const ASTEROID_KILL_DIST := 14.0
const ASTEROID_SPEED_MIN := 40.0
const ASTEROID_SPEED_MAX := 80.0
const ASTEROID_SINE_AMP := 20.0

const DEATH_SLOWMO := 0.25
const DEATH_SLOWMO_SEC := 0.5
