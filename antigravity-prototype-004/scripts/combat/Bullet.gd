extends Area2D
class_name Bullet

var speed: float = 600.0
var damage: int = 5
var pierce_count: int = 1
var blast_radius: float = 0.0
var target: Node2D = null

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	if is_instance_valid(target):
		var dir = (target.global_position - global_position).normalized()
		global_position += dir * speed * delta
	else:
		global_position.y -= speed * delta

func _on_area_entered(area: Area2D) -> void:
	if area is Zombie:
		
		# 爆発範囲ダメージを持つ場合
		if blast_radius > 0.0:
			var main = get_tree().current_scene
			if main.has_method("trigger_merge_burst"):
				# 簡易的に同じバーストエフェクトの仕組みを流用（黄色エフェクト）
				# より専用の爆発を作りたい場合は別関数を用意します
				var burst_level = int(damage / 10.0) + 1
				main.trigger_merge_burst(global_position, burst_level)
			else:
				# メインに関数がなければ自前で範囲ダメージ処理
				var zombies = get_tree().get_nodes_in_group("zombies")
				for z in zombies:
					if is_instance_valid(z) and z.global_position.distance_to(global_position) <= blast_radius:
						if z.has_method("take_damage"):
							z.take_damage(damage)
							
			# 爆発弾は貫通せずに1発で消滅
			queue_free()
			return
			
		# 通常 or 貫通ダメージ
		area.take_damage(damage)
		pierce_count -= 1
		
		if pierce_count <= 0:
			queue_free()
