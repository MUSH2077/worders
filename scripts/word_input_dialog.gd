extends AcceptDialog

signal word_submitted(slot_index, word)

var _slot_idx: int = -1

@onready var line_edit: LineEdit = $VBoxContainer/LineEdit
@onready var hint_lbl: Label = $VBoxContainer/HintLabel

func setup(idx: int, card: CardData) -> void:
    _slot_idx = idx
    hint_lbl.text = "%s | %s | %s" % [card.get_pos_name(), card.get_comp_name(), card.get_content_name()]
    line_edit.text = ""
    line_edit.grab_focus()

func _on_confirmed() -> void:
    word_submitted.emit(_slot_idx, line_edit.text)
