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

func _ready() -> void:
	if game_over_panel:
		game_over_panel.hide()
		var ad_btn = game_over_panel.get_node_or_null(^"VBoxContainer/AdButton") as Button
		var coin_btn = game_over_panel.get_node_or_null(^"VBoxContainer/CoinButton") as Button
		var giveup_btn = game_over_panel.get_node_or_null(^"VBoxContainer/GiveUpButton") as Button
		
		if ad_btn: ad_btn.pressed.connect(_on_ad_pressed)
		if coin_btn: coin_btn.pressed.connect(_on_coin_pressed)
		if giveup_btn: giveup_btn.pressed.connect(_on_giveup_pressed)
		
	# セーブデータの読み込み
	if SaveDataManager.get_val("stamina") != null:
		stamina = SaveDataManager.get_val("stamina")
	else:
		stamina = 20
	
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
		
	if enemy_manager:
		enemy_manager.game_over.connect(trigger_game_over)
		
	if combo_manager:
		combo_manager.combo_reached.connect(_on_combo_reached)

func _on_item_merged(level: int) -> void:
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
		cp.initial_velocity_max = 300.0
		cp.scale_amount_min = 8.0
		cp.scale_amount_max = 15.0
		cp.color = Color(0.8, 0.05, 0.05)
		
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
	get_tree().reload_current_scene()
