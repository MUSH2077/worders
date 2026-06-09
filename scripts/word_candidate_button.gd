class_name WordCandidateButton extends Button

const ATK_COLOR := Color(0.95, 0.22, 0.14, 1.0)
const DEF_COLOR := Color(0.28, 0.68, 1.0, 1.0)
const CRT_COLOR := Color(0.98, 0.76, 0.28, 1.0)

var _word := ""
var _preview := ScoringEngine.ScoreBreakdown.new()
var _constraint_state := "match"

func apply_preview(word: String, preview: ScoringEngine.ScoreBreakdown, constraint_state: String) -> void:
	_word = word
	_preview = preview
	_constraint_state = constraint_state
	text = ""
	tooltip_text = "%s  ATK %d  DEF %d  CRT %d" % [word, preview.atk, preview.def_, preview.crt]
	queue_redraw()

func _font() -> Font:
	var font = get_theme_font("font")
	if font:
		return font
	return ThemeDB.fallback_font

func _draw() -> void:
	var rect = get_rect().size
	var pad = Vector2(14, 8)
	var y_mid = rect.y * 0.5
	var font = _font()

	draw_string(font, Vector2(pad.x, y_mid + 6), _word, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.95, 0.76, 1.0))

	var badge_text = "OK"
	var badge_color = Color(0.36, 0.95, 0.58, 0.95)
	if _constraint_state == "risk":
		badge_text = "!"
		badge_color = Color(0.95, 0.38, 0.22, 0.95)
	elif _constraint_state == "unknown":
		badge_text = "~"
		badge_color = Color(0.72, 0.84, 1.0, 0.92)
	var badge_x = pad.x + font.get_string_size(_word, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 10
	draw_circle(Vector2(badge_x + 10, y_mid), 10, badge_color * Color(1, 1, 1, 0.22))
	draw_arc(Vector2(badge_x + 10, y_mid), 10, 0, TAU, 24, badge_color, 1.5)
	draw_string(font, Vector2(badge_x + 6, y_mid + 5), badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, badge_color)

	var bar_w = 72.0
	var bar_h = 7.0
	var gap = 8.0
	var total_w = bar_w * 3.0 + gap * 2.0
	var start_x = rect.x - pad.x - total_w
	var peak = maxi(12, maxi(_preview.atk, maxi(_preview.def_, _preview.crt)))
	_draw_mini_bar(font, Vector2(start_x, y_mid - bar_h * 0.5), bar_w, bar_h, float(_preview.atk) / float(peak), ATK_COLOR, str(_preview.atk))
	_draw_mini_bar(font, Vector2(start_x + bar_w + gap, y_mid - bar_h * 0.5), bar_w, bar_h, float(_preview.def_) / float(peak), DEF_COLOR, str(_preview.def_))
	_draw_mini_bar(font, Vector2(start_x + (bar_w + gap) * 2.0, y_mid - bar_h * 0.5), bar_w, bar_h, float(_preview.crt) / float(peak), CRT_COLOR, str(_preview.crt))

func _draw_mini_bar(font: Font, origin: Vector2, width: float, height: float, ratio: float, color: Color, value_text: String) -> void:
	draw_rect(Rect2(origin, Vector2(width, height)), Color(0.02, 0.025, 0.04, 0.88), true)
	if ratio > 0.0:
		draw_rect(Rect2(origin, Vector2(width * clampf(ratio, 0.0, 1.0), height)), color, true)
	draw_string(font, origin + Vector2(width + 4, height - 1), value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
