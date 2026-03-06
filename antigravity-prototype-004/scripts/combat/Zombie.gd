extends Area2D
class_name Zombie

signal reached_bottom
signal died(zombie_ref: Node)

enum ZombieType { NORMAL, TANK, RUNNER }
var type: ZombieType = ZombieType.NORMAL

var speed: float = 40.0
var hp: int = 10
var bottom_limit: float = 800.0

# 状態管理
var is_knockbacked: bool = false
var base_modulate: Color = Color.WHITE

func setup(z_type: ZombieType, base_hp: int, base_speed: float) -> void:
	type = z_type
	match type:
		ZombieType.NORMAL:
			hp = base_hp
			speed = base_speed
			base_modulate = Color(0.3, 0.8, 0.3) # Standard Green
		ZombieType.TANK:
			hp = base_hp * 3
			speed = base_speed * 0.5
			base_modulate = Color(0.2, 0.4, 0.2) # Dark Green
			scale = Vector2(1.5, 1.5) # Bigger footprint
			add_to_group("tanks")
		ZombieType.RUNNER:
			hp = int(base_hp * 0.5)
			if hp < 1: hp = 1
			speed = base_speed * 1.8
			base_modulate = Color(0.8, 0.3, 0.3) # Reddish
			scale = Vector2(0.8, 0.8) # Smaller footprint
			add_to_group("runners")
			
	# Update color rect if it exists
	var rect = get_node_or_null("ColorRect")
	if rect:
		rect.color = base_modulate
		
	modulate = base_modulate

func _ready() -> void:
	add_to_group("zombies")
	
func _process(delta: float) -> void:
	if not is_knockbacked:
		position.y += speed * delta
		
	if position.y >= bottom_limit:
		reached_bottom.emit()
		queue_free()

func apply_knockback(distance: float) -> void:
	# 既にノックバック中なら重ね掛けしない(または距離を伸ばす等)でも良いが、今回はシンプルに無効化
	if is_knockbacked: return
	
	is_knockbacked = true
	var tw = get_tree().create_tween()
	tw.set_parallel(true)
	
	# 上に押し戻すが、画面外に出すぎないよう制限 (-30くらいまで)
	var target_y = max(-30.0, position.y - distance)
	tw.tween_property(self, "position:y", target_y, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# 横に少しだけ散らす（他のゾンビと被りにくくする）
	# 例: -20px 〜 20px の範囲でランダムにX座標をズラす
	var screen_width = get_viewport_rect().size.x
	var target_x = clamp(position.x + randf_range(-20.0, 20.0), 40.0, screen_width - 40.0)
	tw.tween_property(self, "position:x", target_x, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	tw.chain().tween_callback(func(): is_knockbacked = false)

func take_damage(amount: int) -> void:
	hp -= amount
	modulate = Color(1, 0, 0)
	var tw = get_tree().create_tween()
	tw.tween_property(self, "modulate", base_modulate, 0.1)
	
	if hp <= 0:
		if AudioManager:
			AudioManager.play_zombie_death_sfx()
		var particles_scene = load("res://scenes/effects/ZombieDeathParticles.tscn")
		if particles_scene:
			var p_instance = particles_scene.instantiate()
			p_instance.global_position = global_position
			get_tree().current_scene.add_child(p_instance)
			
		died.emit(self)
		queue_free()
