extends Node

@onready var game_over_panel: Control = $UILayer/GameOverPanel
@onready var stamina_panel: Control = $UILayer/StaminaPanel
@onready var order_btn: Button = $UILayer/SafeAreaMargin/MainVBox/OrderButtonContainer/HBoxContainer/OrderButton
@onready var grid_manager = get_node_or_null(^"UILayer/SafeAreaMargin/MainVBox/BottomGridArea/AspectRatioContainer/GridManager")
@onready var combo_manager = get_node_or_null(^"ComboManager")
@onready var enemy_manager: Node = $EnemyManager

var stamina: int = 20
var max_stamina: int = 20
var stamina_timer: float = 0.0
const STAMINA_REGEN_TIME: float = 3.0 # 3秒で1回復
var bonus_spawns_remaining: int = 0

var shake_intensity: float = 0.0
var shake_timer: float = 0.0
@onready var ui_layer: CanvasLayer = $UILayer

func _ready() -> void:
	if game_over_panel:
		game_over_panel.hide()
		var ad_btn = game_over_panel.get_node_or_null(^"VBoxContainer/AdButton") as Button
		var coin_btn = game_over_panel.get_node_or_null(^"VBoxContainer/CoinButton") as Button
		var giveup_btn = game_over_panel.get_node_or_null(^"VBoxContainer/GiveUpButton") as Button
		
		if ad_btn: ad_btn.pressed.connect(_on_ad_pressed)
		if coin_btn: coin_btn.pressed.connect(_on_coin_pressed)
		if giveup_btn: giveup_btn.pressed.connect(_on_giveup_pressed)
		
	# シールドラベルの生成
	_create_shield_label_if_missing()
		
	var sign_level = SaveDataManager.get_val("sign_upgrade_level")
	if sign_level == null: sign_level = 0
	max_stamina = 20 + sign_level
	
	# セーブデータの読み込み
	if SaveDataManager.get_val("stamina") != null:
		stamina = SaveDataManager.get_val("stamina")
	else:
		stamina = max_stamina
	
	if stamina_panel:
		stamina_panel.hide()
		var ad_stam = stamina_panel.get_node_or_null(^"VBoxContainer/AdStaminaButton") as Button
		var cancel_stam = stamina_panel.get_node_or_null(^"VBoxContainer/CancelStaminaButton") as Button
		if ad_stam: ad_stam.pressed.connect(_on_ad_stamina_pressed)
		if cancel_stam: cancel_stam.pressed.connect(_on_cancel_stamina_pressed)
		
	if order_btn:
		order_btn.pressed.connect(_on_order_pressed)
		update_stamina_ui()
	
	if grid_manager:
		grid_manager.merged.connect(_on_item_merged)
		
	if combo_manager:
		combo_manager.combo_reached.connect(_on_combo_reached)

func _on_item_merged(level: int) -> void:
	if AudioManager: AudioManager.play_merge_sfx()
	
	# ComboManagerに通知
	if combo_manager:
		# 今回は画面中央付近を基準にするか、後でGridManagerから座標をもらうようにする
		# とりあえず簡易的にマウス座標(ドロップ位置)を渡す
		combo_manager.register_merge(get_viewport().get_mouse_position())
		
	if level >= 3:
		# ランダムな位置にカットインを出す
		var pos = Vector2(randf_range(100, 600), randf_range(200, 600))
		play_b_movie_effect("cutin", pos)

func _process(delta: float) -> void:
	if stamina < max_stamina:
		stamina_timer += delta
		if stamina_timer >= STAMINA_REGEN_TIME:
			stamina_timer -= STAMINA_REGEN_TIME
			stamina += 1
			SaveDataManager.set_val("stamina", stamina)
			update_stamina_ui()
			
	if shake_timer > 0:
		shake_timer -= delta
		if ui_layer:
			var rand_val = randf_range(-shake_intensity, shake_intensity)
			ui_layer.offset = Vector2(rand_val, rand_val)
		if shake_timer <= 0 and ui_layer:
			ui_layer.offset = Vector2.ZERO

func update_stamina_ui() -> void:
	if order_btn:
		order_btn.text = "ORDER (%d/%d)" % [stamina, max_stamina]

func _on_order_pressed() -> void:
	if stamina <= 0:
		get_tree().paused = true
		if stamina_panel: stamina_panel.show()
		return
		
	if grid_manager and grid_manager.has_method("spawn_order"):
		# ボーナスタイム中は強制的に高いレベルを生成させるためのフラグを渡す
		var is_bonus = bonus_spawns_remaining > 0
		var success = grid_manager.spawn_order(is_bonus)
		if success:
			stamina -= 1
			SaveDataManager.set_val("stamina", stamina)
			update_stamina_ui()
			if is_bonus:
				bonus_spawns_remaining -= 1
		else:
			print("Order failed: grid is full!")
			play_b_movie_effect("cutin", Vector2(360, 600))

func _on_ad_stamina_pressed() -> void:
	print("--- AD WATCHED: STAMINA REFILLED ---")
	stamina = max_stamina
	SaveDataManager.set_val("stamina", stamina)
	bonus_spawns_remaining = 3 # ボーナスタイム（次3回はLv2/3確定）
	update_stamina_ui()
	if stamina_panel: stamina_panel.hide()
	get_tree().paused = false

func _on_cancel_stamina_pressed() -> void:
	if stamina_panel: stamina_panel.hide()
	get_tree().paused = false

func shake_screen(intensity: float, duration: float) -> void:
	shake_intensity = intensity
	shake_timer = duration

func play_b_movie_effect(effect_type: String, pos: Vector2) -> void:
	if effect_type == "ketchup":
		# シンプルなパーティクル生成
		var cp = CPUParticles2D.new()
		cp.emitting = false
		cp.one_shot = true
		cp.amount = 30
		cp.explosiveness = 0.95
		cp.lifetime = 0.6
		cp.spread = 180.0
		cp.gravity = Vector2(0, 400)
		cp.initial_velocity_min = 150.0
		cp.initial_velocity_max = 400.0
		cp.scale_amount_min = 6.0
		cp.scale_amount_max = 12.0
		
		# 王道のBlood RedからドギツイNeon Pink, Neon Greenなどをランダムに設定
		var neon_colors = [
			Color(1.0, 0.1, 0.8), # ネオンピンク
			Color(0.2, 1.0, 0.2), # ネオングリーン
			Color(0.0, 0.8, 1.0), # ネオンシアン
			Color(1.0, 0.0, 0.0), # 通常の血
			Color(1.0, 0.5, 0.0)  # オレンジ
		]
		cp.color = neon_colors[randi() % neon_colors.size()]
		
		add_child(cp)
		cp.global_position = pos
		cp.restart()
		
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(cp):
			cp.queue_free()
			
	elif effect_type == "cutin":
		var label = Label.new()
		label.text = "MERGE!"
		label.add_theme_font_size_override("font_size", 40)
		label.add_theme_color_override("font_color", Color(1, 1, 0))
		get_node("UILayer").add_child(label)
		label.global_position = pos
		var tw = create_tween()
		tw.tween_property(label, "position:y", pos.y - 100, 0.5)
		tw.tween_property(label, "modulate:a", 0, 0.5)
		tw.tween_callback(label.queue_free)
	elif effect_type == "trash_shredder":
		# ガガガガッという感じで赤いパーティクルを散らす
		var cp = CPUParticles2D.new()
		cp.emitting = false
		cp.one_shot = true
		cp.amount = 40
		cp.lifetime = 0.6
		cp.explosiveness = 0.9
		cp.spread = 180
		cp.gravity = Vector2(0, 800)
		cp.initial_velocity_min = 200
		cp.initial_velocity_max = 500
		cp.color = Color(0.9, 0.1, 0.1) # 血の様な色
		cp.scale_amount_min = 4.0
		cp.scale_amount_max = 8.0
		add_child(cp)
		cp.global_position = pos
		cp.emitting = true
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(cp):
			cp.queue_free()

func trigger_merge_burst(pos: Vector2, level: int) -> void:
	# 円形に広がる衝撃波のビジュアルエフェクト
	var burst_visual = ColorRect.new()
	burst_visual.color = Color(1.0, 0.8, 0.0, 0.5) # 半透明の黄色
	burst_visual.size = Vector2(10, 10)
	burst_visual.position = pos - (burst_visual.size / 2.0)
	# 角を丸くして円に見せる（Theme Override等の手法もありますが今回はシンプルに）
	get_node("UILayer").add_child(burst_visual)
	
	var explosion_radius = 120.0 + (level * 20.0) # レベルに応じて範囲拡大
	var damage = level * 15 # 範囲ダメージ
	
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(burst_visual, "size", Vector2(explosion_radius * 2, explosion_radius * 2), 0.3)
	tw.tween_property(burst_visual, "position", pos - Vector2(explosion_radius, explosion_radius), 0.3)
	tw.tween_property(burst_visual, "modulate:a", 0.0, 0.3)
	tw.set_parallel(false)
	tw.tween_callback(burst_visual.queue_free)
	
	# 周辺のゾンビにダメージ
	var zombies = get_tree().get_nodes_in_group("zombies")
	for z in zombies:
		if is_instance_valid(z) and z.global_position.distance_to(pos) <= explosion_radius:
			if z.has_method("take_damage"):
				z.take_damage(damage)

func _on_combo_reached(count: int, _pos: Vector2) -> void:
	if AudioManager: AudioManager.play_combo_sfx()
	shake_camera(count * 5.0, 0.3)

func shake_camera(intensity: float, duration: float) -> void:
	var camera = get_node_or_null(^"Camera2D") as Camera2D
	if not camera: return
	
	var tw = create_tween()
	var shake_steps = int(duration / 0.05)
	var current_intensity = intensity
	
	for i in range(shake_steps):
		var offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * current_intensity
		tw.tween_property(camera, "offset", offset, 0.05)
		current_intensity *= 0.8 # 減衰
		
	tw.tween_property(camera, "offset", Vector2.ZERO, 0.05)

func trigger_game_over() -> void:
	get_tree().paused = true
	if game_over_panel:
		game_over_panel.show()

var shield_ui_label: Label = null

func _create_shield_label_if_missing() -> void:
	var hbox = get_node_or_null(^"UILayer/SafeAreaMargin/MainVBox/OrderButtonContainer/HBoxContainer")
	if hbox and not shield_ui_label:
		shield_ui_label = Label.new()
		shield_ui_label.name = "ShieldLabel"
		shield_ui_label.add_theme_font_size_override("font_size", 28)
		shield_ui_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
		shield_ui_label.text = "SHIELD: ?/?"
		shield_ui_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shield_ui_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hbox.add_child(shield_ui_label)

func update_shield_ui(current: int, max_val: int) -> void:
	if shield_ui_label:
		shield_ui_label.text = "SHIELD: %d/%d" % [current, max_val]

func _on_ad_pressed() -> void:
	print("--- AD WATCHED ---")
	resume_game()

func _on_coin_pressed() -> void:
	print("--- CONSUMED 50 COINS ---")
	resume_game()

func resume_game() -> void:
	get_tree().paused = false
	if game_over_panel:
		game_over_panel.hide()
	
	# コンティニュー時に敵を全滅させる
	for z in get_tree().get_nodes_in_group("zombies"):
		if z.has_method("take_damage"):
			z.take_damage(9999) # 演出付きで死なせる

func _on_giveup_pressed() -> void:
	get_tree().paused = false
	if SceneManager:
		SceneManager.change_scene("res://scenes/HomeScene.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/HomeScene.tscn")

# -------------------------
# DEBUG MENU
# -------------------------
var active_touches: Dictionary = {}
var debug_menu_instance: Control = null

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			active_touches[event.index] = event.position
			if active_touches.size() >= 3 and debug_menu_instance == null:
				var is_top_area = true
				for pos in active_touches.values():
					# 画面上部の300ピクセル以内か
					if pos.y > 300:
						is_top_area = false
						break
				if is_top_area:
					show_debug_menu()
		else:
			active_touches.erase(event.index)

func show_debug_menu() -> void:
	var panel = PanelContainer.new()
	debug_menu_instance = panel
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "=== DEBUG MENU ==="
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var btn_coin = Button.new()
	btn_coin.text = "Add +100 Coins (Stamina as Coin)"
	btn_coin.pressed.connect(func():
		max_stamina += 100
		stamina += 100
		update_stamina_ui()
		print("DEBUG: Added 100 max stamina/coins.")
	)
	vbox.add_child(btn_coin)
	
	var btn_skip = Button.new()
	btn_skip.text = "Skip Stage"
	btn_skip.pressed.connect(func():
		var lm = get_tree().current_scene.get_node_or_null("LevelManager")
		if lm:
			# 強制クリア
			print("DEBUG: Skipping Stage ", lm.current_stage)
			lm.zombies_defeated = lm.zombies_to_spawn
			lm.zombies_spawned = lm.zombies_to_spawn
			lm.handle_stage_clear()
	)
	vbox.add_child(btn_skip)
	
	var btn_close = Button.new()
	btn_close.text = "Close"
	btn_close.pressed.connect(func():
		panel.queue_free()
		debug_menu_instance = null
	)
	vbox.add_child(btn_close)
	
	get_node("UILayer").add_child(panel)

# -------------------------
# RESULT DIALOG
# -------------------------
func show_result(stage: int) -> void:
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var panel = PanelContainer.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	center.add_child(panel)
	bg.add_child(center)
	
	var title = Label.new()
	title.text = "STAGE %d CLEAR" % stage
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)
	
	var coins_reward = stage * 50
	var reward_label = Label.new()
	reward_label.text = "Reward: %d Coins" % coins_reward
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(reward_label)
	
	var btn_ad = Button.new()
	btn_ad.text = "Watch AD: Double Coins"
	btn_ad.add_theme_font_size_override("font_size", 32)
	btn_ad.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	btn_ad.pressed.connect(func():
		print("--- AD WATCHED (MOCK) ---")
		print("Coins Doubled!")
		_on_return_to_home_pressed(stage, coins_reward * 2)
		panel.queue_free()
	)
	vbox.add_child(btn_ad)
	
	var btn_home = Button.new()
	btn_home.text = "RETURN TO HOME"
	btn_home.add_theme_font_size_override("font_size", 32)
	btn_home.pressed.connect(func():
		_on_return_to_home_pressed(stage, coins_reward)
		bg.queue_free()
	)
	vbox.add_child(btn_home)
	
	var ui_layer = get_node("UILayer")
	if ui_layer:
		ui_layer.add_child(bg)

func disable_input() -> void:
	var ui_layer = get_node("UILayer")
	if ui_layer and not ui_layer.has_node("InputBlocker"):
		var blocker = Control.new()
		blocker.name = "InputBlocker"
		blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		blocker.mouse_filter = Control.MOUSE_FILTER_STOP
		ui_layer.add_child(blocker)

func _on_return_to_home_pressed(stage: int, coins_reward: int) -> void:
	# セーブ更新
	var current_coins = SaveDataManager.get_val("coins")
	if current_coins == null: current_coins = 0
	SaveDataManager.set_val("coins", current_coins + coins_reward)
	
	# 次のステージへ
	SaveDataManager.set_val("current_stage", stage + 1)
	
	# スタミナも保存
	SaveDataManager.set_val("stamina", stamina)
	
	get_tree().paused = false
	if SceneManager:
		SceneManager.change_scene("res://scenes/HomeScene.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/HomeScene.tscn")
