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
const CAM_FOLLOW_SPEED := 6.0   # 카메라 lerp 속도

const SWIFT_GAUGE := 0.30
const COMBO_MAX := 5
const SWIFT_BONUS := 25
const DWARF_BONUS := 50
const PX_PER_M := 10.0

# cracks = 그 별 전용 균열 오버레이. 별마다 캔버스와 원 지름이 달라서(스프라이트에 여백이 있다)
# 한 장을 늘려 쓰면 금이 별 밖으로 삐져나온다. scripts/gen_cracks.py가 종류별로 뽑아 둔다.
const STAR_TYPES := {
	"standard": {"sprite": "star_standard", "cracks": "cracks_standard", "orbit_r": 28.0, "ang_vel": 2.4, "collapse": 3.5},
	"dwarf": {"sprite": "star_dwarf", "cracks": "cracks_dwarf", "orbit_r": 16.0, "ang_vel": 3.6, "collapse": 2.0},
	"giant": {"sprite": "star_giant", "cracks": "cracks_giant", "orbit_r": 44.0, "ang_vel": 1.6, "collapse": 6.0},
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
const COLLAPSE_GRACE_SCORE := 1000  # HUD 점수 1000까지는 별이 붕괴하지 않는다 (도입부)
const ASTEROID_START_H := 3000.0    # 300m부터 소행성
const ASTEROID_P_BASE := 0.15
const ASTEROID_P_RANGE := 0.25
const ASTEROID_RAMP_H := 12000.0
const ASTEROID_KILL_DIST := 14.0
const ASTEROID_SPEED_MIN := 40.0
const ASTEROID_SPEED_MAX := 80.0
const ASTEROID_SINE_AMP := 20.0

# 스폰 배치 (spawner.gd 전용)
const SPAWN_SAFETY_MARGIN := 8.0    # 도달 예산에서 빼는 여유
const SPAWN_MAX_DX := 160.0         # 별 간 최대 수평 거리
const SPAWN_RETRY_COUNT := 20
const SPAWN_GAP_JITTER_MIN := 0.85
const SPAWN_GAP_JITTER_MAX := 1.15
const SPAWN_DRIFT_X := 120.0        # 다음 별 x 이동 범위(±)
const SPAWN_WALL_MARGIN := 8.0      # 벽에서 궤도 반경 외 추가 여유

# 월드 조립 (main.gd·asteroid.gd 전용)
const SPAWN_AHEAD := 200.0          # 카메라 상단 위로 미리 생성할 여유
const DESPAWN_BELOW := 100.0        # 카메라 하단 아래 해제 여유
const FIRST_STAR_OFFSET_Y := 100.0  # 첫 거성: 화면 하단에서 위로
const ASTEROID_Y_OFFSET := 45.0     # 동반 스폰 시 별 아래 오프셋
const ASTEROID_EDGE_MARGIN := 30.0
const ASTEROID_SPIN := 1.5
const ASTEROID_SINE_FREQ := 2.0

const DEATH_SLOWMO := 0.25
const DEATH_SLOWMO_SEC := 0.5
