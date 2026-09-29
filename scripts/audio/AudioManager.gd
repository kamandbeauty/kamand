class_name AudioManager
extends Node

## Audio bus and player pools for Phase 2 sound design
var sfx_players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer = null
const MAX_SFX_VOICES: int = 8

var _sfx_streams: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_players()
	_generate_procedural_sound_effects()

func _setup_players() -> void:
	for i in range(MAX_SFX_VOICES):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_players.append(p)
		
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	add_child(music_player)

## Synthesizes clean 16-bit PCM WAV audio streams for original game sounds
func _generate_procedural_sound_effects() -> void:
	_sfx_streams["shoot"] = _create_pop_sound(480.0, 180.0, 0.08)
	_sfx_streams["bounce"] = _create_ping_sound(650.0, 0.06)
	_sfx_streams["match"] = _create_chime_sound(523.25, 0.15) # C5
	_sfx_streams["drop"] = _create_whoosh_sound(0.22)
	_sfx_streams["combo"] = _create_fanfare_sound(0.25)
	_sfx_streams["win"] = _create_victory_sound(0.6)
	_sfx_streams["lose"] = _create_defeat_sound(0.5)
	_sfx_streams["ui_click"] = _create_click_sound(0.04)

func play_shoot() -> void:
	_play_sfx("shoot", 0.0, 1.0)

func play_bounce() -> void:
	_play_sfx("bounce", -2.0, randf_range(0.95, 1.05))

func play_match(combo: int = 1) -> void:
	var pitch: float = clampf(1.0 + float(combo - 1) * 0.1, 1.0, 2.0)
	_play_sfx("match", 0.0, pitch)

func play_drop() -> void:
	_play_sfx("drop", -1.0, randf_range(0.9, 1.1))

func play_combo(combo: int) -> void:
	var pitch: float = clampf(1.0 + float(combo - 2) * 0.15, 1.0, 2.2)
	_play_sfx("combo", 2.0, pitch)

func play_win() -> void:
	_play_sfx("win", 3.0, 1.0)

func play_lose() -> void:
	_play_sfx("lose", 0.0, 1.0)

func play_ui_click() -> void:
	_play_sfx("ui_click", -4.0, 1.0)

func _play_sfx(sound_name: String, volume_db_offset: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not SaveManager.sound_enabled or SaveManager.sfx_muted or SaveManager.sfx_volume <= 0.001:
		return
	if not _sfx_streams.has(sound_name):
		return
		
	var stream: AudioStreamWAV = _sfx_streams[sound_name]
	var player: AudioStreamPlayer = _get_available_sfx_player()
	if player:
		player.stream = stream
		player.pitch_scale = pitch_scale
		var base_vol_db: float = linear_to_db(SaveManager.sfx_volume)
		player.volume_db = base_vol_db + volume_db_offset
		player.play()

func _get_available_sfx_player() -> AudioStreamPlayer:
	for p in sfx_players:
		if not p.playing:
			return p
	# Steal first player if all are busy
	return sfx_players[0]

# --- Procedural Audio Synthesizer Helpers ---

func _create_pop_sound(start_freq: float, end_freq: float, duration: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var total_samples: int = int(sample_rate * duration)
	var byte_data: PackedByteArray = PackedByteArray()
	byte_data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var progress: float = float(i) / float(total_samples)
		var freq: float = lerpf(start_freq, end_freq, progress)
		var env: float = (1.0 - progress) * (1.0 - progress)
		var sample: float = sin(t * freq * TAU) * env * 0.8
		var val_16: int = clampi(int(sample * 32767.0), -32768, 32767)
		byte_data.encode_s16(i * 2, val_16)
		
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = byte_data
	return wav

func _create_ping_sound(freq: float, duration: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var total_samples: int = int(sample_rate * duration)
	var byte_data: PackedByteArray = PackedByteArray()
	byte_data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var progress: float = float(i) / float(total_samples)
		var env: float = exp(-progress * 8.0)
		var sample: float = sin(t * freq * TAU) * env * 0.7
		var val_16: int = clampi(int(sample * 32767.0), -32768, 32767)
		byte_data.encode_s16(i * 2, val_16)
		
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = byte_data
	return wav

func _create_chime_sound(freq: float, duration: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var total_samples: int = int(sample_rate * duration)
	var byte_data: PackedByteArray = PackedByteArray()
	byte_data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var progress: float = float(i) / float(total_samples)
		var env: float = exp(-progress * 5.0)
		# Fundamental + 2nd harmonic + 3rd harmonic
		var sample: float = (sin(t * freq * TAU) * 0.6 + sin(t * freq * 2.0 * TAU) * 0.3 + sin(t * freq * 3.0 * TAU) * 0.1) * env
		var val_16: int = clampi(int(sample * 32767.0), -32768, 32767)
		byte_data.encode_s16(i * 2, val_16)
		
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = byte_data
	return wav

func _create_whoosh_sound(duration: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var total_samples: int = int(sample_rate * duration)
	var byte_data: PackedByteArray = PackedByteArray()
	byte_data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var progress: float = float(i) / float(total_samples)
		var env: float = sin(progress * PI)
		var noise: float = randf_range(-1.0, 1.0)
		var sample: float = noise * env * 0.5
		var val_16: int = clampi(int(sample * 32767.0), -32768, 32767)
		byte_data.encode_s16(i * 2, val_16)
		
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = byte_data
	return wav

func _create_fanfare_sound(duration: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var total_samples: int = int(sample_rate * duration)
	var byte_data: PackedByteArray = PackedByteArray()
	byte_data.resize(total_samples * 2)
	
	# Arpeggio C5 -> E5 -> G5 -> C6
	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.50]
	var samples_per_note: int = total_samples / notes.size()
	
	for i in range(total_samples):
		var note_idx: int = mini(i / samples_per_note, notes.size() - 1)
		var note_progress: float = float(i % samples_per_note) / float(samples_per_note)
		var t: float = float(i) / float(sample_rate)
		var freq: float = notes[note_idx]
		var env: float = (1.0 - note_progress * 0.8)
		var sample: float = (sin(t * freq * TAU) * 0.7 + sin(t * freq * 2.0 * TAU) * 0.3) * env * 0.7
		var val_16: int = clampi(int(sample * 32767.0), -32768, 32767)
		byte_data.encode_s16(i * 2, val_16)
		
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = byte_data
	return wav

func _create_victory_sound(duration: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var total_samples: int = int(sample_rate * duration)
	var byte_data: PackedByteArray = PackedByteArray()
	byte_data.resize(total_samples * 2)
	
	# Triumph chord C5-G5-C6
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var progress: float = float(i) / float(total_samples)
		var env: float = (1.0 - progress) * (1.0 - progress)
		var s1: float = sin(t * 523.25 * TAU) * 0.4
		var s2: float = sin(t * 659.25 * TAU) * 0.3
		var s3: float = sin(t * 783.99 * TAU) * 0.3
		var s4: float = sin(t * 1046.50 * TAU) * 0.2
		var sample: float = (s1 + s2 + s3 + s4) * env
		var val_16: int = clampi(int(sample * 32767.0), -32768, 32767)
		byte_data.encode_s16(i * 2, val_16)
		
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = byte_data
	return wav

func _create_defeat_sound(duration: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var total_samples: int = int(sample_rate * duration)
	var byte_data: PackedByteArray = PackedByteArray()
	byte_data.resize(total_samples * 2)
	
	# Melancholy minor glide
	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var progress: float = float(i) / float(total_samples)
		var freq: float = lerpf(392.0, 220.0, progress) # G4 to A3
		var env: float = (1.0 - progress)
		var sample: float = sin(t * freq * TAU) * env * 0.6
		var val_16: int = clampi(int(sample * 32767.0), -32768, 32767)
		byte_data.encode_s16(i * 2, val_16)
		
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = byte_data
	return wav

func _create_click_sound(duration: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var total_samples: int = int(sample_rate * duration)
	var byte_data: PackedByteArray = PackedByteArray()
	byte_data.resize(total_samples * 2)
	
	for i in range(total_samples):
		var progress: float = float(i) / float(total_samples)
		var env: float = 1.0 - progress
		var sample: float = sin(float(i) * 0.8) * env * 0.5
		var val_16: int = clampi(int(sample * 32767.0), -32768, 32767)
		byte_data.encode_s16(i * 2, val_16)
		
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = byte_data
	return wav
