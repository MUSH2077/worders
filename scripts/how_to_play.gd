extends Control

@onready var title_label: Label = $TitleLabel
@onready var body_label: Label = $BodyLabel
@onready var back_button: Button = $BackButton
@onready var language_button: Button = $LanguageButton

func _ready() -> void:
	AudioDirector.play_music("menu")
	resized.connect(func(): _apply_responsive_layout(size))
	_apply_visual_theme()
	_apply_responsive_layout(size)
	back_button.pressed.connect(func():
		AudioDirector.play_sfx("ui_cancel")
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	language_button.pressed.connect(I18n.toggle_language)
	I18n.language_changed.connect(_refresh_language)
	_refresh_language()

func _refresh_language() -> void:
	title_label.text = I18n.t("how_title")
	body_label.text = I18n.t("how_body")
	back_button.text = I18n.t("back")
	language_button.text = I18n.t("lang_button")

func _apply_visual_theme() -> void:
	if has_node("Background") and UiTheme.asset_texture("menu_background_ink_polished"):
		$Background.texture = UiTheme.asset_texture("menu_background_ink_polished")
	if has_node("Panel"):
		$Panel.color = Color(0.02, 0.026, 0.038, 0.86)
	UiTheme.apply_button(back_button, "primary")
	UiTheme.apply_button(language_button, "normal")

func _apply_responsive_layout(viewport_size: Vector2 = Vector2(1920, 1080)) -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1920, 1080)
	var scale = min(viewport_size.x / 1920.0, viewport_size.y / 1080.0)
	var offset = (viewport_size - Vector2(1920, 1080) * scale) * 0.5
	for node_name in ["Background", "Shade", "Panel", "TitleLabel", "BodyLabel", "BackButton", "LanguageButton"]:
		if has_node(node_name):
			_apply_scaled_rect(get_node(node_name) as Control, scale, offset)

func _apply_scaled_rect(control: Control, scale: float, offset: Vector2) -> void:
	if control == null:
		return
	if not control.has_meta("worders_base_rect"):
		control.set_meta("worders_base_rect", Rect2(control.position, control.size))
	var base: Rect2 = control.get_meta("worders_base_rect")
	control.position = offset + base.position * scale
	control.size = base.size * scale
