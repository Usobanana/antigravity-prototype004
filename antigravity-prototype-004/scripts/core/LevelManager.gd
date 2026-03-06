extends Node

@export var enemy_manager: Node
@export var uilayer: CanvasLayer

var current_stage: int = 1
var zombies_to_spawn: int = 0
var zombies_spawned: int = 0
var zombies_defeated: int = 0

var stage_clear_label: Label
var countdown_label: Label
var skip_button: Button

var max_shield: int = 1
var current_shield: int = 1

var ready_timer: float = 0.0
var is_ready_phase: bool = false
var spawn_rate_cache: float = 0.0
var min_speed_cache: float = 0.0
var max_speed_cache: float = 0.0
var zombie_hp_cache: int = 10

var is_stage_clearing: bool = false

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
			
	# 準備フェーズ用UI生成
	countdown_label = Label.new()
	countdown_label.add_theme_font_size_override("font_size", 80)
	countdown_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	countdown_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	countdown_label.position.y = 120
	countdown_label.hide()
	if uilayer: uilayer.add_child(countdown_label)
	
	skip_button = Button.new()
	skip_button.text = "BRING 'EM ON!"
	skip_button.add_theme_font_size_override("font_size", 36)
	skip_button.add_theme_color_override("font_color", Color(1, 1, 0))
	skip_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_button.position = Vector2(400, 1000) # 右下付近
	skip_button.custom_minimum_size = Vector2(300, 80)
	skip_button.pressed.connect(_on_skip_pressed)
	skip_button.hide()
	if uilayer: uilayer.add_child(skip_button)
		
	# 初期化待機してから開始
	await get_tree().create_timer(1.0).timeout
	var saved_stage = SaveDataManager.get_val("current_stage")
	if saved_stage == null: saved_stage = 1
	start_stage(saved_stage)

func start_stage(stage: int) -> void:
	current_stage = stage
	zombies_spawned = 0
	zombies_defeated = 0
	is_stage_clearing = false
	
	# ステージごとの難易度調整 (5x5用に低下)
	zombies_to_spawn = 5 + int(stage * 1.5)
	var spawn_rate = max(0.5, 2.0 - (stage * 0.2))
	var min_speed = 20.0 + (stage * 3.0)
	var max_speed = 45.0 + (stage * 5.0)
	
	var grid_manager = get_tree().current_scene.get_node_or_null("UILayer/SafeAreaMargin/MainVBox/BottomGridArea/AspectRatioContainer/GridManager")
	if grid_manager and grid_manager.has_method("load_layout"):
		var layout = []
		layout.resize(25)
		layout.fill(0)
		
		# 基本ステージ定義(5x5想定)
		var obstacle_count = 0
		var item_lv1_count = 0
		var item_lv2_count = 0
		
		if stage == 1:
			item_lv1_count = 3
			obstacle_count = 1
		elif stage == 2:
			item_lv1_count = 3
			item_lv2_count = 1
			obstacle_count = 2
		else:
			# Stage 3以降は数式に基づいて自動生成
			obstacle_count = min(stage + 1, 8)
			item_lv1_count = min(stage + 2, 8)
			item_lv2_count = min(stage, 5)
			
		for i in range(obstacle_count):
			var idx = randi() % 25
			if layout[idx] == 0: layout[idx] = -1
		for i in range(item_lv1_count):
			var idx = randi() % 25
			if layout[idx] == 0: layout[idx] = 1
		for i in range(item_lv2_count):
			var idx = randi() % 25
			if layout[idx] == 0: layout[idx] = 2
				
		grid_manager.load_layout(layout)
	
	print("--- STAGE %d START ---" % current_stage)
	print("Zombies: %d, Rate: %.2f" % [zombies_to_spawn, spawn_rate])
	
	spawn_rate_cache = spawn_rate
	min_speed_cache = min_speed
	max_speed_cache = max_speed
	zombie_hp_cache = 10 + ((stage - 1) * 5)
	
	# シールド初期化 (固定で5)
	max_shield = 5
	
	var saved_shield = SaveDataManager.get_val("current_shield")
	if saved_shield == null: saved_shield = max_shield
	
	current_shield = min(saved_shield, max_shield)
	
	# UI用シールド更新
	var main_node = get_tree().current_scene
	if main_node and main_node.has_method("update_shield_ui"):
		main_node.update_shield_ui(current_shield, max_shield)
	
	# 準備フェーズ開始（15秒）
	is_ready_phase = true
	ready_timer = 15.0
	countdown_label.show()
	skip_button.show()
	update_countdown_ui()

func _process(delta: float) -> void:
	if is_ready_phase:
		ready_timer -= delta
		update_countdown_ui()
		if ready_timer <= 0.0:
			end_ready_phase()

func update_countdown_ui() -> void:
	if countdown_label:
		countdown_label.text = "WAVE IN: %d" % max(0, int(ready_timer))

func _on_skip_pressed() -> void:
	if is_ready_phase:
		ready_timer = 0.0
		end_ready_phase()

func end_ready_phase() -> void:
	is_ready_phase = false
	if countdown_label: countdown_label.hide()
	if skip_button: skip_button.hide()
	
	if enemy_manager:
		enemy_manager.start_spawning(spawn_rate_cache, min_speed_cache, max_speed_cache, zombie_hp_cache)

func _on_zombie_spawned() -> void:
	zombies_spawned += 1
	if zombies_spawned >= zombies_to_spawn:
		if enemy_manager:
			enemy_manager.stop_spawning()

func _on_zombie_defeated() -> void:
	zombies_defeated += 1
	if zombies_spawned >= zombies_to_spawn and zombies_defeated >= zombies_to_spawn:
		trigger_slowmo_stage_clear()

func _on_zombie_escaped() -> void:
	zombies_defeated += 1
	
	current_shield -= 1
	SaveDataManager.set_val("current_shield", current_shield)
	
	var main_node = get_tree().current_scene
	if main_node and main_node.has_method("update_shield_ui"):
		main_node.update_shield_ui(current_shield, max_shield)
		
	if current_shield <= 0:
		# シールドが無くなったのでゲームオーバー
		if main_node and main_node.has_method("trigger_game_over"):
			main_node.trigger_game_over()
		else:
			print("GAME OVER: Out of Shields.")
			
	# コンティニュー後などにウェーブが終了できるようにする
	if current_shield > 0 and zombies_spawned >= zombies_to_spawn and zombies_defeated >= zombies_to_spawn:
		trigger_slowmo_stage_clear()

func trigger_slowmo_stage_clear() -> void:
	if is_stage_clearing: return
	is_stage_clearing = true
	
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("disable_input"):
		main_scene.disable_input()
		
	Engine.time_scale = 0.2
	
	# 実時間で約1.0秒（ゲーム内時間0.2秒分）待機して余韻を作る
	await get_tree().create_timer(1.0, true, false, true).timeout
	
	Engine.time_scale = 1.0
	handle_stage_clear()

func handle_stage_clear() -> void:
	print("--- STAGE %d CLEAR ---" % current_stage)
	
	# クリア演出とリザルト画面呼び出し
	var tw = create_tween()
	stage_clear_label.text = "STAGE %d CLEAR!" % current_stage
	tw.tween_property(stage_clear_label, "modulate:a", 1.0, 0.5)
	
	await tw.finished
	await get_tree().create_timer(1.0).timeout
	
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("show_result"):
		main_scene.show_result(current_stage)
