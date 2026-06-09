extends HBoxContainer

var card_scene := preload("res://scenes/card.tscn")

func display_hand(cards: Array[CardData]) -> void:
    for child in get_children():
        child.queue_free()
    for card_data in cards:
        var card_instance := card_scene.instantiate()
        add_child(card_instance)
        card_instance.card_data = card_data

func clear_hand() -> void:
    for child in get_children():
        child.queue_free()
