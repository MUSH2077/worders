extends Control

func _ready() -> void:
    AudioDirector.play_music("menu")
    resized.connect(func(): _apply_responsive_layout(size))
    _apply_visual_theme()
    _apply_responsive_layout(size)
    $DifficultyOption.item_selected.connect(_on_difficulty_changed)
    $BackButton.pressed.connect(_on_back)
    $DifficultyOption.select(AIController.difficulty)
    if has_node("MusicEnableCheck"):
        $MusicEnableCheck.toggled.connect(_on_music_enabled_toggled)
        $SfxEnableCheck.toggled.connect(_on_sfx_enabled_toggled)
        $MusicVolumeSlider.value_changed.connect(_on_music_volume_changed)
        $SfxVolumeSlider.value_changed.connect(_on_sfx_volume_changed)
        _load_audio_controls()
    if has_node("DeepSeekEnableCheck"):
        $DeepSeekEnableCheck.toggled.connect(_on_deepseek_enabled_toggled)
        $DeepSeekApiKeyEdit.text_changed.connect(_on_deepseek_key_changed)
        $DeepSeekModelOption.item_selected.connect(_on_deepseek_model_selected)
        $DeepSeekBaseUrlEdit.text_changed.connect(_on_deepseek_base_url_changed)
        $DeepSeekTestButton.pressed.connect(_on_deepseek_test_pressed)
        _load_deepseek_controls()
    if has_node("JudgmentModeOption"):
        $JudgmentModeOption.item_selected.connect(_on_judgment_mode_selected)
        $JudgmentAffectsCheck.toggled.connect(_on_judgment_affects_toggled)
        $JudgmentScopeOption.item_selected.connect(_on_judgment_scope_selected)
        $JudgmentTimeoutOption.item_selected.connect(_on_judgment_timeout_selected)
        _load_judgment_controls()
    _setup_api_key_reveal()
    if has_node("LanguageButton"):
        $LanguageButton.pressed.connect(I18n.toggle_language)
        I18n.language_changed.connect(_refresh_language)
    _refresh_language()

func _refresh_language() -> void:
    $TitleLabel.text = I18n.t("settings")
    $DiffLabel.text = I18n.t("ai_difficulty")
    $BackButton.text = I18n.t("back")
    if has_node("AudioTitle"):
        $AudioTitle.text = I18n.t("audio_title")
        $MusicEnableCheck.text = I18n.t("music")
        $SfxEnableCheck.text = I18n.t("sfx")
    if has_node("DeepSeekTitle"):
        $DeepSeekTitle.text = I18n.t("deepseek_title")
        $DeepSeekEnableCheck.text = I18n.t("deepseek_enable")
        $DeepSeekKeyLabel.text = I18n.t("deepseek_api_key")
        $DeepSeekApiKeyEdit.placeholder_text = I18n.t("deepseek_key_placeholder")
        $DeepSeekModelLabel.text = I18n.t("deepseek_model")
        $DeepSeekBaseUrlLabel.text = I18n.t("deepseek_base_url")
        $DeepSeekTestButton.text = I18n.t("deepseek_test")
    if has_node("LanguageButton"):
        $LanguageButton.text = I18n.t("lang_button")
    if has_node("JudgmentModeOption"):
        $JudgmentLabel.text = I18n.t("judgment_title")
        $JudgmentAffectsCheck.text = I18n.t("judgment_affects_short")
        $JudgmentModeOption.set_item_text(0, I18n.t("judgment_mode_local"))
        $JudgmentModeOption.set_item_text(1, I18n.t("judgment_mode_confirm"))
        $JudgmentModeOption.set_item_text(2, I18n.t("judgment_mode_preview"))
        $JudgmentScopeOption.set_item_text(0, I18n.t("judgment_scope_unknown"))
        $JudgmentScopeOption.set_item_text(1, I18n.t("judgment_scope_all"))
    $DifficultyOption.set_item_text(0, I18n.t("difficulty_easy"))
    $DifficultyOption.set_item_text(1, I18n.t("difficulty_normal"))
    $DifficultyOption.set_item_text(2, I18n.t("difficulty_hard"))

func _apply_visual_theme() -> void:
    if has_node("Background") and UiTheme.asset_texture("menu_background_ink_polished"):
        $Background.texture = UiTheme.asset_texture("menu_background_ink_polished")
    if has_node("SettingsPanel"):
        $SettingsPanel.add_theme_stylebox_override("panel", UiTheme.panel_style("tool"))
    _decorate_section_headers()
    for button_name in ["BackButton", "LanguageButton", "DeepSeekTestButton"]:
        if has_node(button_name):
            UiTheme.apply_button(get_node(button_name), "primary" if button_name == "DeepSeekTestButton" else "normal")
    for option_name in ["DifficultyOption", "DeepSeekModelOption", "JudgmentModeOption", "JudgmentScopeOption", "JudgmentTimeoutOption"]:
        if has_node(option_name):
            var option = get_node(option_name)
            option.add_theme_stylebox_override("normal", UiTheme.button_style("ghost"))
            option.add_theme_stylebox_override("hover", UiTheme.button_style("primary"))
            option.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78, 1))
    for edit_name in ["DeepSeekApiKeyEdit", "DeepSeekBaseUrlEdit"]:
        if has_node(edit_name):
            UiTheme.apply_input(get_node(edit_name))
    for slider_name in ["MusicVolumeSlider", "SfxVolumeSlider"]:
        if has_node(slider_name):
            var slider = get_node(slider_name)
            slider.add_theme_stylebox_override("slider", UiTheme.panel_style("tool"))
            slider.add_theme_stylebox_override("grabber_area", UiTheme.button_style("primary"))

func _decorate_section_headers() -> void:
    for header_name in ["TitleLabel", "AudioTitle", "DeepSeekTitle"]:
        if not has_node(header_name):
            continue
        var label = get_node(header_name) as Control
        if label == null or label.has_node("HeaderAccent"):
            continue
        var bar = ColorRect.new()
        bar.name = "HeaderAccent"
        bar.color = Color(0.92, 0.68, 0.28, 0.8)
        bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
        bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
        bar.offset_left = 6.0
        bar.offset_right = -6.0
        bar.offset_top = 3.0
        bar.offset_bottom = 6.0
        label.add_child(bar)

func _apply_responsive_layout(viewport_size: Vector2 = Vector2(1920, 1080)) -> void:
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        viewport_size = Vector2(1920, 1080)
    var scale = min(viewport_size.x / 1920.0, viewport_size.y / 1080.0)
    var offset = (viewport_size - Vector2(1920, 1080) * scale) * 0.5
    for node_name in [
        "Background", "Shade", "SettingsPanel", "TitleLabel", "DiffLabel", "DifficultyOption",
        "AudioTitle", "MusicEnableCheck", "MusicVolumeSlider", "SfxEnableCheck", "SfxVolumeSlider",
        "BackButton", "LanguageButton", "DeepSeekTitle", "DeepSeekEnableCheck", "DeepSeekKeyLabel",
        "DeepSeekApiKeyEdit", "DeepSeekModelLabel", "DeepSeekModelOption", "DeepSeekBaseUrlLabel",
        "DeepSeekBaseUrlEdit", "DeepSeekTestButton", "DeepSeekStatusLabel",
        "JudgmentLabel", "JudgmentModeOption", "JudgmentAffectsCheck",
        "JudgmentScopeOption", "JudgmentTimeoutOption"
    ]:
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

func _on_difficulty_changed(idx: int) -> void:
    AIController.difficulty = idx as AIController.Difficulty

func _on_back() -> void:
    AudioDirector.play_sfx("ui_cancel")
    get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _load_audio_controls() -> void:
    var settings = AudioDirector.load_settings()
    $MusicEnableCheck.button_pressed = bool(settings.get("music_enabled", true))
    $SfxEnableCheck.button_pressed = bool(settings.get("sfx_enabled", true))
    $MusicVolumeSlider.value = float(settings.get("music_volume", 0.58))
    $SfxVolumeSlider.value = float(settings.get("sfx_volume", 0.72))

func _on_music_enabled_toggled(enabled: bool) -> void:
    AudioDirector.set_music_enabled(enabled)
    AudioDirector.play_sfx("ui_confirm")

func _on_sfx_enabled_toggled(enabled: bool) -> void:
    AudioDirector.set_sfx_enabled(enabled)
    AudioDirector.play_sfx("ui_confirm")

func _on_music_volume_changed(value: float) -> void:
    AudioDirector.set_music_volume(value)

func _on_sfx_volume_changed(value: float) -> void:
    AudioDirector.set_sfx_volume(value)
    AudioDirector.play_sfx("ui_confirm")

func _load_deepseek_controls() -> void:
    var settings = LLMClient.load_settings()
    $DeepSeekEnableCheck.button_pressed = bool(settings.get("enabled", false))
    $DeepSeekApiKeyEdit.secret = true
    $DeepSeekApiKeyEdit.text = str(settings.get("api_key", ""))
    $DeepSeekBaseUrlEdit.text = str(settings.get("base_url", LLMClient.DEFAULT_BASE_URL))
    var model_name = str(settings.get("model", LLMClient.DEFAULT_MODEL))
    $DeepSeekModelOption.clear()
    $DeepSeekModelOption.add_item("deepseek-v4-pro")
    $DeepSeekModelOption.add_item("deepseek-v4-flash")
    var idx = 0 if model_name == "deepseek-v4-pro" else 1
    if model_name not in ["deepseek-v4-pro", "deepseek-v4-flash"]:
        idx = 0
    $DeepSeekModelOption.select(idx)
    _update_deepseek_status()

func _current_deepseek_settings() -> Dictionary:
    var selected = $DeepSeekModelOption.selected
    if selected < 0:
        selected = 0
        $DeepSeekModelOption.select(selected)
    return {
        "enabled": $DeepSeekEnableCheck.button_pressed,
        "api_key": $DeepSeekApiKeyEdit.text.strip_edges(),
        "model": $DeepSeekModelOption.get_item_text(selected),
        "base_url": $DeepSeekBaseUrlEdit.text.strip_edges(),
        "timeout_seconds": LLMClient.timeout_seconds,
        "judgment_mode": LLMClient.judgment_mode,
        "judgment_scope": LLMClient.judgment_scope,
        "judgment_timeout_ms": LLMClient.judgment_timeout_ms,
        "judgment_affects_score": LLMClient.judgment_affects_score,
    }

func _save_deepseek_settings() -> void:
    LLMClient.save_settings(_current_deepseek_settings())
    _update_deepseek_status()

func _update_deepseek_status(message: String = "") -> void:
    var key = $DeepSeekApiKeyEdit.text.strip_edges()
    var masked = LLMClient.mask_api_key(key)
    if message.is_empty():
        if $DeepSeekEnableCheck.button_pressed and not key.is_empty():
            message = I18n.t("deepseek_status_ready") % masked
        elif $DeepSeekEnableCheck.button_pressed and LLMClient.has_api_key():
            message = I18n.t("deepseek_status_ready") % "env"
        elif $DeepSeekEnableCheck.button_pressed:
            message = I18n.t("deepseek_status_need_key")
        else:
            message = I18n.t("deepseek_status_off")
    $DeepSeekStatusLabel.text = message

func _on_deepseek_enabled_toggled(_enabled: bool) -> void:
    _save_deepseek_settings()

func _on_deepseek_key_changed(_text: String) -> void:
    _save_deepseek_settings()

func _on_deepseek_model_selected(_index: int) -> void:
    _save_deepseek_settings()

func _on_deepseek_base_url_changed(_text: String) -> void:
    _save_deepseek_settings()

func _on_deepseek_test_pressed() -> void:
    _save_deepseek_settings()
    $DeepSeekTestButton.disabled = true
    _update_deepseek_status(I18n.t("deepseek_testing"))
    var result = await LLMClient.test_connection()
    $DeepSeekTestButton.disabled = false
    if result.get("ok", false):
        _update_deepseek_status(I18n.t("deepseek_test_ok"))
    else:
        _update_deepseek_status(I18n.t("deepseek_test_failed") % str(result.get("error", "unknown")))

const JUDGMENT_TIMEOUT_OPTIONS = [3000, 6000, 12000]

func _load_judgment_controls() -> void:
    var settings = LLMClient.load_settings()
    var mode = str(settings.get("judgment_mode", "local_only"))
    var idx = LLMClient.JUDGMENT_MODES.find(mode)
    if idx < 0:
        idx = 0
    $JudgmentModeOption.select(idx)
    $JudgmentAffectsCheck.button_pressed = bool(settings.get("judgment_affects_score", false))
    var scope = str(settings.get("judgment_scope", "unknown_only"))
    var scope_idx = LLMClient.JUDGMENT_SCOPES.find(scope)
    if scope_idx < 0:
        scope_idx = 0
    $JudgmentScopeOption.select(scope_idx)
    var timeout = int(settings.get("judgment_timeout_ms", 6000))
    var t_idx = JUDGMENT_TIMEOUT_OPTIONS.find(timeout)
    if t_idx < 0:
        t_idx = 1
    $JudgmentTimeoutOption.select(t_idx)

func _save_judgment_settings() -> void:
    var settings = LLMClient.load_settings()
    var idx = $JudgmentModeOption.selected
    if idx < 0 or idx >= LLMClient.JUDGMENT_MODES.size():
        idx = 0
    settings["judgment_mode"] = LLMClient.JUDGMENT_MODES[idx]
    settings["judgment_affects_score"] = $JudgmentAffectsCheck.button_pressed
    var scope_idx = $JudgmentScopeOption.selected
    if scope_idx < 0 or scope_idx >= LLMClient.JUDGMENT_SCOPES.size():
        scope_idx = 0
    settings["judgment_scope"] = LLMClient.JUDGMENT_SCOPES[scope_idx]
    var t_idx = $JudgmentTimeoutOption.selected
    if t_idx < 0 or t_idx >= JUDGMENT_TIMEOUT_OPTIONS.size():
        t_idx = 1
    settings["judgment_timeout_ms"] = JUDGMENT_TIMEOUT_OPTIONS[t_idx]
    LLMClient.save_settings(settings)

func _on_judgment_mode_selected(_index: int) -> void:
    _save_judgment_settings()

func _on_judgment_affects_toggled(_enabled: bool) -> void:
    _save_judgment_settings()

func _on_judgment_scope_selected(_index: int) -> void:
    _save_judgment_settings()

func _on_judgment_timeout_selected(_index: int) -> void:
    _save_judgment_settings()

func _setup_api_key_reveal() -> void:
    if not has_node("DeepSeekApiKeyEdit"):
        return
    var edit = $DeepSeekApiKeyEdit
    if edit.has_node("RevealButton"):
        return
    var btn = Button.new()
    btn.name = "RevealButton"
    btn.toggle_mode = true
    btn.focus_mode = Control.FOCUS_NONE
    btn.text = "👁"
    btn.tooltip_text = I18n.t("api_key_reveal")
    btn.anchor_left = 1.0
    btn.anchor_right = 1.0
    btn.anchor_top = 0.0
    btn.anchor_bottom = 1.0
    btn.offset_left = -36.0
    btn.offset_right = -3.0
    btn.offset_top = 3.0
    btn.offset_bottom = -3.0
    btn.add_theme_font_size_override("font_size", 16)
    btn.add_theme_stylebox_override("normal", UiTheme.button_style("ghost"))
    btn.add_theme_stylebox_override("hover", UiTheme.button_style("primary"))
    btn.add_theme_stylebox_override("pressed", UiTheme.button_style("primary"))
    btn.toggled.connect(func(pressed: bool): edit.secret = not pressed)
    edit.add_child(btn)
