extends Node

signal game_over
signal zombie_spawned
signal zombie_defeated
signal zombie_escaped

@export var spawn_area: Control

var spawn_timer: Timer
var zombie_script = preload("res://scripts/combat/Zombie.gd")

func _ready() -> void:
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 2.0
	spawn_timer.autostart = false
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)

var current_min_speed: float = 30.0
var current_max_speed: float = 60.0

func start_spawning(rate: float, min_speed: float, max_speed: float) -> void:
	spawn_timer.wait_time = rate
	current_min_speed = min_speed
	current_max_speed = max_speed
	spawn_timer.start()

func stop_spawning() -> void:
	spawn_timer.stop()

func _on_spawn_timer_timeout() -> void:
	if not spawn_area: return
	
	var zombie = Area2D.new()
	zombie.set_script(zombie_script)
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(60, 60)
	collision.shape = shape
	zombie.add_child(collision)
	
	var visual = ColorRect.new()
	visual.color = Color(0.2, 0.6, 0.2)
	visual.size = Vector2(60, 60)
	visual.position = Vector2(-30, -30)
	zombie.add_child(visual)
	
	var label = Label.new()
	label.text = "Zombie"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visual.add_child(label)
	
	spawn_area.add_child(zombie)
	
	zombie.speed = randf_range(current_min_speed, current_max_speed)
	zombie.hp = 10
	
	var spawn_width = spawn_area.size.x
	zombie.position.x = randf_range(40.0, spawn_width - 40.0)
	zombie.position.y = -40.0
	
	# Zombie reached the bottom of the TopGameplayArea
	zombie.bottom_limit = spawn_area.size.y
	
	zombie.reached_bottom.connect(_on_zombie_reached_bottom)
	zombie.died.connect(_on_zombie_died)
	
	zombie_spawned.emit()

func _on_zombie_reached_bottom() -> void:
	game_over.emit()
	zombie_escaped.emit()

func _on_zombie_died(zombie: Node) -> void:
	var main = get_tree().current_scene
	if main.has_method("play_b_movie_effect"):
		main.play_b_movie_effect("ketchup", zombie.global_position)
	zombie_defeated.emit()
