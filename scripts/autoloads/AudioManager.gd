extends Node

## 전역 WW2 군사 사운드 매니저

var sounds: Dictionary = {}
var audio_pool: Array[AudioStreamPlayer] = []
var pool_size: int = 16
var propeller_player: AudioStreamPlayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 오디오 스트림 로드
	var sound_files = {
		"propeller": "res://assets/audio/propeller_hum.wav",
		"dive_siren": "res://assets/audio/dive_siren.wav",
		"yamato": "res://assets/audio/yamato_cannon.wav",
		"gustav": "res://assets/audio/gustav_cannon.wav",
		"fortress": "res://assets/audio/fortress_cannon.wav",
		"flak": "res://assets/audio/flak_fire.wav",
		"explosion": "res://assets/audio/heavy_explosion.wav",
		"plane_crash": "res://assets/audio/plane_crash.wav"
	}
	
	for s_key in sound_files:
		var path = sound_files[s_key]
		if ResourceLoader.exists(path):
			sounds[s_key] = load(path)
			
	# 절차적 오디오 생성 (도탄 금속음, 포탄 낙하 휘파람음, 파편 비산음)
	sounds["ricochet"] = _generate_ricochet_sound()
	sounds["whistle"] = _generate_whistle_sound()
	sounds["debris"] = _generate_debris_sound()
	
	# 오디오 플레이어 풀 생성
	for i in range(pool_size):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		audio_pool.append(p)
		
	# B-29 프로펠러 루프 플레이어
	propeller_player = AudioStreamPlayer.new()
	if sounds.has("propeller"):
		propeller_player.stream = sounds["propeller"]
	propeller_player.volume_db = -8.0
	propeller_player.bus = "Master"
	add_child(propeller_player)

func _generate_ricochet_sound() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.28
	var total_samples: int = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(total_samples)
	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var freq = 2800.0 - t * 4500.0
		var envelope = exp(-t * 18.0)
		var wave = sin(TAU * freq * t) * envelope
		var val = clampi(int((wave * 0.95 + 1.0) * 127.5), 0, 255)
		data[i] = val
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

func _generate_whistle_sound() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.75
	var total_samples: int = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(total_samples)
	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		# 2400Hz에서 650Hz로 급강하하는 포탄 비행 휘파람
		var freq = 2400.0 - (t / duration) * 1750.0
		var envelope = (t / duration) * 0.85 # 크레센도
		var wave = sin(TAU * freq * t) * envelope
		var val = clampi(int((wave * 0.9 + 1.0) * 127.5), 0, 255)
		data[i] = val
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

func _generate_debris_sound() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.45
	var total_samples: int = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(total_samples)
	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var noise = randf_range(-1.0, 1.0)
		var envelope = exp(-t * 8.0)
		var wave = noise * envelope
		var val = clampi(int((wave * 0.8 + 1.0) * 127.5), 0, 255)
		data[i] = val
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

func play_sfx(sound_name: String, vol_db: float = 0.0, pitch_var: float = 0.08) -> void:
	if not sounds.has(sound_name):
		return
	var stream = sounds[sound_name]
	
	# 풀에서 유휴 플레이어 찾기
	var player: AudioStreamPlayer = null
	for p in audio_pool:
		if not p.playing:
			player = p
			break
	
	if not player:
		player = audio_pool[0]
		
	player.stream = stream
	player.volume_db = vol_db
	player.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	player.play()

func start_propeller_sound() -> void:
	if propeller_player and not propeller_player.playing:
		propeller_player.play()

func stop_propeller_sound() -> void:
	if propeller_player and propeller_player.playing:
		propeller_player.stop()
