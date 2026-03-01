extends Node

# 演出（Juice）用Audio Manager
# サウンドリソースは仮のパス（sfx/...）を設定。存在しない場合は安全に無視されます。

var merge_stream: AudioStream = null
var combo_stream: AudioStream = null
var death_stream: AudioStream = null

var audio_players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	if ResourceLoader.exists("res://sfx/merged.wav"):
		merge_stream = load("res://sfx/merged.wav")
	if ResourceLoader.exists("res://sfx/combo.wav"):
		combo_stream = load("res://sfx/combo.wav")
	if ResourceLoader.exists("res://sfx/zombie_death.wav"):
		death_stream = load("res://sfx/zombie_death.wav")
	# 同時再生用のプレイヤープールをいくつか用意
	for i in range(5):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		audio_players.append(p)

func play_sfx(stream: AudioStream) -> void:
	if not stream: return
	
	for p in audio_players:
		if not p.playing:
			p.stream = stream
			p.play()
			return
			
	# 全て再生中の場合、強引に最初のプレイヤーを再利用（今回は簡易版）
	if audio_players.size() > 0:
		audio_players[0].stream = stream
		audio_players[0].play()

func play_merge_sfx() -> void:
	play_sfx(merge_stream)

func play_combo_sfx() -> void:
	play_sfx(combo_stream)

func play_zombie_death_sfx() -> void:
	play_sfx(death_stream)
