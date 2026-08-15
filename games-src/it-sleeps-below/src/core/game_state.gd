extends Node
## 오토로드 — 프로필(영속) + 런 상태(휘발). 씬들은 이 노드만 본다.

const SAVE_PATH := "user://isb_save.json"

var profile: Dictionary = Persistence.default_profile()
var run: Dictionary = {}

func _ready() -> void:
	load_save()

func load_save() -> void:
	profile = Persistence.load_profile(SAVE_PATH)

func save() -> void:
	Persistence.save_profile(SAVE_PATH, profile)

func corruption() -> int:
	return WorldGen.strata_of(profile.best_depth)

func start_run() -> Dictionary:
	run = {
		"seed": randi(),
		"bag": [], "hearts": Economy.max_hearts(profile.upgrades.helmet),
		"oil": Oil.tank(profile.upgrades.lamp), "lamp_on": true,
		"depth": 0, "bottles": profile.oil_bottles,
	}
	return {"journals_found": profile.journals_found, "relic": profile.relic}

func end_run_death(depth_m: int) -> void:
	profile.relic = {"row": depth_m, "items": run.bag.duplicate()}  # 이전 유품은 덮어써 소멸
	profile.oil_bottles = 0
	profile.miner_no += 1
	profile.best_depth = maxi(profile.best_depth, int(run.get("depth", depth_m)))
	save()

func end_run_settle() -> int:
	var earned := Economy.settle(run.bag)
	profile.gold += earned
	profile.oil_bottles = run.bottles
	profile.best_depth = maxi(profile.best_depth, run.depth)
	run.bag = []
	save()
	return earned
