# TitleScene.gd
extends Control

func _ready() -> void:
	# "TAP TO START" の点滅アニメーション
	var start_label = $VBoxContainer/StartLabel
	var tw = create_tween().set_loops()
	tw.tween_property(start_label, "modulate:a", 0.2, 0.8)
	tw.tween_property(start_label, "modulate:a", 1.0, 0.8)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.is_pressed():
			# 一度だけ反応させるため入力を無効化
			set_process_input(false)
			SceneManager.change_scene("res://scenes/HomeScene.tscn")
