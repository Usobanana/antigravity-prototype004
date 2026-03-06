extends Area2D
class_name Bullet

var speed: float = 600.0
var damage: int = 5
var pierce_count: int = 1
var blast_radius: float = 0.0
var knockback_power: float = 0.0
var weapon_type: int = 1
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
		# CombatSystemのエフェクトを呼び出す
		var parent = get_parent() # spawn_area
		if parent and parent.get_parent() is CombatSystem:
			parent.get_parent().on_hit_effect(weapon_type, global_position)
			
		# ノックバック適用
		if knockback_power > 0.0 and area.has_method("apply_knockback"):
			area.apply_knockback(knockback_power)
		
		# 爆発範囲ダメージを持つ場合
		if blast_radius > 0.0:
			var main = get_tree().current_scene
			
			if main and main.has_method("shake_screen"):
				main.shake_screen(6.0, 0.25)
				
			if main and main.has_method("trigger_merge_burst"):
				var burst_level = int(damage / 10.0) + 1
				main.trigger_merge_burst(global_position, burst_level)
			else:
				var zombies = get_tree().get_nodes_in_group("zombies")
				for z in zombies:
					if is_instance_valid(z) and z.global_position.distance_to(global_position) <= blast_radius:
						if z.has_method("take_damage"):
							z.take_damage(damage)
							
			queue_free()
			return
			
		# 通常 or 貫通ダメージ
		if area.has_method("take_damage"):
			area.take_damage(damage)
			
		pierce_count -= 1
		if pierce_count <= 0:
			queue_free()
