class_name UiTheme extends RefCounted

const INK := Color(0.035, 0.042, 0.058, 0.92)
const INK_DARK := Color(0.014, 0.018, 0.028, 0.94)
const PAPER := Color(0.92, 0.82, 0.62, 0.96)
const GOLD := Color(0.92, 0.68, 0.28, 1.0)
const CINNABAR := Color(0.82, 0.24, 0.16, 1.0)
const PLAYER_BLUE := Color(0.24, 0.66, 1.0, 1.0)
const AI_ORANGE := Color(1.0, 0.42, 0.20, 1.0)
const JADE := Color(0.36, 0.95, 0.58, 1.0)

const ASSET_PATHS := {
	"ui_style_sheet_ai_reference": "res://resources/art/ui/ui_style_sheet_ai_reference.png",
	"ui_panel_ink_dark": "res://resources/art/ui/ui_panel_ink_dark.png",
	"ui_panel_paper_gold": "res://resources/art/ui/ui_panel_paper_gold.png",
	"ui_button_ink_gold": "res://resources/art/ui/ui_button_ink_gold.png",
	"ui_button_cinnabar": "res://resources/art/ui/ui_button_cinnabar.png",
	"ui_avatar_ring_player": "res://resources/art/ui/ui_avatar_ring_player.png",
	"ui_avatar_ring_ai": "res://resources/art/ui/ui_avatar_ring_ai.png",
	"ui_event_scroll": "res://resources/art/ui/ui_event_scroll.png",
	"card_frame_fill": "res://resources/art/ui/card_frame_fill.png",
	"card_frame_function": "res://resources/art/ui/card_frame_function.png",
	"card_frame_equipment": "res://resources/art/ui/card_frame_equipment.png",
	"card_frame_status": "res://resources/art/ui/card_frame_status.png",
	"fx_ink_red": "res://resources/art/fx/fx_ink_red.png",
	"fx_ink_blue": "res://resources/art/fx/fx_ink_blue.png",
	"fx_ink_green": "res://resources/art/fx/fx_ink_green.png",
	"fx_ink_gold": "res://resources/art/fx/fx_ink_gold.png",
	"fx_ink_black": "res://resources/art/fx/fx_ink_black.png",
	"menu_background_ink_polished": "res://resources/art/ui/menu_background_ink_polished.png",
	"battle_background_ink_overlay": "res://resources/art/ui/battle_background_ink_overlay.png",
}

static func asset_keys() -> Array[String]:
	var keys: Array[String] = []
	for key in ASSET_PATHS.keys():
		keys.append(str(key))
	keys.sort()
	return keys

static func asset_path(key: String) -> String:
	return str(ASSET_PATHS.get(key, ""))

static func asset_texture(key: String) -> Texture2D:
	var path = asset_path(key)
	if path.is_empty():
		return null
	return load(path) as Texture2D

static func panel_style(kind: String = "ink") -> StyleBox:
	match kind:
		"paper":
			return _texture_style("ui_panel_paper_gold", Color(0.74, 0.58, 0.36, 0.95), 18, _flat(Color(0.16, 0.12, 0.08, 0.88), GOLD, 8, 2, Color(0, 0, 0, 0.35)))
		"cinnabar":
			return _flat(Color(0.18, 0.065, 0.055, 0.92), CINNABAR, 8, 2, Color(0, 0, 0, 0.42))
		"tool":
			return _texture_style("ui_panel_ink_dark", Color(0.78, 0.86, 1.0, 0.86), 14, _flat(Color(0.022, 0.028, 0.04, 0.82), Color(0.56, 0.42, 0.22, 0.72), 6, 1, Color(0, 0, 0, 0.28)))
		"slot":
			return _texture_style("ui_panel_ink_dark", Color(0.72, 0.84, 1.0, 0.62), 14, _flat(Color(0.035, 0.05, 0.072, 0.76), Color(0.60, 0.46, 0.25, 0.86), 6, 1, Color(0, 0, 0, 0.32)))
		_:
			return _texture_style("ui_panel_ink_dark", Color(0.86, 0.90, 1.0, 0.92), 14, _flat(INK, GOLD, 8, 2, Color(0, 0, 0, 0.40)))

static func button_style(kind: String = "normal") -> StyleBox:
	match kind:
		"danger":
			return _texture_style("ui_button_cinnabar", Color(1.0, 0.74, 0.55, 0.98), 8, _flat(Color(0.18, 0.055, 0.045, 0.94), CINNABAR, 6, 2, Color(0, 0, 0, 0.36)))
		"primary":
			return _texture_style("ui_button_ink_gold", Color(0.84, 0.92, 1.0, 1.0), 8, _flat(Color(0.05, 0.09, 0.16, 0.94), GOLD, 6, 2, Color(0, 0, 0, 0.36)))
		"ghost":
			return _texture_style("ui_button_ink_gold", Color(0.72, 0.78, 0.90, 0.70), 8, _flat(Color(0.03, 0.04, 0.058, 0.62), Color(0.72, 0.56, 0.30, 0.72), 6, 1, Color(0, 0, 0, 0.25)))
		_:
			return _texture_style("ui_button_ink_gold", Color(0.78, 0.84, 0.96, 0.90), 8, _flat(Color(0.06, 0.075, 0.105, 0.92), Color(0.82, 0.62, 0.30, 0.86), 6, 1, Color(0, 0, 0, 0.32)))

# Dark ink input field with a bright focus border, for high contrast against
# light text. Use for LineEdit / text inputs on dark panels.
static func input_style(focused: bool = false) -> StyleBox:
	if focused:
		return _flat(Color(0.07, 0.085, 0.12, 1.0), Color(1.0, 0.82, 0.34, 1.0), 6, 2, Color(0, 0, 0, 0.30))
	return _flat(Color(0.03, 0.038, 0.055, 1.0), Color(0.62, 0.70, 0.86, 0.78), 6, 1, Color(0, 0, 0, 0.30))

# Applies a high-contrast dark input look with light text to a LineEdit.
static func apply_input(edit: LineEdit) -> void:
	if edit == null:
		return
	edit.add_theme_stylebox_override("normal", input_style(false))
	edit.add_theme_stylebox_override("focus", input_style(true))
	edit.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0, 1.0))
	edit.add_theme_color_override("font_placeholder_color", Color(0.66, 0.72, 0.84, 0.85))
	edit.add_theme_color_override("caret_color", Color(1.0, 0.86, 0.42, 1.0))

static func apply_button(button: Button, kind: String = "normal") -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", button_style(kind))
	button.add_theme_stylebox_override("hover", button_style("primary"))
	button.add_theme_stylebox_override("pressed", button_style("cinnabar" if kind == "danger" else "paper"))
	button.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78, 1))
	button.add_theme_color_override("font_hover_color", Color.WHITE)

static func card_style(card: CardData) -> StyleBox:
	var color = card_color(card)
	var bg = Color(0.07, 0.085, 0.115, 0.96)
	var frame_key = "card_frame_fill"
	if card:
		match card.card_type:
			CardData.CardType.FUNCTION:
				bg = Color(0.13, 0.07, 0.065, 0.96)
				frame_key = "card_frame_function"
			CardData.CardType.EQUIPMENT:
				bg = Color(0.07, 0.12, 0.08, 0.96)
				frame_key = "card_frame_equipment"
			CardData.CardType.STATUS:
				bg = Color(0.11, 0.07, 0.14, 0.96)
				frame_key = "card_frame_status"
	return _texture_style(frame_key, Color(color.r, color.g, color.b, 0.94), 18, _flat(bg, color, 8, 2, Color(0, 0, 0, 0.38)))

static func card_color(card: CardData) -> Color:
	if card == null:
		return GOLD
	if card.card_type != CardData.CardType.FILL:
		match card.card_type:
			CardData.CardType.FUNCTION:
				return AI_ORANGE
			CardData.CardType.EQUIPMENT:
				return JADE
			CardData.CardType.STATUS:
				return Color(0.70, 0.42, 1.0, 1)
	return component_color(card.comp_constraint)

static func component_color(component: int) -> Color:
	match component:
		CardData.SentenceComponent.SUBJECT:
			return PLAYER_BLUE
		CardData.SentenceComponent.PREDICATE:
			return AI_ORANGE
		CardData.SentenceComponent.OBJECT:
			return Color(1.0, 0.62, 0.32, 1)
		CardData.SentenceComponent.ATTRIBUTE:
			return Color(0.72, 0.9, 0.45, 1)
		CardData.SentenceComponent.ADVERBIAL:
			return Color(0.76, 0.48, 1.0, 1)
		CardData.SentenceComponent.COMPLEMENT:
			return Color(0.35, 0.95, 0.86, 1)
		_:
			return GOLD

static func content_color(category: int) -> Color:
	match category:
		CardData.ContentCategory.COLOR:
			return Color(1.0, 0.48, 0.58, 1)
		CardData.ContentCategory.ANIMAL:
			return Color(0.92, 0.72, 0.42, 1)
		CardData.ContentCategory.EMOTION:
			return Color(1.0, 0.62, 0.82, 1)
		CardData.ContentCategory.ACTION:
			return Color(1.0, 0.45, 0.28, 1)
		CardData.ContentCategory.NATURE:
			return JADE
		CardData.ContentCategory.BODY:
			return Color(0.95, 0.48, 0.42, 1)
		CardData.ContentCategory.ARTIFACT:
			return Color(0.7, 0.8, 0.95, 1)
		CardData.ContentCategory.ABSTRACT:
			return Color(0.72, 0.55, 1.0, 1)
		CardData.ContentCategory.TIME:
			return Color(0.95, 0.78, 0.38, 1)
		CardData.ContentCategory.SPACE:
			return Color(0.42, 0.72, 1.0, 1)
		_:
			return Color(0.86, 0.91, 1.0, 1)

static func _flat(bg: Color, border: Color, radius: int, width: int, shadow: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = width
	style.border_width_right = width
	style.border_width_top = width
	style.border_width_bottom = width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = shadow
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func _texture_style(asset_key: String, tint: Color, margin: int, fallback: StyleBox) -> StyleBox:
	var texture = asset_texture(asset_key)
	if texture == null:
		return fallback
	var style = StyleBoxTexture.new()
	style.texture = texture
	style.draw_center = true
	style.texture_margin_left = margin
	style.texture_margin_right = margin
	style.texture_margin_top = margin
	style.texture_margin_bottom = margin
	style.expand_margin_left = 2
	style.expand_margin_right = 2
	style.expand_margin_top = 2
	style.expand_margin_bottom = 2
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.modulate_color = tint
	return style
