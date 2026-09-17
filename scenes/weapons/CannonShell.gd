extends Area2D
class_name CannonShell

@export var speed: float = 600.0
@export var damage: float = 85.0
@export var explosion_radius: float = 110.0
@export var lifetime: float = 1.8

var direction: Vector2 = Vector2.RIGHT
var has_exploded: bool = false
var explosion_timer: float = 0.0
var explosion_duration: float = 0.35

func _ready() -> void:
	collision_layer = 0
	collision_mask = 4 # Enemy layer
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func initialize(pos: Vector2, dir: Vector2) -> void:
	global_position = pos
	direction = dir.normalized()
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	if has_exploded:
		explosion_timer += delta
		queue_redraw()
		if explosion_timer >= explosion_duration:
			queue_free()
		return
	
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		_explode()
	queue_redraw()

func _on_body_entered(_body: Node2D) -> void:
	if not has_exploded:
		_explode()

func _on_area_entered(_area: Area2D) -> void:
	if not has_exploded:
		_explode()

func _explode() -> void:
	has_exploded = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# 반경 내 모든 적 일괄 폭발 데미지
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = global_position.distance_to(enemy.global_position)
			if dist <= explosion_radius:
				# 거리에 따른 감쇄 데미지
				var falloff = 1.0 - (dist / explosion_radius) * 0.4
				if enemy.has_method("take_damage"):
					enemy.take_damage(damage * falloff)
				# 넉백 적용
				if enemy is CharacterBody2D:
					var knock_dir = (enemy.global_position - global_position).normalized()
					enemy.velocity += knock_dir * 380.0

func _draw() -> void:
	if not has_exploded:
		# 비행 중인 거대 대구경 철갑탄
		draw_line(Vector2.ZERO, -direction.rotated(-rotation) * 18.0, Color(1.0, 0.5, 0.1, 0.7), 4.0)
		draw_circle(Vector2.ZERO, 7.0, Color(0.2, 0.2, 0.25))
		draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.8, 0.2))
	else:
		# 고폭탄 폭발 화염 구체 연출
		var progress = explosion_timer / explosion_duration
		var current_r = explosion_radius * ease(progress, 0.3)
		var alpha = 1.0 - progress
		
		# 외부 폭풍 파편
		draw_circle(Vector2.ZERO, current_r, Color(1.0, 0.3, 0.05, 0.4 * alpha))
		# 중간 폭발 화염
		draw_circle(Vector2.ZERO, current_r * 0.7, Color(1.0, 0.7, 0.1, 0.7 * alpha))
		# 중심부 백색 섬광
		draw_circle(Vector2.ZERO, current_r * 0.35, Color(1.0, 1.0, 0.9, 0.95 * alpha))
		# 충격파 링
		draw_arc(Vector2.ZERO, current_r, 0, TAU, 32, Color(1.0, 0.9, 0.5, alpha), 3.0)
