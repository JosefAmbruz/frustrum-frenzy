extends Node3D

var sounds := {
	"camera_click_sound": preload("res://assets/sounds/camera_click_sound.mp3"),
	"player_jump_sound": preload("res://assets/sounds/jump.wav"),
	"player_running_sound": preload("res://assets/sounds/player_running_sound.mp3"),
	"throw_sound": preload("res://assets/sounds/throw.wav")
}

var music := {
	"background_music": preload("res://assets/sounds/background_music.mp3"),
	"camera_music": preload("res://assets/sounds/camera_timer_music.mp3")
}

# footsteps, jumps, etc...
var sound_player: AudioStreamPlayer

# background music / camera timer music
var music_player: AudioStreamPlayer

func play_background_music() -> void:
	print("music is playing")
	music_player.stream = music["background_music"]
	music_player.play()
	
func play_camera_music() -> void:
	music_player.stop()
	music_player.stream = music["camera_music"]
	music_player.play()


func restore_background_music() -> void:
	music_player.stop()
	music_player.stream = music["background_music"]
	music_player.play()

func _ready() -> void:
	sound_player = AudioStreamPlayer.new()
	add_child(sound_player)
	
	music_player = AudioStreamPlayer.new()
	add_child(music_player)

	play_background_music()


func play_sound(sound_name: String) -> void:
	if sounds.has(sound_name):
		sound_player.stream = sounds[sound_name]
		sound_player.play()
	else:
		print("Sound not found: ", sound_name)	
		
func stop() -> void:
	sound_player.stop()
