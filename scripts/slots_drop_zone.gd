extends HBoxContainer

func _ready() -> void:
    mouse_filter = MOUSE_FILTER_STOP

func _can_drop_data(_at_position: Vector2, data) -> bool:
    if data is CardData:
        return true
    return data is Dictionary and data.has("type")

func _drop_data(_at_position: Vector2, data) -> void:
    var scene = get_tree().current_scene
    if scene and scene.has_method("_handle_slots_drop"):
        scene._handle_slots_drop(data)
