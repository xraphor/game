extends Node

var kick_player: AudioStreamPlayer
var goal_player: AudioStreamPlayer
var pass_player: AudioStreamPlayer

func _ready() -> void:
	kick_player = _player(_tone(100.0, 0.14, true), -11.0)
	pass_player = _player(_tone(160.0, 0.1, true), -17.0)
	goal_player = _player(_tone(760.0, 0.6, false), -17.0)

func kick() -> void:
	kick_player.play()

func pass_ball() -> void:
	pass_player.play()

func goal() -> void:
	goal_player.play()

func _player(stream: AudioStreamWAV, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume
	add_child(player)
	return player

func _tone(frequency: float, duration: float, impact: bool) -> AudioStreamWAV:
	var samples := PackedByteArray()
	var rate := 22050
	for i in range(int(rate * duration)):
		var time := float(i) / rate
		var envelope := exp(-time * (25.0 if impact else 5.0))
		var signal_value := sin(TAU * frequency * time) * envelope
		if impact:
			signal_value += sin(float(i * i + 37)) * 0.23 * envelope
		else:
			signal_value += sin(TAU * frequency * 1.5 * time) * envelope * 0.35
		var sample: int = int(clampf(signal_value, -1.0, 1.0) * 22000.0)
		samples.append(sample & 255)
		samples.append((sample >> 8) & 255)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = samples
	return stream
