extends CharacterBody2D
class_name Snakeling

@export var move_speed: float = 340.0
@export var damage_per_second: float = 18.0
@export var lifetime: float = 8.0

var mother_head: Node2D = null
var current_target: Node2D = null
var carrying_gem: Node2D = null
var elapsed: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 4 # Enemy
	add_to_group("snakelings")
	
	var heads = get_tree().get_nodes_in_group("player_head")
	if not heads.is_empty():
		mother_head = heads[0]

func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime:
		queue_free()
		return
	
	# 1. 만약 보급품(젬)을 물고 있다면 어미 머리로 배달!
	if is_instance_valid(carrying_gem):
		if is_instance_valid(mother_head):
			var dir_to_mother = (mother_head.global_position - global_position).normalized()
			velocity = dir_to_mother * move_speed
			move_and_slide()
			carrying_gem.global_position = global_position
			
			if global_position.distance_to(mother_head.global_position) < 30.0:
				if carrying_gem.has_method("_collect"):
					carrying_gem._collect()
				carrying_gem = null
		return
	
	# 2. 주변 보급품(젬) 탐색 루팅
	var gems = get_tree().get_nodes_in_group("gems")
	if not gems.is_empty():
		var closest_gem: Node2D = null
		var min_gem_dist: float = 260.0
		for g in gems:
			if is_instance_valid(g) and not g.get("is_being_attracted"):
				var d = global_position.distance_to(g.global_position)
				if d < min_gem_dist:
					min_gem_dist = d
					closest_gem = g
		if closest_gem:
			var dir_gem = (closest_gem.global_position - global_position).normalized()
			velocity = dir_gem * move_speed
			move_and_slide()
			if global_position.distance_to(closest_gem.global_position) < 20.0:
				carrying_gem = closest_gem
			queue_redraw()
			return
	
	# 3. 타겟 적/장애물 탐색
	if not is_instance_valid(current_target):
		_find_target()
	
	if is_instance_valid(current_target):
		var dir = (current_target.global_position - global_position).normalized()
		velocity = dir * move_speed
		move_and_slide()
		
		# 적과 접촉 시 지속 피해 및 결박(감속)
		if global_position.distance_to(current_target.global_position) < 25.0:
			if current_target.has_method("take_damage"):
				current_target.take_damage(damage_per_second * delta)
			# 적의 이동 속도 70% 둔화
			if current_target is CharacterBody2D:
				current_target.velocity *= 0.3
	else:
		# 목표가 없으면 어미 머리 주변을 호위 순찰
		if is_instance_valid(mother_head):
			var offset = (global_position - mother_head.global_position).normalized() * 120.0
			var patrol_target = mother_head.global_position + offset.rotated(delta * 2.0)
			velocity = (patrol_target - global_position).normalized() * (move_speed * 0.6)
			move_and_slide()
	
	queue_redraw()

func _find_target() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest: Node2D = null
	var min_d: float = 400.0
	
	for e in enemies:
		if is_instance_valid(e):
			var d = global_position.distance_to(e.global_position)
			if d < min_d:
				min_d = d
				closest = e
	current_target = closest

func _draw() -> void:
	# 강철 새끼 뱀 비주얼 (빠른 유선형 곡선 몸체)
	var move_dir = velocity.normalized()
	if move_dir == Vector2.ZERO:
		move_dir = Vector2.RIGHT
	var forward_angle = move_dir.angle()
	
	# 몸체 꼬리선
	var tail_pts = PackedVector2Array([
		Vector2.ZERO,
		Vector2(-move_dir.x * 10.0, -move_dir.y * 10.0).rotated(sin(elapsed * 15.0) * 0.4),
		Vector2(-move_dir.x * 18.0, -move_dir.y * 18.0).rotated(cos(elapsed * 15.0) * 0.5)
	])
	draw_polyline(tail_pts, Color(0.4, 0.9, 0.6, 0.85), 3.5)
	
	# 은빛 강철 머리
	draw_circle(Vector2.ZERO, 5.0, Color(0.8, 0.95, 0.85))
	draw_circle(Vector2.ZERO, 2.5, Color(0.1, 0.4, 0.2))
