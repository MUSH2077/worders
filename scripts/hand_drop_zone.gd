extends HBoxContainer

func _ready() -> void:
    mouse_filter = MOUSE_FILTER_STOP

func _can_drop_data(_at_position: Vector2, data) -> bool:
    return data is Dictionary and data.get("type", "") == "sentence_slot"

func _drop_data(_at_position: Vector2, data) -> void:
    var scene = get_tree().current_scene
    if scene and scene.has_method("_handle_hand_drop"):
        scene._handle_hand_drop(data)
