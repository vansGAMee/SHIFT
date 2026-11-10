class_name Soundscape
extends Node
## Quiet, layered original sound design. All gains are linear [0,1].

const AUDIO := "res://assets/audio/"
var music_player: AudioStreamPlayer
var personal_player: AudioStreamPlayer
var _personal_kind := ""
var _personal_gain := 0.0
var _chapter4_played := false
var _finale_played := false
var outdoor_player: AudioStreamPlayer
var indoor_player: AudioStreamPlayer
var danger_player: AudioStreamPlayer
var shot_player: AudioStreamPlayer
var cue_players: Array[AudioStreamPlayer] = []
var _cue_streams: Dictionary = {}
var _scene := "void"
var streamer_mode := false
var _wind_reveal := false
var _master := 0.85
var _music_volume := 0.60
var _ambience_volume := 0.75
var _music_gain := 0.0
var _outdoor_gain := 0.0
var _indoor_gain := 0.0
var _music_target := 0.0
var _outdoor_target := 0.0
var _indoor_target := 0.0
var _cue_index := 0
var _step_index := 0
var _danger_level := 0.0
var _danger_gain := 0.0
var _duck_remaining := 0.0
var _duck_gain := 1.0
var _music_silence := 0.0
var _music_return := 1.0

func _ready() -> void:
	music_player = _player("Music")
	music_player.stream = _find_music()
	if music_player.stream:
		music_player.play()
	personal_player = _player("Author music")
	personal_player.finished.connect(_on_personal_finished)
	outdoor_player = _player("Mountain air")
	outdoor_player.stream = _loop(AUDIO + "mountain.ogg")
	outdoor_player.play()
	indoor_player = _player("Room tone")
	indoor_player.stream = _loop(AUDIO + "interior.ogg")
	indoor_player.play()
	danger_player = _player("Pressure in the walls")
	danger_player.stream = _loop(AUDIO + "pressure_bed.ogg")
	danger_player.play()
	shot_player = _player("Mountain report")
	for index in range(8):
		cue_players.append(_player("Detail %d" % index))
	for name in ["select", "shift", "error", "lever", "door", "pickup", "crack", "shot", "transition", "pressure_warning", "pressure_release", "power_drop", "memory", "ring", "wall_break"]:
		_cue_streams[name] = load(AUDIO + name + ".wav")
	for index in range(4):
		_cue_streams["step_stone_%d" % index] = load(AUDIO + "step_stone_%d.wav" % index)
		_cue_streams["step_grass_%d" % index] = load(AUDIO + "step_grass_%d.wav" % index)
	set_master(_master)
	set_scene(_scene)

func _player(title: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = title
	player.volume_db = -80.0
	add_child(player)
	return player

func _loop(path: String) -> AudioStream:
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamMP3:
		stream.loop = true
	return stream

func _find_music() -> AudioStream:
	# A file beside the native executable is deliberately easy to replace.
	# In editor, the project root is checked instead of the Godot binary folder.
	var directory := OS.get_executable_path().get_base_dir()
	if OS.has_feature("editor"):
		directory = ProjectSettings.globalize_path("res://")
	for filename in ["music.ogg", "music.mp3"]:
		var path := directory.path_join(filename)
		if FileAccess.file_exists(path):
			var external: AudioStream
			if filename.ends_with(".ogg"):
				external = AudioStreamOggVorbis.load_from_file(path)
			else:
				external = AudioStreamMP3.load_from_file(path)
			if external:
				external.loop = true
				return external
	return _loop(AUDIO + "score.ogg")

func set_scene(kind: String) -> void:
	if kind in ["menu","mountain"]:
		personal_player.stop()
		_personal_kind=""
	_scene = kind
	_music_silence = 0.0
	_music_return = 1.0
	if is_instance_valid(music_player): music_player.stream_paused = false
	_wind_reveal = false
	set_danger(0.0)
	match kind:
		"mountain":
			_music_target = 0.23
			_outdoor_target = 0.28
			_indoor_target = 0.0
		"interior":
			_music_target = 0.15
			_outdoor_target = 0.0
			_indoor_target = 0.22
		"finale":
			_music_target = 0.0
			_outdoor_target = 0.22
			_indoor_target = 0.0
			if not _finale_played:
				_finale_played=true
				_start_personal("finale","shift.mp3",0.24)
		"menu":
			_music_target = 0.26
			_outdoor_target = 0.18
			_indoor_target = 0.0
		_:
			_music_target = 0.0
			_outdoor_target = 0.0
			_indoor_target = 0.0
	if kind=="interior" and get_parent().stage=="chamber4":
		_music_target=0.0
		if not _chapter4_played:
			_chapter4_played=true
			_start_personal("chapter4","shift1.mp3",0.085)
	if not _personal_kind.is_empty(): _music_target=0.0

func _start_personal(kind: String, filename: String, gain: float):
	var stream: AudioStreamMP3=load(AUDIO+"author/"+filename).duplicate()
	stream.loop=false
	personal_player.stop()
	personal_player.stream=stream
	personal_player.stream_paused=false
	_personal_kind=kind
	_personal_gain=gain
	_music_gain=0.0
	music_player.volume_db=-80.0
	personal_player.volume_db=_db(gain*_music_volume*(0.0 if streamer_mode else 1.0))
	personal_player.play()

func _on_personal_finished():
	_personal_kind=""
	if _scene=="interior" and get_parent().stage!="chamber4": _music_target=0.15

func reset_journey_music():
	_chapter4_played=false
	_finale_played=false
	personal_player.stop()
	_personal_kind=""

func _process(delta: float) -> void:
	if not is_instance_valid(music_player):
		return
	var game = get_parent()
	var time_frozen: bool = game.get("paused")==true or (game.get("ui")!=null and game.ui.settings.visible)
	personal_player.stream_paused=time_frozen or _music_silence>0.0
	if not time_frozen:
		_music_silence = maxf(0.0,_music_silence-delta)
		if _music_silence<=0:
			music_player.stream_paused=false
			_music_return=move_toward(_music_return,1.0,delta/3.0)
	var smoothing := 1.0 - exp(-delta * (3.0 if _scene == "void" else 0.8))
	_music_gain = lerpf(_music_gain, _music_target, smoothing)
	_outdoor_gain = lerpf(_outdoor_gain, _outdoor_target, smoothing)
	_indoor_gain = lerpf(_indoor_gain, _indoor_target, smoothing)
	_duck_remaining = maxf(0.0, _duck_remaining - delta)
	var duck_target := 0.12 if _duck_remaining > 0.0 else 1.0
	_duck_gain = lerpf(_duck_gain, duck_target, 1.0 - exp(-delta * 2.0))
	_danger_gain = lerpf(_danger_gain, _danger_level, 1.0 - exp(-delta * 1.7))
	music_player.volume_db = _db(_music_gain * _music_volume * _duck_gain * _music_return * (0.0 if streamer_mode else 1.0))
	personal_player.volume_db = _db(_personal_gain*_music_volume*_duck_gain*_music_return*(0.0 if streamer_mode else 1.0))
	outdoor_player.volume_db = _db(_outdoor_gain * _ambience_volume * _duck_gain)
	indoor_player.volume_db = _db(_indoor_gain * _ambience_volume * _duck_gain)
	danger_player.volume_db = _db(_danger_gain * 0.15 * _ambience_volume * _duck_gain)

func _db(gain: float) -> float:
	return linear_to_db(maxf(gain, 0.0001))

func set_master(value: float) -> void:
	_master = clampf(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, _db(_master))

func cut_music(duration: float = 8.0) -> void:
	_music_silence = maxf(_music_silence,duration)
	_music_return = 0.0
	music_player.stream_paused = true
	personal_player.stream_paused = true
	music_player.volume_db = -80.0

func set_music(value: float) -> void:
	_music_volume = clampf(value, 0.0, 1.0)

func set_ambience(value: float) -> void:
	_ambience_volume = clampf(value, 0.0, 1.0)

func set_danger(value: float) -> void:
	_danger_level = clampf(value, 0.0, 1.0)

func duck_ambience(duration: float = 2.8) -> void:
	# The final report gets air around it; its dedicated player preserves echoes.
	_duck_remaining = maxf(_duck_remaining, duration)
	_duck_gain = 0.12

func play_cue(kind: String) -> void:
	if cue_players.is_empty():
		return
	var cue := kind
	if kind=="second_step": cue="step_stone_1"
	if kind == "step":
		_step_index = (_step_index + 1) % 4
		cue = ("step_grass_" if _scene in ["mountain", "finale", "menu"] else "step_stone_") + str(_step_index)
	if not _cue_streams.has(cue):
		return
	if kind == "shot":
		duck_ambience()
		shot_player.stream = _cue_streams[cue]
		shot_player.pitch_scale = 1.0
		shot_player.volume_db = _db(0.90)
		shot_player.play()
		return
	var player := cue_players[_cue_index % cue_players.size()]
	_cue_index += 1
	player.stop()
	player.stream = _cue_streams[cue]
	player.pitch_scale = 0.78 if kind=="second_step" else randf_range(0.96, 1.04) if kind in ["step", "lever"] else 1.0
	var gain := 0.44
	match kind:
		"step": gain = 0.23
		"select": gain = 0.30
		"error": gain = 0.30
		"shift": gain = 0.49
		"door": gain = 0.43
		"pickup": gain = 0.32
		"transition": gain = 0.36
		"pressure_warning": gain = 0.44
		"pressure_release": gain = 0.34
		"power_drop": gain = 0.36
	player.volume_db = _db(gain * _ambience_volume)
	player.play()

func reveal_wind():
	_wind_reveal=true
	# The reveal cuts music for eight seconds; wind remains during the break.
	_indoor_target=0
	_outdoor_target=0.38
	set_danger(0)
