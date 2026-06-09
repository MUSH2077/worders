extends Node

func _ready() -> void:
	call_deferred("_go_to_battle")

func _go_to_battle() -> void:
	get_tree().change_scene_to_file("res://scenes/battle.tscn")
