class_name MineView
extends Node2D
## 보이는 타일만 그린다 + 미탐사 완전 검정 (fog). TileSet 리소스 대신 직접 드로우.

var cells: PackedInt32Array
var explored: Dictionary = {}
var camera_row := 0
var _tex := {}

const ORE_TEX := ["ore_coal", "ore_copper", "ore_iron", "ore_silver", "ore_gold", "ore_amethyst", "ore_glow"]

func _ready() -> void:
	for n in ["tile_dirt", "tile_rock", "tile_deep", "tile_flesh", "tile_crack", "tile_border", "tile_bg",
			"oil_bottle", "journal", "relic_bag", "heart"] + ORE_TEX:
		_tex[n] = load("res://assets/img/%s.png" % n)

func tile_texture(c: int, row: int) -> Texture2D:
	if c >= WorldGen.ORE_BASE:
		return _tex[ORE_TEX[c - WorldGen.ORE_BASE]]
	match c:
		WorldGen.T_DIRT: return _tex["tile_dirt"]
		WorldGen.T_ROCK: return _tex["tile_rock"]
		WorldGen.T_DEEP: return _tex["tile_deep"]
		WorldGen.T_FLESH: return _tex["tile_flesh"]
		WorldGen.T_CRACK: return _tex["tile_crack"]
		WorldGen.T_BORDER: return _tex["tile_border"]
		WorldGen.T_OIL: return _tex["oil_bottle"]
		WorldGen.T_JOURNAL: return _tex["journal"]
		WorldGen.T_RELIC: return _tex["relic_bag"]
		WorldGen.T_HEART: return _tex["heart"]
	return null

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	if cells == null or cells.is_empty():
		return
	var top: int = maxi(0, camera_row - 16)
	var bottom: int = mini(WorldGen.DEPTH - 1, camera_row + 17)
	for y in range(top, bottom + 1):
		for x in range(WorldGen.W):
			var pos := Vector2(x * Tuning.TILE_PX, y * Tuning.TILE_PX)
			var c := cells[WorldGen.idx(x, y)]
			if not explored.has(Vector2i(x, y)):
				draw_rect(Rect2(pos, Vector2(16, 16)), Color.BLACK)
				continue
			if c == WorldGen.T_EMPTY:
				draw_texture(_tex["tile_bg"], pos)
			else:
				var t := tile_texture(c, y)
				if t:
					if c == WorldGen.T_OIL or c == WorldGen.T_JOURNAL or c == WorldGen.T_RELIC:
						draw_texture(_tex["tile_bg"], pos)  # 픽업은 배경 위에
					draw_texture(t, pos)

func reveal(center: Vector2i, radius: float) -> void:
	var r := int(ceilf(radius))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if Vector2(dx, dy).length() <= radius + 0.5:
				explored[center + Vector2i(dx, dy)] = true
