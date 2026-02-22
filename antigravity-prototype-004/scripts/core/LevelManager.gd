extends Node

@export var enemy_manager: Node
@export var uilayer: CanvasLayer

var current_stage: int = 1
var zombies_to_spawn: int = 0
var zombies_spawned: int = 0
var zombies_defeated: int = 0

var stage_clear_label: Label

func _ready() -> void:
	if not enemy_manager:
		enemy_manager = get_tree().current_scene.get_node_or_null("EnemyManager")
	if not uilayer:
		uilayer = get_tree().current_scene.get_node_or_null("UILayer")
		
	# ステージクリア用ラベルを準備
	stage_clear_label = Label.new()
	stage_clear_label.text = "STAGE CLEAR!"
	stage_clear_label.add_theme_font_size_override("font_size", 60)
	stage_clear_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	stage_clear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_clear_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stage_clear_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_clear_label.modulate = Color(1, 1, 1, 0) # 最初は透明
	stage_clear_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if uilayer:
		uilayer.add_child(stage_clear_label)
		
	# EnemyManagerのシグナル監視
	if enemy_manager:
		enemy_manager.zombie_spawned.connect(_on_zombie_spawned)
		enemy_manager.zombie_defeated.connect(_on_zombie_defeated)
		if not enemy_manager.zombie_escaped.is_connected(_on_zombie_escaped):
			enemy_manager.zombie_escaped.connect(_on_zombie_escaped)
		
	# 少し待ってからステージ1開始
	await get_tree().create_timer(1.0).timeout
	start_stage(1)

func start_stage(stage: int) -> void:
	current_stage = stage
	zombies_spawned = 0
	zombies_defeated = 0
	
	# ステージごとの難易度調整
	zombies_to_spawn = 5 + (stage * 2)
	var spawn_rate = max(0.5, 2.0 - (stage * 0.2))
	var min_speed = 30.0 + (stage * 5.0)
	var max_speed = 60.0 + (stage * 10.0)
	
	# 簡易的なステージ（レイアウト）定義
	# 0: Empty, 1: Lv1 Item, 2: Lv2 Item, -1: Obstacle
	var layouts = {
		# Stage 1: 中央に障害物、四隅に近い所にLv1
		1: [
			1, 0, 0, 0, 1,
			0, 0, 0, 0, 0,
			0, 0,-1, 0, 0,
			0, 0, 0, 0, 0,
			1, 0, 0, 0, 1
		],
		# Stage 2: 少し障害物が増え、いくつかのLv2がある
		2: [
			2, 0, 0, 0, 2,
			0,-1, 0,-1, 0,
			1, 0, 0, 0, 1,
			0,-1, 0,-1, 0,
			1, 0, 0, 0, 1
		]
	}
	
	var grid_manager = get_tree().current_scene.get_node_or_null("UILayer/SafeAreaMargin/MainVBox/BottomGridArea/AspectRatioContainer/GridManager")
	if grid_manager and grid_manager.has_method("load_layout"):
		# 定義がないステージ以降はすべて空の盤面(Stage 1ベースなどを使い回す処理も可能)
		var layout = layouts.get(stage, [])
		if layout.is_empty():
			layout = []
			layout.resize(25)
			layout.fill(0)
		grid_manager.load_layout(layout)
	
	print("--- STAGE %d START ---" % current_stage)
	print("Zombies: %d, Rate: %.2f" % [zombies_to_spawn, spawn_rate])
	
	if enemy_manager:
		enemy_manager.start_spawning(spawn_rate, min_speed, max_speed)

func _on_zombie_spawned() -> void:
	zombies_spawned += 1
	if zombies_spawned >= zombies_to_spawn:
		if enemy_manager:
			enemy_manager.stop_spawning()

func _on_zombie_defeated() -> void:
	zombies_defeated += 1
	if zombies_spawned >= zombies_to_spawn and zombies_defeated >= zombies_to_spawn:
		handle_stage_clear()

func _on_zombie_escaped() -> void:
	zombies_defeated += 1
	# コンティニュー後などにウェーブが終了できるようにする
	if zombies_spawned >= zombies_to_spawn and zombies_defeated >= zombies_to_spawn:
		handle_stage_clear()

func handle_stage_clear() -> void:
	print("--- STAGE %d CLEAR ---" % current_stage)
	
	# クリア演出
	var tw = create_tween()
	stage_clear_label.text = "STAGE %d CLEAR!" % current_stage
	tw.tween_property(stage_clear_label, "modulate:a", 1.0, 0.5)
	tw.tween_interval(1.5)
	tw.tween_property(stage_clear_label, "modulate:a", 0.0, 0.5)
	
	await tw.finished
	
	# 次のステージへ
	start_stage(current_stage + 1)
