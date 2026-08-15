extends Node2D

func _ready() -> void:
	var mine := Mine.new()
	add_child(mine)
	mine.run_ended.connect(func(reason: String, depth: int) -> void:
		print("run ended: ", reason, " @", depth, "m")
		get_tree().reload_current_scene())
