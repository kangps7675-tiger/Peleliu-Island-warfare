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
	# 자폭 폭발 연출
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("spawn_cannon_shell"):
		main_scene.spawn_cannon_shell(global_position, Vector2.ZERO)
	queue_free()

func _die_airborne() -> void:
	# 공중 격추 성공 시 고가치 보급품 3개 드롭
	EventBus.enemy_killed.emit(global_position, "KAMIKAZE")
	if gem_scene:
		for i in range(3):
			var g = gem_scene.instantiate()
			g.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
			get_parent().call_deferred("add_child", g)
	queue_free()

func _draw() -> void:
	var col = Color.WHITE if flash_timer > 0.0 else Color(0.18, 0.4, 0.22) # 짙은 국방색 제로센
	
	# 비행기 동체
	var body_pts = PackedVector2Array([
		Vector2(18, 0),
		Vector2(-14, -4),
		Vector2(-18, 0),
		Vector2(-14, 4)
	])
	draw_colored_polygon(body_pts, col)
	
	# 주익 (날개)
	draw_line(Vector2(2, -22), Vector2(2, 22), col, 5.0)
	# 붉은 일장기 마킹 (Hinomaru)
	draw_circle(Vector2(2, -14), 3.5, Color(0.9, 0.1, 0.1))
	draw_circle(Vector2(2, 14), 3.5, Color(0.9, 0.1, 0.1))
	
	# 꼬리 날개
	draw_line(Vector2(-14, -8), Vector2(-14, 8), col, 3.0)
	
	# 프로펠러 회전 잔상
	var prop_rot = Time.get_ticks_msec() * 0.05
	draw_line(Vector2(19, -8).rotated(prop_rot), Vector2(19, 8).rotated(prop_rot), Color(0.9, 0.9, 0.9, 0.6), 2.0)
	
	# 급강하 스피드 라인 (제리코 사이렌 시각화)
	draw_line(Vector2(-24, -12), Vector2(-40, -12), Color(1.0, 0.4, 0.1, 0.5), 1.5)
	draw_line(Vector2(-24, 12), Vector2(-40, 12), Color(1.0, 0.4, 0.1, 0.5), 1.5)
