extends CharacterBody2D
class_name KamikazePlane

@export var max_hp: float = 60.0
@export var current_hp: float = 60.0
@export var dive_speed: float = 540.0
@export var kamikaze_damage: float = 35.0
@export var gem_scene: PackedScene = preload("res://scenes/entities/drops/Gem.tscn")

var target: Node2D = null
var flash_timer: float = 0.0
var dive_angle: float = 0.0
var engine_trail_timer: float = 0.0

func _ready() -> void:
	collision_layer = 4 # Enemy layer
	collision_mask = 1  # Player Head
	add_to_group("enemies")
	add_to_group("kamikaze") # 대공포 최우선 집중 타깃 그룹!
	current_hp = max_hp
	
	var heads = get_tree().get_nodes_in_group("player_head")
	if not heads.is_empty():
		target = heads[0]

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		var heads = get_tree().get_nodes_in_group("player_head")
		if not heads.is_empty():
			target = heads[0]
		return
	
	# 뱀 머리를 향해 무자비하게 급강하 유도
	var dir = (target.global_position - global_position).normalized()
	rotation = dir.angle()
	velocity = dir * dive_speed
	
	# 이동 및 충돌 체크
	var collision = move_and_collide(velocity * delta)
	if collision:
		var collider = collision.get_collider()
		if collider and collider.is_in_group("player_head"):
			if collider.has_method("take_damage"):
				collider.take_damage(kamikaze_damage)
			_self_destruct()
	
	# 짙은 검은색 엔진 화염 연기 배출
	engine_trail_timer -= delta
	if engine_trail_timer <= 0.0:
		engine_trail_timer = 0.05
		var main_scene = get_tree().current_scene
		if main_scene and main_scene.has_method("add_exhaust_smoke"):
			var tail_pos = global_position - dir * 35.0
			main_scene.add_exhaust_smoke(tail_pos, -dir * 120.0)
	
	if flash_timer > 0.0:
		flash_timer -= delta
	
	queue_redraw()

func take_damage(amount: float) -> void:
	current_hp -= amount
	flash_timer = 0.08
	queue_redraw()
	
	if current_hp <= 0.0:
		_die_airborne()

func _self_destruct() -> void:
	# 지면/플레이어 자폭 격발
	var main_scene = get_tree().current_scene
	if main_scene:
		if main_scene.has_method("spawn_heavy_explosion"):
			main_scene.spawn_heavy_explosion(global_position, 140.0)
		if main_scene.has_method("add_crater_decal"):
			main_scene.add_crater_decal(global_position, 35.0)
	queue_free()

@export var crashing_plane_scene: PackedScene = preload("res://scenes/entities/enemies/CrashingPlane.tscn")

func _die_airborne() -> void:
	EventBus.enemy_killed.emit(global_position, "KAMIKAZE")
	
	# 불타며 추락하는 전투기 생성!
	if crashing_plane_scene:
		var crash = crashing_plane_scene.instantiate()
		crash.initialize(global_position, velocity)
		get_parent().call_deferred("add_child", crash)
		
	if gem_scene:
		for i in range(3):
			var g = gem_scene.instantiate()
			g.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
			get_parent().call_deferred("add_child", g)
			
	queue_free()

func _draw() -> void:
	# 급강하 스피드 라인
	draw_line(Vector2(-30, -18), Vector2(-60, -18), Color(1.0, 0.5, 0.1, 0.6), 2.0)
	draw_line(Vector2(-30, 18), Vector2(-60, 18), Color(1.0, 0.5, 0.1, 0.6), 2.0)
