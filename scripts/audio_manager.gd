extends Node

# One reusable music player; we swap its stream per level.
@onready var music_player: AudioStreamPlayer2D = $Music
@onready var game_over_player: AudioStreamPlayer2D = $SFX/GameOver
@onready var victory: AudioStreamPlayer2D = $SFX/Victory

# Map level number -> track. Assign these in the scene (see below) or preload.
const TRACKS := {
	1: preload("res://audio/music/[TwoShot] LevelOne.mp3"),
	2: preload("res://audio/music/[TwoShot] LevelTwo.mp3"),
	3: preload("res://audio/music/[TwoShot] LevelThree.mp3"),
	4: preload("res://audio/music/[TwoShot] LevelFour.mp3")
}

func play_music(level_number: int) -> void:
	game_over_player.stop()
	victory.stop()
	if not TRACKS.has(level_number):
		push_warning("No track for level %d" % level_number)
		return
	music_player.stream = TRACKS[level_number]
	music_player.play()

func play_game_over() -> void:
	music_player.stop()
	game_over_player.play()
	
func play_victory() -> void:
	music_player.stop()
	victory.play()
