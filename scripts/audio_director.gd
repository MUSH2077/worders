extends Node

const SETTINGS_PATH := "user://worders_audio_settings.cfg"
const MIX_RATE := 22050

var music_enabled := true
var sfx_enabled := true
var music_volume := 0.58
var sfx_volume := 0.72
var current_music_key := ""
var last_sfx_key := ""

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor := 0
var _music_streams: Dictionary = {}
var _sfx_streams: Dictionary = {}
var _events_connected := false

func _ready() -> void:
	_ensure_players()
	load_settings()
	_apply_volumes()
	_connect_events()

func _exit_tree() -> void:
	if _music_player:
		_music_player.stop()
	for player in _sfx_players:
		player.stop()
	_music_streams.clear()
	_sfx_streams.clear()

func load_settings() -> Dictionary:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	if err == OK:
		music_enabled = bool(config.get_value("audio", "music_enabled", music_enabled))
		sfx_enabled = bool(config.get_value("audio", "sfx_enabled", sfx_enabled))
		music_volume = clampf(float(config.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
		sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
	_apply_volumes()
	return {
		"music_enabled": music_enabled,
		"sfx_enabled": sfx_enabled,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
	}

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "music_enabled", music_enabled)
	config.set_value("audio", "sfx_enabled", sfx_enabled)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.save(SETTINGS_PATH)

func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	if not music_enabled and _music_player:
		_music_player.stop()
	elif music_enabled and not current_music_key.is_empty():
		play_music(current_music_key)
	save_settings()

func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	save_settings()

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	save_settings()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()
	save_settings()

func play_music(key: String) -> void:
	current_music_key = key
	if not music_enabled or _is_headless():
		return
	_ensure_players()
	_build_streams()
	if not _music_streams.has(key):
		key = "menu"
	_music_player.stream = _music_streams[key]
	_apply_volumes()
	if not _music_player.playing:
		_music_player.play()

func stop_music() -> void:
	if _music_player:
		_music_player.stop()

func play_sfx(key: String) -> void:
	last_sfx_key = key
	if not sfx_enabled or _is_headless():
		return
	_ensure_players()
	_build_streams()
	if not _sfx_streams.has(key):
		key = "ui_confirm"
	var player = _sfx_players[_sfx_cursor % _sfx_players.size()]
	_sfx_cursor += 1
	player.stream = _sfx_streams[key]
	_apply_volumes()
	player.play()

func _ensure_players() -> void:
	if _music_player == null:
		_music_player = AudioStreamPlayer.new()
		_music_player.name = "MusicPlayer"
		add_child(_music_player)
	if _sfx_players.is_empty():
		for i in range(4):
			var player = AudioStreamPlayer.new()
			player.name = "SfxPlayer%d" % i
			add_child(player)
			_sfx_players.append(player)

func _build_streams() -> void:
	if not _music_streams.is_empty():
		return
	_music_streams["menu"] = _make_music_stream([196.0, 246.94, 293.66, 392.0], 7.5, 0.20)
	_music_streams["battle"] = _make_music_stream([146.83, 220.0, 261.63, 329.63], 8.0, 0.23)
	_sfx_streams["ui_confirm"] = _make_tone(660.0, 0.09, 0.34)
	_sfx_streams["ui_cancel"] = _make_tone(246.94, 0.10, 0.28)
	_sfx_streams["card_play"] = _make_chime([392.0, 493.88], 0.16, 0.36)
	_sfx_streams["sentence_submit"] = _make_chime([329.63, 440.0, 659.25], 0.24, 0.34)
	_sfx_streams["attack"] = _make_noise_hit(0.18, 0.42)
	_sfx_streams["defend"] = _make_chime([220.0, 293.66], 0.18, 0.28)
	_sfx_streams["heal"] = _make_chime([523.25, 659.25, 783.99], 0.24, 0.24)
	_sfx_streams["crit"] = _make_chime([659.25, 880.0, 1174.66], 0.28, 0.40)
	_sfx_streams["event_reward"] = _make_chime([392.0, 523.25, 783.99], 0.30, 0.32)
	_sfx_streams["event_curse"] = _make_noise_hit(0.26, 0.30)
	_sfx_streams["turn"] = _make_chime([293.66, 392.0], 0.14, 0.24)

func _connect_events() -> void:
	if _events_connected:
		return
	_events_connected = true
	if Events.has_signal("event_triggered"):
		Events.event_triggered.connect(_on_event_triggered)
	if Events.has_signal("combat_resolved"):
		Events.combat_resolved.connect(_on_combat_resolved)
	if Events.has_signal("ai_card_committed"):
		Events.ai_card_committed.connect(func(_card, _slot_index): play_sfx("card_play"))
	if Events.has_signal("ai_word_filled"):
		Events.ai_word_filled.connect(func(_slot, _word): play_sfx("ui_confirm"))
	if Events.has_signal("score_calculated"):
		Events.score_calculated.connect(func(_breakdown): play_sfx("sentence_submit"))
	if Events.has_signal("turn_changed"):
		Events.turn_changed.connect(func(_player): play_sfx("turn"))
	if Events.has_signal("card_effect_resolved"):
		Events.card_effect_resolved.connect(_on_card_effect_resolved)

func _on_event_triggered(event_type: String) -> void:
	match event_type:
		"reward", "shop", "event_choice_take_card", "event_choice_empower", "event_choice_charge":
			play_sfx("event_reward")
		"curse":
			play_sfx("event_curse")
		"no_mana", "incomplete":
			play_sfx("ui_cancel")
		_:
			play_sfx("ui_confirm")

func _on_combat_resolved(result) -> void:
	if result == null:
		return
	if result.was_crit:
		play_sfx("crit")
	elif result.damage_dealt > 0:
		play_sfx("attack")
	elif result.shield_gained > 0:
		play_sfx("defend")
	elif result.heal_amount > 0:
		play_sfx("heal")

func _on_card_effect_resolved(_card, _player, effect_type: String, _amount) -> void:
	match effect_type:
		"SHIELD":
			play_sfx("defend")
		"HEAL":
			play_sfx("heal")
		"WEAKEN":
			play_sfx("attack")
		_:
			play_sfx("card_play")

func _apply_volumes() -> void:
	if _music_player:
		_music_player.volume_db = _linear_to_db(music_volume)
	for player in _sfx_players:
		player.volume_db = _linear_to_db(sfx_volume)

func _linear_to_db(value: float) -> float:
	if value <= 0.001:
		return -80.0
	return linear_to_db(value)

func _make_music_stream(notes: Array[float], duration: float, volume: float) -> AudioStreamWAV:
	var sample_count = int(duration * MIX_RATE)
	var data = PackedByteArray()
	for i in range(sample_count):
		var t = float(i) / float(MIX_RATE)
		var note = notes[int(t / 1.5) % notes.size()]
		var slow = sin(TAU * note * t) * 0.55
		var fifth = sin(TAU * note * 1.5 * t) * 0.18
		var bell = sin(TAU * note * 2.0 * t) * 0.10
		var pulse = 0.74 + 0.26 * sin(TAU * 0.25 * t)
		_append_sample(data, (slow + fifth + bell) * pulse * volume)
	var stream = _stream_from_data(data)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream

func _make_tone(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var sample_count = int(duration * MIX_RATE)
	var data = PackedByteArray()
	for i in range(sample_count):
		var t = float(i) / float(MIX_RATE)
		var env = _envelope(t, duration)
		_append_sample(data, sin(TAU * freq * t) * env * volume)
	return _stream_from_data(data)

func _make_chime(notes: Array[float], duration: float, volume: float) -> AudioStreamWAV:
	var sample_count = int(duration * MIX_RATE)
	var data = PackedByteArray()
	for i in range(sample_count):
		var t = float(i) / float(MIX_RATE)
		var mixed = 0.0
		for n in range(notes.size()):
			var start = float(n) * duration / float(notes.size() + 1)
			if t >= start:
				var local = t - start
				mixed += sin(TAU * notes[n] * local) * exp(-local * 10.0)
		_append_sample(data, mixed * volume * 0.42)
	return _stream_from_data(data)

func _make_noise_hit(duration: float, volume: float) -> AudioStreamWAV:
	var sample_count = int(duration * MIX_RATE)
	var data = PackedByteArray()
	var seed := 9127
	for i in range(sample_count):
		var t = float(i) / float(MIX_RATE)
		seed = int((seed * 1103515245 + 12345) & 0x7fffffff)
		var noise = float(seed % 2000) / 1000.0 - 1.0
		var body = sin(TAU * 90.0 * t) * exp(-t * 12.0)
		_append_sample(data, (noise * 0.32 + body) * _envelope(t, duration) * volume)
	return _stream_from_data(data)

func _stream_from_data(data: PackedByteArray) -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream

func _append_sample(data: PackedByteArray, sample: float) -> void:
	var value = clampi(int(clampf(sample, -1.0, 1.0) * 32767.0), -32768, 32767)
	if value < 0:
		value = 65536 + value
	data.append(value & 0xff)
	data.append((value >> 8) & 0xff)

func _envelope(t: float, duration: float) -> float:
	var attack = min(1.0, t / 0.018)
	var release = min(1.0, max(duration - t, 0.0) / 0.08)
	return attack * release

func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"
