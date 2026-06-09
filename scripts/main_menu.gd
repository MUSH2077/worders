extends Control

static var intro_has_played := false

const INTRO_DURATION := 8.20
const WORDERS_TITLE := "WORDERS"
const WORDS_PER_LETTER := 48
const INTRO_LETTER_BASE := Vector2(500.0, 350.0)
const INTRO_LETTER_STEP := 135.0
const INTRO_LETTER_WIDTH := 94.0
const INTRO_LETTER_HEIGHT := 250.0
const INTRO_LOGO_PADDING := Vector2(52.0, 58.0)
const INTRO_BRUSH_START := 3.55
const INTRO_BRUSH_STEP := 0.010

func _ready() -> void:
    AudioDirector.play_music("menu")
    $TitleLabel.text = WORDERS_TITLE
    _style_worders_title($TitleLabel)
    resized.connect(func(): _apply_responsive_layout(size))
    _apply_visual_theme()
    _apply_responsive_layout(size)
    $StartButton.pressed.connect(_on_start)
    $HowToPlayButton.pressed.connect(_on_how_to_play)
    $SettingsButton.pressed.connect(_on_settings)
    $QuitButton.pressed.connect(_on_quit)
    if has_node("LanguageButton"):
        $LanguageButton.pressed.connect(I18n.toggle_language)
        I18n.language_changed.connect(_refresh_language)
    _refresh_language()
    _play_menu_button_intro()
    if not intro_has_played:
        intro_has_played = true
        _play_intro_animation.call_deferred()

func _refresh_language() -> void:
    if has_node("TitleLabel"):
        $TitleLabel.text = WORDERS_TITLE
    if has_node("SubtitleLabel"):
        $SubtitleLabel.text = I18n.t("main_subtitle")
    if has_node("StartButton"):
        $StartButton.text = I18n.t("start_battle")
    if has_node("SettingsButton"):
        $SettingsButton.text = I18n.t("settings")
    if has_node("HowToPlayButton"):
        $HowToPlayButton.text = I18n.t("how_to_play")
    if has_node("QuitButton"):
        $QuitButton.text = I18n.t("quit_game")
    if has_node("LanguageButton"):
        $LanguageButton.text = I18n.t("lang_button")

func _apply_visual_theme() -> void:
    if has_node("Background") and UiTheme.asset_texture("menu_background_ink_polished"):
        $Background.texture = UiTheme.asset_texture("menu_background_ink_polished")
        $Background.modulate = Color(1.0, 1.0, 1.0, 1.0)
    for button_name in ["StartButton", "SettingsButton", "HowToPlayButton", "QuitButton", "LanguageButton"]:
        if has_node(button_name):
            UiTheme.apply_button(get_node(button_name), "danger" if button_name == "QuitButton" else "primary" if button_name == "StartButton" else "normal")
    if has_node("MenuPanel"):
        $MenuPanel.color = Color(0.012, 0.016, 0.026, 0.42)
        _ensure_texture_backing("MenuPanelTexture", $MenuPanel, UiTheme.asset_texture("ui_panel_ink_dark"), Color(0.78, 0.86, 1.0, 0.72), 2)
    _ensure_corner_seal()

func _apply_responsive_layout(viewport_size: Vector2 = Vector2(1920, 1080)) -> void:
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        viewport_size = Vector2(1920, 1080)
    var scale = min(viewport_size.x / 1920.0, viewport_size.y / 1080.0)
    var offset = (viewport_size - Vector2(1920, 1080) * scale) * 0.5
    for node_name in ["Background", "Shade", "MenuPanel", "TitleLabel", "SubtitleLabel", "StartButton", "SettingsButton", "HowToPlayButton", "QuitButton", "LanguageButton"]:
        if has_node(node_name):
            _apply_scaled_rect(get_node(node_name) as Control, scale, offset)
    for meta_node in ["MenuPanelTexture", "CornerSeal"]:
        if has_node(meta_node):
            _apply_scaled_rect(get_node(meta_node) as Control, scale, offset)

func _apply_scaled_rect(control: Control, scale: float, offset: Vector2) -> void:
    if control == null:
        return
    if not control.has_meta("worders_base_rect"):
        control.set_meta("worders_base_rect", Rect2(control.position, control.size))
    var base: Rect2 = control.get_meta("worders_base_rect")
    control.position = offset + base.position * scale
    control.size = base.size * scale

func _ensure_texture_backing(node_name: String, target: Control, texture: Texture2D, tint: Color, z_after: int) -> void:
    if target == null or texture == null:
        return
    var backing: TextureRect
    if has_node(node_name):
        backing = get_node(node_name) as TextureRect
    else:
        backing = TextureRect.new()
        backing.name = node_name
        backing.layout_mode = 0
        backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(backing)
        move_child(backing, min(z_after, get_child_count() - 1))
    backing.texture = texture
    backing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    backing.stretch_mode = TextureRect.STRETCH_SCALE
    backing.modulate = tint
    backing.position = target.position - Vector2(8, 8)
    backing.size = target.size + Vector2(16, 16)
    backing.set_meta("worders_base_rect", Rect2(backing.position, backing.size))

func _ensure_corner_seal() -> void:
    if has_node("CornerSeal"):
        return
    var seal = ColorRect.new()
    seal.name = "CornerSeal"
    seal.layout_mode = 0
    seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
    seal.position = Vector2(1190, 670)
    seal.size = Vector2(124, 124)
    seal.color = Color(0.58, 0.055, 0.035, 0.58)
    add_child(seal)
    move_child(seal, 3)

func _on_start() -> void:
    AudioDirector.play_sfx("ui_confirm")
    get_tree().change_scene_to_file("res://scenes/battle.tscn")

func _on_settings() -> void:
    AudioDirector.play_sfx("ui_confirm")
    get_tree().change_scene_to_file("res://scenes/settings.tscn")

func _on_how_to_play() -> void:
    AudioDirector.play_sfx("ui_confirm")
    get_tree().change_scene_to_file("res://scenes/how_to_play.tscn")

func _on_quit() -> void:
    AudioDirector.play_sfx("ui_cancel")
    get_tree().quit()

func _play_menu_button_intro() -> void:
    var delay = 0.0
    for node_name in ["StartButton", "SettingsButton", "HowToPlayButton", "QuitButton"]:
        if has_node(node_name):
            var button = get_node(node_name) as Control
            var tween = UiMotion.tween_in(button, "rise")
            if tween:
                tween.set_speed_scale(1.0)
            delay += 0.04

func _style_worders_title(label: Label) -> void:
    label.text = WORDERS_TITLE
    label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.22, 1))
    label.add_theme_color_override("font_outline_color", Color(0.42, 0.08, 0.02, 0.95))
    label.add_theme_constant_override("outline_size", 5)
    label.add_theme_color_override("font_shadow_color", Color(0.05, 0.02, 0.0, 0.82))
    label.add_theme_constant_override("shadow_offset_x", 3)
    label.add_theme_constant_override("shadow_offset_y", 4)
    label.add_theme_font_size_override("font_size", 66)

func _make_intro_word_pool() -> Array[String]:
    return [
        "word", "battle", "verse", "spell", "syntax", "rhyme", "chaos", "shield",
        "词", "句", "韵", "意", "墨", "锋", "守", "合律",
        "言葉", "詩", "力", "夢", "문장", "빛", "마음", "칼",
        "palabra", "fuego", "verso", "alma", "mot", "lumiere", "rune", "ordre",
        "слово", "ритм", "щит", "искра", "λόγος", "φως", "ψυχή", "κύμα",
        "كلمة", "نور", "قافية", "حبر", "शब्द", "ज्योति", "कविता", "रक्षा"
    ]

func _intro_duration() -> float:
    return INTRO_DURATION

func _intro_word_count() -> int:
    return WORDERS_TITLE.length() * WORDS_PER_LETTER

func _intro_word_color(_index: int) -> Color:
    return Color(1.0, 1.0, 1.0, 1.0)

func _intro_has_radial_ray_burst() -> bool:
    return false

func _intro_uses_brush_written_title() -> bool:
    return true

func _intro_has_art_title_overlay() -> bool:
    return false

func _intro_brush_sequence_count() -> int:
    return _intro_word_count()

func _intro_label_index_for_brush_order(order_index: int) -> int:
    var letter_index = int(order_index / WORDS_PER_LETTER)
    var point_index = order_index % WORDS_PER_LETTER
    return point_index * WORDERS_TITLE.length() + letter_index

func _intro_brush_sequence_position(order_index: int) -> Vector2:
    return _intro_letter_structure_position(_intro_label_index_for_brush_order(order_index))

func _intro_worders_structure_rect() -> Rect2:
    var min_pos = INTRO_LETTER_BASE - INTRO_LOGO_PADDING
    var max_pos = INTRO_LETTER_BASE + Vector2(
        INTRO_LETTER_STEP * float(WORDERS_TITLE.length() - 1) + INTRO_LETTER_WIDTH,
        INTRO_LETTER_HEIGHT
    ) + INTRO_LOGO_PADDING
    return Rect2(min_pos, max_pos - min_pos)

func _play_intro_animation() -> void:
    _set_menu_visible(false)
    var overlay = ColorRect.new()
    overlay.name = "WordersIntroOverlay"
    overlay.layout_mode = 0
    overlay.size = Vector2(1920, 1080)
    overlay.color = Color(0.01, 0.012, 0.02, 0.97)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(overlay)

    var center = Vector2(960, 500)
    _spawn_intro_atmosphere(overlay, center)
    var word_labels = _spawn_intro_words(overlay, center)
    _spawn_intro_brush(overlay, word_labels)

    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(overlay, "color:a", 0.0, 0.62).set_delay(INTRO_DURATION)
    tween.set_parallel(false)
    tween.tween_callback(func():
        _set_menu_visible(true)
        overlay.queue_free())

func _spawn_intro_words(parent: Control, center: Vector2) -> Array[Label]:
    var labels: Array[Label] = []
    var words = _make_intro_word_pool()
    for i in range(_intro_word_count()):
        var label = Label.new()
        label.text = words[i % words.size()]
        label.size = Vector2(86, 28)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.add_theme_color_override("font_color", _intro_word_color(i))
        label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
        label.add_theme_color_override("font_outline_color", Color(0.07, 0.025, 0.0, 0.82))
        label.add_theme_constant_override("outline_size", 2)
        label.add_theme_constant_override("shadow_offset_x", 2)
        label.add_theme_constant_override("shadow_offset_y", 2)
        label.add_theme_font_size_override("font_size", 13 + (i % 4))
        var start = _intro_start_position(i)
        var orbit = _intro_orbit_position(i, center)
        var final_target = _intro_letter_structure_position(i)
        label.position = start
        label.rotation = deg_to_rad(float((i % 11) - 5) * 5.0)
        label.scale = Vector2(0.76, 0.76)
        label.modulate.a = 0.0
        parent.add_child(label)
        labels.append(label)
        var tween = create_tween()
        tween.set_parallel(true)
        tween.tween_property(label, "modulate:a", 0.78, 0.55).set_delay(float(i % 16) * 0.035)
        tween.tween_property(label, "position", orbit, 1.55 + float(i % 7) * 0.06).set_delay(0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        tween.tween_property(label, "rotation", label.rotation * 0.36, 1.35).set_delay(0.22).set_trans(Tween.TRANS_SINE)
        tween.tween_property(label, "scale", Vector2(1.04, 1.04), 1.20).set_delay(0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        tween.tween_property(label, "position", final_target, 1.42 + float(i % 9) * 0.035).set_delay(2.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
        tween.tween_property(label, "rotation", 0.0, 1.24).set_delay(2.10).set_trans(Tween.TRANS_SINE)
        tween.tween_property(label, "scale", Vector2(0.64, 0.64), 0.92).set_delay(3.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
        tween.tween_property(label, "modulate:a", 0.40, 0.42).set_delay(3.28)
        tween.tween_property(label, "modulate:a", 0.0, 0.50).set_delay(INTRO_DURATION - 0.24)
    return labels

func _spawn_intro_brush(parent: Control, labels: Array[Label]) -> void:
    var brush = Panel.new()
    brush.size = Vector2(44, 34)
    brush.position = _intro_brush_sequence_position(0) - brush.size * 0.5 + Vector2(43, 14)
    brush.modulate.a = 0.0
    brush.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var brush_style = StyleBoxFlat.new()
    brush_style.bg_color = Color(1.0, 0.74, 0.18, 0.78)
    brush_style.corner_radius_top_left = 18
    brush_style.corner_radius_top_right = 18
    brush_style.corner_radius_bottom_left = 18
    brush_style.corner_radius_bottom_right = 18
    brush_style.shadow_color = Color(1.0, 0.42, 0.08, 0.55)
    brush_style.shadow_size = 12
    brush.add_theme_stylebox_override("panel", brush_style)
    parent.add_child(brush)

    var brush_tween = create_tween()
    brush_tween.tween_interval(INTRO_BRUSH_START)
    brush_tween.tween_property(brush, "modulate:a", 1.0, 0.16)
    for order_index in range(_intro_brush_sequence_count()):
        var target_position = _intro_brush_sequence_position(order_index) - brush.size * 0.5 + Vector2(43, 14)
        brush_tween.tween_property(brush, "position", target_position, INTRO_BRUSH_STEP).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    brush_tween.tween_property(brush, "modulate:a", 0.0, 0.28)
    brush_tween.tween_callback(brush.queue_free)

    for order_index in range(_intro_brush_sequence_count()):
        var label_index = _intro_label_index_for_brush_order(order_index)
        if label_index < 0 or label_index >= labels.size():
            continue
        var label = labels[label_index]
        var delay = INTRO_BRUSH_START + float(order_index) * INTRO_BRUSH_STEP
        var mark = Panel.new()
        mark.size = Vector2(34, 10)
        mark.position = _intro_brush_sequence_position(order_index) + Vector2(26, 17)
        mark.rotation = label.rotation
        mark.modulate.a = 0.0
        mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var mark_style = StyleBoxFlat.new()
        mark_style.bg_color = Color(1.0, 0.66, 0.14, 0.35)
        mark_style.corner_radius_top_left = 5
        mark_style.corner_radius_top_right = 5
        mark_style.corner_radius_bottom_left = 5
        mark_style.corner_radius_bottom_right = 5
        mark.add_theme_stylebox_override("panel", mark_style)
        parent.add_child(mark)

        var label_tween = create_tween()
        label_tween.set_parallel(true)
        label_tween.tween_property(label, "modulate:a", 1.0, 0.12).set_delay(delay)
        label_tween.tween_property(label, "scale", Vector2(0.82, 0.82), 0.16).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        label_tween.tween_property(mark, "modulate:a", 0.85, 0.08).set_delay(delay)
        label_tween.tween_property(mark, "modulate:a", 0.0, 0.30).set_delay(delay + 0.12)
        label_tween.set_parallel(false)
        label_tween.tween_callback(mark.queue_free)

func _intro_start_position(index: int) -> Vector2:
    var side = index % 4
    var step = float((index * 73) % 1000) / 1000.0
    match side:
        0:
            return Vector2(-190, 80 + step * 880)
        1:
            return Vector2(1940, 70 + step * 900)
        2:
            return Vector2(120 + step * 1680, -70)
        _:
            return Vector2(120 + step * 1680, 1110)

func _intro_orbit_position(index: int, center: Vector2) -> Vector2:
    var angle = float(index) * 0.46 + float(index % 5) * 0.21
    var radius_x = 520.0 - float(index % 9) * 22.0
    var radius_y = 255.0 - float(index % 7) * 14.0
    return center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y)

func _intro_letter_position(index: int) -> Vector2:
    return _intro_letter_structure_position(index)

func _intro_letter_structure_position(index: int) -> Vector2:
    var letter_index = index % WORDERS_TITLE.length()
    var point_index = int(index / WORDERS_TITLE.length())
    var origin = INTRO_LETTER_BASE + Vector2(float(letter_index) * INTRO_LETTER_STEP, 0.0)
    var width = INTRO_LETTER_WIDTH
    var height = INTRO_LETTER_HEIGHT
    match WORDERS_TITLE[letter_index]:
        "W":
            return _intro_w_point(origin, width, height, point_index)
        "O":
            return _intro_o_point(origin, width, height, point_index)
        "R":
            return _intro_r_point(origin, width, height, point_index)
        "D":
            return _intro_d_point(origin, width, height, point_index)
        "E":
            return _intro_e_point(origin, width, height, point_index)
        "S":
            return _intro_s_point(origin, width, height, point_index)
    return origin

func _line_point(a: Vector2, b: Vector2, local_index: int, count: int) -> Vector2:
    var t = float(local_index) / float(max(count - 1, 1))
    return a.lerp(b, t)

func _intro_w_point(origin: Vector2, width: float, height: float, point_index: int) -> Vector2:
    var count = int(ceil(float(WORDS_PER_LETTER) / 4.0))
    var segment = int(point_index / count)
    var local = point_index % count
    var points = [
        origin,
        origin + Vector2(width * 0.24, height),
        origin + Vector2(width * 0.50, height * 0.42),
        origin + Vector2(width * 0.76, height),
        origin + Vector2(width, 0),
    ]
    return _line_point(points[min(segment, 3)], points[min(segment + 1, 4)], local, count)

func _intro_o_point(origin: Vector2, width: float, height: float, point_index: int) -> Vector2:
    var angle = TAU * float(point_index) / float(WORDS_PER_LETTER)
    return origin + Vector2(width * 0.5 + cos(angle) * width * 0.48, height * 0.5 + sin(angle) * height * 0.48)

func _intro_r_point(origin: Vector2, width: float, height: float, point_index: int) -> Vector2:
    var stem_count = int(ceil(float(WORDS_PER_LETTER) * 0.34))
    var bowl_count = int(ceil(float(WORDS_PER_LETTER) * 0.38))
    var leg_count = max(WORDS_PER_LETTER - stem_count - bowl_count, 1)
    if point_index < stem_count:
        return _line_point(origin, origin + Vector2(0, height), point_index, stem_count)
    if point_index < stem_count + bowl_count:
        var angle = -PI * 0.5 + PI * float(point_index - stem_count) / float(max(bowl_count - 1, 1))
        return origin + Vector2(width * 0.40 + cos(angle) * width * 0.42, height * 0.26 + sin(angle) * height * 0.25)
    return _line_point(origin + Vector2(width * 0.18, height * 0.52), origin + Vector2(width, height), point_index - stem_count - bowl_count, leg_count)

func _intro_d_point(origin: Vector2, width: float, height: float, point_index: int) -> Vector2:
    var stem_count = int(ceil(float(WORDS_PER_LETTER) * 0.34))
    if point_index < stem_count:
        return _line_point(origin, origin + Vector2(0, height), point_index, stem_count)
    var arc_count = max(WORDS_PER_LETTER - stem_count, 1)
    var angle = -PI * 0.5 + PI * float(point_index - stem_count) / float(max(arc_count - 1, 1))
    return origin + Vector2(width * 0.18 + cos(angle) * width * 0.78, height * 0.5 + sin(angle) * height * 0.50)

func _intro_e_point(origin: Vector2, width: float, height: float, point_index: int) -> Vector2:
    var stem_count = int(ceil(float(WORDS_PER_LETTER) * 0.34))
    var top_count = int(ceil(float(WORDS_PER_LETTER) * 0.24))
    var middle_count = int(ceil(float(WORDS_PER_LETTER) * 0.20))
    var bottom_count = max(WORDS_PER_LETTER - stem_count - top_count - middle_count, 1)
    if point_index < stem_count:
        return _line_point(origin, origin + Vector2(0, height), point_index, stem_count)
    if point_index < stem_count + top_count:
        return _line_point(origin, origin + Vector2(width, 0), point_index - stem_count, top_count)
    if point_index < stem_count + top_count + middle_count:
        return _line_point(origin + Vector2(0, height * 0.50), origin + Vector2(width * 0.78, height * 0.50), point_index - stem_count - top_count, middle_count)
    return _line_point(origin + Vector2(0, height), origin + Vector2(width, height), point_index - stem_count - top_count - middle_count, bottom_count)

func _intro_s_point(origin: Vector2, width: float, height: float, point_index: int) -> Vector2:
    var segment_count = int(ceil(float(WORDS_PER_LETTER) / 5.0))
    var segment = int(point_index / segment_count)
    var local = point_index % segment_count
    match min(segment, 4):
        0:
            return _line_point(origin + Vector2(width, 0), origin, local, segment_count)
        1:
            return _line_point(origin, origin + Vector2(0, height * 0.50), local, segment_count)
        2:
            return _line_point(origin + Vector2(0, height * 0.50), origin + Vector2(width, height * 0.50), local, segment_count)
        3:
            return _line_point(origin + Vector2(width, height * 0.50), origin + Vector2(width, height), local, segment_count)
    var final_count = max(WORDS_PER_LETTER - segment_count * 4, 1)
    return _line_point(origin + Vector2(width, height), origin + Vector2(0, height), point_index - segment_count * 4, final_count)

func _spawn_intro_atmosphere(parent: Control, center: Vector2) -> void:
    for i in range(10):
        var glyph = Label.new()
        glyph.text = ["W", "O", "R", "D", "E", "R", "S", "文", "詞", "語"][i]
        glyph.size = Vector2(170, 120)
        glyph.position = center + Vector2(cos(float(i) * 0.72) * 520.0 - 85.0, sin(float(i) * 0.72) * 280.0 - 60.0)
        glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        glyph.add_theme_color_override("font_color", Color.WHITE)
        glyph.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.65))
        glyph.add_theme_constant_override("outline_size", 4)
        glyph.add_theme_font_size_override("font_size", 72)
        glyph.modulate.a = 0.0
        glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
        parent.add_child(glyph)
        var tween = create_tween()
        tween.set_parallel(true)
        tween.tween_property(glyph, "modulate:a", 0.18, 1.0).set_delay(0.38 + float(i % 4) * 0.12)
        tween.tween_property(glyph, "position", glyph.position + (center - glyph.position) * 0.16, 2.8).set_delay(0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        tween.tween_property(glyph, "modulate:a", 0.0, 1.0).set_delay(3.35)
        tween.set_parallel(false)
        tween.tween_callback(glyph.queue_free)

func _set_menu_visible(visible_state: bool) -> void:
    for node_name in ["MenuPanel", "TitleLabel", "SubtitleLabel", "StartButton", "SettingsButton", "HowToPlayButton", "QuitButton", "LanguageButton"]:
        if has_node(node_name):
            get_node(node_name).visible = visible_state
