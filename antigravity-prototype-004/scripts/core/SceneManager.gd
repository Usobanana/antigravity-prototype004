extends CanvasLayer

@onready var color_rect = $ColorRect

func _ready() -> void:
	color_rect.modulate.a = 0.0
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func change_scene(path: String) -> void:
	# 1. 画面を赤くフェードイン（最前面なので入力をブロック）
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw = create_tween()
	tw.tween_property(color_rect, "modulate:a", 1.0, 0.5)
	await tw.finished
	
	# 2. シーン切り替え
	get_tree().change_scene_to_file(path)
	
	# 少し待つ（シーンのロード待ち演出）
	await get_tree().create_timer(0.2).timeout
	
	# 3. フェードアウト
	var tw2 = create_tween()
	tw2.tween_property(color_rect, "modulate:a", 0.0, 0.5)
	await tw2.finished
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
