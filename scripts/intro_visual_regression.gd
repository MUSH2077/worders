class_name IntroVisualRegression extends RefCounted

static func scan(menu: Node) -> Dictionary:
	var result = {
		"ok": false,
		"word_count": 0,
		"letters": {},
		"dense_inside": false,
		"bounds": Rect2(),
		"s_final_bottom": false,
		"s_final_horizontal": false,
		"errors": [],
	}
	if menu == null or not menu.has_method("_intro_word_count") or not menu.has_method("_intro_letter_structure_position"):
		result.errors.append("missing_intro_contract")
		return result
	var word_count = int(menu.call("_intro_word_count"))
	var title_len = 7
	result.word_count = word_count
	var structure_rect = menu.call("_intro_worders_structure_rect") if menu.has_method("_intro_worders_structure_rect") else Rect2()
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	var letters: Dictionary = {}
	var inside = true
	for i in range(word_count):
		var pos = menu.call("_intro_letter_structure_position", i)
		var letter_index = i % title_len
		letters[letter_index] = int(letters.get(letter_index, 0)) + 1
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)
		if structure_rect.size != Vector2.ZERO:
			inside = inside and structure_rect.grow(4.0).has_point(pos)
	result.letters = letters
	result.dense_inside = inside
	result.bounds = Rect2(min_pos, max_pos - min_pos)
	if word_count >= 336:
		var s_bottom_start = menu.call("_intro_letter_structure_position", 40 * title_len + 6)
		var s_bottom_end = menu.call("_intro_letter_structure_position", 47 * title_len + 6)
		result.s_final_bottom = s_bottom_end.y > 590.0 and s_bottom_start.y > 590.0
		result.s_final_horizontal = s_bottom_end.x < s_bottom_start.x and abs(s_bottom_end.y - s_bottom_start.y) <= 2.0
	for letter_index in range(title_len):
		if int(letters.get(letter_index, 0)) < 40:
			result.errors.append("letter_%d_sparse" % letter_index)
	if not result.dense_inside:
		result.errors.append("outside_structure_rect")
	if not result.s_final_bottom or not result.s_final_horizontal:
		result.errors.append("bad_final_s")
	result.ok = result.errors.is_empty()
	return result
