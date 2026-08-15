class_name WorldGen
## 시드 절차 생성 — 순수 함수. 씬/노드 접근 금지.

const W := 16
const DEPTH := 401

const T_EMPTY := 0
const T_DIRT := 1
const T_ROCK := 2
const T_CRACK := 3
const T_DEEP := 4
const T_FLESH := 5
const T_BORDER := 6
const T_OIL := 7
const T_JOURNAL := 8
const T_RELIC := 9
const T_HEART := 10
const ORE_BASE := 100

const STRATA_BASE_TILE := [T_DIRT, T_ROCK, T_DEEP, T_FLESH]
const STRATA_ORES := [[0, 1], [2, 3], [4, 5], [6]]  # 광석 id: 0석탄 1구리 2철 3은 4금 5자수정 6발광

static func idx(x: int, y: int) -> int:
	return y * W + x

static func strata_of(row: int) -> int:
	for i in range(Tuning.STRATA_BOUNDS.size()):
		if row < Tuning.STRATA_BOUNDS[i]:
			return i
	return 4

static func generate(seed_v: int, ctx: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var cells := PackedInt32Array()
	cells.resize(W * DEPTH)

	for y in range(DEPTH):
		for x in range(W):
			if x == 0 or x == W - 1:
				cells[idx(x, y)] = T_BORDER
				continue
			if y == 0:
				cells[idx(x, y)] = T_EMPTY
				continue
			var s := strata_of(y)
			if s == 4:
				cells[idx(x, y)] = T_FLESH
				continue
			var roll := rng.randf()
			if roll < Tuning.ORE_CHANCE[s]:
				var ores: Array = STRATA_ORES[s]
				cells[idx(x, y)] = ORE_BASE + ores[rng.randi_range(0, ores.size() - 1)]
			elif roll < Tuning.ORE_CHANCE[s] + Tuning.OIL_CHANCE[s]:
				cells[idx(x, y)] = T_OIL
			elif roll < Tuning.ORE_CHANCE[s] + Tuning.OIL_CHANCE[s] + Tuning.CRACK_CHANCE[s]:
				cells[idx(x, y)] = T_CRACK
			else:
				cells[idx(x, y)] = STRATA_BASE_TILE[s]

	_carve_chamber(cells)
	var journal_spots := _place_journals(cells, rng, ctx.get("journals_found", []))
	var relic_spot := _place_relic(cells, rng, ctx.get("relic", {}))
	return {"cells": cells, "journal_spots": journal_spots, "relic_spot": relic_spot}

static func _carve_chamber(cells: PackedInt32Array) -> void:
	for y in range(396, DEPTH):
		for x in range(5, 11):
			cells[idx(x, y)] = T_EMPTY
	cells[idx(8, 400)] = T_HEART

static func _place_journals(cells: PackedInt32Array, rng: RandomNumberGenerator, found: Array) -> Array:
	var spots: Array = []
	for entry in Lore.series():
		if found.has(entry.id):
			continue
		var y: int = clampi(entry.row + rng.randi_range(-2, 2), 1, 395)
		var x: int = rng.randi_range(1, W - 2)
		cells[idx(x, y)] = T_JOURNAL
		spots.append({"id": entry.id, "x": x, "y": y})
	return spots

static func _place_relic(cells: PackedInt32Array, rng: RandomNumberGenerator, relic: Dictionary) -> Dictionary:
	if not relic.has("row"):
		return {}
	var y: int = clampi(int(relic.row) + rng.randi_range(-Tuning.RELIC_ROW_JITTER, Tuning.RELIC_ROW_JITTER), 1, 395)
	var x: int = rng.randi_range(1, W - 2)
	cells[idx(x, y)] = T_RELIC
	return {"x": x, "y": y}
