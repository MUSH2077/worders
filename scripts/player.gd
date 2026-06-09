class_name Player extends RefCounted

const TacticalStanceScript = preload("res://scripts/tactical_stance.gd")

var player_name: String = ""
var hp: int = 30
var max_hp: int = 30
var shield: int = 0
var mana: int = 0
var max_mana: int = 0
var turns_taken: int = 0
var hand: Array[CardData] = []
var deck: Deck
var is_ai: bool = false
var skip_draw_next: bool = false
var current_stance: int = TacticalStanceScript.Stance.BALANCED
var archetype_seal: String = "balanced"
var current_objective = null
var objective_reward_claimed: bool = false
var completed_objective_ids: Array[String] = []
var ai_profile = null

func take_damage(amount: int) -> int:
    if amount <= 0:
        return 0
    var actual = amount
    if shield > 0:
        var absorbed = min(shield, actual)
        shield = 0
        actual -= absorbed
    hp = max(hp - actual, 0)
    Events.player_hp_changed.emit(self, hp, max_hp)
    return actual

func add_shield(amount: int) -> void:
    shield += amount
    Events.player_hp_changed.emit(self, hp, max_hp)

func heal(amount: int) -> void:
    hp = min(hp + amount, max_hp)
    Events.player_hp_changed.emit(self, hp, max_hp)

func spend_mana(amount: int) -> bool:
    if amount > mana:
        return false
    mana -= amount
    Events.player_mana_changed.emit(self, mana, max_mana)
    return true

func refresh_mana() -> void:
    mana = max_mana
    Events.player_mana_changed.emit(self, mana, max_mana)

func increase_max_mana() -> void:
    max_mana = min(max_mana + 1, 10)

func is_alive() -> bool:
    return hp > 0

func reset_shield() -> void:
    shield = 0
    Events.player_hp_changed.emit(self, hp, max_hp)

func remove_from_hand(card: CardData) -> bool:
    var idx = hand.find(card)
    if idx >= 0:
        hand.remove_at(idx)
        return true
    return false
