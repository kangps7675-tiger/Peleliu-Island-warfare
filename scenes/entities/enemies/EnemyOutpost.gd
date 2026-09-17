extends StaticBody2D
class_name EnemyOutpost

@export var max_hp: float = 180.0
@export var current_hp: float = 180.0
@export var respawn_time: float = 15.0 # 15초 뒤 지하에서 재건축 부활!
@export var infantry_scene: PackedScene = preload("res://scenes/entities/enemies/EnemyBase.tscn")
@export var gem_scene: PackedScene = preload("res://scenes/entities/drops/Gem.tscn")

var is_destroyed: bool = false
var respawn_timer: float = 0.0
var spawn_soldier_timer: float = 2.0
var flash_timer: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	collision_layer = 4 # Enemy/Obstacle layer
	collision_mask = 3  # Player Head & Body
	add_to_group("outposts")
	add_to_group("enemies")
	current_hp = max_hp

func _process(delta: float) -> void:
	if is_destroyed:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_respawn()
		queue_redraw()
		return
	
	spawn_soldier_timer -= delta
	if spawn_soldier_timer <= 0.0:
		spawn_soldier_timer = 2.8
		_spawn_soldier()
		
	if flash_timer > 0.0:
		flash_timer -= delta
		if sprite:
			sprite.modulate = Color(2.0, 2.0, 2.0)
	elif sprite and not is_destroyed:
		sprite.modulate = Color.WHITE
	
	queue_redraw()

func _spawn_soldier() -> void:
	if infantry_scene:
		var soldier = infantry_scene.instantiate()
		soldier.global_position = global_position + Vector2(randf_range(-30, 30), 45.0)
		get_parent().add_child(soldier)

func take_damage(amount: float) -> void:
	if is_destroyed:
		return
	current_hp -= amount
	flash_timer = 0.08
	queue_redraw()
	
	if current_hp <= 0.0:
		_destroy()

func _destroy() -> void:
	is_destroyed = true
	respawn_timer = respawn_time
	collision_shape.set_deferred("disabled", true)
	if sprite:
		sprite.modulate = Color(0.25, 0.22, 0.2, 0.45) # 파괴된 폐허 음영
	
	# 대량 보급품 드롭
	if gem_scene:
		for i in range(4):
			var g = gem_scene.instantiate()
			g.global_position = global_position + Vector2(randf_range(-25, 25), randf_range(-25, 25))
			get_parent().call_deferred("add_child", g)
			
	EventBus.enemy_killed.emit(global_position, "OUTPOST")

func _respawn() -> void:
	is_destroyed = false
	current_hp = max_hp
	collision_shape.set_deferred("disabled", false)
	if sprite:
		sprite.modulate = Color.WHITE

func _draw() -> void:
	if is_destroyed:
		# 15초 재건축 진행도 원형 게이지
		var prog = 1.0 - (respawn_timer / respawn_time)
		draw_arc(Vector2.ZERO, 45.0, -PI * 0.5, -PI * 0.5 + TAU * prog, 32, Color(1.0, 0.85, 0.2), 4.0)
		draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.4, 0.1))
