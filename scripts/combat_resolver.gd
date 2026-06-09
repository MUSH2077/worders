class_name CombatResolver extends RefCounted

class CombatResult:
    var damage_dealt: int = 0
    var shield_gained: int = 0
    var heal_amount: int = 0
    var was_crit: bool = false
    var crit_chance: float = 0.0

static func resolve(attacker: Player, defender: Player,
                    breakdown: ScoringEngine.ScoreBreakdown) -> CombatResult:
    var result = CombatResult.new()
    result.crit_chance = crit_chance_for_breakdown(breakdown)
    result.was_crit = randf() < result.crit_chance
    var atk = breakdown.atk
    if result.was_crit:
        atk = int(float(atk) * ScoringEngine.CRIT_MULT)
    result.shield_gained = breakdown.def_
    attacker.add_shield(result.shield_gained)
    result.damage_dealt = defender.take_damage(atk)
    result.heal_amount = int(float(breakdown.def_) * ScoringEngine.HEAL_RATIO) + int(breakdown.stance_modifiers.get("heal_bonus", 0))
    attacker.heal(result.heal_amount)
    return result

static func crit_chance_for_breakdown(breakdown: ScoringEngine.ScoreBreakdown) -> float:
    return min(float(breakdown.crt) * 0.02, 0.65)
