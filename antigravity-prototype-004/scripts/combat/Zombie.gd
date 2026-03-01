extends Area2D
class_name Zombie

signal reached_bottom
signal died(zombie_ref: Node)

var speed: float = 40.0
var hp: int = 10
var bottom_limit: float = 800.0

func _ready() -> void:
	add_to_group("zombies")
	
func _process(delta: float) -> void:
	position.y += speed * delta
	
	if position.y >= bottom_limit:
		reached_bottom.emit()
		queue_free()

func take_damage(amount: int) -> void:
	hp -= amount
	modulate = Color(1, 0, 0)
	var tw = get_tree().create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.1)
	
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
