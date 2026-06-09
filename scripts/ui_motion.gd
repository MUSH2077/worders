class_name UiMotion extends RefCounted

static func apply_speed_scale(tween: Tween) -> Tween:
	if tween == null:
		return tween
	tween.set_speed_scale(_speed_scale())
	return tween

static func tween_in(control: Control, kind: String = "rise") -> Tween:
	if control == null:
		return null
	var base_pos = control.position
	var base_scale = control.scale
	control.modulate.a = 0.0
	match kind:
		"zoom":
			control.scale = base_scale * 0.92
		"drop":
			control.position = base_pos + Vector2(0, -12)
		_:
			control.position = base_pos + Vector2(0, 12)
	var tween = apply_speed_scale(control.create_tween())
	tween.set_parallel(true)
	tween.tween_property(control, "position", base_pos, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", base_scale, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, 0.18)
	return tween

static func pulse(control: Control, color: Color = Color(1, 0.82, 0.32, 0.32)) -> Tween:
	if control == null:
		return null
	var original_scale = control.scale
	var original_modulate = control.modulate
	var tween = apply_speed_scale(control.create_tween())
	tween.set_parallel(true)
	tween.tween_property(control, "scale", original_scale * 1.035, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate", Color(
		min(1.15, original_modulate.r + color.r * 0.08),
		min(1.15, original_modulate.g + color.g * 0.08),
		min(1.15, original_modulate.b + color.b * 0.08),
		original_modulate.a
	), 0.08)
	tween.set_parallel(false)
	tween.tween_property(control, "scale", original_scale, 0.16)
	tween.tween_property(control, "modulate", original_modulate, 0.16)
	return tween

static func _speed_scale() -> float:
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("BattleManager"):
		return float(tree.root.get_node("BattleManager").animation_speed) / 2.0
	return 0.5
