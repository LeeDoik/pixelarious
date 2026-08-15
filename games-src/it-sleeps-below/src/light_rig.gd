class_name LightRig
extends Node2D
## 화면 암전 + 플레이어 라디얼 라이트. 반경 변화는 러프하게 따라간다.

var light := PointLight2D.new()
var modulate_node := CanvasModulate.new()
var _target_scale := 1.0
var _flicker := 0.0

func _ready() -> void:
	modulate_node.color = Color(0.08, 0.07, 0.12)
	add_child(modulate_node)
	light.texture = _radial_texture(128)
	light.energy = 1.3
	add_child(light)

func _radial_texture(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size / 2.0
	for y in range(size):
		for x in range(size):
			var d := Vector2(x - c, y - c).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 0.95, 0.85, pow(a, 1.5)))
	return ImageTexture.create_from_image(img)

func set_radius_tiles(r: float) -> void:
	_target_scale = r * Tuning.TILE_PX * 2.0 / 128.0

func follow(pos: Vector2) -> void:
	light.position = pos

func _process(delta: float) -> void:
	_flicker += delta * 7.0
	var flick := 1.0 + sin(_flicker) * 0.03
	light.scale = light.scale.lerp(Vector2.ONE * _target_scale * flick, minf(1.0, delta * 8.0))

func blackout(sec: float) -> void:
	var prev := light.energy
	light.energy = 0.05
	await get_tree().create_timer(sec).timeout
	light.energy = prev
