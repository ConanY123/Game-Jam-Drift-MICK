extends Node

@onready var game_over_player: AudioStreamPlayer2D = $SFX/GameOver
@onready var player: AudioStreamPlayer2D = $LevelOne

func _ready():
	player.play()
	

# Call this from any script to play the game over sound
func play_game_over():
	player.stop()
	game_over_player.play()
