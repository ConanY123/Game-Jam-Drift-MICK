extends Node

# One reusable music player; we swap its stream per level.
@onready var music_player: AudioStreamPlayer2D = $Music
@onready var game_over_player: AudioStreamPlayer2D = $SFX/GameOver
@onready var victory: AudioStreamPlayer2D = $SFX/Victory
@onready var goose_honk_player: AudioStreamPlayer = $SFX/GooseHonk

# Map level number -> track. Assign these in the scene (see below) or preload.
const TRACKS := {
	1: preload("res://audio/music/[TwoShot] LevelOne.mp3"),
	2: preload("res://audio/music/[TwoShot] LevelTwo.mp3"),
	3: preload("res://audio/music/[TwoShot] LevelThree.mp3"),
	4: preload("res://audio/music/[TwoShot] LevelFour.mp3"),
	5: preload("res://audio/music/Dark Techno EBM Industrial beat Warriors of the Wasteland - Cybermode Beats (128k).mp3")
}

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
