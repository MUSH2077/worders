extends Control

var card_scene = preload("res://scenes/card.tscn")
var slot_panel_script = preload("res://scripts/slot_panel.gd")
var card_back_texture = preload("res://resources/art/card_back.png")
var constraint_validator_script = preload("res://scripts/constraint_validator.gd")
var tactical_stance_script = preload("res://scripts/tactical_stance.gd")
var chat_panel_helper = preload("res://scripts/battle_chat_panel.gd")
var debug_panel_scene = preload("res://scripts/battle_debug_panel.gd")
var codex_panel_scene = preload("res://scripts/battle_codex_panel.gd")
var battle_fx_director_script = preload("res://scripts/battle_fx_director.gd")

@onready var phase_label: Label = $PhaseLabel
@onready var score_preview_panel: ScorePreviewPanel = $ScorePreviewPanel
@onready var confirm_btn: Button = $ConfirmButton
@onready var auto_words_btn: Button = $AutoWordsButton
@onready var clear_sentence_btn: Button = $ClearSentenceButton
@onready var end_turn_btn: Button = $EndTurnButton
@onready var stance_option: OptionButton = $StanceOption
@onready var turn_timer_label: Label = $TurnTimerLabel
@onready var speed_btn: Button = $SpeedButton
@onready var language_btn: Button = $LanguageButton
@onready var game_over_label: Label = $GameOverLabel
@onready var log_label: Label = $LogLabel
@onready var slots_panel: ColorRect = $SlotsPanel
@onready var slots_container: HBoxContainer = $SlotsContainer
@onready var hand_category_bar: HBoxContainer = $HandCategoryBar
@onready var cards_panel: ColorRect = $CardsPanel
@onready var cards_container: Control = $CardsContainer
@onready var prev_page_btn: Button = $PrevPageButton
@onready var next_page_btn: Button = $NextPageButton
@onready var exit_btn: Button = $ExitButton
@onready var exit_dialog: ConfirmationDialog = $ExitDialog
@onready var fx_layer: Control = $FxLayer
@onready var opp_name: Label = $OpponentName
@onready var opp_hp: Label = $OpponentHP
@onready var opp_mana: Label = $OpponentMana
@onready var opp_deck: Label = $OpponentDeck
@onready var ply_name: Label = $PlayerName
@onready var ply_hp: Label = $PlayerHP
@onready var ply_mana: Label = $PlayerMana
@onready var ply_deck: Label = $PlayerDeck
@onready var player_role_panel: Panel = $PlayerRolePanel
@onready var ai_role_panel: Panel = $AIRolePanel
@onready var player_avatar_label: Label = $PlayerRolePanel/PlayerAvatarLabel
@onready var player_stats_label: Label = $PlayerRolePanel/PlayerStatsLabel
@onready var ai_avatar_label: Label = $AIRolePanel/AIAvatarLabel
@onready var ai_stats_label: Label = $AIRolePanel/AIStatsLabel
@onready var chat_panel: Panel = $ChatPanel
@onready var chat_title: Label = $ChatPanel/ChatTitle
@onready var chat_scroll: ScrollContainer = $ChatPanel/ChatScroll
@onready var chat_log: VBoxContainer = $ChatPanel/ChatScroll/ChatLog
@onready var emoji_bar: HBoxContainer = $ChatPanel/EmojiBar
@onready var chat_input: LineEdit = $ChatPanel/ChatInput
@onready var chat_send_btn: Button = $ChatPanel/ChatSendButton

const CHAT_LOG_MAX_LINES = 60

const HAND_PAGE_SIZE = 7
const CHAT_PRESETS = ["😊", "✨", "🛡️", "💥", "💚"]
const FILTER_ALL = -1
const FILTER_TYPE_BASE = -10

var _game_over_flag = false
var _is_submitting = false
var _hand_filter: int = FILTER_ALL
var _hand_page: int = 0
var _ai_intent_name: String = ""
var _low_hp_active: bool = false
var _low_hp_tween: Tween = null
var _ai_thinking_label: Label = null
var _ai_thinking_tween: Tween = null
var _chat_history: Array[Dictionary] = []
var _ally_chat_history: Array[Dictionary] = []
var _chat_request_in_flight: bool = false
var _chat_target: String = "enemy"
var _chat_tab_enemy: Button = null
var _chat_tab_ally: Button = null
var _debug_panel = null
var _debug_toggle_btn: Button = null
var _codex_panel = null
var _codex_btn: Button = null
var _fx_director: BattleFxDirector = null
var _objective_label: Label = null
var _start_words_btn: Button = null
var _word_fill_queue: Array = []
var _word_fill_active := false
var _layout_viewport_size := Vector2(1920, 1080)
var _last_hand_page_size := HAND_PAGE_SIZE

func _debug_log(msg: String) -> void:
	var f = FileAccess.open("user://export_debug.log", FileAccess.READ_WRITE)
	if f:
		f.seek_end()
		f.store_line("%s: %s" % [Time.get_datetime_string_from_system(), msg])
		f.close()

func _ready() -> void:
	_debug_log("battle_ui._ready() START")
	AudioDirector.play_music("battle")
	_fx_director = battle_fx_director_script.new(self, fx_layer)
	_setup_objective_label()
	_setup_start_words_button()
	resized.connect(func(): _apply_responsive_layout(size))
	_apply_visual_theme()
	_apply_responsive_layout(size)
	_hide_legacy_status_labels()
	_style_role_panel(player_role_panel, Color(0.38, 0.66, 1.0, 1))
	_style_role_panel(ai_role_panel, Color(1.0, 0.42, 0.28, 1))
	_style_chat_panel()
	_setup_chat_presets()
	_setup_support_panels()
	if cards_container.has_signal("card_double_clicked"):
		cards_container.card_double_clicked.connect(_on_hand_card_clicked)
	if cards_container.has_method("set_enabled"):
		cards_container.set_enabled(true)
	confirm_btn.pressed.connect(_on_confirm_pressed)
	auto_words_btn.pressed.connect(_on_auto_words_pressed)
	clear_sentence_btn.pressed.connect(_on_clear_sentence_pressed)
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	stance_option.item_selected.connect(_on_stance_selected)
	speed_btn.pressed.connect(BattleManager.cycle_animation_speed)
	language_btn.pressed.connect(I18n.toggle_language)
	I18n.language_changed.connect(_refresh_language)
	exit_btn.pressed.connect(func(): exit_dialog.popup_centered())
	exit_dialog.confirmed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	prev_page_btn.pressed.connect(_prev_hand_page)
	next_page_btn.pressed.connect(_next_hand_page)
	chat_send_btn.pressed.connect(_send_chat_from_input)
	chat_input.text_submitted.connect(func(_text): _send_chat_from_input())
	Events.word_input_requested.connect(_on_word_input)
	Events.score_calculated.connect(_on_score)
	Events.sentence_built.connect(_on_sentence_built_ui)
	Events.combat_resolved.connect(_on_combat_resolved)
	Events.event_triggered.connect(_on_event_triggered)
	Events.phase_changed.connect(_on_phase_changed)
	Events.turn_changed.connect(_on_turn)
	Events.game_over.connect(_on_game_over)
	Events.card_drawn.connect(func(_p): _update_hud())
	Events.card_added_to_deck.connect(func(_card): _update_hud())
	Events.player_hp_changed.connect(func(_p, _hp, _max_hp): _update_hud())
	Events.player_mana_changed.connect(func(_p, _mana, _max_mana): _update_hud())
	Events.turn_timer_changed.connect(_on_turn_timer_changed)
	Events.card_effect_resolved.connect(_on_card_effect_resolved)
	Events.ai_card_committed.connect(_on_ai_card_committed)
	Events.ai_word_filled.connect(_on_ai_word_filled)
	Events.animation_speed_changed.connect(_on_animation_speed_changed)
	Events.ai_intent_declared.connect(_on_ai_intent_declared)
	Events.stance_changed.connect(_on_stance_changed)
	Events.ai_stance_declared.connect(_on_ai_stance_declared)
	Events.rhetoric_combo_triggered.connect(_on_rhetoric_combo_triggered)
	Events.reward_choice_offered.connect(_on_reward_choice_offered)
	Events.event_choices_offered.connect(_on_event_choices_offered)
	Events.ai_emote_sent.connect(_on_ai_emote_sent)
	Events.ai_llm_plan_failed.connect(_on_ai_llm_plan_failed)
	Events.llm_status_changed.connect(_on_llm_status_changed)
	Events.ai_event_choice_declared.connect(_on_ai_event_choice_declared)
	Events.objective_offered.connect(_on_objective_offered)
	Events.objective_progress_updated.connect(_on_objective_progress_updated)
	Events.objective_completed.connect(_on_objective_completed)
	Events.archetype_seal_changed.connect(_on_archetype_seal_changed)
	Events.ai_profile_declared.connect(_on_ai_profile_declared)
	Events.word_judgment_completed.connect(_on_word_judgment_completed)
	BattleManager.start_battle()
	_debug_log("battle_ui: start_battle() done, player1=%s player2=%s" % [str(BattleManager.player1), str(BattleManager.player2)])
	_refresh_language()
	_setup_stance_option()
	_update_hud()
	_refresh_slots()
	_add_chat_message("System", I18n.t("system_chat"), Color(0.95, 0.82, 0.52, 1))
	_debug_log("battle_ui._ready() END")

func _can_drop_data(_pos: Vector2, data) -> bool:
	return _is_player_turn() and _is_supported_drag(data)

func _drop_data(_pos: Vector2, data) -> void:
	if not _is_player_turn():
		return
	if cards_panel.get_rect().has_point(_pos):
		var slot = _drag_slot(data)
		if slot:
			_return_slot_to_hand(slot)
		return
	if slots_panel.get_rect().has_point(_pos):
		_handle_slots_drop(data)

func _is_player_turn() -> bool:
	var cp = BattleManager.current_player
	return cp != null and not cp.is_ai and not _game_over_flag

func _is_supported_drag(data) -> bool:
	if data is CardData:
		return true
	return data is Dictionary and data.has("type")

func _drag_card(data) -> CardData:
	if data is CardData:
		return data
	if data is Dictionary and data.get("type", "") == "hand_card":
		return data.get("card", null) as CardData
	return null

func _drag_slot(data) -> SentenceBuilder.Slot:
	if data is Dictionary and data.get("type", "") == "sentence_slot":
		return data.get("slot", null) as SentenceBuilder.Slot
	return null

func _drag_source(data) -> Control:
	if data is Dictionary and data.has("source_node") and data["source_node"] is Control:
		return data["source_node"] as Control
	return null

func _on_confirm_pressed() -> void:
	if _game_over_flag:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
	_confirm_with_animation()

func _on_end_turn_pressed() -> void:
	if not _is_player_turn() or _is_submitting:
		return
	_word_fill_active = false
	_word_fill_queue.clear()
	confirm_btn.disabled = true
	auto_words_btn.disabled = true
	if _start_words_btn:
		_start_words_btn.disabled = true
	clear_sentence_btn.disabled = true
	end_turn_btn.disabled = true
	BattleManager.pass_turn("manual")

func _on_stance_selected(index: int) -> void:
	if not _is_player_turn():
		_sync_stance_option()
		return
	var stance = stance_option.get_item_id(index)
	BattleManager.set_current_stance(stance)
	_update_cost_preview()

func _on_animation_speed_changed(_speed: float) -> void:
	_refresh_speed_button()

func _on_auto_words_pressed() -> void:
	if not _is_player_turn():
		return
	AudioDirector.play_sfx("ui_confirm")
	var filled = 0
	for slot in BattleManager.sentence_builder.get_ordered_slots():
		if slot.word.strip_edges().is_empty():
			slot.word = _pick_word_for_slot(slot)
			filled += 1
	_refresh_slots()
	_update_cost_preview()
	_refresh_word_flow_button()
	if filled > 0:
		_set_label_animated(log_label, I18n.t("filled_slots") % filled)
		_spawn_rising_particles(_control_center(slots_panel), Color(0.45, 1.0, 0.58, 1), 8)
	else:
		_set_label_animated(log_label, I18n.t("no_empty_slots"))

func _on_clear_sentence_pressed() -> void:
	if not _is_player_turn():
		return
	AudioDirector.play_sfx("ui_cancel")
	var cp = BattleManager.current_player
	var slots = BattleManager.sentence_builder.get_ordered_slots()
	if slots.is_empty():
		_set_label_animated(log_label, I18n.t("sentence_empty"))
		return
	for slot in slots:
		cp.hand.append(slot.card)
	BattleManager.sentence_builder.clear()
	_word_fill_active = false
	_word_fill_queue.clear()
	_hand_filter = FILTER_ALL
	_hand_page = 0
	_refresh_hand(cp)
	_refresh_slots()
	_update_cost_preview()
	_refresh_word_flow_button()
	_flash_rect(_control_center(cards_panel), Color(0.45, 0.78, 1.0, 0.24), Vector2(420, 82))
	_set_label_animated(log_label, I18n.t("returned_all"))

func _confirm_with_animation() -> void:
	if _is_submitting:
		return
	if not BattleManager.sentence_builder.is_complete():
		BattleManager.confirm_sentence()
		return
	var cp = BattleManager.current_player
	if cp == null or BattleManager.sentence_builder.get_total_mana_cost() > cp.mana:
		BattleManager.confirm_sentence()
		return
	AudioDirector.play_sfx("sentence_submit")
	_is_submitting = true
	confirm_btn.disabled = true
	end_turn_btn.disabled = true
	var preview = BattleManager.preview_sentence(BattleManager.sentence_builder.get_sentence_input(), cp)
	await _animate_sentence_submit(preview)
	BattleManager.confirm_sentence()
	_is_submitting = false
	if _is_player_turn() and not BattleManager._ending_turn:
		confirm_btn.disabled = false
		end_turn_btn.disabled = false
		_refresh_word_flow_button()

func _play_card_from_hand(card: CardData, target_index: int = -1, source_node: Control = null) -> void:
	var cp = BattleManager.current_player
	if cp == null or cp.is_ai or not cp.hand.has(card):
		return
	if card.card_type != CardData.CardType.FILL:
		_use_special_card(card, source_node)
		return
	var start_pos = _control_center(source_node) if source_node else _control_center(cards_panel)
	AudioDirector.play_sfx("card_play")
	cp.remove_from_hand(card)
	_clamp_hand_page(cp)
	var slot = BattleManager.sentence_builder.add_card(card, target_index)
	_refresh_hand(cp)
	_refresh_slots()
	_update_cost_preview()
	var target_pos = _slot_center(slot)
	if _fx_director:
		_fx_director.play_card_to_slot(card, start_pos, target_pos)
	else:
		_spawn_flying_card(card, start_pos, target_pos)
		_spawn_play_particles(target_pos, _component_color(card.comp_constraint), 14)
	_pulse_slot(slot)
	_refresh_word_flow_button()
	_set_label_animated(log_label, I18n.t("cards_staged_start_words"))

func _use_special_card(card: CardData, source_node: Control = null) -> void:
	var cp = BattleManager.current_player
	if cp == null or cp.is_ai or not cp.hand.has(card):
		return
	var start_pos = _control_center(source_node) if source_node else _control_center(cards_panel)
	var target_panel = ai_role_panel if card.effect == CardData.CardEffect.WEAKEN else player_role_panel
	if BattleManager.play_special_card(card, cp):
		AudioDirector.play_sfx("card_play")
		_clamp_hand_page(cp)
		_refresh_hand(cp)
		_update_hud()
		_update_cost_preview()
		if _fx_director:
			_fx_director.play_card_to_slot(card, start_pos, _control_center(target_panel))
		else:
			_spawn_flying_card(card, start_pos, _control_center(target_panel))

func _handle_slots_drop(data) -> void:
	if not _is_player_turn():
		return
	var slot = _drag_slot(data)
	if slot:
		BattleManager.sentence_builder.move_slot(slot, BattleManager.sentence_builder.slots.size())
		_refresh_slots()
		_update_cost_preview()
		_pulse_slot(slot)
		_set_label_animated(log_label, I18n.t("order_updated"))
		return
	var card = _drag_card(data)
	if card:
		_play_card_from_hand(card, BattleManager.sentence_builder.slots.size(), _drag_source(data))

func _handle_slot_drop(data, target_slot: SentenceBuilder.Slot) -> void:
	if not _is_player_turn() or target_slot == null:
		return
	var target_index = BattleManager.sentence_builder.get_slot_index(target_slot)
	if target_index < 0:
		return
	var slot = _drag_slot(data)
	if slot:
		BattleManager.sentence_builder.move_slot(slot, target_index)
		_refresh_slots()
		_update_cost_preview()
		_pulse_slot(slot)
		_flash_rect(_slot_center(target_slot), Color(0.95, 0.72, 0.32, 0.55), Vector2(160, 84))
		_set_label_animated(log_label, I18n.t("order_updated"))
		return
	var card = _drag_card(data)
	if card:
		_play_card_from_hand(card, target_index, _drag_source(data))

func _handle_hand_drop(data) -> void:
	var slot = _drag_slot(data)
	if slot:
		_return_slot_to_hand(slot)

func _on_word_input(slot: SentenceBuilder.Slot) -> void:
	if slot == null:
		return
	var old_dialog = get_node_or_null("WordInputDialog")
	if old_dialog:
		old_dialog.queue_free()
	var dlg = AcceptDialog.new()
	dlg.name = "WordInputDialog"
	dlg.title = "%s · %s" % [I18n.t("write_word"), slot.card.get_display_name()]
	dlg.ok_button_text = I18n.t("write_word")
	dlg.min_size = Vector2i(720, 480)
	dlg.add_theme_stylebox_override("panel", UiTheme.panel_style("paper"))
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 22)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	var title = Label.new()
	title.text = slot.card.get_display_name()
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.46, 1))
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.0, 0.95))
	title.add_theme_constant_override("outline_size", 4)
	var hint = Label.new()
	hint.text = "%s / %s / %s" % [
		slot.card.get_pos_name(),
		slot.card.get_comp_name(),
		slot.card.get_content_name(),
	]
	hint.add_theme_color_override("font_color", Color(0.86, 0.94, 1.0, 1))
	hint.add_theme_font_size_override("font_size", 17)
	var tip = Label.new()
	tip.text = I18n.t("word_dialog_tip")
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_color_override("font_color", Color(1.0, 0.92, 0.70, 1.0))
	tip.add_theme_font_size_override("font_size", 16)
	var suggestion_panel = Panel.new()
	suggestion_panel.custom_minimum_size = Vector2(620, 190)
	suggestion_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.025, 0.032, 0.046, 0.96), Color(0.96, 0.68, 0.28, 0.86), 10, 2))
	var suggestion_margin = MarginContainer.new()
	suggestion_margin.layout_mode = 1
	suggestion_margin.anchors_preset = PRESET_FULL_RECT
	suggestion_margin.anchor_right = 1.0
	suggestion_margin.anchor_bottom = 1.0
	suggestion_margin.add_theme_constant_override("margin_left", 14)
	suggestion_margin.add_theme_constant_override("margin_top", 12)
	suggestion_margin.add_theme_constant_override("margin_right", 14)
	suggestion_margin.add_theme_constant_override("margin_bottom", 12)
	var suggestions = VBoxContainer.new()
	suggestions.name = "WordCandidateButtons"
	suggestions.custom_minimum_size = Vector2(580, 160)
	suggestions.add_theme_constant_override("separation", 8)
	var suggestion_title = Label.new()
	suggestion_title.text = I18n.t("try_words") + _suggest_words(slot)
	suggestion_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	suggestion_title.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1))
	suggestion_title.add_theme_font_size_override("font_size", 15)
	var buttons = VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 7)
	var le = LineEdit.new()
	le.name = "WordInputLineEdit"
	le.placeholder_text = I18n.t("word_placeholder")
	le.text = slot.word
	le.custom_minimum_size = Vector2(620, 54)
	le.add_theme_color_override("font_color", Color(1.0, 0.98, 0.9, 1))
	le.add_theme_color_override("font_placeholder_color", Color(0.78, 0.82, 0.90, 0.88))
	le.add_theme_font_size_override("font_size", 22)
	le.add_theme_stylebox_override("normal", _make_panel_style(Color(0.018, 0.024, 0.036, 0.98), Color(0.82, 0.62, 0.30, 0.92), 8, 2))
	le.add_theme_stylebox_override("focus", _make_panel_style(Color(0.05, 0.055, 0.072, 1.0), Color(1.0, 0.82, 0.34, 1.0), 8, 3))
	suggestions.add_child(suggestion_title)
	suggestions.add_child(buttons)
	suggestion_margin.add_child(suggestions)
	suggestion_panel.add_child(suggestion_margin)
	vbox.add_child(title)
	vbox.add_child(hint)
	vbox.add_child(tip)
	vbox.add_child(suggestion_panel)
	vbox.add_child(le)
	margin.add_child(vbox)
	dlg.add_child(margin)
	var submitted := false
	var commit := func():
		if submitted:
			return
		submitted = true
		slot.word = le.text.strip_edges()
		_refresh_slots()
		_update_cost_preview()
		dlg.hide()
		dlg.queue_free()
		_on_word_dialog_committed(slot)
	for word in _candidate_words_for_slot(slot, 3):
		var preview = _preview_with_slot_word(slot, word)
		var btn: WordCandidateButton = WordCandidateButton.new()
		btn.name = "WordCandidateButton"
		btn.apply_preview(word, preview, _constraint_state_for_word(slot, word))
		btn.custom_minimum_size = Vector2(580, 46)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_stylebox_override("normal", _make_panel_style(Color(0.055, 0.072, 0.11, 0.98), Color(0.86, 0.62, 0.26, 0.92), 8, 2))
		btn.add_theme_stylebox_override("hover", _make_panel_style(Color(0.10, 0.13, 0.20, 1.0), Color(1.0, 0.80, 0.34, 1.0), 8, 2))
		btn.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.17, 0.10, 0.045, 1.0), Color(1.0, 0.88, 0.46, 1.0), 8, 2))
		btn.pressed.connect(func():
			le.text = word
			commit.call()
		)
		buttons.add_child(btn)
	dlg.confirmed.connect(commit)
	le.text_submitted.connect(func(_text): commit.call())
	dlg.canceled.connect(func():
		_word_fill_active = false
		_word_fill_queue.clear()
		_refresh_word_flow_button()
		dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered(Vector2i(720, 480))
	le.grab_focus.call_deferred()

func _on_start_fill_words_pressed() -> void:
	_start_word_fill_sequence()

func _start_word_fill_sequence() -> void:
	if not _is_player_turn() or _is_submitting:
		return
	_word_fill_queue = _empty_sentence_slots()
	if _word_fill_queue.is_empty():
		_set_label_animated(log_label, I18n.t("no_empty_slots"))
		_word_fill_active = false
		_refresh_word_flow_button()
		return
	_word_fill_active = true
	_refresh_word_flow_button()
	_set_label_animated(log_label, I18n.t("word_flow_started") % _word_fill_queue.size())
	_open_next_word_fill_dialog()

func _open_next_word_fill_dialog() -> void:
	while not _word_fill_queue.is_empty():
		var slot = _word_fill_queue.pop_front()
		if _slot_needs_word(slot):
			Events.word_input_requested.emit(slot)
			return
	_word_fill_active = false
	_refresh_word_flow_button()
	_set_label_animated(log_label, I18n.t("word_flow_finished"))

func _on_word_dialog_committed(_slot: SentenceBuilder.Slot) -> void:
	_refresh_word_flow_button()
	if not _word_fill_active:
		return
	call_deferred("_continue_word_flow_after_dialog_close")

func _continue_word_flow_after_dialog_close() -> void:
	await get_tree().process_frame
	if _word_fill_active:
		_open_next_word_fill_dialog()

func _empty_sentence_slots() -> Array:
	var result: Array = []
	for slot in BattleManager.sentence_builder.get_ordered_slots():
		if _slot_needs_word(slot):
			result.append(slot)
	return result

func _slot_needs_word(slot) -> bool:
	return slot != null and BattleManager.sentence_builder.get_ordered_slots().has(slot) and slot.word.strip_edges().is_empty()

func _refresh_word_flow_button() -> void:
	if _start_words_btn == null:
		return
	var has_empty = not _empty_sentence_slots().is_empty()
	_start_words_btn.disabled = not _is_player_turn() or _is_submitting or _word_fill_active or not has_empty

func _suggest_words(slot: SentenceBuilder.Slot) -> String:
	var words = _candidate_words_for_slot(slot, 6)
	return ", ".join(words) if not words.is_empty() else I18n.t("free_text")

func _pick_word_for_slot(slot: SentenceBuilder.Slot) -> String:
	var candidates = _candidate_words_for_slot(slot, 6)
	if candidates.is_empty():
		return "word"
	var best_word = candidates[0]
	var best_value = -INF
	for word in candidates:
		var preview = _preview_with_slot_word(slot, word)
		var value = _word_candidate_value(preview)
		if value > best_value:
			best_value = value
			best_word = word
	return best_word

func _candidate_words_for_slot(slot: SentenceBuilder.Slot, limit: int = 3) -> Array[String]:
	var words: Array[String] = []
	if slot == null or slot.card == null or limit <= 0:
		return words
	var pos_f = CardData.PartOfSpeech.keys()[slot.card.pos_constraint]
	var cat_f = CardData.ContentCategory.keys()[slot.card.content_constraint]
	var exclude = _words_already_in_sentence()
	var entries = WordBank.sample_by_constraints(pos_f, cat_f, limit * 3, _word_candidate_rng(), exclude)
	for entry in entries:
		if words.size() >= limit:
			break
		var text = str(entry.text).strip_edges()
		if text.is_empty() or words.has(text):
			continue
		words.append(text)
	if words.is_empty():
		words.append("word")
	return words

func _word_candidate_rng() -> RandomNumberGenerator:
	var rng = RandomNumberGenerator.new()
	rng.seed = BattleManager.battle_seed + TurnManager.current_turn_number * 997 + _empty_sentence_slots().size() * 131
	return rng

func _words_already_in_sentence() -> Array[String]:
	var used: Array[String] = []
	for slot in BattleManager.sentence_builder.get_ordered_slots():
		if slot == null:
			continue
		var text = str(slot.word).strip_edges()
		if not text.is_empty() and not used.has(text):
			used.append(text)
	return used

func _append_candidate_words(words: Array[String], entries: Array, limit: int) -> void:
	for entry in entries:
		if words.size() >= limit:
			return
		if entry == null:
			continue
		var text = str(entry.text).strip_edges()
		if text.is_empty() or words.has(text):
			continue
		words.append(text)

func _word_candidate_label(slot: SentenceBuilder.Slot, word: String) -> String:
	var preview = _preview_with_slot_word(slot, word)
	var state = _constraint_state_for_word(slot, word)
	var state_text = "OK"
	if state == "risk":
		state_text = "RISK"
	elif state == "unknown":
		state_text = "FREE"
	return "%s  ATK %d DEF %d CRT %d %s" % [word, preview.atk, preview.def_, preview.crt, state_text]

func _preview_with_slot_word(slot: SentenceBuilder.Slot, word: String) -> ScoringEngine.ScoreBreakdown:
	var input = ScoringEngine.SentenceInput.new()
	var slots: Array = []
	if BattleManager.sentence_builder:
		slots = BattleManager.sentence_builder.get_ordered_slots()
	if slot != null and slots.has(slot):
		for existing in slots:
			input.cards.append(existing.card)
			input.words.append(word if existing == slot else existing.word)
			input.components.append(existing.get_component())
	elif slot != null:
		input.cards.append(slot.card)
		input.words.append(word)
		input.components.append(slot.get_component())
	var stance = BattleManager.current_player.current_stance if BattleManager.current_player else 0
	return ScoringEngine.calculate_with_stance(input, BattleManager.rhyme_map, stance)

func _word_candidate_value(preview: ScoringEngine.ScoreBreakdown) -> float:
	return float(preview.atk) + float(preview.def_) + float(preview.crt) * 0.6 + preview.constraint_bonus * 2.0 - preview.constraint_penalty_percent * 100.0

func _constraint_state_for_word(slot: SentenceBuilder.Slot, word: String) -> String:
	if slot == null:
		return "unknown"
	var input = ScoringEngine.SentenceInput.new()
	input.cards.append(slot.card)
	input.words.append(word)
	input.components.append(slot.get_component())
	var result = ConstraintValidator.validate(input)
	if result.penalty_percent > 0.0:
		return "risk"
	for flag in result.flags:
		if str(flag).ends_with(":UNKNOWN"):
			return "unknown"
	return "match"

func _on_score(b: ScoringEngine.ScoreBreakdown) -> void:
	if _debug_panel:
		_debug_panel.record_score(b)
	_refresh_score_preview(b, false)

func _on_sentence_built_ui(input: ScoringEngine.SentenceInput) -> void:
	_refresh_slots()
	if BattleManager.current_player and BattleManager.current_player.is_ai and input.words.size() > 0:
		_set_label_animated(log_label, I18n.t("ai_sentence") % " ".join(input.words))
		var stance = BattleManager.current_player.current_stance
		var preview = ScoringEngine.calculate_with_stance(input, BattleManager.rhyme_map, stance)
		await _animate_sentence_submit(preview)

func _on_ai_card_committed(card: CardData, _slot_index: int) -> void:
	_refresh_slots()
	_show_opponent_hand(BattleManager.current_player)
	_update_cost_preview()
	var target_pos = _slot_center(BattleManager.sentence_builder.slots.back()) if not BattleManager.sentence_builder.slots.is_empty() else _control_center(slots_panel)
	if _fx_director:
		_fx_director.play_card_to_slot(card, _control_center(ai_role_panel), target_pos)
	else:
		_spawn_flying_card(card, _control_center(ai_role_panel), target_pos)
		_spawn_play_particles(target_pos, _component_color(card.comp_constraint), 10)
	_set_label_animated(log_label, I18n.t("ai_play_card_intent") % [card.get_display_name(), _ai_intent_label(_ai_intent_name)])

func _on_ai_word_filled(slot: SentenceBuilder.Slot, word: String) -> void:
	_refresh_slots()
	_update_cost_preview()
	_pulse_slot(slot)
	_spawn_floating_number(word, _slot_center(slot), _component_color(slot.get_component()), 30)
	_spawn_rising_particles(_slot_center(slot), _component_color(slot.get_component()), 8)
	_set_label_animated(log_label, I18n.t("ai_fill_word") % word)

func _on_ai_intent_declared(strategy_name: String) -> void:
	_ai_intent_name = strategy_name
	_pulse_control(ai_role_panel, Color(1.0, 0.62, 0.28, 0.28))
	_spawn_ring(_control_center(ai_role_panel), Color(1.0, 0.62, 0.28, 0.86), 18)
	_set_label_animated(log_label, I18n.t("ai_intent") % _ai_intent_label(strategy_name))

func _on_stance_changed(player: Player, _stance: int) -> void:
	if player == BattleManager.current_player:
		_sync_stance_option()
		_update_cost_preview()

func _on_ai_stance_declared(strategy_name: String, stance_name: String) -> void:
	_flash_rect(_control_center(ai_role_panel), Color(1.0, 0.72, 0.32, 0.18), Vector2(160, 90))
	_set_label_animated(log_label, I18n.t("ai_stance") % [_ai_intent_label(strategy_name), _stance_label_by_key(stance_name)])

func _on_ai_profile_declared(profile_name: String, archetype: String, weakness: String) -> void:
	var text = I18n.t("ai_profile_log") % [profile_name, _archetype_label(archetype), weakness]
	_set_label_animated(log_label, text)
	_flash_rect(_control_center(ai_role_panel), _archetype_color(archetype) * Color(1, 1, 1, 0.22), Vector2(210, 110))

func _on_archetype_seal_changed(player: Player, archetype: String) -> void:
	if player == BattleManager.player1:
		_add_chat_message("System", I18n.t("player_seal_log") % _archetype_label(archetype), Color(0.95, 0.82, 0.52, 1))
	_refresh_objective_label()

func _on_objective_offered(player: Player, objective) -> void:
	if player != BattleManager.current_player:
		return
	_refresh_objective_label()
	if objective:
		_set_label_animated(log_label, I18n.t("objective_offered_log") % I18n.t(objective.name))
		_flash_rect(_control_center(score_preview_panel) + Vector2(0, 34), _archetype_color(objective.archetype) * Color(1, 1, 1, 0.20), Vector2(720, 46))

func _on_objective_progress_updated(player: Player, objective, _state: Dictionary) -> void:
	if player == BattleManager.current_player and objective:
		_refresh_objective_label()

func _on_objective_completed(player: Player, objective, reward_text: String) -> void:
	if objective == null:
		return
	var who = "AI" if player and player.is_ai else I18n.t("player")
	var text = I18n.t("objective_completed_log") % [who, I18n.t(objective.name), reward_text]
	_set_label_animated(log_label, text)
	_add_chat_message("System", text, _archetype_color(objective.archetype))
	_spawn_burst(_control_center(score_preview_panel) + Vector2(0, 38), _archetype_color(objective.archetype), 18, "*", Vector2(320, 48))
	_refresh_objective_label()

func _on_ai_event_choice_declared(choice, reason: String) -> void:
	if choice == null:
		return
	var text = I18n.t(choice.name)
	if not reason.strip_edges().is_empty():
		text += " · " + reason.left(36)
	_set_label_animated(log_label, "AI " + text)
	_spawn_floating_number(text, _control_center(ai_role_panel) + Vector2(0, 46), _archetype_color(choice.preferred_archetype), 26)
	_flash_rect(_control_center(ai_role_panel), _archetype_color(choice.preferred_archetype) * Color(1, 1, 1, 0.24), Vector2(210, 90))

func _on_phase_changed(phase_name: String) -> void:
	match phase_name:
		"SCORING":
			_stop_ai_thinking_anim()
			_show_phase_banner(I18n.t("phase_scoring"), Color(1.0, 0.86, 0.35, 0.28))
		"RESOLVE":
			_show_phase_banner(I18n.t("phase_resolve"), Color(1.0, 0.42, 0.28, 0.22))
		"EVENT":
			_show_phase_banner(I18n.t("phase_event"), Color(0.72, 0.48, 1.0, 0.20))
		"END":
			_show_phase_banner(I18n.t("phase_end"), Color(0.35, 0.78, 1.0, 0.20))

func _on_combat_resolved(result: CombatResolver.CombatResult) -> void:
	if _fx_director:
		_fx_director.play_combat_result(result)
	if _debug_panel:
		_debug_panel.record_combat(result)
	var crit_text = " CRIT!" if result.was_crit else ""
	_set_label_animated(log_label, "Damage %d, shield %d, heal %d.%s" % [
		result.damage_dealt,
		result.shield_gained,
		result.heal_amount,
		crit_text,
	])
	var attacker_panel = player_role_panel if BattleManager.current_player == BattleManager.player1 else ai_role_panel
	var defender_panel = ai_role_panel if BattleManager.current_player == BattleManager.player1 else player_role_panel
	if result.damage_dealt > 0:
		_spawn_burst(_control_center(defender_panel), Color(1.0, 0.36, 0.18, 1), 24, "*", Vector2(210, 72))
		_pulse_control(defender_panel, Color(1.0, 0.36, 0.18, 0.28))
		_spawn_floating_number("-%d" % result.damage_dealt, _control_center(defender_panel), Color(1.0, 0.36, 0.18, 1), 44)
	if result.shield_gained > 0:
		_spawn_ring(_control_center(attacker_panel), Color(0.35, 0.78, 1.0, 0.95), 18)
		_pulse_control(attacker_panel, Color(0.35, 0.78, 1.0, 0.22))
		_spawn_floating_number("+%d盾" % result.shield_gained, _control_center(attacker_panel) + Vector2(30, 0), Color(0.35, 0.78, 1.0, 1), 36)
	if result.heal_amount > 0:
		_spawn_rising_particles(_control_center(attacker_panel), Color(0.45, 1.0, 0.58, 1), 12)
		_spawn_floating_number("+%d血" % result.heal_amount, _control_center(attacker_panel) + Vector2(-30, -20), Color(0.45, 1.0, 0.58, 1), 36)
	if result.was_crit:
		_screen_shake()
		_flash_screen(Color(1.0, 0.86, 0.32, 0.28))
		_spawn_floating_number("暴击！", _control_center(defender_panel) + Vector2(0, -58), Color(1.0, 0.86, 0.32, 1), 52)
	_update_hud()

func _on_event_triggered(event_type: String) -> void:
	if _debug_panel:
		_debug_panel.record_event(event_type)
	var messages = {
		"reward": I18n.t("event_reward"),
		"shop": I18n.t("event_shop"),
		"curse": I18n.t("event_curse"),
		"incomplete": I18n.t("event_incomplete"),
		"no_mana": I18n.t("event_no_mana"),
		"ai_pass": I18n.t("event_ai_pass"),
		"focus": I18n.t("event_focus"),
		"spring": I18n.t("event_spring"),
		"calm": I18n.t("event_calm"),
		"turn_timeout": I18n.t("turn_timeout"),
		"turn_passed": I18n.t("turn_passed"),
		"event_choice_take_card": I18n.t("event_choice_take_card_log"),
		"event_choice_empower": I18n.t("event_choice_empower_log"),
		"event_choice_refine": I18n.t("event_choice_refine_log"),
		"event_choice_cleanse": I18n.t("event_choice_cleanse_log"),
		"event_choice_charge": I18n.t("event_choice_charge_log"),
	}
	_set_label_animated(log_label, messages.get(event_type, "Event: " + event_type))
	var colors = {
		"reward": Color(0.45, 1.0, 0.58, 0.36),
		"shop": Color(0.95, 0.72, 0.32, 0.36),
		"curse": Color(0.72, 0.32, 1.0, 0.36),
		"incomplete": Color(1.0, 0.42, 0.28, 0.30),
		"no_mana": Color(0.35, 0.78, 1.0, 0.30),
		"focus": Color(0.35, 0.78, 1.0, 0.30),
		"spring": Color(0.45, 1.0, 0.58, 0.30),
		"calm": Color(0.86, 0.91, 0.98, 0.18),
		"turn_timeout": Color(1.0, 0.42, 0.28, 0.28),
		"turn_passed": Color(0.35, 0.78, 1.0, 0.22),
		"event_choice_take_card": Color(0.45, 1.0, 0.58, 0.30),
		"event_choice_empower": Color(0.95, 0.72, 0.32, 0.30),
		"event_choice_refine": Color(0.86, 0.91, 1.0, 0.24),
		"event_choice_cleanse": Color(0.72, 0.48, 1.0, 0.24),
		"event_choice_charge": Color(0.35, 0.78, 1.0, 0.24),
	}
	if colors.has(event_type):
		_flash_rect(_control_center(log_label), colors[event_type], Vector2(680, 46))
	if event_type in ["turn_timeout", "turn_passed"]:
		_refresh_slots()
		if BattleManager.current_player and not BattleManager.current_player.is_ai:
			_refresh_hand(BattleManager.current_player)
	_update_hud()

func _on_turn_timer_changed(seconds_left: int) -> void:
	turn_timer_label.text = I18n.t("timer") % seconds_left
	if seconds_left <= 10 and seconds_left > 0:
		turn_timer_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.28, 1))
		_pulse_control(turn_timer_label, Color(1.0, 0.42, 0.28, 0.24))
	else:
		turn_timer_label.add_theme_color_override("font_color", Color(0.92, 0.82, 0.58, 1))

func _on_card_effect_resolved(card: CardData, player: Player, effect_type: String, _amount: int) -> void:
	var who = "AI" if player.is_ai else I18n.t("player")
	_set_label_animated(log_label, I18n.t("card_effect_log") % [who, card.get_display_name()])
	var panel = ai_role_panel if player.is_ai else player_role_panel
	match effect_type:
		"DRAW":
			_spawn_rising_particles(_control_center(cards_panel), Color(0.95, 0.72, 0.32, 1), 8)
		"SHIELD":
			_spawn_ring(_control_center(panel), Color(0.35, 0.78, 1.0, 0.95), 16)
			_pulse_control(panel, Color(0.35, 0.78, 1.0, 0.22))
		"HEAL":
			_spawn_rising_particles(_control_center(panel), Color(0.45, 1.0, 0.58, 1), 10)
		"MANA":
			_spawn_burst(_control_center(panel), Color(0.55, 0.76, 1.0, 1), 12, "*", Vector2(82, 42))
		"WEAKEN":
			var target_panel = player_role_panel if player.is_ai else ai_role_panel
			_spawn_burst(_control_center(target_panel), Color(1.0, 0.36, 0.18, 1), 18, "*", Vector2(160, 58))
			_pulse_control(target_panel, Color(1.0, 0.36, 0.18, 0.24))
		"CLEANSE":
			_flash_rect(_control_center(panel), Color(0.72, 0.48, 1.0, 0.22), Vector2(220, 120))
		"STEAL":
			var steal_src = ai_role_panel if player.is_ai else player_role_panel
			var steal_dst_panel = player_role_panel if player.is_ai else ai_role_panel
			_spawn_burst(_control_center(steal_src), Color(0.95, 0.72, 0.32, 1), 16, "★", Vector2(140, 60))
			_spawn_flying_card(card, _control_center(steal_src), _control_center(steal_dst_panel))
		"SEAL":
			var seal_target_panel = player_role_panel if player.is_ai else ai_role_panel
			_flash_rect(_control_center(seal_target_panel), Color(0.52, 0.22, 0.72, 0.42), Vector2(220, 120))
			_spawn_ring(_control_center(seal_target_panel), Color(0.52, 0.22, 0.72, 0.9), 16)
		"ECHO":
			_spawn_ring(_control_center(panel), Color(0.35, 0.95, 0.86, 0.9), 20)
			_flash_rect(_control_center(panel), Color(0.35, 0.95, 0.86, 0.22), Vector2(240, 130))
	_update_hud()

func _on_hand_card_clicked(card: CardData) -> void:
	if not _is_player_turn() or card == null:
		return
	if card.card_type != CardData.CardType.FILL:
		_use_special_card(card)

func _on_turn(player: Player) -> void:
	_is_submitting = false
	if _debug_panel:
		_debug_panel.record_turn(player)
	_stop_ai_thinking_anim()
	_update_hud()
	_refresh_slots()
	if player and not player.is_ai:
		_set_label_animated(phase_label, I18n.t("your_turn"))
		confirm_btn.disabled = false
		auto_words_btn.disabled = false
		_refresh_word_flow_button()
		clear_sentence_btn.disabled = false
		end_turn_btn.disabled = false
		stance_option.disabled = false
		_refresh_hand(player)
		_set_label_animated(log_label, I18n.t("log_ready"))
		_pulse_control(player_role_panel, Color(0.38, 0.66, 1.0, 0.26))
	else:
		_set_label_animated(phase_label, I18n.t("ai_turn"))
		confirm_btn.disabled = true
		auto_words_btn.disabled = true
		if _start_words_btn:
			_start_words_btn.disabled = true
		clear_sentence_btn.disabled = true
		end_turn_btn.disabled = true
		stance_option.disabled = true
		_show_opponent_hand(player)
		_set_label_animated(log_label, I18n.t("log_ai"))
		_pulse_control(ai_role_panel, Color(1.0, 0.42, 0.28, 0.24))
		_start_ai_thinking_anim()
	_refresh_objective_label()

func _refresh_hand(player: Player) -> void:
	_debug_log("_refresh_hand() player=%s hand_size=%d" % [player.player_name, player.hand.size()])
	_refresh_hand_categories(player)
	var filtered = _get_filtered_hand(player)
	_debug_log("_refresh_hand() visible_cards=%d" % filtered.size())
	if cards_container.has_method("set_enabled"):
		cards_container.set_enabled(_is_player_turn())
	if cards_container.has_method("set_cards"):
		cards_container.set_cards(filtered)
	prev_page_btn.visible = false
	next_page_btn.visible = false
	if filtered.is_empty():
		var empty = Label.new()
		empty.text = I18n.t("no_cards")
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.size = cards_container.size
		empty.add_theme_color_override("font_color", Color(0.86, 0.91, 0.98, 0.72))
		empty.add_theme_font_size_override("font_size", 18)
		cards_container.add_child(empty)
	_refresh_word_flow_button()

func _show_opponent_hand(p: Player) -> void:
	if not p:
		return
	for c in hand_category_bar.get_children():
		c.queue_free()
	prev_page_btn.visible = false
	next_page_btn.visible = false
	if cards_container.has_method("set_enabled"):
		cards_container.set_enabled(false)
	if cards_container.has_method("set_card_backs"):
		cards_container.set_card_backs(p.hand.size(), card_back_texture)

func _refresh_slots() -> void:
	for c in slots_container.get_children():
		c.queue_free()
	var ordered = BattleManager.sentence_builder.get_ordered_slots()
	if ordered.is_empty():
		var hint = Label.new()
		hint.text = I18n.t("drag_hint")
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.add_theme_color_override("font_color", Color(0.92, 0.82, 0.58, 0.82))
		hint.add_theme_font_size_override("font_size", 18)
		slots_container.add_child(hint)
		_refresh_word_flow_button()
		return
	for slot in ordered:
		var panel = slot_panel_script.new()
		panel.slot_ref = slot
		panel.custom_minimum_size = Vector2(150, 92)
		var slot_color = _component_color(slot.card.comp_constraint)
		var border_color = _constraint_slot_color(slot, slot_color)
		panel.add_theme_stylebox_override("panel", _make_panel_style(
			Color(0.08 + slot_color.r * 0.08, 0.09 + slot_color.g * 0.07, 0.12 + slot_color.b * 0.07, 0.92),
			border_color,
			8,
			1
		))

		var vbox = VBoxContainer.new()
		vbox.layout_mode = 1
		vbox.anchors_preset = PRESET_FULL_RECT
		vbox.anchor_right = 1.0
		vbox.anchor_bottom = 1.0
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_theme_constant_override("separation", 2)
		panel.add_child(vbox)

		var comp_lbl = Label.new()
		comp_lbl.text = slot.card.get_comp_name()
		comp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		comp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		comp_lbl.add_theme_color_override("font_color", slot_color)
		comp_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(comp_lbl)

		var word_lbl = Label.new()
		word_lbl.text = slot.word if slot.is_filled() else I18n.t("double_click_write")
		word_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		word_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		word_lbl.add_theme_color_override("font_color", Color(0.96, 0.97, 1, 1) if slot.is_filled() else Color(0.56, 0.6, 0.68, 1))
		word_lbl.add_theme_font_size_override("font_size", 16)
		vbox.add_child(word_lbl)

		var chip = SlotContributionChip.new()
		chip.name = "SlotContributionChip"
		chip.visible = false
		vbox.add_child(chip)

		panel.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed:
				if ev.button_index == MOUSE_BUTTON_LEFT and ev.double_click:
					Events.word_input_requested.emit(slot)
				elif ev.button_index == MOUSE_BUTTON_RIGHT:
					_return_card_to_hand(slot.card))
		slots_container.add_child(panel)
	_refresh_slot_contributions()
	_refresh_word_flow_button()

func _refresh_slot_contributions() -> void:
	var ordered = BattleManager.sentence_builder.get_ordered_slots()
	if ordered.is_empty() or BattleManager.current_player == null:
		return
	var input = BattleManager.sentence_builder.get_sentence_input()
	if input.length() == 0:
		return
	var stance = BattleManager.current_player.current_stance
	var deltas = ScoringEngine.compute_slot_deltas(input, BattleManager.rhyme_map, stance)
	for i in range(ordered.size()):
		var slot = ordered[i]
		for child in slots_container.get_children():
			if child.get("slot_ref") != slot:
				continue
			var chip = child.find_child("SlotContributionChip", true, false) as SlotContributionChip
			if chip == null:
				break
			if slot.is_filled() and i < deltas.size():
				chip.set_deltas(deltas[i])
			else:
				chip.visible = false
			break

func _update_cost_preview() -> void:
	var current_mana = BattleManager.current_player.mana if BattleManager.current_player else 0
	var cost = BattleManager.sentence_builder.get_total_mana_cost()
	var input = BattleManager.sentence_builder.get_sentence_input()
	if score_preview_panel == null:
		return
	if input.length() == 0:
		score_preview_panel.update_mana_only(cost, current_mana)
		_refresh_objective_label(input)
		return
	var breakdown = BattleManager.preview_sentence(input, BattleManager.current_player)
	score_preview_panel.update_preview(
		breakdown,
		cost,
		current_mana,
		not BattleManager.sentence_builder.is_complete(),
	)
	_refresh_slot_contributions()
	_refresh_objective_label(input, breakdown)

func _refresh_score_preview(b: ScoringEngine.ScoreBreakdown, partial: bool) -> void:
	if score_preview_panel == null:
		return
	var cost = BattleManager.sentence_builder.get_total_mana_cost()
	var mana = BattleManager.current_player.mana if BattleManager.current_player else 0
	score_preview_panel.update_preview(b, cost, mana, partial)
	_refresh_objective_label(BattleManager.sentence_builder.get_sentence_input(), b)
	_update_hud()

func _update_hud() -> void:
	var p1 = BattleManager.player1
	var p2 = BattleManager.player2
	if p1:
		ply_name.text = I18n.t("player")
		ply_hp.text = "%s %d/%d  %s %d" % [I18n.t("hp"), p1.hp, p1.max_hp, I18n.t("shield"), p1.shield]
		ply_mana.text = "%s %d/%d" % [I18n.t("mana"), p1.mana, p1.max_mana]
		ply_deck.text = "%s %d" % [I18n.t("deck"), p1.deck.size()]
		player_avatar_label.text = I18n.t("you")
		player_stats_label.text = "%d/%d\n%d/%d" % [p1.hp, p1.max_hp, p1.mana, p1.max_mana]
		if player_role_panel.has_method("set_player"):
			player_role_panel.set_player(p1, false)
		# Low HP warning pulse
		var hp_ratio = float(p1.hp) / float(p1.max_hp)
		if hp_ratio <= 0.3 and not _low_hp_active:
			_low_hp_active = true
			_start_low_hp_pulse()
		elif hp_ratio > 0.3 and _low_hp_active:
			_stop_low_hp_pulse()
	if p2:
		opp_name.text = "AI"
		opp_hp.text = "%s %d/%d  %s %d" % [I18n.t("hp"), p2.hp, p2.max_hp, I18n.t("shield"), p2.shield]
		opp_mana.text = "%s %d/%d" % [I18n.t("mana"), p2.mana, p2.max_mana]
		opp_deck.text = "%s %d" % [I18n.t("deck"), p2.deck.size()]
		ai_avatar_label.text = "AI"
		ai_stats_label.text = "%d/%d\n%d/%d" % [p2.hp, p2.max_hp, p2.mana, p2.max_mana]
		if ai_role_panel.has_method("set_player"):
			ai_role_panel.set_player(p2, true)

func _refresh_language() -> void:
	language_btn.text = I18n.t("lang_button")
	exit_btn.text = I18n.t("exit_battle")
	exit_dialog.title = I18n.t("exit_dialog_title")
	exit_dialog.ok_button_text = I18n.t("exit_dialog_ok")
	exit_dialog.cancel_button_text = I18n.t("exit_dialog_cancel")
	exit_dialog.dialog_text = I18n.t("exit_dialog_text")
	confirm_btn.text = I18n.t("confirm_play")
	confirm_btn.tooltip_text = I18n.t("confirm_play_tooltip")
	auto_words_btn.text = I18n.t("auto_words")
	auto_words_btn.tooltip_text = I18n.t("auto_words_tooltip")
	if _start_words_btn:
		_start_words_btn.text = I18n.t("start_words")
		_start_words_btn.tooltip_text = I18n.t("start_words_tooltip")
	clear_sentence_btn.text = I18n.t("clear")
	clear_sentence_btn.tooltip_text = I18n.t("clear_tooltip")
	end_turn_btn.text = I18n.t("end_turn")
	end_turn_btn.tooltip_text = I18n.t("end_turn_tooltip")
	turn_timer_label.text = I18n.t("timer") % int(BattleManager.turn_seconds_left)
	if score_preview_panel:
		score_preview_panel.tooltip_text = I18n.t("score_preview_tooltip")
	stance_option.tooltip_text = I18n.t("stance_tooltip")
	_refresh_speed_button()
	prev_page_btn.text = I18n.t("prev")
	next_page_btn.text = I18n.t("next")
	chat_title.text = I18n.t("chat")
	chat_input.placeholder_text = I18n.t("message")
	chat_send_btn.text = I18n.t("send")
	if _chat_tab_enemy:
		_chat_tab_enemy.text = I18n.t("chat_tab_enemy")
		_chat_tab_ally.text = I18n.t("chat_tab_ally")
		_update_chat_tabs()
	if _debug_toggle_btn:
		_debug_toggle_btn.text = I18n.t("debug")
	if _codex_btn:
		_codex_btn.text = I18n.t("codex")
	if _codex_panel:
		_codex_panel.title = I18n.t("codex_title")
		_codex_panel.refresh()
	_setup_stance_option()
	_update_hud()
	_refresh_slots()
	_update_cost_preview()
	_refresh_objective_label()
	_refresh_word_flow_button()

func _hide_legacy_status_labels() -> void:
	for label in [opp_name, opp_hp, opp_mana, opp_deck, ply_name, ply_hp, ply_mana, ply_deck]:
		label.visible = false

func _apply_visual_theme() -> void:
	if has_node("Background"):
		var bg = get_node("Background") as TextureRect
		if bg and UiTheme.asset_texture("battle_background_ink_overlay"):
			bg.texture = UiTheme.asset_texture("battle_background_ink_overlay")
			bg.modulate = Color(1, 1, 1, 1)
	if has_node("Shade"):
		$Shade.color = Color(0.018, 0.014, 0.012, 0.10)
	if not has_node("InkOverlay"):
		var overlay = TextureRect.new()
		overlay.name = "InkOverlay"
		overlay.layout_mode = 0
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.texture = UiTheme.asset_texture("ui_panel_ink_dark")
		overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		overlay.stretch_mode = TextureRect.STRETCH_TILE
		overlay.modulate = Color(1, 1, 1, 0.035)
		add_child(overlay)
		move_child(overlay, 2)
	if has_node("OpponentBg"):
		_ensure_texture_backing("OpponentBgTexture", $OpponentBg, UiTheme.asset_texture("ui_panel_ink_dark"), Color(1.0, 0.50, 0.28, 0.38))
		$OpponentBg.color = Color(0.08, 0.028, 0.018, 0.28)
	if has_node("PlayerBg"):
		_ensure_texture_backing("PlayerBgTexture", $PlayerBg, UiTheme.asset_texture("ui_panel_ink_dark"), Color(0.34, 0.68, 1.0, 0.34))
		$PlayerBg.color = Color(0.018, 0.036, 0.07, 0.28)
	for panel in [player_role_panel, ai_role_panel, chat_panel]:
		if panel:
			panel.add_theme_stylebox_override("panel", UiTheme.panel_style("tool"))
	for rect in [slots_panel, cards_panel]:
		if rect:
			rect.color = Color(0.022, 0.028, 0.040, 0.42)
	if slots_panel:
		_ensure_texture_backing("SlotsPanelTexture", slots_panel, UiTheme.asset_texture("ui_panel_paper_gold"), Color(1.0, 0.84, 0.48, 0.36))
	if cards_panel:
		_ensure_texture_backing("CardsPanelTexture", cards_panel, UiTheme.asset_texture("ui_panel_ink_dark"), Color(0.70, 0.82, 1.0, 0.48))
	for button in [confirm_btn, auto_words_btn, clear_sentence_btn, end_turn_btn, speed_btn, language_btn, exit_btn, _start_words_btn]:
		if button == null:
			continue
		UiTheme.apply_button(button, "danger" if button == exit_btn else "primary" if button == confirm_btn else "normal")
	prev_page_btn.visible = false
	next_page_btn.visible = false
	if stance_option:
		stance_option.add_theme_stylebox_override("normal", UiTheme.button_style("ghost"))
		stance_option.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72, 1))
	for label in [phase_label, log_label]:
		if label:
			label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
			label.add_theme_constant_override("shadow_offset_x", 2)
			label.add_theme_constant_override("shadow_offset_y", 3)
	if score_preview_panel:
		score_preview_panel.add_theme_stylebox_override("panel", UiTheme.panel_style("tool"))

func _apply_responsive_layout(viewport_size: Vector2 = Vector2(1920, 1080)) -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1920, 1080)
	_layout_viewport_size = viewport_size
	var scale = min(viewport_size.x / 1920.0, viewport_size.y / 1080.0)
	var offset = (viewport_size - Vector2(1920, 1080) * scale) * 0.5
	var top_level = [
		"Background", "Shade", "InkOverlay", "OpponentBg", "PlayerBg", "ExitButton", "LanguageButton",
		"OpponentBgTexture", "PlayerBgTexture", "SlotsPanelTexture", "CardsPanelTexture",
		"PhaseLabel", "TurnTimerLabel", "SpeedButton", "ScorePreviewPanel", "LogLabel", "AIRolePanel",
		"ObjectiveLabel",
		"SlotsPanel", "SlotsContainer", "HandCategoryBar", "CardsPanel", "CardsContainer",
		"PlayerRolePanel", "ChatPanel", "PrevPageButton", "NextPageButton", "FxLayer",
		"StanceOption", "ConfirmButton", "AutoWordsButton", "StartWordsButton", "ClearSentenceButton", "EndTurnButton",
		"GameOverLabel", "DebugToggleButton", "CodexButton", "BattleDebugPanel"
	]
	for node_name in top_level:
		if has_node(node_name):
			_apply_scaled_rect(get_node(node_name) as Control, scale, offset)
	if BattleManager.current_player and not BattleManager.current_player.is_ai and cards_container.has_method("card_count") and int(cards_container.call("card_count")) > 0:
		cards_container.call_deferred("_layout_cards")

func _apply_scaled_rect(control: Control, scale: float, offset: Vector2) -> void:
	if control == null:
		return
	if not control.has_meta("worders_base_rect"):
		control.set_meta("worders_base_rect", Rect2(control.position, control.size))
	var base: Rect2 = control.get_meta("worders_base_rect")
	control.position = offset + base.position * scale
	control.size = base.size * scale
	if control.name in ["AIRolePanel", "PlayerRolePanel"]:
		control.scale = Vector2.ONE
	if control.name == "FxLayer":
		control.position = Vector2.ZERO
		control.size = Vector2(1920, 1080)

func _ensure_texture_backing(node_name: String, target: Control, texture: Texture2D, tint: Color) -> void:
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
		move_child(backing, max(target.get_index(), 0))
	backing.texture = texture
	backing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backing.stretch_mode = TextureRect.STRETCH_SCALE
	backing.modulate = tint
	backing.position = target.position - Vector2(8, 8)
	backing.size = target.size + Vector2(16, 16)
	backing.set_meta("worders_base_rect", Rect2(backing.position, backing.size))

func _style_role_panel(panel: Panel, border_color: Color) -> void:
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.018, 0.024, 0.036, 0.92), border_color, 10, 2))
	panel.self_modulate = Color(border_color.r, border_color.g, border_color.b, 0.96)
	panel.pivot_offset = panel.size * 0.5

func _style_chat_panel() -> void:
	chat_panel_helper.style_panel(chat_panel, UiTheme.panel_style("tool"))
	chat_title.text = I18n.t("chat")
	chat_input.placeholder_text = I18n.t("message")
	chat_send_btn.text = I18n.t("send")
	UiTheme.apply_input(chat_input)
	UiTheme.apply_button(chat_send_btn, "primary")
	_style_chat_scrollbar()

func _style_chat_scrollbar() -> void:
	if chat_scroll == null:
		return
	var bar = chat_scroll.get_v_scroll_bar()
	if bar == null:
		return
	bar.add_theme_stylebox_override("scroll", _make_panel_style(Color(0.02, 0.025, 0.038, 0.6), Color(0.4, 0.34, 0.2, 0.4), 4, 1))
	bar.add_theme_stylebox_override("grabber", _make_panel_style(Color(0.62, 0.46, 0.2, 0.85), Color(0.92, 0.68, 0.28, 0.9), 4, 1))
	bar.add_theme_stylebox_override("grabber_highlight", _make_panel_style(Color(0.86, 0.64, 0.28, 0.95), Color(1.0, 0.82, 0.4, 1.0), 4, 1))
	bar.add_theme_stylebox_override("grabber_pressed", _make_panel_style(Color(1.0, 0.78, 0.36, 1.0), Color(1.0, 0.88, 0.5, 1.0), 4, 1))

func _setup_support_panels() -> void:
	_debug_toggle_btn = Button.new()
	_debug_toggle_btn.name = "DebugToggleButton"
	_debug_toggle_btn.text = I18n.t("debug")
	_debug_toggle_btn.position = Vector2(1716, 128)
	_debug_toggle_btn.size = Vector2(78, 38)
	_debug_toggle_btn.focus_mode = Control.FOCUS_NONE
	_debug_toggle_btn.pressed.connect(_toggle_debug_panel)
	add_child(_debug_toggle_btn)

	_codex_btn = Button.new()
	_codex_btn.name = "CodexButton"
	_codex_btn.text = I18n.t("codex")
	_codex_btn.position = Vector2(1802, 128)
	_codex_btn.size = Vector2(78, 38)
	_codex_btn.focus_mode = Control.FOCUS_NONE
	_codex_btn.pressed.connect(_show_card_codex)
	add_child(_codex_btn)

	_debug_panel = debug_panel_scene.new()
	_debug_panel.name = "BattleDebugPanel"
	_debug_panel.position = Vector2(1518, 174)
	_debug_panel.visible = false
	_debug_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.025, 0.032, 0.046, 0.92), Color(0.95, 0.72, 0.32, 0.78), 8, 1))
	add_child(_debug_panel)

	_codex_panel = codex_panel_scene.new()
	_codex_panel.name = "BattleCodexPanel"
	add_child(_codex_panel)
	_apply_responsive_layout(size)

func _setup_objective_label() -> void:
	if _objective_label != null:
		return
	_objective_label = Label.new()
	_objective_label.name = "ObjectiveLabel"
	_objective_label.position = Vector2(420, 300)
	_objective_label.size = Vector2(1080, 38)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_objective_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.50, 0.96))
	_objective_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
	_objective_label.add_theme_constant_override("shadow_offset_x", 2)
	_objective_label.add_theme_constant_override("shadow_offset_y", 3)
	_objective_label.add_theme_font_size_override("font_size", 18)
	_objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_objective_label)

func _setup_start_words_button() -> void:
	if _start_words_btn != null:
		return
	_start_words_btn = Button.new()
	_start_words_btn.name = "StartWordsButton"
	_start_words_btn.position = Vector2(890, 970)
	_start_words_btn.size = Vector2(170, 60)
	_start_words_btn.text = I18n.t("start_words")
	_start_words_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_start_words_btn.add_theme_font_size_override("font_size", 18)
	_start_words_btn.pressed.connect(_on_start_fill_words_pressed)
	add_child(_start_words_btn)
	_start_words_btn.set_meta("worders_base_rect", Rect2(_start_words_btn.position, _start_words_btn.size))

func _refresh_objective_label(input: ScoringEngine.SentenceInput = null, breakdown: ScoringEngine.ScoreBreakdown = null) -> void:
	if _objective_label == null:
		return
	var player = BattleManager.current_player
	if player == null or player.current_objective == null:
		_objective_label.text = I18n.t("objective_none")
		return
	if input == null:
		input = BattleManager.sentence_builder.get_sentence_input()
	if breakdown == null:
		breakdown = BattleManager.preview_sentence(input, player)
	var state = BattleManager.evaluate_active_objective(player, input, breakdown)
	_objective_label.text = _format_objective(player.current_objective, state)

func _format_objective(objective, state: Dictionary) -> String:
	var marker = I18n.t("objective_state_pending")
	match str(state.get("state", "empty")):
		"complete":
			marker = I18n.t("objective_state_ready")
		"partial":
			marker = I18n.t("objective_state_partial")
		"empty":
			marker = I18n.t("objective_state_empty")
	return "%s: %s | %s | %s %s" % [
		I18n.t("objective_title"),
		I18n.t(objective.name),
		marker,
		I18n.t("objective_reward"),
		objective.reward_summary(),
	]

func _toggle_debug_panel() -> void:
	if _debug_panel:
		_debug_panel.visible = not _debug_panel.visible

func _show_card_codex() -> void:
	if _codex_panel:
		_codex_panel.refresh()
		_codex_panel.popup_centered()

func _setup_stance_option() -> void:
	if stance_option == null:
		return
	stance_option.clear()
	for stance in [
		tactical_stance_script.Stance.BALANCED,
		tactical_stance_script.Stance.BREAK,
		tactical_stance_script.Stance.GUARD,
		tactical_stance_script.Stance.HARMONY,
	]:
		stance_option.add_item(I18n.t(tactical_stance_script.label_key(stance)), stance)
	_sync_stance_option()

func _sync_stance_option() -> void:
	if stance_option == null:
		return
	var stance = tactical_stance_script.Stance.BALANCED
	if BattleManager.current_player:
		stance = BattleManager.current_player.current_stance
	for i in range(stance_option.item_count):
		if stance_option.get_item_id(i) == stance:
			stance_option.select(i)
			break
	stance_option.disabled = not _is_player_turn() or _is_submitting

func _refresh_speed_button() -> void:
	speed_btn.text = I18n.t("speed_button") % int(BattleManager.animation_speed)

func _new_anim_tween() -> Tween:
	return create_tween().set_speed_scale(BattleManager.animation_speed / 2.0)

func _make_panel_style(bg: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
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
	return style

func _setup_chat_presets() -> void:
	for child in emoji_bar.get_children():
		child.queue_free()
	for preset in CHAT_PRESETS:
		var btn = Button.new()
		btn.text = preset
		btn.custom_minimum_size = Vector2(42, 34)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		btn.add_theme_font_size_override("font_size", 20)
		btn.add_theme_stylebox_override("normal", _make_panel_style(Color(0.08, 0.1, 0.16, 0.92), Color(0.95, 0.62, 0.18, 0.82), 6, 1))
		btn.add_theme_stylebox_override("hover", _make_panel_style(Color(0.16, 0.2, 0.3, 0.96), Color(1.0, 0.78, 0.28, 1.0), 6, 1))
		btn.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.22, 0.16, 0.08, 0.96), Color(1.0, 0.88, 0.38, 1.0), 6, 1))
		btn.pressed.connect(func(): _send_chat_message(preset, true))
		emoji_bar.add_child(btn)
	_setup_chat_tabs()

func _setup_chat_tabs() -> void:
	if _chat_tab_enemy == null:
		_chat_tab_enemy = Button.new()
		_chat_tab_enemy.name = "ChatTabEnemy"
		_chat_tab_enemy.focus_mode = Control.FOCUS_NONE
		_chat_tab_enemy.position = Vector2(150, 6)
		_chat_tab_enemy.size = Vector2(64, 28)
		_chat_tab_enemy.add_theme_font_size_override("font_size", 13)
		_chat_tab_enemy.pressed.connect(func(): _set_chat_target("enemy"))
		chat_panel.add_child(_chat_tab_enemy)
	if _chat_tab_ally == null:
		_chat_tab_ally = Button.new()
		_chat_tab_ally.name = "ChatTabAlly"
		_chat_tab_ally.focus_mode = Control.FOCUS_NONE
		_chat_tab_ally.position = Vector2(218, 6)
		_chat_tab_ally.size = Vector2(62, 28)
		_chat_tab_ally.add_theme_font_size_override("font_size", 13)
		_chat_tab_ally.pressed.connect(func(): _set_chat_target("ally"))
		chat_panel.add_child(_chat_tab_ally)
	_chat_tab_enemy.text = I18n.t("chat_tab_enemy")
	_chat_tab_ally.text = I18n.t("chat_tab_ally")
	_update_chat_tabs()

func _set_chat_target(target: String) -> void:
	_chat_target = target
	_update_chat_tabs()
	var hint = I18n.t("chat_target_enemy") if target == "enemy" else I18n.t("chat_target_ally")
	chat_input.placeholder_text = hint

func _update_chat_tabs() -> void:
	if _chat_tab_enemy == null or _chat_tab_ally == null:
		return
	var enemy_active = _chat_target == "enemy"
	_style_chat_tab(_chat_tab_enemy, enemy_active, Color(1.0, 0.55, 0.32, 1.0))
	_style_chat_tab(_chat_tab_ally, not enemy_active, Color(0.46, 0.80, 1.0, 1.0))

func _style_chat_tab(btn: Button, active: bool, accent: Color) -> void:
	var bg = Color(accent.r * 0.32, accent.g * 0.32, accent.b * 0.32, 0.96) if active else Color(0.05, 0.06, 0.085, 0.9)
	var border = accent if active else Color(0.4, 0.45, 0.56, 0.7)
	btn.add_theme_stylebox_override("normal", _make_panel_style(bg, border, 6, 2 if active else 1))
	btn.add_theme_stylebox_override("hover", _make_panel_style(bg, accent, 6, 2))
	btn.add_theme_stylebox_override("pressed", _make_panel_style(bg, accent, 6, 2))
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1) if active else Color(0.7, 0.74, 0.82, 1))

func _send_chat_from_input() -> void:
	var text = chat_input.text.strip_edges()
	if text.is_empty():
		return
	chat_input.text = ""
	if text.to_lower().begins_with("/worders"):
		await _handle_worders_command(text)
		return
	if BattleSkillRegistry.is_skill_command(text):
		_handle_skill_command(text)
		return
	if text.begins_with("/"):
		_add_chat_message("System", "Unknown command. Try /help.", Color(0.95, 0.72, 0.52, 1))
		return
	var routed = _route_chat_target(text)
	if routed["agent"] == "ally":
		await _handle_ally_chat(routed["text"])
		return
	_send_chat_message(routed["text"], false)

# Decides which agent a plain chat line targets. "@ally"/"@己方" → ally helper,
# "@enemy"/"@敌方" or default → enemy table-talk.
func _route_chat_target(text: String) -> Dictionary:
	var lower = text.to_lower()
	for prefix in ["@ally", "@己方", "@队友"]:
		if lower.begins_with(prefix) or text.begins_with(prefix):
			return {"agent": "ally", "text": text.substr(prefix.length()).strip_edges()}
	for prefix in ["@enemy", "@敌方", "@对手"]:
		if lower.begins_with(prefix) or text.begins_with(prefix):
			return {"agent": "enemy", "text": text.substr(prefix.length()).strip_edges()}
	return {"agent": _chat_target, "text": text}

func _handle_ally_chat(text: String) -> void:
	if text.is_empty():
		return
	if _chat_request_in_flight:
		_add_chat_message("System", "Assistant is still replying...", Color(0.82, 0.84, 0.9, 1))
		return
	_add_chat_message("You", text, Color(0.76, 0.84, 1, 1))
	if not LLMClient.is_enabled_for_battle():
		_add_chat_message("Ally", "DeepSeek ally is off. Use /worders <text>, /suggest, /fill, /play, /stance, /preview, /confirm.", Color(0.86, 0.94, 1.0, 1))
		return
	_ally_chat_history.append({"role": "user", "content": text})
	_trim_ally_history()
	_chat_request_in_flight = true
	chat_send_btn.disabled = true
	var old_placeholder = chat_input.placeholder_text
	chat_input.placeholder_text = "Ally thinking..."
	var context = _build_ally_context()
	var response = await LLMClient.request_ally_assist(context, text, _ally_chat_history, I18n.language)
	if response.get("ok", false):
		var reply = str(response.get("reply", "")).strip_edges()
		if not reply.is_empty():
			_add_chat_message("Ally", reply, Color(0.86, 0.94, 1.0, 1))
			_ally_chat_history.append({"role": "assistant", "content": reply})
			_trim_ally_history()
		await _apply_ally_tool_calls(response.get("tool_calls", []))
	else:
		var reason = str(response.get("fallback_reason", ""))
		_add_chat_message("Ally", "I can't reach DeepSeek now — try slash commands like /suggest or /fill.", Color(0.86, 0.94, 1.0, 1))
		if reason != "not_configured" and response.has("error"):
			_add_chat_message("System", "DeepSeek offline: " + str(response.get("error", "")), Color(0.88, 0.74, 0.52, 1))
	_chat_request_in_flight = false
	chat_send_btn.disabled = false
	chat_input.placeholder_text = old_placeholder

func _apply_ally_tool_calls(tool_calls: Array) -> void:
	var ui_dirty = false
	for call in tool_calls:
		if not (call is Dictionary):
			continue
		var name = str(call.get("name", ""))
		var args = call.get("arguments", {})
		if not (args is Dictionary):
			args = {}
		if name == "say":
			var line = str(args.get("message", "")).strip_edges()
			if not line.is_empty():
				_add_chat_message("Ally", line, Color(0.86, 0.94, 1.0, 1))
			continue
		if name == "auto_build_sentence":
			var build_text = str(args.get("text", "")).strip_edges()
			if not build_text.is_empty():
				await _handle_worders_command("/worders " + build_text)
			continue
		var mapped = LLMClient.ally_tool_to_command(name, args)
		var command = str(mapped.get("command", ""))
		if command.is_empty():
			continue
		var result = BattleSkillRegistry.execute(command, mapped.get("args", []))
		var color = Color(0.74, 0.94, 1.0, 1) if result.ok else Color(0.95, 0.72, 0.52, 1)
		_add_chat_message("Ally", result.message, color)
		Events.ally_skill_result.emit(result.command, result.to_dict())
		if result.ok and result.kind in ["fill", "play", "stance"]:
			ui_dirty = true
	if ui_dirty:
		_refresh_slots()
		if BattleManager.current_player:
			_refresh_hand(BattleManager.current_player)
		_update_cost_preview()

func _trim_ally_history() -> void:
	while _ally_chat_history.size() > 8:
		_ally_chat_history.remove_at(0)

func _build_ally_context() -> Dictionary:
	var context = _build_llm_battle_context()
	var player = BattleManager.current_player if BattleManager.current_player and not BattleManager.current_player.is_ai else BattleManager.player1
	var hand: Array = []
	if player:
		for card in player.hand:
			if card == null:
				continue
			hand.append({
				"id": card.id,
				"name": card.get_display_name(),
				"type": CardData.TYPE_LABELS[card.card_type],
				"cost": card.mana_cost,
				"component": CardData.COMPONENT_LABELS[card.comp_constraint],
				"part_of_speech": CardData.POS_LABELS[card.pos_constraint],
				"theme": CardData.CONTENT_LABELS[card.content_constraint],
			})
	context["hand"] = hand
	var slots: Array = []
	var ordered = BattleManager.sentence_builder.get_ordered_slots()
	for i in range(ordered.size()):
		var slot = ordered[i]
		slots.append({
			"index": i,
			"component": slot.card.get_comp_name(),
			"part_of_speech": slot.card.get_pos_name(),
			"theme": slot.card.get_content_name(),
			"word": slot.word,
			"filled": slot.is_filled(),
		})
	context["slots"] = slots
	context["available_mana"] = player.mana if player else 0
	return context

func _handle_skill_command(raw: String) -> void:
	_add_chat_message("You", raw, Color(0.76, 0.84, 1, 1))
	var result = BattleSkillRegistry.execute_raw(raw)
	var color = Color(0.74, 0.94, 1.0, 1) if result.ok else Color(0.95, 0.72, 0.52, 1)
	_add_chat_message("Ally", result.message, color)
	Events.ally_skill_result.emit(result.command, result.to_dict())
	if result.ok and result.kind in ["fill", "play", "stance"]:
		_refresh_slots()
		if BattleManager.current_player:
			_refresh_hand(BattleManager.current_player)
		_update_cost_preview()

func _handle_worders_command(raw_text: String) -> void:
	var body = raw_text.strip_edges()
	if body.to_lower().begins_with("/worders"):
		body = body.substr(8).strip_edges()
	if body.is_empty():
		_add_chat_message("System", "Usage: /worders your sentence or paragraph", Color(0.95, 0.82, 0.52, 1))
		return
	if not _is_player_turn():
		_add_chat_message("System", "WORDERS command is only available during your turn.", Color(0.95, 0.72, 0.52, 1))
		return
	var tokens: Array[String] = []
	if LLMClient.is_ready_for_requests() or not LLMClient.mock_worders_segmentation_response.is_empty():
		var response = await LLMClient.request_worders_segmentation(body, _build_llm_battle_context(), I18n.language)
		if response.get("ok", false):
			for token in response.get("tokens", []):
				var clean = str(token).strip_edges()
				if not clean.is_empty() and not tokens.has(clean):
					tokens.append(clean)
	if tokens.is_empty():
		tokens = _segment_worders_text(body)
	if tokens.is_empty():
		_add_chat_message("System", "WORDERS: no usable words found.", Color(0.95, 0.82, 0.52, 1))
		return
	var result = _worders_autobuild(tokens)
	_refresh_slots()
	if BattleManager.current_player:
		_refresh_hand(BattleManager.current_player)
	_update_cost_preview()
	var committed: Array = result.get("committed", [])
	var filled: Array = result.get("filled", [])
	var unused: Array = result.get("unused", [])
	var unfilled: Array = result.get("unfilled", [])
	if filled.is_empty() and committed.is_empty():
		var reason = result.get("reason", "")
		if reason == "no_cards":
			_add_chat_message("System", I18n.t("worders_no_cards"), Color(0.95, 0.72, 0.52, 1))
		else:
			_add_chat_message("System", "WORDERS: nothing could be placed.", Color(0.95, 0.72, 0.52, 1))
		return
	if not committed.is_empty():
		_add_chat_message("Ally", I18n.t("worders_committed") % ", ".join(_stringify_array(committed)), Color(0.86, 0.94, 1.0, 1))
	var labels: Array[String] = []
	for item in filled:
		if item is Dictionary:
			labels.append("%s=%s" % [str(item.get("slot", "")), str(item.get("word", ""))])
			var slot_ref = item.get("slot_ref", null)
			if slot_ref is SentenceBuilder.Slot:
				_pulse_slot(slot_ref)
				_spawn_play_particles(_slot_center(slot_ref), Color(0.95, 0.72, 0.32, 1), 8)
	if not labels.is_empty():
		_add_chat_message("System", "WORDERS filled: " + ", ".join(labels), Color(0.74, 0.94, 1.0, 1))
	_add_chat_message("Ally", I18n.t("worders_built"), Color(0.86, 0.94, 1.0, 1))
	if not unused.is_empty():
		_add_chat_message("System", "Unused: " + ", ".join(_stringify_array(unused).slice(0, 8)), Color(0.86, 0.82, 0.66, 1))
	if not unfilled.is_empty():
		_add_chat_message("System", "Still empty: " + str(unfilled.size()), Color(0.86, 0.82, 0.66, 1))

# Auto-builds a sentence from segmented tokens: commits matching fill cards from
# hand (biased toward subject+predicate so the sentence is valid), respecting
# mana, then assigns every token to an empty slot. Player only needs to confirm.
func _worders_autobuild(tokens: Array) -> Dictionary:
	var player = BattleManager.current_player
	var builder = BattleManager.sentence_builder
	if player == null:
		return {"committed": [], "filled": [], "unused": tokens, "unfilled": [], "reason": "no_player"}
	var token_list: Array[String] = []
	for t in tokens:
		_add_worders_token(token_list, str(t))
	var committed: Array[String] = []
	var safety = 0
	const MAX_SENTENCE_SLOTS = 6
	while safety < 12:
		safety += 1
		var empty_count = _count_empty_slots()
		if empty_count >= token_list.size():
			break
		if builder.slots.size() >= MAX_SENTENCE_SLOTS:
			break
		var card = _pick_autobuild_card(player, builder, token_list)
		if card == null:
			break
		var projected = builder.get_total_mana_cost() + max(1, card.mana_cost)
		if projected > player.mana:
			break
		player.remove_from_hand(card)
		var slot = builder.add_card(card)
		Events.ai_card_committed.emit(card, builder.get_slot_index(slot))
		committed.append(card.get_display_name())
	if committed.is_empty() and _count_empty_slots() == 0:
		return {"committed": [], "filled": [], "unused": token_list, "unfilled": [], "reason": "no_cards"}
	var assignment = _assign_words_to_empty_slots(token_list)
	return {
		"committed": committed,
		"filled": assignment.get("filled", []),
		"unused": assignment.get("unused", []),
		"unfilled": assignment.get("unfilled", []),
	}

func _count_empty_slots() -> int:
	var count = 0
	for slot in BattleManager.sentence_builder.get_ordered_slots():
		if slot.word.strip_edges().is_empty():
			count += 1
	return count

func _missing_required_components() -> Array:
	var present: Dictionary = {}
	for slot in BattleManager.sentence_builder.get_ordered_slots():
		present[slot.get_component()] = true
	var missing: Array = []
	for req in StructureValidator.REQUIRED_COMPONENTS:
		if not present.has(req):
			missing.append(req)
	return missing

# Picks the next fill card to auto-commit: prefers cards whose component fills a
# missing required role (subject/predicate), then best token fit.
func _pick_autobuild_card(player, builder, tokens: Array) -> CardData:
	var hand_fill: Array[CardData] = []
	for card in player.hand:
		if card != null and card.card_type == CardData.CardType.FILL:
			hand_fill.append(card)
	if hand_fill.is_empty():
		return null
	var missing = _missing_required_components()
	var best: CardData = null
	var best_score = -INF
	for card in hand_fill:
		if max(1, card.mana_cost) + builder.get_total_mana_cost() > player.mana:
			continue
		var score = _best_token_fit_score(card, tokens)
		if card.comp_constraint in missing:
			score += 100.0
		if score > best_score:
			best_score = score
			best = card
	return best

func _best_token_fit_score(card: CardData, tokens: Array) -> float:
	if tokens.is_empty():
		return card.base_disorder
	var best = -INF
	for token in tokens:
		var s = _score_card_for_word(card, str(token))
		if s > best:
			best = s
	return best

func _score_card_for_word(card: CardData, word: String) -> float:
	var input = ScoringEngine.SentenceInput.new()
	input.cards.append(card)
	input.words.append(word)
	input.components.append(card.comp_constraint)
	var constraint = ConstraintValidator.validate(input)
	var score = card.base_disorder
	score += constraint.bonus * 10.0
	score -= constraint.penalty_percent * 140.0
	if not WordBank.find_entries(word).is_empty():
		score += 4.0
	return score

func _segment_worders_text(raw_text: String) -> Array[String]:
	var text = raw_text.strip_edges()
	if text.to_lower().begins_with("/worders"):
		text = text.substr(8).strip_edges()
	var normalized = text
	for sep in [",", ".", ";", ":", "!", "?", "\n", "\r", "\t", "，", "。", "；", "：", "！", "？", "、", "“", "”", "\"", "'", "(", ")", "[", "]", "{", "}"]:
		normalized = normalized.replace(sep, " ")
	var result: Array[String] = []
	for part in normalized.split(" ", false):
		# CJK has no spaces, so a whole clause arrives as one part. Split it into
		# dictionary words via longest-match instead of treating it as one token.
		if _has_cjk(part):
			for word in _segment_cjk_run(part):
				_add_worders_token(result, word)
		else:
			_add_worders_token(result, part)
	return result

func _has_cjk(text: String) -> bool:
	for i in range(text.length()):
		var c = text.unicode_at(i)
		if c >= 0x4E00 and c <= 0x9FFF:
			return true
	return false

# Greedy longest-match dictionary segmentation over the word bank for a run of
# CJK characters. Unmatched runs of >=2 chars are kept as candidate tokens
# (e.g. names not in the bank); isolated leftover chars are dropped as particles.
func _segment_cjk_run(run: String) -> Array[String]:
	var words: Array[String] = []
	var max_len = 5
	var i = 0
	var pending = ""
	while i < run.length():
		var matched = ""
		var upper = min(max_len, run.length() - i)
		for length in range(upper, 0, -1):
			var sub = run.substr(i, length)
			if not WordBank.find_entries(sub).is_empty():
				matched = sub
				break
		if matched != "":
			if pending.length() >= 2:
				words.append(pending)
			pending = ""
			words.append(matched)
			i += matched.length()
		else:
			pending += run.substr(i, 1)
			i += 1
	if pending.length() >= 2:
		words.append(pending)
	if words.is_empty() and run.length() >= 2:
		var j = 0
		while j < run.length():
			words.append(run.substr(j, 2))
			j += 2
	return words

func _assign_words_to_empty_slots(tokens: Array) -> Dictionary:
	var open_slots: Array[SentenceBuilder.Slot] = []
	for slot in BattleManager.sentence_builder.get_ordered_slots():
		if slot.word.strip_edges().is_empty():
			open_slots.append(slot)
	var remaining_tokens: Array[String] = []
	for token in tokens:
		_add_worders_token(remaining_tokens, str(token))
	var filled: Array[Dictionary] = []
	while not open_slots.is_empty() and not remaining_tokens.is_empty():
		var best_slot_index = -1
		var best_token_index = -1
		var best_score = -INF
		for si in range(open_slots.size()):
			for ti in range(remaining_tokens.size()):
				var score = _worders_assignment_score(open_slots[si], remaining_tokens[ti])
				if score > best_score:
					best_score = score
					best_slot_index = si
					best_token_index = ti
		if best_slot_index < 0 or best_token_index < 0:
			break
		var chosen_slot = open_slots[best_slot_index]
		var chosen_word = remaining_tokens[best_token_index]
		chosen_slot.word = chosen_word
		filled.append({
			"slot": chosen_slot.card.get_comp_name(),
			"word": chosen_word,
			"slot_ref": chosen_slot,
			"score": best_score,
		})
		open_slots.remove_at(best_slot_index)
		remaining_tokens.remove_at(best_token_index)
	return {
		"filled": filled,
		"unused": remaining_tokens,
		"unfilled": open_slots,
	}

func _add_worders_token(tokens: Array[String], raw: String) -> void:
	var clean = raw.strip_edges()
	if clean.is_empty() or tokens.has(clean) or tokens.size() >= 24:
		return
	tokens.append(clean)

func _worders_assignment_score(slot: SentenceBuilder.Slot, word: String) -> float:
	var preview = _preview_with_slot_word(slot, word)
	var input = ScoringEngine.SentenceInput.new()
	input.cards.append(slot.card)
	input.words.append(word)
	input.components.append(slot.get_component())
	var constraint = ConstraintValidator.validate(input)
	var entries = WordBank.find_entries(word)
	var score = _word_candidate_value(preview)
	score += constraint.bonus * 10.0
	score -= constraint.penalty_percent * 140.0
	if not entries.is_empty():
		score += 4.0
	else:
		# Unknown words dodge mismatch penalties, so a stray long chunk (e.g. a
		# whole un-segmented clause) could otherwise outrank real words. Penalize
		# unknown tokens by length so proper dictionary words win.
		score -= 6.0 + float(word.length()) * 2.0
	if _constraint_state_for_word(slot, word) == "match":
		score += 6.0
	return score

func _stringify_array(items: Array) -> Array[String]:
	var result: Array[String] = []
	for item in items:
		result.append(str(item))
	return result

func _send_chat_message(text: String, is_preset: bool) -> void:
	if _chat_request_in_flight:
		_add_chat_message("System", "AI is still replying...", Color(0.82, 0.84, 0.9, 1))
		return
	_add_chat_message("Player", text, Color(0.76, 0.84, 1, 1))
	_spawn_chat_bubble(text, _control_center(player_role_panel), Color(0.38, 0.66, 1.0, 0.94))
	_chat_history.append({"role": "user", "content": text})
	_trim_chat_history()
	await BattleManager.wait_anim(0.18 if is_preset else 0.24)
	await _request_ai_chat_reply(text)

func _ai_chat_react(seed: String) -> void:
	var reply = "😊"
	if seed == "💥":
		reply = "🛡️"
	elif seed == "💚":
		reply = "✨"
	elif seed == "🛡️":
		reply = "💥"
	elif seed == "✨":
		reply = "😊"
	_add_chat_message("AI", reply, Color(1.0, 0.78, 0.62, 1))
	_spawn_chat_bubble(reply, _control_center(ai_role_panel), Color(1.0, 0.42, 0.28, 0.92))

func _request_ai_chat_reply(seed: String) -> void:
	if _chat_request_in_flight:
		_add_chat_message("System", "AI is still replying...", Color(0.82, 0.84, 0.9, 1))
		return
	_chat_request_in_flight = true
	chat_send_btn.disabled = true
	var old_placeholder = chat_input.placeholder_text
	chat_input.placeholder_text = "AI thinking..."
	var context = _build_llm_battle_context()
	var response = {"ok": false, "fallback_reason": "disabled"}
	if LLMClient.is_ready_for_requests():
		response = await LLMClient.request_battle_chat(seed, context, _chat_history, I18n.language)
	var reply = ""
	if response.get("ok", false):
		reply = str(response.get("reply", "")).strip_edges()
		if reply.is_empty():
			reply = LLMClient.fallback_battle_reply(seed, context)
	else:
		reply = LLMClient.fallback_battle_reply(seed, context)
		if response.get("fallback_reason", "") != "disabled":
			var error = str(response.get("error", "DeepSeek unavailable."))
			_add_chat_message("System", "DeepSeek offline: " + error, Color(0.88, 0.74, 0.52, 1))
	_chat_history.append({"role": "assistant", "content": reply})
	_trim_chat_history()
	_add_chat_message("AI", reply, Color(1.0, 0.78, 0.62, 1))
	_spawn_chat_bubble(reply, _control_center(ai_role_panel), Color(1.0, 0.42, 0.28, 0.92))
	_chat_request_in_flight = false
	chat_send_btn.disabled = false
	chat_input.placeholder_text = old_placeholder

func _trim_chat_history() -> void:
	while _chat_history.size() > 8:
		_chat_history.remove_at(0)

func _build_llm_battle_context() -> Dictionary:
	var p1 = BattleManager.player1
	var p2 = BattleManager.player2
	var builder = BattleManager.sentence_builder
	var current_name = "none"
	if BattleManager.current_player:
		current_name = "AI" if BattleManager.current_player.is_ai else "Player"
	return {
		"game": "WORDERS",
		"turn": TurnManager.current_turn_number,
		"phase": TurnManager.Phase.keys()[TurnManager.current_phase],
		"current_player": current_name,
		"player": _llm_player_summary(p1),
		"ai": _llm_player_summary(p2),
		"sentence_words": _llm_sentence_words(builder),
		"sentence_cost": builder.get_total_mana_cost(),
		"ai_intent": _ai_intent_name,
		"rules_summary": [
			"Drag fill cards into the sentence zone, write words, reorder slots, then confirm play.",
			"Matching card constraints gives a small bonus; known mismatches add soft scoring risk.",
			"Attack tends to come from predicate/object/complement; defense from subject/attribute; critical from adverbial and rhetoric.",
			"Mana limits sentence length and card use.",
		],
	}

func _llm_player_summary(player: Player) -> Dictionary:
	if player == null:
		return {}
	return {
		"hp": player.hp,
		"max_hp": player.max_hp,
		"shield": player.shield,
		"mana": player.mana,
		"max_mana": player.max_mana,
		"hand_count": player.hand.size(),
		"deck_count": player.deck.size() if player.deck else 0,
		"stance": tactical_stance_script.key(player.current_stance),
	}

func _llm_sentence_words(builder: SentenceBuilder) -> Array[String]:
	var words: Array[String] = []
	if builder == null:
		return words
	for slot in builder.get_ordered_slots():
		if slot.is_filled():
			words.append(slot.word)
		else:
			words.append("<empty>")
	return words

func _on_ai_emote_sent(emoji: String, message: String) -> void:
	var text = emoji if message.strip_edges().is_empty() else "%s %s" % [emoji, message]
	_add_chat_message("AI", text, Color(1.0, 0.78, 0.62, 1))
	_spawn_chat_bubble(text, _control_center(ai_role_panel), Color(1.0, 0.42, 0.28, 0.92))
	_set_label_animated(log_label, I18n.t("ai_emote") % [emoji, message])

func _on_ai_llm_plan_failed(reason: String) -> void:
	_set_label_animated(log_label, I18n.t("deepseek_plan_failed") % reason)

func _on_word_judgment_completed(judgments, affected_score: bool) -> void:
	if not (judgments is Array) or judgments.is_empty():
		return
	var parts: Array[String] = []
	for j in judgments:
		if not (j is Dictionary):
			continue
		var mark = "✓" if bool(j.get("matched", false)) else "✗"
		parts.append("%s %s(%.0f%%)" % [mark, str(j.get("word", "")), float(j.get("confidence", 0.0)) * 100.0])
	if parts.is_empty():
		return
	var prefix = I18n.t("judgment_review_done") % parts.size()
	var color = Color(0.74, 0.94, 1.0, 1) if affected_score else Color(0.86, 0.86, 0.7, 1)
	_add_chat_message("Judge", prefix + "  " + ", ".join(parts), color)

func _on_llm_status_changed(_enabled: bool, _ready: bool, message: String) -> void:
	if not message.is_empty():
		_add_chat_message("System", message, Color(0.88, 0.84, 0.64, 1))

func _add_chat_message(sender: String, text: String, color: Color) -> void:
	chat_panel_helper.prune_log(chat_log, CHAT_LOG_MAX_LINES)
	chat_log.add_child(chat_panel_helper.make_message_row(sender, text, _chat_accent_for_sender(sender, color)))
	_scroll_chat_to_bottom()

# Maps a sender to its agent accent color so enemy/ally/you/judge/system are
# instantly distinguishable in the log.
func _chat_accent_for_sender(sender: String, fallback: Color) -> Color:
	match sender:
		"AI", "Enemy", "敌方":
			return Color(1.0, 0.55, 0.32, 1.0)
		"Ally", "己方":
			return Color(0.46, 0.80, 1.0, 1.0)
		"You", "Player", "玩家":
			return Color(0.74, 0.86, 1.0, 1.0)
		"Judge":
			return Color(0.92, 0.84, 0.5, 1.0)
		"System":
			return Color(0.96, 0.80, 0.46, 1.0)
	return fallback

func _scroll_chat_to_bottom() -> void:
	if chat_scroll == null:
		return
	await get_tree().process_frame
	var bar = chat_scroll.get_v_scroll_bar()
	if bar:
		chat_scroll.scroll_vertical = int(bar.max_value)

func _spawn_chat_bubble(text: String, origin: Vector2, color: Color) -> void:
	var bubble = chat_panel_helper.make_bubble(text, Color(1, 1, 1, 1), _make_panel_style(color, Color(1, 1, 1, 0.45), 8, 1))
	bubble.position = origin + Vector2(-bubble.size.x * 0.5, -86)
	fx_layer.add_child(bubble)
	var tween = _new_anim_tween()
	tween.set_parallel(true)
	tween.tween_property(bubble, "position", bubble.position + Vector2(0, -34), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.32).set_delay(0.62)
	tween.set_parallel(false)
	tween.tween_callback(bubble.queue_free)

func _return_card_to_hand(card: CardData) -> void:
	var cp = BattleManager.current_player
	if not cp or cp.is_ai:
		return
	for i in range(BattleManager.sentence_builder.slots.size()):
		if BattleManager.sentence_builder.slots[i].card == card:
			if _word_fill_queue.has(BattleManager.sentence_builder.slots[i]):
				_word_fill_queue.erase(BattleManager.sentence_builder.slots[i])
			BattleManager.sentence_builder.slots.remove_at(i)
			break
	cp.hand.append(card)
	_refresh_hand(cp)
	_refresh_slots()
	_update_cost_preview()
	_refresh_word_flow_button()

func _return_slot_to_hand(slot: SentenceBuilder.Slot) -> void:
	var cp = BattleManager.current_player
	if not cp or cp.is_ai or slot == null:
		return
	var idx = BattleManager.sentence_builder.slots.find(slot)
	if idx >= 0:
		BattleManager.sentence_builder.slots.remove_at(idx)
		cp.hand.append(slot.card)
		if _word_fill_queue.has(slot):
			_word_fill_queue.erase(slot)
		_hand_filter = slot.card.comp_constraint if slot.card.card_type == CardData.CardType.FILL else _type_filter(slot.card.card_type)
		_hand_page = 0
		_refresh_hand(cp)
		_refresh_slots()
		_update_cost_preview()
		_refresh_word_flow_button()
		_flash_rect(_control_center(cards_panel), Color(0.45, 0.78, 1.0, 0.24), Vector2(360, 82))

func _refresh_hand_categories(player: Player) -> void:
	for child in hand_category_bar.get_children():
		child.queue_free()
	_add_hand_filter_button("%s %d" % [I18n.t("all_cards"), player.hand.size()], FILTER_ALL)
	var type_counts: Dictionary = {}
	var counts: Dictionary = {}
	for card in player.hand:
		type_counts[card.card_type] = type_counts.get(card.card_type, 0) + 1
		if card.card_type == CardData.CardType.FILL:
			counts[card.comp_constraint] = counts.get(card.comp_constraint, 0) + 1
	for card_type in [
		CardData.CardType.FILL,
		CardData.CardType.FUNCTION,
		CardData.CardType.EQUIPMENT,
		CardData.CardType.STATUS,
	]:
		if type_counts.has(card_type):
			_add_hand_filter_button("%s %d" % [I18n.card_type_label(card_type), type_counts[card_type]], _type_filter(card_type))
	var comps = [
		CardData.SentenceComponent.ATTRIBUTE,
		CardData.SentenceComponent.SUBJECT,
		CardData.SentenceComponent.ADVERBIAL,
		CardData.SentenceComponent.PREDICATE,
		CardData.SentenceComponent.COMPLEMENT,
		CardData.SentenceComponent.OBJECT,
		CardData.SentenceComponent.ANY,
	]
	for comp in comps:
		if counts.has(comp):
			_add_hand_filter_button("%s %d" % [_component_label(comp), counts[comp]], comp)

func _add_hand_filter_button(text: String, filter: int) -> void:
	var btn = Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_pressed = filter == _hand_filter
	btn.custom_minimum_size = Vector2(110, 34)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.pressed.connect(func():
		_hand_filter = filter
		_hand_page = 0
		if BattleManager.current_player and not BattleManager.current_player.is_ai:
			_refresh_hand(BattleManager.current_player))
	hand_category_bar.add_child(btn)

func _component_label(comp: int) -> String:
	return I18n.component_label(comp)

func _get_filtered_hand(player: Player) -> Array[CardData]:
	var result: Array[CardData] = []
	for card in player.hand:
		if _hand_filter == FILTER_ALL:
			result.append(card)
		elif _hand_filter <= FILTER_TYPE_BASE:
			if card.card_type == _filter_to_type(_hand_filter):
				result.append(card)
		elif card.card_type == CardData.CardType.FILL and card.comp_constraint == _hand_filter:
			result.append(card)
	return result

func _type_filter(card_type: int) -> int:
	return FILTER_TYPE_BASE - card_type

func _filter_to_type(filter: int) -> int:
	return FILTER_TYPE_BASE - filter

func _clamp_hand_page(player: Player) -> void:
	_hand_page = 0

func _hand_page_size() -> int:
	return 999

func _prev_hand_page() -> void:
	if BattleManager.current_player == null:
		return
	_hand_page = max(0, _hand_page - 1)
	_refresh_hand(BattleManager.current_player)

func _next_hand_page() -> void:
	if BattleManager.current_player == null:
		return
	_hand_page += 1
	_clamp_hand_page(BattleManager.current_player)
	_refresh_hand(BattleManager.current_player)

func _animate_sentence_submit(preview: ScoringEngine.ScoreBreakdown) -> void:
	if slots_container.get_child_count() == 0:
		return
	var input = BattleManager.sentence_builder.get_sentence_input()
	var stance = BattleManager.current_player.current_stance if BattleManager.current_player else 0
	var deltas = ScoringEngine.compute_slot_deltas(input, BattleManager.rhyme_map, stance)
	var slots = BattleManager.sentence_builder.get_ordered_slots()
	await _spawn_score_stat_fly_ins(deltas, slots)
	# Re-fetch after the await: the slot container may have been rebuilt or freed
	# while the fly-in animation was running, invalidating earlier references.
	var children = slots_container.get_children()
	var tween = _new_anim_tween()
	tween.set_parallel(true)
	for i in range(children.size()):
		var child = children[i]
		if is_instance_valid(child) and child is Control:
			var base_pos = child.position
			tween.tween_property(child, "position", base_pos + Vector2(0, -18), 0.18).set_delay(float(i) * 0.035).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(child, "modulate:a", 0.18, 0.18).set_delay(float(i) * 0.035)
	await tween.finished
	await _spawn_sentence_word_art(preview)
	if not preview.rhetoric_flags.is_empty():
		await _spawn_rhetoric_fx(preview.rhetoric_flags)
	_spawn_burst(_control_center(slots_panel), _break_color(preview), 18, "*", Vector2(260, 72))

func _spawn_sentence_word_art(preview: ScoringEngine.ScoreBreakdown) -> void:
	var slots = BattleManager.sentence_builder.get_ordered_slots()
	var chars: Array[Dictionary] = []
	for slot in slots:
		var word = slot.word.strip_edges()
		if word.is_empty():
			continue
		for i in range(word.length()):
			chars.append({"char": word.substr(i, 1), "slot": slot, "component": slot.get_component()})
	if chars.is_empty():
		return
	var visible_count = min(chars.size(), 22)
	var spacing = 42.0 if visible_count <= 14 else 30.0
	var start_x = 960.0 - spacing * float(visible_count - 1) * 0.5
	var labels: Array[Label] = []
	for i in range(visible_count):
		var info = chars[i]
		var slot = info["slot"] as SentenceBuilder.Slot
		var label = Label.new()
		label.text = info["char"]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.position = _slot_center(slot) + Vector2(randf_range(-16.0, 16.0), randf_range(-8.0, 8.0))
		label.pivot_offset = Vector2(18, 18)
		label.scale = Vector2(0.35, 0.35)
		label.modulate.a = 0.0
		label.add_theme_color_override("font_color", _component_color(info["component"]))
		label.add_theme_color_override("font_shadow_color", Color(0.02, 0.015, 0.01, 0.82))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 3)
		label.add_theme_font_size_override("font_size", 38)
		fx_layer.add_child(label)
		labels.append(label)
		var target = Vector2(start_x + spacing * float(i), 372.0 + sin(float(i) * 0.7) * 12.0)
		var fly = _new_anim_tween()
		fly.set_parallel(true)
		fly.tween_property(label, "position", target, 0.28).set_delay(float(i) * 0.025).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fly.tween_property(label, "scale", Vector2(1.0, 1.0), 0.24).set_delay(float(i) * 0.025).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		fly.tween_property(label, "modulate:a", 1.0, 0.14).set_delay(float(i) * 0.025)
	await BattleManager.wait_anim(0.46 + float(visible_count) * 0.025)
	var break_color = _break_color(preview)
	_flash_rect(Vector2(960, 382), Color(break_color.r, break_color.g, break_color.b, 0.24), Vector2(880, 96))
	for label in labels:
		_shatter_word_label(label, break_color)
	await BattleManager.wait_anim(0.16)

func _shatter_word_label(label: Label, color: Color) -> void:
	if not is_instance_valid(label):
		return
	var origin = label.position + Vector2(18, 18)
	var glyph = label.text
	var tween = _new_anim_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2(1.38, 1.38), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.18)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)
	for i in range(5):
		var shard = Label.new()
		shard.text = glyph if i == 0 else "."
		shard.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shard.position = origin
		shard.rotation = randf_range(-0.55, 0.55)
		shard.add_theme_color_override("font_color", color)
		shard.add_theme_font_size_override("font_size", randi_range(12, 22))
		fx_layer.add_child(shard)
		var travel = Vector2(randf_range(-80.0, 80.0), randf_range(-58.0, 72.0))
		var shard_tween = _new_anim_tween()
		shard_tween.set_parallel(true)
		shard_tween.tween_property(shard, "position", origin + travel, randf_range(0.24, 0.44)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		shard_tween.tween_property(shard, "rotation", shard.rotation + randf_range(-1.8, 1.8), 0.36)
		shard_tween.tween_property(shard, "modulate:a", 0.0, 0.36)
		shard_tween.set_parallel(false)
		shard_tween.tween_callback(shard.queue_free)

func _component_color(comp: int) -> Color:
	return UiTheme.component_color(comp)

func _constraint_slot_color(slot: SentenceBuilder.Slot, fallback: Color) -> Color:
	if slot == null or not slot.is_filled():
		return fallback
	match _constraint_slot_state(slot):
		"match":
			return Color(0.45, 1.0, 0.58, 1)
		"mismatch":
			return Color(1.0, 0.36, 0.18, 1)
		"unknown":
			return Color(0.95, 0.72, 0.32, 1)
	return fallback

func _constraint_slot_state(slot: SentenceBuilder.Slot) -> String:
	var entries = WordBank.find_entries(slot.word)
	if entries.is_empty():
		return "unknown"
	var input = ScoringEngine.SentenceInput.new()
	input.cards = [slot.card]
	input.words.append(slot.word)
	input.components = [slot.get_component()]
	var result = constraint_validator_script.validate(input)
	if result.penalty_percent > 0.0:
		return "mismatch"
	if result.bonus > 0.0:
		return "match"
	return "neutral"

func _ai_intent_label(strategy_name: String) -> String:
	var key = strategy_name.split("/")[0]
	match key:
		"AGGRESSIVE":
			return I18n.t("intent_aggressive")
		"DEFENSIVE":
			return I18n.t("intent_defensive")
		_:
			return I18n.t("intent_balanced")

func _break_color(preview: ScoringEngine.ScoreBreakdown) -> Color:
	if preview.atk >= preview.def_ and preview.atk >= preview.crt:
		return Color(1.0, 0.36, 0.18, 1)
	if preview.def_ >= preview.atk and preview.def_ >= preview.crt:
		return Color(0.35, 0.78, 1.0, 1)
	return Color(0.45, 1.0, 0.58, 1)

func _stance_label_by_key(stance_name: String) -> String:
	match stance_name:
		"break":
			return I18n.t("stance_break")
		"guard":
			return I18n.t("stance_guard")
		"harmony":
			return I18n.t("stance_harmony")
		_:
			return I18n.t("stance_balanced")

func _control_center(control: Control) -> Vector2:
	if control == null:
		return Vector2.ZERO
	return fx_layer.get_global_transform_with_canvas().affine_inverse() * control.get_global_rect().get_center()

func _slot_center(slot: SentenceBuilder.Slot) -> Vector2:
	for child in slots_container.get_children():
		if child is Control and child.get("slot_ref") == slot:
			return _control_center(child)
	return _control_center(slots_panel)

func _pulse_slot(slot: SentenceBuilder.Slot) -> void:
	for child in slots_container.get_children():
		if child is Control and child.get("slot_ref") == slot:
			_pulse_control(child, Color(0.95, 0.72, 0.32, 0.42))
			return

func _pulse_control(control: Control, flash_color: Color) -> void:
	if control == null:
		return
	var original_scale = control.scale
	var original_modulate = control.modulate
	var tween = _new_anim_tween()
	tween.set_parallel(true)
	tween.tween_property(control, "scale", original_scale * 1.06, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate", Color(1.08, 1.04, 0.92, 1), 0.08)
	tween.set_parallel(false)
	tween.tween_property(control, "scale", original_scale, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate", original_modulate, 0.16)
	_flash_rect(_control_center(control), flash_color, control.size + Vector2(14, 10))

func _show_phase_banner(text: String, color: Color) -> void:
	var banner = Label.new()
	banner.text = text
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.position = Vector2(660, 330)
	banner.size = Vector2(600, 76)
	banner.modulate.a = 0.0
	banner.add_theme_color_override("font_color", Color(1, 0.94, 0.72, 1))
	banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	banner.add_theme_constant_override("shadow_offset_x", 2)
	banner.add_theme_constant_override("shadow_offset_y", 3)
	banner.add_theme_font_size_override("font_size", 34)
	fx_layer.add_child(banner)
	_flash_rect(Vector2(960, 368), color, Vector2(660, 82))
	var tween = _new_anim_tween()
	tween.set_parallel(true)
	tween.tween_property(banner, "position", banner.position + Vector2(0, -12), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(banner, "modulate:a", 1.0, 0.16)
	tween.tween_property(banner, "scale", Vector2(1.03, 1.03), 0.22)
	tween.set_parallel(false)
	tween.tween_interval(0.22)
	tween.tween_property(banner, "modulate:a", 0.0, 0.22)
	tween.tween_callback(banner.queue_free)

func _set_label_animated(label: Label, text: String) -> void:
	if not label.has_meta("base_position"):
		label.set_meta("base_position", label.position)
	var base_pos: Vector2 = label.get_meta("base_position")
	label.text = text
	label.position = base_pos + Vector2(0, 8)
	label.modulate.a = 0.0
	var tween = _new_anim_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", base_pos, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 1.0, 0.18)

func _spawn_flying_card(card: CardData, start_pos: Vector2, end_pos: Vector2) -> void:
	var fly = Panel.new()
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly.size = Vector2(118, 148)
	fly.position = start_pos - fly.size * 0.5
	var card_color = _component_color(card.comp_constraint)
	fly.add_theme_stylebox_override("panel", _make_panel_style(Color(0.10, 0.12, 0.17, 0.94), card_color, 8, 2))
	var label = Label.new()
	label.layout_mode = 1
	label.anchors_preset = PRESET_FULL_RECT
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.text = card.get_display_name()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", card_color)
	label.add_theme_font_size_override("font_size", 18)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly.add_child(label)
	fx_layer.add_child(fly)
	var tween = _new_anim_tween()
	tween.set_parallel(true)
	tween.tween_property(fly, "position", end_pos - fly.size * 0.5, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(fly, "scale", Vector2(0.92, 0.92), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(fly, "modulate:a", 0.0, 0.10).set_delay(0.18)
	tween.set_parallel(false)
	tween.tween_callback(fly.queue_free)

func _flash_rect(center: Vector2, color: Color, rect_size: Vector2) -> void:
	var flash = ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = color
	flash.size = rect_size
	flash.position = center - rect_size * 0.5
	fx_layer.add_child(flash)
	var tween = _new_anim_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(1.08, 1.18), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "modulate:a", 0.0, 0.22)
	tween.set_parallel(false)
	tween.tween_callback(flash.queue_free)

func _flash_screen(color: Color) -> void:
	_flash_rect(Vector2(960, 540), color, Vector2(1920, 1080))

func _screen_shake() -> void:
	var original_pos = position
	var tween = _new_anim_tween()
	tween.tween_property(self, "position", original_pos + Vector2(8, -4), 0.035)
	tween.tween_property(self, "position", original_pos + Vector2(-6, 5), 0.04)
	tween.tween_property(self, "position", original_pos + Vector2(3, -2), 0.035)
	tween.tween_property(self, "position", original_pos, 0.045)

func _spawn_burst(origin: Vector2, color: Color, count: int, glyph: String, spread: Vector2) -> void:
	for i in range(count):
		var spark = Label.new()
		spark.text = glyph
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.position = origin + Vector2(randf_range(-14.0, 14.0), randf_range(-8.0, 8.0))
		spark.add_theme_color_override("font_color", color)
		spark.add_theme_font_size_override("font_size", randi_range(12, 22))
		fx_layer.add_child(spark)
		var travel = Vector2(randf_range(-spread.x, spread.x), randf_range(-spread.y, spread.y))
		var tween = _new_anim_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "position", spark.position + travel, randf_range(0.34, 0.58)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "modulate:a", 0.0, 0.50).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.set_parallel(false)
		tween.tween_callback(spark.queue_free)

func _spawn_ring(origin: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		var angle = TAU * float(i) / float(count)
		var spark = Label.new()
		spark.text = "o"
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.position = origin
		spark.add_theme_color_override("font_color", color)
		spark.add_theme_font_size_override("font_size", 13)
		fx_layer.add_child(spark)
		var travel = Vector2(cos(angle), sin(angle)) * randf_range(36.0, 64.0)
		var tween = _new_anim_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "position", origin + travel, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "modulate:a", 0.0, 0.42)
		tween.set_parallel(false)
		tween.tween_callback(spark.queue_free)

func _spawn_rising_particles(origin: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		var spark = Label.new()
		spark.text = "+"
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.position = origin + Vector2(randf_range(-28.0, 28.0), randf_range(-8.0, 8.0))
		spark.add_theme_color_override("font_color", color)
		spark.add_theme_font_size_override("font_size", randi_range(16, 24))
		fx_layer.add_child(spark)
		var tween = _new_anim_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "position", spark.position + Vector2(randf_range(-18.0, 18.0), -80.0), 0.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "modulate:a", 0.0, 0.58)
		tween.set_parallel(false)
		tween.tween_callback(spark.queue_free)

func _spawn_play_particles(origin: Vector2, color: Color, count: int = 24) -> void:
	_spawn_burst(origin, color, count, "*", Vector2(120, 54))

func _on_game_over(winner: Player) -> void:
	_game_over_flag = true
	_stop_ai_thinking_anim()
	_stop_low_hp_pulse()
	# Full overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.size = Vector2(1920, 1080)
	overlay.position = Vector2.ZERO
	add_child(overlay)
	var is_player_win = not winner.is_ai
	var banner_text = "✓ 胜利！" if is_player_win else "✗ 战败"
	var banner_color = Color(0.45, 1.0, 0.58, 1) if is_player_win else Color(1.0, 0.42, 0.28, 1)
	var panel = Panel.new()
	panel.size = Vector2(620, 300)
	panel.position = Vector2(660, 240)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.05, 0.06, 0.09, 0.98), banner_color, 18, 3))
	overlay.add_child(panel)
	var big_title = Label.new()
	big_title.text = banner_text
	big_title.size = Vector2(580, 90)
	big_title.position = Vector2(20, 20)
	big_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_title.add_theme_color_override("font_color", banner_color)
	big_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	big_title.add_theme_constant_override("shadow_offset_x", 3)
	big_title.add_theme_constant_override("shadow_offset_y", 4)
	big_title.add_theme_font_size_override("font_size", 64)
	panel.add_child(big_title)
	var stats_lbl = Label.new()
	stats_lbl.size = Vector2(580, 90)
	stats_lbl.position = Vector2(20, 110)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var p1 = BattleManager.player1
	var p2 = BattleManager.player2
	stats_lbl.text = "%s %d/%d  →  AI %d/%d\n%s：%d" % [
		I18n.t("player"), p1.hp if p1 else 0, p1.max_hp if p1 else 30,
		p2.hp if p2 else 0, p2.max_hp if p2 else 30,
		I18n.t("turn"), TurnManager.current_turn_number
	]
	stats_lbl.add_theme_color_override("font_color", Color(0.86, 0.91, 0.98, 0.88))
	stats_lbl.add_theme_font_size_override("font_size", 22)
	panel.add_child(stats_lbl)
	var menu_btn = Button.new()
	menu_btn.text = I18n.t("main_menu")
	menu_btn.size = Vector2(240, 52)
	menu_btn.position = Vector2(190, 220)
	menu_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	menu_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	panel.add_child(menu_btn)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.7, 0.7)
	panel.pivot_offset = panel.size * 0.5
	var tween = _new_anim_tween()
	tween.set_parallel(true)
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0.72), 0.44).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(panel, "modulate:a", 1.0, 0.32).set_trans(Tween.TRANS_QUAD).set_delay(0.16)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.10)
	if is_player_win:
		_flash_screen(Color(0.45, 1.0, 0.58, 0.28))
		_spawn_burst(Vector2(960, 540), Color(0.45, 1.0, 0.58, 1), 32, "★", Vector2(400, 300))
	else:
		_flash_screen(Color(1.0, 0.22, 0.22, 0.28))
		_screen_shake()
	# Keep legacy label hidden (overlay replaces it)
	game_over_label.text = I18n.t("game_over") % ("AI" if winner.is_ai else I18n.t("player"))
	game_over_label.visible = false
	confirm_btn.disabled = false
	confirm_btn.text = I18n.t("main_menu")

# ── Floating numbers ──────────────────────────────────────────────────────────
func _spawn_floating_number(text: String, origin: Vector2, color: Color, font_size: int = 38) -> void:
	var label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = origin + Vector2(randf_range(-20.0, 20.0), 0)
	label.pivot_offset = Vector2(20, 20)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate.a = 0.0
	fx_layer.add_child(label)
	var tween = _new_anim_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2(1.4, 1.4), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 1.0, 0.10)
	tween.set_parallel(false)
	tween.tween_interval(0.25)
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0, -60), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.32).set_delay(0.15)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func _spawn_score_stat_fly_ins(deltas: Array, slots: Array) -> void:
	if score_preview_panel == null or deltas.is_empty():
		return
	var projectiles: Array[Tween] = []
	for i in range(mini(deltas.size(), slots.size())):
		var slot = slots[i] as SentenceBuilder.Slot
		if slot == null or not slot.is_filled():
			continue
		var delta: Dictionary = deltas[i]
		var origin = _slot_center(slot)
		for key in ["atk", "def", "crt"]:
			var value = int(delta.get(key, 0))
			if value == 0:
				continue
			var color = _stat_fly_color(key)
			var target_global = score_preview_panel.stat_global_center(key)
			projectiles.append(_spawn_stat_projectile(origin, target_global, value, color, key))
	if projectiles.is_empty():
		return
	for tween in projectiles:
		if tween:
			await tween.finished
	await BattleManager.wait_anim(0.06)

func _stat_fly_color(key: String) -> Color:
	match key:
		"atk":
			return ScorePreviewPanel.ATK_COLOR
		"def":
			return ScorePreviewPanel.DEF_COLOR
		"crt":
			return ScorePreviewPanel.CRT_COLOR
	return Color.WHITE

func _spawn_stat_projectile(origin: Vector2, target_global: Vector2, value: int, color: Color, stat_key: String) -> Tween:
	var target = fx_layer.get_global_transform_with_canvas().affine_inverse() * target_global
	var label = Label.new()
	label.text = "%s%d" % ["+" if value > 0 else "", value]
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = origin + Vector2(randf_range(-8.0, 8.0), randf_range(-4.0, 4.0))
	label.pivot_offset = Vector2(16, 12)
	label.scale = Vector2(0.6, 0.6)
	label.modulate = Color(color.r, color.g, color.b, 0.0)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", 22)
	fx_layer.add_child(label)
	var mid = (origin + target) * 0.5 + Vector2(randf_range(-24.0, 24.0), -36.0)
	var tween = _new_anim_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 0.08)
	tween.tween_property(label, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_property(label, "position", mid, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", target, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2(0.85, 0.85), 0.12)
	tween.tween_property(label, "modulate:a", 0.0, 0.12)
	tween.set_parallel(false)
	tween.tween_callback(func():
		if score_preview_panel:
			score_preview_panel.play_stat_hit(stat_key)
		label.queue_free()
	)
	return tween

# ── Rhetoric VFX ──────────────────────────────────────────────────────────────
func _spawn_rhetoric_fx(flags: Array[String]) -> void:
	var slot_centers: Array[Vector2] = []
	for child in slots_container.get_children():
		if child is Control:
			slot_centers.append(_control_center(child))
	for flag in flags:
		match flag:
			"PARALLELISM":
				for i in range(slot_centers.size() - 1):
					_spawn_connecting_line(slot_centers[i], slot_centers[i + 1], Color(1.0, 0.82, 0.32, 0.9))
				_show_rhetoric_banner("排比！", Color(1.0, 0.82, 0.32, 1))
			"RHYME":
				for center in slot_centers:
					for _j in range(3):
						await BattleManager.wait_anim(0.04)
						_spawn_music_note(center + Vector2(randf_range(-20.0, 20.0), 0))
				_show_rhetoric_banner("押韵！", Color(0.72, 0.48, 1.0, 1))
			"ANTITHESIS":
				if slot_centers.size() >= 2:
					var mid_x = (slot_centers[0].x + slot_centers[slot_centers.size() - 1].x) * 0.5
					_spawn_axis_flash(mid_x, slot_centers)
				_show_rhetoric_banner("对仗！", Color(0.35, 0.95, 0.86, 1))
	await BattleManager.wait_anim(0.3)

func _spawn_connecting_line(start: Vector2, end: Vector2, color: Color) -> void:
	var delta = end - start
	var length = delta.length()
	var line = ColorRect.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.size = Vector2(length, 3)
	line.color = color
	line.position = start
	line.pivot_offset = Vector2(0, 1.5)
	line.rotation = atan2(delta.y, delta.x)
	line.modulate.a = 0.0
	fx_layer.add_child(line)
	var tween = _new_anim_tween()
	tween.set_parallel(true)
	tween.tween_property(line, "modulate:a", 1.0, 0.12)
	tween.tween_property(line, "scale", Vector2(1.0, 3.5), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(0.28)
	tween.tween_property(line, "modulate:a", 0.0, 0.22)
	tween.tween_callback(line.queue_free)

func _spawn_music_note(origin: Vector2) -> void:
	var note = Label.new()
	note.text = "♪" if randf() > 0.5 else "♫"
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.position = origin
	note.add_theme_color_override("font_color", Color(0.72, 0.48, 1.0, 1))
	note.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	note.add_theme_constant_override("shadow_offset_x", 1)
	note.add_theme_constant_override("shadow_offset_y", 2)
	note.add_theme_font_size_override("font_size", randi_range(22, 36))
	note.modulate.a = 0.0
	fx_layer.add_child(note)
	var tween = _new_anim_tween()
	tween.set_parallel(true)
	tween.tween_property(note, "position", origin + Vector2(randf_range(-18.0, 18.0), -90.0), 0.72).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(note, "modulate:a", 1.0, 0.10)
	tween.tween_property(note, "modulate:a", 0.0, 0.28).set_delay(0.44)
	tween.set_parallel(false)
	tween.tween_callback(note.queue_free)

func _spawn_axis_flash(mid_x: float, centers: Array[Vector2]) -> void:
	var min_y = (centers[0].y - 100.0) if not centers.is_empty() else 300.0
	var line = ColorRect.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.size = Vector2(4, 200)
	line.color = Color(0.35, 0.95, 0.86, 0.9)
	line.position = Vector2(mid_x - 2.0, min_y)
	line.modulate.a = 0.0
	fx_layer.add_child(line)
	for center in centers:
		_spawn_burst(center, Color(0.35, 0.95, 0.86, 1), 8, "◆", Vector2(60, 30))
	var tween = _new_anim_tween()
	tween.tween_property(line, "modulate:a", 1.0, 0.10)
	tween.tween_property(line, "scale", Vector2(1.0, 1.15), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(line, "modulate:a", 0.0, 0.28)
	tween.tween_callback(line.queue_free)

func _show_rhetoric_banner(text: String, color: Color) -> void:
	var banner = Label.new()
	banner.text = text
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.position = Vector2(760, 300)
	banner.size = Vector2(400, 72)
	banner.pivot_offset = Vector2(200, 36)
	banner.scale = Vector2(0.5, 0.5)
	banner.modulate.a = 0.0
	banner.add_theme_color_override("font_color", color)
	banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	banner.add_theme_constant_override("shadow_offset_x", 2)
	banner.add_theme_constant_override("shadow_offset_y", 3)
	banner.add_theme_font_size_override("font_size", 48)
	fx_layer.add_child(banner)
	var tween = _new_anim_tween()
	tween.set_parallel(true)
	tween.tween_property(banner, "scale", Vector2(1.18, 1.18), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(banner, "modulate:a", 1.0, 0.14)
	tween.set_parallel(false)
	tween.tween_interval(0.32)
	tween.tween_property(banner, "modulate:a", 0.0, 0.26)
	tween.tween_callback(banner.queue_free)

# ── Rhetoric combo notification ───────────────────────────────────────────────
func _on_rhetoric_combo_triggered(combo_count: int, bonus_mult: float) -> void:
	var text = I18n.t("rhetoric_combo") % [combo_count, bonus_mult]
	_show_phase_banner(text, Color(1.0, 0.82, 0.32, 1))
	_spawn_burst(_control_center(slots_panel), Color(1.0, 0.82, 0.32, 1), 20, "★", Vector2(220, 60))

# ── Reward choice dialog ──────────────────────────────────────────────────────
func _on_reward_choice_offered(cards: Array) -> void:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.size = Vector2(1920, 1080)
	overlay.position = Vector2.ZERO
	add_child(overlay)
	var panel = Panel.new()
	panel.size = Vector2(740, 290)
	panel.position = Vector2(590, 270)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.07, 0.10, 0.98), Color(0.72, 0.58, 0.32, 1), 14, 2))
	overlay.add_child(panel)
	var title = Label.new()
	title.text = I18n.t("event_reward_choose")
	title.position = Vector2(20, 14)
	title.size = Vector2(700, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.52, 1))
	title.add_theme_font_size_override("font_size", 22)
	panel.add_child(title)
	var hbox = HBoxContainer.new()
	hbox.position = Vector2(18, 60)
	hbox.size = Vector2(704, 215)
	hbox.add_theme_constant_override("separation", 18)
	panel.add_child(hbox)
	for card in cards:
		var btn_panel = Panel.new()
		btn_panel.custom_minimum_size = Vector2(216, 200)
		var card_color = _component_color(card.comp_constraint)
		btn_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.10, 0.12, 0.17, 0.94), card_color, 10, 2))
		var vb = VBoxContainer.new()
		vb.layout_mode = 1
		vb.anchors_preset = PRESET_FULL_RECT
		vb.anchor_right = 1.0
		vb.anchor_bottom = 1.0
		vb.add_theme_constant_override("separation", 6)
		var name_lbl = Label.new()
		name_lbl.text = card.get_display_name()
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		name_lbl.add_theme_font_size_override("font_size", 16)
		var comp_lbl = Label.new()
		comp_lbl.text = card.get_comp_name()
		comp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		comp_lbl.add_theme_color_override("font_color", card_color)
		comp_lbl.add_theme_font_size_override("font_size", 13)
		var chaos_lbl = Label.new()
		chaos_lbl.text = "紊乱 %.1f" % card.base_disorder
		chaos_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chaos_lbl.add_theme_color_override("font_color", Color(0.76, 0.84, 1, 0.72))
		chaos_lbl.add_theme_font_size_override("font_size", 13)
		var choose_btn = Button.new()
		choose_btn.text = I18n.t("choose_card")
		choose_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		var chosen = card
		choose_btn.pressed.connect(func():
			Events.reward_card_chosen.emit(chosen)
			overlay.queue_free())
		vb.add_child(name_lbl)
		vb.add_child(comp_lbl)
		vb.add_child(chaos_lbl)
		vb.add_child(choose_btn)
		btn_panel.add_child(vb)
		hbox.add_child(btn_panel)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = panel.size * 0.5
	var tween = _new_anim_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_event_choices_offered(choices: Array) -> void:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.70)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.size = Vector2(1920, 1080)
	overlay.position = Vector2.ZERO
	add_child(overlay)
	var panel = Panel.new()
	panel.size = Vector2(880, 286)
	panel.position = Vector2(520, 292)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style("paper"))
	overlay.add_child(panel)
	if _fx_director and not choices.is_empty():
		_fx_director.play_event_choice(choices[0])
	var title = Label.new()
	title.text = I18n.t("event_choice_title")
	title.position = Vector2(20, 16)
	title.size = Vector2(840, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.52, 1))
	title.add_theme_font_size_override("font_size", 22)
	panel.add_child(title)
	var hbox = HBoxContainer.new()
	hbox.position = Vector2(20, 66)
	hbox.size = Vector2(840, 194)
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)
	for choice in choices:
		var choice_panel = Panel.new()
		choice_panel.custom_minimum_size = Vector2(200, 180)
		choice_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.10, 0.12, 0.17, 0.94), _archetype_color(choice.preferred_archetype), 10, 2))
		var vb = VBoxContainer.new()
		vb.layout_mode = 1
		vb.anchors_preset = PRESET_FULL_RECT
		vb.anchor_right = 1.0
		vb.anchor_bottom = 1.0
		vb.add_theme_constant_override("separation", 8)
		var name_lbl = Label.new()
		name_lbl.text = I18n.t(choice.name)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_color_override("font_color", Color(1, 0.96, 0.78, 1))
		name_lbl.add_theme_font_size_override("font_size", 17)
		var desc_lbl = Label.new()
		desc_lbl.text = I18n.t(choice.description)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.add_theme_color_override("font_color", Color(0.84, 0.90, 1.0, 0.88))
		desc_lbl.add_theme_font_size_override("font_size", 12)
		var choose_btn = Button.new()
		choose_btn.text = I18n.t("choose_card")
		choose_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		var selected = choice
		choose_btn.pressed.connect(func():
			Events.event_choice_selected.emit(selected)
			overlay.queue_free())
		vb.add_child(name_lbl)
		vb.add_child(desc_lbl)
		vb.add_child(choose_btn)
		choice_panel.add_child(vb)
		hbox.add_child(choice_panel)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.88, 0.88)
	panel.pivot_offset = panel.size * 0.5
	var tween = _new_anim_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _archetype_color(archetype: String) -> Color:
	match archetype:
		"attack":
			return Color(1.0, 0.36, 0.18, 1)
		"defense":
			return Color(0.35, 0.78, 1.0, 1)
		"rhetoric":
			return Color(0.45, 1.0, 0.58, 1)
	return Color(0.95, 0.72, 0.32, 1)

func _archetype_label(archetype: String) -> String:
	match archetype:
		"attack":
			return I18n.t("archetype_attack")
		"defense":
			return I18n.t("archetype_defense")
		"rhetoric":
			return I18n.t("archetype_rhetoric")
	return I18n.t("archetype_balanced")

# ── Low HP pulse ──────────────────────────────────────────────────────────────
func _start_low_hp_pulse() -> void:
	if _low_hp_tween and _low_hp_tween.is_running():
		_low_hp_tween.kill()
	player_role_panel.add_theme_stylebox_override("panel",
		_make_panel_style(Color(0.12, 0.03, 0.04, 0.86), Color(1.0, 0.22, 0.22, 1.0), 70, 4))
	_low_hp_tween = create_tween().set_loops()
	_low_hp_tween.tween_property(player_role_panel, "modulate", Color(1.0, 0.80, 0.80, 1.0), 0.5).set_trans(Tween.TRANS_SINE)
	_low_hp_tween.tween_property(player_role_panel, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)

func _stop_low_hp_pulse() -> void:
	if _low_hp_tween:
		_low_hp_tween.kill()
		_low_hp_tween = null
	_low_hp_active = false
	player_role_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_style_role_panel(player_role_panel, Color(0.38, 0.66, 1.0, 1))

# ── AI thinking animation ─────────────────────────────────────────────────────
func _start_ai_thinking_anim() -> void:
	_stop_ai_thinking_anim()
	_ai_thinking_label = Label.new()
	_ai_thinking_label.text = "…"
	_ai_thinking_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ai_thinking_label.position = _control_center(ai_role_panel) + Vector2(-20, -40)
	_ai_thinking_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.62, 1))
	_ai_thinking_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_ai_thinking_label.add_theme_constant_override("shadow_offset_x", 1)
	_ai_thinking_label.add_theme_constant_override("shadow_offset_y", 2)
	_ai_thinking_label.add_theme_font_size_override("font_size", 32)
	_ai_thinking_label.modulate.a = 0.3
	fx_layer.add_child(_ai_thinking_label)
	_ai_thinking_tween = create_tween().set_loops()
	_ai_thinking_tween.tween_property(_ai_thinking_label, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
	_ai_thinking_tween.tween_property(_ai_thinking_label, "modulate:a", 0.3, 0.5).set_trans(Tween.TRANS_SINE)

func _stop_ai_thinking_anim() -> void:
	if _ai_thinking_tween:
		_ai_thinking_tween.kill()
		_ai_thinking_tween = null
	if _ai_thinking_label and is_instance_valid(_ai_thinking_label):
		_ai_thinking_label.queue_free()
		_ai_thinking_label = null
