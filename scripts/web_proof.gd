extends Node3D

@onready var fps_label: Label = $fpslabel

func _process(_delta: float) -> void:
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
