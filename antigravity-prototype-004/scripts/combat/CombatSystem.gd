extends Node
class_name CombatSystem

@export var grid_manager: GridContainer
@export var spawn_area: Control

var bullet_script = preload("res://scripts/combat/Bullet.gd")

# 武器種ごとの基本攻撃間隔
var fire_rates = {
	1: 0.5,  # Pistol
	2: 0.8,  # Shotgun
	3: 0.15, # Chainsaw (超高頻度)
	4: 1.0,  # Grenade
	5: 0.2,  # SMG
	99: 999.0 # Wooden Box (攻撃不可)
}

# 武器スロットごとの前回の攻撃時間
var last_attack_times: Array = []

func _ready() -> void:
	last_attack_times.resize(25) # 5x5 = 25
	last_attack_times.fill(0.0)

func _process(delta: float) -> void:
	if not grid_manager or not spawn_area: return
	
	var items = grid_manager.get("items")
	if typeof(items) != TYPE_ARRAY: return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	
	for i in range(items.size()):
		var item = items[i]
		if item != null and item.get("level", 0) >= 1 and item.get("cooldown", 0.0) <= 0:
			var w_type = item.get("type", 1)
			if w_type == 99: continue
			
			var fire_rate = fire_rates.get(w_type, 0.5)
			if current_time - last_attack_times[i] >= fire_rate:
				if try_shoot_from_slot(i, item, w_type):
					last_attack_times[i] = current_time

func try_shoot_from_slot(slot_idx: int, item: Dictionary, w_type: int) -> bool:
	var zombies = get_tree().get_nodes_in_group("zombies")
	if zombies.is_empty(): return false
	
	var slot_node = grid_manager.get_child(slot_idx)
	if not slot_node is Control: return false
	
	var start_pos = slot_node.global_position + (slot_node.size / 2.0)
	var level = item.get("level", 1)
	
	# スロットの列 (0〜4) と行 (0〜4) を計算
	var cols = 5
	var slot_col = slot_idx % cols
	var slot_row = int(slot_idx / cols)
	
	# 列の幅を計算
	var grid_width = grid_manager.size.x
	var col_width = grid_width / float(cols)
	var col_start_x = grid_manager.global_position.x + (slot_col * col_width)
	var col_end_x = col_start_x + col_width
	var center_x = col_start_x + (col_width / 2.0)
	
	var shot_fired = false
	
	match w_type:
		1: # Pistol: Nearest enemy in front, infinite range
			var target = get_nearest_zombie_in_col(zombies, col_start_x, col_end_x, start_pos, INF)
			if target == null: 
				target = get_nearest_zombie(zombies, start_pos, INF)
			
			if target:
				fire_bullet(start_pos, target, level, w_type)
				shot_fired = true
				
		2: # Shotgun: 3 columns front, knockback
			var left_start = col_start_x - col_width
			var right_end = col_end_x + col_width
			var target = get_nearest_zombie_in_range(zombies, left_start, right_end, start_pos, 400.0)
			if target:
				# ショットガンは扇状に弾を出すなど様々考えられるが、ここではシンプルに
				# 対象の敵に向かって、少し散る3発の弾を撃つ
				for i in range(3):
					var spread = Vector2(randf_range(-30, 30), 0)
					fire_bullet(start_pos, target, level, w_type, spread)
				
				var main = get_tree().current_scene
				if main and main.has_method("shake_screen"):
					main.shake_screen(3.0, 0.1)
				
				shot_fired = true
				
		3: # Chainsaw: Range 1 front (approx 150px)
			var target = get_nearest_zombie_in_col(zombies, col_start_x, col_end_x, start_pos, 200.0)
			if target:
				# 弾を撃つのではなく即着弾＋エフェクト
				target.take_damage(level * 2)
				target.apply_knockback(5.0) # 微妙に止める
				on_hit_effect(w_type, target.global_position)
				
				var main = get_tree().current_scene
				if main and main.has_method("shake_screen"):
					main.shake_screen(1.5, 0.1)
					
				shot_fired = true
				
		4: # Grenade: Nearest enemy in col, AoE on hit
			var target = get_nearest_zombie_in_col(zombies, col_start_x, col_end_x, start_pos, INF)
			if target == null:
				target = get_nearest_zombie(zombies, start_pos, INF)
				
			if target:
				fire_bullet(start_pos, target, level, w_type)
				shot_fired = true
				
		5: # SMG: Normal rapid fire
			var target = get_nearest_zombie_in_col(zombies, col_start_x, col_end_x, start_pos, INF)
			if target:
				fire_bullet(start_pos, target, level, w_type)
				shot_fired = true
				
	return shot_fired

func get_nearest_zombie_in_col(zombies: Array, st_x: float, ed_x: float, start_pos: Vector2, max_dist: float) -> Node:
	var nearest: Node = null
	var min_dist = INF
	for z in zombies:
		if is_instance_valid(z):
			var z_x = z.global_position.x
			if z_x >= st_x and z_x <= ed_x:
				var dist = start_pos.distance_to(z.global_position)
				if dist <= max_dist and dist < min_dist:
					min_dist = dist
					nearest = z
	return nearest

func get_nearest_zombie_in_range(zombies: Array, st_x: float, ed_x: float, start_pos: Vector2, max_dist: float) -> Node:
	var nearest: Node = null
	var min_dist = INF
	for z in zombies:
		if is_instance_valid(z):
			var z_x = z.global_position.x
			if z_x >= st_x and z_x <= ed_x:
				var dist = start_pos.distance_to(z.global_position)
				if dist <= max_dist and dist < min_dist:
					min_dist = dist
					nearest = z
	return nearest

func get_nearest_zombie(zombies: Array, start_pos: Vector2, max_dist: float) -> Node:
	var nearest: Node = null
	var min_dist = INF
	for z in zombies:
		if is_instance_valid(z):
			var dist = start_pos.distance_to(z.global_position)
			if dist <= max_dist and dist < min_dist:
				min_dist = dist
				nearest = z
	return nearest

func fire_bullet(start_pos: Vector2, target: Node, level: int, w_type: int, offset_pos: Vector2 = Vector2.ZERO) -> void:
	var bullet = Area2D.new()
	bullet.set_script(bullet_script)
	
	var rect = ColorRect.new()
	
	# デフォルト値
	var base_dmg = level * 2
	bullet.speed = 600.0
	bullet.pierce_count = 1
	bullet.blast_radius = 0.0
	bullet.knockback_power = 0.0
	bullet.weapon_type = w_type
	
	# 武器ごとの弾・性能カスタマイズ
	match w_type:
		1: # Pistol
			rect.color = Color(1.0, 1.0, 0.0) # 黄色
			rect.size = Vector2(8, 20)
			bullet.damage = base_dmg + 5
		2: # Shotgun
			rect.color = Color(1.0, 0.5, 0.0) # オレンジ
			rect.size = Vector2(6, 12)
			bullet.damage = level * 3
			bullet.knockback_power = 20.0
		4: # Grenade
			rect.color = Color(1.0, 0.2, 0.2) # 赤
			rect.size = Vector2(12, 12)
			bullet.speed = 400.0
			bullet.damage = level * 5
			bullet.blast_radius = 80.0 + (level * 10.0)
		5: # SMG
			rect.color = Color(0.5, 1.0, 1.0) # 水色
			rect.size = Vector2(6, 16)
			bullet.speed = 800.0
			bullet.damage = max(1, level * 1)
			
	rect.position = -rect.size / 2.0
	bullet.add_child(rect)
	
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = rect.size
	col.shape = shape
	col.rotation_degrees = 90
	bullet.add_child(col)
	
	bullet.target = target
	
	spawn_area.add_child(bullet)
	bullet.global_position = start_pos + offset_pos
	
	# 音 (簡易)
	if AudioManager and AudioManager.has_method("play_shoot_sfx"):
		AudioManager.play_shoot_sfx()

# 弾丸や近接攻撃がヒットした際に呼び出される共通エフェクトフック
func on_hit_effect(w_type: int, hit_pos: Vector2) -> void:
	var main = get_tree().current_scene
	
	match w_type:
		2: # Shotgun hit sparks
			if main.has_method("play_b_movie_effect"):
				main.play_b_movie_effect("spark", hit_pos)
		3: # Chainsaw blood
			if main.has_method("play_b_movie_effect"):
				# 既存のケチャップエフェクトなどを再利用
				main.play_b_movie_effect("ketchup", hit_pos)
		4: # Grenade Explosion (別にバースト処理があるがエフェクト用)
			pass
