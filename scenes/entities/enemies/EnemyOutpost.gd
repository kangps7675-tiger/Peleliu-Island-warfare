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

func _ready() -> void:
	collision_layer = 4 # Enemy/Obstacle layer
	collision_mask = 3  # Player Head & Body
	add_to_group("outposts")
	add_to_group("enemies") # 타겟팅 가능하도록
	current_hp = max_hp

func _process(delta: float) -> void:
	if is_destroyed:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_respawn()
		queue_redraw()
		return
	
	# 살아있을 때는 주기적으로 일본군 보병 출격!
	spawn_soldier_timer -= delta
	if spawn_soldier_timer <= 0.0:
		spawn_soldier_timer = 2.8
		_spawn_soldier()
		
	if flash_timer > 0.0:
		flash_timer -= delta
	
	queue_redraw()

func _spawn_soldier() -> void:
	if infantry_scene:
		var soldier = infantry_scene.instantiate()
		soldier.global_position = global_position + Vector2(randf_range(-30, 30), 35.0)
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

func _draw() -> void:
	if is_destroyed:
		# 무너진 폐허 및 재건축 카운트다운 게이지
		draw_rect(Rect2(-24, -16, 48, 32), Color(0.2, 0.18, 0.16, 0.6))
		draw_line(Vector2(-20, -10), Vector2(20, 12), Color(0.1, 0.08, 0.05), 3.0)
		# 15초 재건축 진행도 아크
		var prog = 1.0 - (respawn_timer / respawn_time)
		draw_arc(Vector2.ZERO, 32.0, -PI * 0.5, -PI * 0.5 + TAU * prog, 24, Color(1.0, 0.8, 0.2), 3.0)
	else:
		# 콘크리트 토치카 요새
		var bunker_col = Color.WHITE if flash_timer > 0.0 else Color(0.4, 0.42, 0.38)
		draw_rect(Rect2(-26, -20, 52, 40), bunker_col)
		draw_rect(Rect2(-26, -20, 52, 40), Color(0.15, 0.16, 0.14), false, 2.5)
		
		# 총안구 (포구 구멍)
		draw_rect(Rect2(-12, 6, 24, 6), Color(0.08, 0.08, 0.08))
		
		# 욱일기 깃대 & 깃발
		draw_line(Vector2(20, -18), Vector2(20, -42), Color(0.3, 0.25, 0.2), 2.0)
		draw_rect(Rect2(20, -42, 20, 14), Color.WHITE)
		draw_circle(Vector2(30, -35), 4.5, Color(0.85, 0.15, 0.15))
		for i in range(8):
			var ray_angle = i * (TAU / 8.0)
			draw_line(Vector2(30, -35), Vector2(30, -35) + Vector2.RIGHT.rotated(ray_angle) * 7.0, Color(0.85, 0.15, 0.15), 1.2)
