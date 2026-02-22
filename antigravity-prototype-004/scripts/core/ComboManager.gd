class_name ComboManager
extends Node

signal combo_reached(count: int, pos: Vector2)

var combo_timer: float = 0.0
var current_combo: int = 0
const COMBO_WINDOW: float = 1.0

func _process(delta: float) -> void:
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_timer = 0.0
			current_combo = 0 # コンボ途切れ

func register_merge(pos: Vector2) -> void:
	if combo_timer > 0.0 or current_combo == 0:
		# 1秒以内のマージ、または最初のマージ
		current_combo += 1
	else:
		# タイマー切れ直後の場合はリセット
		current_combo = 1
		
	combo_timer = COMBO_WINDOW
	
	if current_combo >= 2:
		combo_reached.emit(current_combo, pos)
		spawn_kill_bill_text(current_combo, pos)

func spawn_kill_bill_text(count: int, pos: Vector2) -> void:
	var canvas = get_tree().current_scene.get_node_or_null("UILayer")
	if not canvas: return
	
	# バックグラウンドの黄色矩形
	var bg = ColorRect.new()
	bg.color = Color(1.0, 0.85, 0.0) # ピカピカの黄色
	bg.size = Vector2(160, 50)
	
	# 黒くて太い文字
	var label = Label.new()
	label.text = "x%d COMBO!" % count
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color.BLACK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	bg.add_child(label)
	canvas.add_child(bg)
	
	# 位置と傾きの初期設定
	bg.global_position = pos - (bg.size / 2.0)
	bg.pivot_offset = bg.size / 2.0
	bg.rotation_degrees = -15.0
	
	# バウンド＆フロートアニメーション
	var tw = create_tween()
	
	# 1. 出現時のバウンド (0.1秒)
	bg.scale = Vector2(0.5, 0.5)
	tw.set_trans(Tween.TRANS_SPRING)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(bg, "scale", Vector2(1.2, 1.2), 0.1)
	tw.tween_property(bg, "scale", Vector2(1.0, 1.0), 0.1)
	
	# 2. 上にフワッと浮かびながらフェードアウト (0.6秒)
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.set_parallel(true)
	tw.tween_property(bg, "global_position:y", bg.global_position.y - 80.0, 0.6)
	tw.tween_property(bg, "modulate:a", 0.0, 0.6).set_delay(0.2) # 少し経ってから消え始める
	tw.set_parallel(false)
	
	tw.tween_callback(bg.queue_free)
