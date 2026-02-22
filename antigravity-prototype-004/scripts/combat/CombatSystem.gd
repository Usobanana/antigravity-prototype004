extends Node
class_name CombatSystem

@export var grid_manager: GridContainer
@export var spawn_area: Control

var attack_timer: Timer
var bullet_script = preload("res://scripts/combat/Bullet.gd")

func _ready() -> void:
	attack_timer = Timer.new()
	attack_timer.wait_time = 0.5 # 0.5秒ごとに攻撃判定
	attack_timer.autostart = true
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	add_child(attack_timer)

func _on_attack_timer_timeout() -> void:
	if not grid_manager or not spawn_area: return
	
	var items = grid_manager.get("items")
	if typeof(items) != TYPE_ARRAY: return
	
	for i in range(items.size()):
		var item = items[i]
		# クールダウンがない、または0以下なら攻撃可能
		if item != null and item.get("level", 0) >= 3 and item.get("cooldown", 0.0) <= 0:
			shoot_from_slot(i, item.level)

func shoot_from_slot(slot_idx: int, level: int) -> void:
	var zombies = get_tree().get_nodes_in_group("zombies")
	if zombies.is_empty(): return
	
	var slot_node = grid_manager.get_child(slot_idx)
	if not slot_node is Control: return
	
	var start_pos = slot_node.global_position + (slot_node.size / 2.0)
	
	# スロットの列 (0〜4) を計算
	var slot_col = slot_idx % 5
	# 列の幅を計算
	var grid_width = grid_manager.size.x
	var col_width = grid_width / 5.0
	var col_start_x = grid_manager.global_position.x + (slot_col * col_width)
	var col_end_x = col_start_x + col_width
	
	var nearest_zombie: Node = null
	var min_dist = INF
	
	# 同一列にいる一番近いゾンビを探す
	for z in zombies:
		var z_x = z.global_position.x
		if z_x >= col_start_x and z_x <= col_end_x:
			var dist = start_pos.distance_squared_to(z.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest_zombie = z
				
	# 同一列にいなければ、全体で一番近いゾンビを探す
	if nearest_zombie == null:
		min_dist = INF
		for z in zombies:
			var dist = start_pos.distance_squared_to(z.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest_zombie = z
	
	if nearest_zombie:
		var bullet = Area2D.new()
		bullet.set_script(bullet_script)
		
		var rect = ColorRect.new()
		
		# レベルによる弾の性能分岐
		if level >= 7:
			# Lv.7〜：爆発弾 (赤色、やや大きく、着弾地点で範囲ダメージ)
			rect.color = Color(1.0, 0.2, 0.0)
			rect.size = Vector2(12, 24)
			bullet.damage = level * 4
			bullet.blast_radius = 80.0
			bullet.pierce_count = 1
		elif level >= 5:
			# Lv.5〜6：貫通弾 (シアン色、3体まで貫通)
			rect.color = Color(0.0, 1.0, 1.0)
			rect.size = Vector2(6, 30)
			bullet.damage = level * 3
			bullet.blast_radius = 0.0
			bullet.pierce_count = 3
		else:
			# Lv.3〜4：通常弾 (黄色、単発)
			rect.color = Color(1.0, 1.0, 0.0)
			rect.size = Vector2(8, 20)
			bullet.damage = level * 2
			bullet.blast_radius = 0.0
			bullet.pierce_count = 1
		
		rect.position = -rect.size / 2.0
		bullet.add_child(rect)
		
		# Bullet collision
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = rect.size
		col.shape = shape
		col.rotation_degrees = 90
		bullet.add_child(col)
		
		bullet.target = nearest_zombie
		
		spawn_area.add_child(bullet)
		bullet.global_position = start_pos
