extends Control

var tracked_player = null

@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var hp_label: Label = $VBoxContainer/HPLabel
@onready var mana_label: Label = $VBoxContainer/ManaLabel
@onready var deck_label: Label = $VBoxContainer/DeckLabel
@onready var shield_label = $VBoxContainer/ShieldLabel if has_node("VBoxContainer/ShieldLabel") else null

func _ready() -> void:
	Events.player_hp_changed.connect(_on_hp_changed)
	Events.player_mana_changed.connect(_on_mana_changed)
	Events.card_drawn.connect(_on_card_drawn)

func set_player(player) -> void:
	tracked_player = player
	name_label.text = player.player_name
	hp_label.text = "HP " + str(player.hp) + "/" + str(player.max_hp)
	mana_label.text = "Mana " + str(player.mana) + "/" + str(player.max_mana)
	deck_label.text = "Deck " + str(player.deck.size())
	if shield_label:
		_update_shield(player.shield)

func _update_shield(val: int) -> void:
	if not shield_label:
		return
	if val > 0:
		shield_label.text = "Shield " + str(val)
		shield_label.visible = true
	else:
		shield_label.visible = false

func _on_hp_changed(target, hp: int, max_hp: int) -> void:
	if target == tracked_player:
		hp_label.text = "HP " + str(hp) + "/" + str(max_hp)
		_update_shield(target.shield)

func _on_mana_changed(target, mana: int, max_mana: int) -> void:
	if target == tracked_player:
		mana_label.text = "Mana " + str(mana) + "/" + str(max_mana)

func _on_card_drawn(target) -> void:
	if target == tracked_player:
		deck_label.text = "Deck " + str(target.deck.size())
