extends Area2D
class_name SnakeSegment

@export var segment_index: int = 1
@export var is_tail_tip: bool = false
@export var segment_radius: float = 15.0

var target_position: Vector2 = Vector2.ZERO
var target_rotation: float = 0.0

# 💣 마디 무장: 30mm 대공포 & 중포 포탑
var is_heavy_artillery: bool = false
var aa_gun_cooldown: float = 0.0
var aa_fire_rate: float = 0.35 # 0.35초마다 30mm 대공기관포 연사!
var heavy_cooldown: float = 0.0

func _ready() -> void:
	collision_layer = 2 # Player body layer
	collision_mask = 5  # Enemy & Head layer
	add_to_group("snake_segments")
	
	# 4의 배수 마디는 150mm/300mm 대형 중포 포탑
	is_heavy_artillery = (segment_index > 0 and segment_index % 4 == 0)
	aa_gun_cooldown = randf_range(0.05, 0.3)
	heavy_cooldown = randf_range(0.5, 2.0)

func _process(delta: float) -> void:
	global_position = global_position.lerp(target_position, 20.0 * delta)
	rotation = lerp_angle(rotation, target_rotation, 15.0 * delta)
	
	# 1. 30mm 대공기관포 사격 루프
	aa_gun_cooldown -= delta
	if aa_gun_cooldown <= 0.0:
		aa_gun_cooldown = aa_fire_rate
		_fire_30mm_aa_gun()
		
	# 2. 대형 중포 사격 루프 (4번째 마디)
	if is_heavy_artillery:
		heavy_cooldown -= delta
		if heavy_cooldown <= 0.0:
			heavy_cooldown = 2.4
			_fire_heavy_cannon()
	
	queue_redraw()

func set_target_state(pos: Vector2, rot: float) -> void:
	target_position = pos
	target_rotation = rot

func set_tail_tip(tip: bool) -> void:
	is_tail_tip = tip
	queue_redraw()

func _fire_30mm_aa_gun() -> void:
	var main_scene = get_tree().current_scene
	if not main_scene or not main_scene.has_method("spawn_projectile"):
		return
		
	# 🎯 스마트 타겟팅 1순위: [가미카제 자폭 비행기] 최우선 집중 요격!
	var kamikazes = get_tree().get_nodes_in_group("kamikaze")
	var target_enemy: Node2D = null
	
	if not kamikazes.is_empty():
		var min_d = 650.0 # 대공포 긴 사거리
		for k in kamikazes:
			if is_instance_valid(k):
				var d = global_position.distance_to(k.global_position)
				if d < min_d:
					min_d = d
					target_enemy = k
	
	# 가미카제가 없으면 일반 지상 적 사격
	if not target_enemy:
		var enemies = get_tree().get_nodes_in_group("enemies")
		var min_d = 340.0
		for e in enemies:
			if is_instance_valid(e):
				var d = global_position.distance_to(e.global_position)
				if d < min_d:
					min_d = d
					target_enemy = e
					
	if target_enemy:
		var dir = (target_enemy.global_position - global_position).normalized()
		# 30mm 고속 예광탄 사격
		main_scene.spawn_projectile(global_position, dir, 28.0, Color(1.0, 0.8, 0.2))

func _fire_heavy_cannon() -> void:
	var main_scene = get_tree().current_scene
	if not main_scene or not main_scene.has_method("spawn_cannon_shell"):
		return
		
	var enemies = get_tree().get_nodes_in_group("enemies")
	var target_enemy: Node2D = null
	var min_d = 480.0
	for e in enemies:
		if is_instance_valid(e):
			var d = global_position.distance_to(e.global_position)
			if d < min_d:
				min_d = d
				target_enemy = e
				
	if target_enemy:
		var dir = (target_enemy.global_position - global_position).normalized()
		main_scene.spawn_cannon_shell(global_position, dir)

func _draw() -> void:
	if is_tail_tip:
		# 붉은 꼬리 끝 (우로보로스 타겟)
		draw_circle(Vector2.ZERO, segment_radius + 4.0, Color(1.0, 0.8, 0.2, 0.4))
		draw_circle(Vector2.ZERO, segment_radius, Color(0.95, 0.25, 0.15))
		draw_arc(Vector2.ZERO, segment_radius, 0, TAU, 24, Color(0.3, 0.05, 0.0), 2.5)
	elif is_heavy_artillery:
		# 150mm/300mm 대형 중포 마디 (짙은 해군 회색 장갑)
		draw_circle(Vector2.ZERO, segment_radius + 3.0, Color(0.2, 0.23, 0.28))
		draw_arc(Vector2.ZERO, segment_radius + 3.0, 0, TAU, 24, Color(0.08, 0.1, 0.12), 2.5)
		# 쌍발 포신
		draw_rect(Rect2(-4, -segment_radius - 8, 3, 10), Color(0.35, 0.38, 0.42))
		draw_rect(Rect2(1, -segment_radius - 8, 3, 10), Color(0.35, 0.38, 0.42))
		draw_circle(Vector2.ZERO, segment_radius * 0.45, Color(1.0, 0.6, 0.1))
	else:
		# 30mm 쌍발 대공포 탑재 기본 마디
		draw_circle(Vector2.ZERO, segment_radius, Color(0.28, 0.32, 0.36))
		draw_arc(Vector2.ZERO, segment_radius, 0, TAU, 24, Color(0.12, 0.14, 0.16), 2.0)
		# 마디 위 쌍발 대공포 총열
		draw_line(Vector2(-3, -segment_radius - 4), Vector2(-3, 0), Color(0.15, 0.17, 0.2), 2.0)
		draw_line(Vector2(3, -segment_radius - 4), Vector2(3, 0), Color(0.15, 0.17, 0.2), 2.0)
		draw_circle(Vector2.ZERO, segment_radius * 0.35, Color(0.5, 0.8, 0.6))
