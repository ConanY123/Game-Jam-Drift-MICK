extends Node

const DREAM_REVERB_WET := 0.1
const DREAM_MUSIC_ATTENUATION_DB := -4.0
const DREAM_AUDIO_BUS := "DreamFX"
const DREAM_REVERB_EFFECT_INDEX := 0

# One reusable music player; we swap its stream per level.
@onready var music_player: AudioStreamPlayer2D = $Music
@onready var game_over_player: AudioStreamPlayer2D = $SFX/GameOver
@onready var victory: AudioStreamPlayer2D = $SFX/Victory
@onready var goose_honk_player: AudioStreamPlayer = $SFX/GooseHonk

var _dream_audio_bus_index := -1
var _dream_reverb: AudioEffectReverb
var _reverb_tween: Tween
var _music_volume_tween: Tween
var _base_music_volume_db := 0.0

# Map level number -> track. Assign these in the scene (see below) or preload.
const TRACKS := {
	1: preload("res://audio/music/[TwoShot] LevelOne.mp3"),
	2: preload("res://audio/music/[TwoShot] LevelTwo.mp3"),
	3: preload("res://audio/music/[TwoShot] LevelThree.mp3"),
	4: preload("res://audio/music/[TwoShot] LevelFour.mp3"),
	5: preload("res://audio/music/Dark Techno EBM Industrial beat Warriors of the Wasteland - Cybermode Beats (128k).mp3")
}

func _ready() -> void:
	_base_music_volume_db = music_player.volume_db
	_dream_audio_bus_index = AudioServer.get_bus_index(DREAM_AUDIO_BUS)
	if _dream_audio_bus_index < 0:
		push_error("Audio bus '%s' was not found." % DREAM_AUDIO_BUS)
		return
	_dream_reverb = AudioServer.get_bus_effect(
		_dream_audio_bus_index,
		DREAM_REVERB_EFFECT_INDEX
	) as AudioEffectReverb
	if _dream_reverb == null:
		push_error("Audio bus '%s' is missing its reverb effect." % DREAM_AUDIO_BUS)
		return
	_dream_reverb.wet = 0.0
	AudioServer.set_bus_effect_enabled(
		_dream_audio_bus_index,
		DREAM_REVERB_EFFECT_INDEX,
		false
	)

func set_dream_reverb(enabled: bool, fade_duration: float) -> void:
	if _dream_reverb == null:
		return
	if _reverb_tween != null and _reverb_tween.is_valid():
		_reverb_tween.kill()

	var target_wet := DREAM_REVERB_WET if enabled else 0.0
	if enabled:
		AudioServer.set_bus_effect_enabled(
			_dream_audio_bus_index,
			DREAM_REVERB_EFFECT_INDEX,
			true
		)

	if fade_duration <= 0.0:
		_dream_reverb.wet = target_wet
		AudioServer.set_bus_effect_enabled(
			_dream_audio_bus_index,
			DREAM_REVERB_EFFECT_INDEX,
			enabled
		)
		return

	_reverb_tween = create_tween()
	_reverb_tween.tween_method(
		_set_reverb_wet,
		_dream_reverb.wet,
		target_wet,
		fade_duration
	)
	if not enabled:
		_reverb_tween.tween_callback(
			func():
				AudioServer.set_bus_effect_enabled(
					_dream_audio_bus_index,
					DREAM_REVERB_EFFECT_INDEX,
					false
				)
		)

func _set_reverb_wet(wet: float) -> void:
	_dream_reverb.wet = wet

func set_dream_music_quieter(enabled: bool, fade_duration: float) -> void:
	if _music_volume_tween != null and _music_volume_tween.is_valid():
		_music_volume_tween.kill()

	var target_volume := _base_music_volume_db
	if enabled:
		target_volume += DREAM_MUSIC_ATTENUATION_DB

	if fade_duration <= 0.0:
		music_player.volume_db = target_volume
		return

	_music_volume_tween = create_tween()
	_music_volume_tween.tween_property(
		music_player,
		"volume_db",
		target_volume,
		fade_duration
	)

func play_music(level_number: int) -> void:
	game_over_player.stop()
	victory.stop()
	if not TRACKS.has(level_number):
		push_warning("No track for level %d" % level_number)
		return
	music_player.stream = TRACKS[level_number]
	music_player.play(17.0 if level_number == 5 else 0.0)

func play_game_over() -> void:
	music_player.stop()
	game_over_player.play()
	
func play_victory() -> void:
	music_player.stop()
	victory.play()

func play_goose_honk() -> void:
	goose_honk_player.stop()
	goose_honk_player.play()
