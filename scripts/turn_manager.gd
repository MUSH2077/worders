extends Node

enum Phase { DRAW, MAIN, SCORING, RESOLVE, EVENT, END }

var current_phase: Phase = Phase.DRAW
var current_player = null
var current_turn_number: int = 0

func start_turn(player) -> void:
    current_player = player
    current_turn_number += 1
    current_phase = Phase.DRAW
    Events.turn_changed.emit(player)
    Events.phase_changed.emit("DRAW")
    if not current_player.is_ai:
        print("Player turn: ", current_player.player_name)
    else:
        print("AI turn: ", current_player.player_name)

func next_phase() -> void:
    var next_val = (current_phase + 1) % Phase.size()
    set_phase(next_val)

func set_phase(phase: Phase) -> void:
    current_phase = phase
    Events.phase_changed.emit(Phase.keys()[phase])

func end_turn() -> void:
    print("Ending turn for ", current_player.player_name if current_player else "null")
    var p = current_player
    current_player = null
    Events.turn_changed.emit(p)
