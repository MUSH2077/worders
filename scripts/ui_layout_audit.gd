class_name UiLayoutAudit extends RefCounted

static func scan(scene_root: Control, viewport_size: Vector2) -> Dictionary:
	var result = {"ok": true, "viewport": viewport_size, "overlaps": [], "overflow": [], "text_risks": []}
	if scene_root == null:
		result.ok = false
		result.overflow.append("missing_root")
		return result
	if scene_root.has_method("_apply_responsive_layout"):
		scene_root.call("_apply_responsive_layout", viewport_size)
	_collect_overflow(scene_root, scene_root, viewport_size, result)
	_collect_key_overlaps(scene_root, result)
	result.ok = result.overlaps.is_empty() and result.overflow.is_empty() and result.text_risks.is_empty()
	return result

static func _collect_overflow(root: Control, node: Node, viewport: Vector2, result: Dictionary) -> void:
	if node is Control and node.visible:
		var control = node as Control
		var rect = control.get_global_rect()
		if _should_audit_control(root, control):
			if rect.position.x < -2 or rect.position.y < -2 or rect.end.x > viewport.x + 2 or rect.end.y > viewport.y + 2:
				result.overflow.append(str(control.name))
			if control is Label:
				var label = control as Label
				if label.text.length() > 0 and label.size.x < 24:
					result.text_risks.append(str(label.name))
	for child in node.get_children():
		_collect_overflow(root, child, viewport, result)

static func _collect_key_overlaps(root: Control, result: Dictionary) -> void:
	var pairs = [
		["ChatPanel", "CardsPanel"],
		["SlotsPanel", "CardsPanel"],
		["PlayerRolePanel", "ConfirmButton"],
		["PlayerRolePanel", "EndTurnButton"],
		["PlayerRolePanel", "StartWordsButton"],
		["PlayerRolePanel", "ClearSentenceButton"],
		["AIRolePanel", "PhaseLabel"],
		["AIRolePanel", "TurnTimerLabel"],
		["ScorePreviewPanel", "LogLabel"],
	]
	for pair in pairs:
		if root.has_node(pair[0]) and root.has_node(pair[1]):
			var a = root.get_node(pair[0]) as Control
			var b = root.get_node(pair[1]) as Control
			if a and b and a.visible and b.visible and a.get_rect().intersects(b.get_rect()):
				result.overlaps.append("%s/%s" % [pair[0], pair[1]])

static func _should_audit_control(root: Control, control: Control) -> bool:
	if control == root:
		return false
	if str(control.name).begins_with("@"):
		return false
	if control.name in ["FxLayer", "Background", "Shade", "InkOverlay", "CardsContainer", "SlotsContainer", "HandCategoryBar"]:
		return false
	var parent = control.get_parent()
	if parent == root:
		return true
	return control.name in [
		"TitleLabel", "BodyLabel", "BackButton", "LanguageButton", "SettingsPanel",
		"ChatPanel", "CardsPanel", "SlotsPanel", "PhaseLabel", "ScorePreviewPanel", "LogLabel",
		"ConfirmButton", "EndTurnButton", "AutoWordsButton", "StartWordsButton", "ClearSentenceButton",
		"AIRolePanel", "PlayerRolePanel"
	]
