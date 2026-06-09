extends Node2D

func _ready() -> void:
	call_deferred("_redirect_to_supported_battle")

func _redirect_to_supported_battle() -> void:
	get_tree().change_scene_to_file("res://scenes/battle.tscn")
