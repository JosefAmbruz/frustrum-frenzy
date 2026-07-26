extends Node3D

var sounds := {
	"camera_click_sound": preload("res://assets/sounds/camera_click_sound.mp3"),
	"player_jump_sound": preload("res://assets/sounds/jump.wav"),
	"player_running_sound": preload("res://assets/sounds/player_running_sound.mp3")
}

var sound_player: AudioStreamPlayer

func _ready() -> void:
	sound_player = AudioStreamPlayer.new()
	add_child(sound_player)


func play_sound(sound_name: String) -> void:
	if sounds.has(sound_name):
		sound_player.stream = sounds[sound_name]
		sound_player.play()
	else:
		print("Sound not found: ", sound_name)	
		
func stop() -> void:
	sound_player.stop()
