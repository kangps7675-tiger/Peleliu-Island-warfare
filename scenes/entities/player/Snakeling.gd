extends CharacterBody2D
class_name Snakeling

## 🐍 20mm 쌍발 대공기관포 탑재 강철 새끼 뱀 (Twin 20mm Landship Snakeling)

@export var move_speed: float = 340.0
@export var damage_per_second: float = 18.0
@export var lifetime: float = 9.0

var mother_head: Node2D = null
var current_target: Node2D = null
var carrying_gem: Node2D = null
var elapsed: float = 0.0

# 20mm 쌍발 기관포 시스템
var turret_aim_angle: float = 0.0
var autocannon_timer: float = 0.2
const AUTOCANNON_INTERVAL: float = 0.32
var muzzle_flash_timer: float = 0.0
var barrel_recoil: float = 0.0

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
		
	if barrel_recoil > 0.0:
		barrel_recoil = maxf(0.0, barrel_recoil - delta * 20.0)
	if muzzle_flash_timer > 0.0:
		muzzle_flash_timer -= delta
		
	# 1. 보급품(젬) 운반 루프
	if is_instance_valid(carrying_gem):
		if is_instance_valid(mother_head):
			var dir_to_mother = (mother_head.global_position - global_position).normalized()
			velocity = dir_to_mother * move_speed
			move_and_slide()
			carrying_gem.global_position = global_position
			
			if global_position.distance_to(mother_head.global_position) < 32.0:
				if carrying_gem.has_method("_collect"):
					carrying_gem._collect()
				carrying_gem = null
		return
		
	# 2. 주변 보급품(젬) 우선 탐색 루팅
	var gems = get_tree().get_nodes_in_group("gems")
	if not gems.is_empty():
		var closest_gem: Node2D = null
		var min_gem_dist: float = 240.0
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
			if global_position.distance_to(closest_gem.global_position) < 22.0:
				carrying_gem = closest_gem
			_aim_and_fire_20mm_autocannon(delta)
			queue_redraw()
			return
			
	# 3. 타겟 적/장애물 탐색
	if not is_instance_valid(current_target):
		_find_target()
		
	if is_instance_valid(current_target):
		var dir = (current_target.global_position - global_position).normalized()
		velocity = dir * move_speed
		move_and_slide()
		
		# 근접 접촉 시 지속 피해 및 적 둔화
		if global_position.distance_to(current_target.global_position) < 26.0:
			if current_target.has_method("take_damage"):
				current_target.take_damage(damage_per_second * delta)
			if current_target is CharacterBody2D:
				current_target.velocity *= 0.4
	else:
		# 목표가 없으면 어미 머리 주변 호위 순찰
		if is_instance_valid(mother_head):
			var offset = (global_position - mother_head.global_position).normalized() * 110.0
			var patrol_target = mother_head.global_position + offset.rotated(delta * 2.2)
			velocity = (patrol_target - global_position).normalized() * (move_speed * 0.7)
			move_and_slide()
			
	# 4. 20mm 쌍발 기관포 조준 및 발사 루프
	_aim_and_fire_20mm_autocannon(delta)
	
	queue_redraw()

func _find_target() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest: Node2D = null
	var min_d: float = 420.0
	
	for e in enemies:
		if is_instance_valid(e):
			var d = global_position.distance_to(e.global_position)
			if d < min_d:
				min_d = d
				closest = e
	current_target = closest

func _aim_and_fire_20mm_autocannon(delta: float) -> void:
	# 사거리 내 가장 가까운 적 조준
	if not is_instance_valid(current_target):
		_find_target()
		
	if is_instance_valid(current_target):
		var to_target = (current_target.global_position - global_position).normalized()
		turret_aim_angle = to_target.angle()
		
		autocannon_timer -= delta
		if autocannon_timer <= 0.0 and global_position.distance_to(current_target.global_position) <= 380.0:
			autocannon_timer = AUTOCANNON_INTERVAL
			_fire_twin_20mm_rounds(to_target)
	else:
		# 목표가 없으면 이동 방향 조준
		if velocity.length_squared() > 1.0:
			turret_aim_angle = velocity.angle()

func _fire_twin_20mm_rounds(dir: Vector2) -> void:
	var main_scene = get_tree().current_scene
	if not main_scene or not main_scene.has_method("spawn_projectile"):
		return
		
	# 🔊 20mm 경쾌한 쌍발 기관포 속사 사운드
	AudioManager.play_sfx("flak", -5.0, 0.25)
	muzzle_flash_timer = 0.08
	barrel_recoil = 4.0
	
	var normal = Vector2(-dir.y, dir.x) * 3.0
	var muzzle_dist = 16.0
	
	# 좌/우 쌍발 탄환 동시 발사
	main_scene.spawn_projectile(global_position + normal + dir * muzzle_dist, dir.rotated(randf_range(-0.04, 0.04)), 14.0, Color(1.0, 0.85, 0.2))
	main_scene.spawn_projectile(global_position - normal + dir * muzzle_dist, dir.rotated(randf_range(-0.04, 0.04)), 14.0, Color(1.0, 0.85, 0.2))

func _draw() -> void:
	# =========================================================================
	# 3D RTS 강철 새끼 뱀 & 20mm 쌍발 기관포 포탑 렌더링
	# =========================================================================
	var move_dir = velocity.normalized() if velocity != Vector2.ZERO else Vector2.RIGHT
	
	# 1. 지면 투영 그림자 (남동쪽 오프셋)
	var shadow_pos = Vector2(3.0, 4.5)
	draw_circle(shadow_pos, 7.5, Color(0.04, 0.08, 0.04, 0.45))
	
	# 2. 강철 장갑 꼬리 세그먼트
	var tail_pts = PackedVector2Array([
		Vector2.ZERO,
		Vector2(-move_dir.x * 9.0, -move_dir.y * 9.0).rotated(sin(elapsed * 16.0) * 0.35),
		Vector2(-move_dir.x * 17.0, -move_dir.y * 17.0).rotated(cos(elapsed * 16.0) * 0.45)
	])
	draw_polyline(tail_pts, Color(0.24, 0.32, 0.28), 5.0) # 강철 외피
	draw_polyline(tail_pts, Color(0.45, 0.95, 0.65, 0.85), 2.5) # 중앙 에너지 라인
	
	# 3. 강철 장갑 본체 차체 (Mini Armored Hull)
	draw_circle(Vector2.ZERO, 7.0, Color(0.22, 0.25, 0.28))
	draw_circle(Vector2(-1.5, -1.5), 5.0, Color(0.35, 0.40, 0.44)) # 햇빛 상부 하이라이트
	draw_arc(Vector2.ZERO, 7.0, 0, TAU, 16, Color(0.12, 0.14, 0.16), 1.5)
	
	# 4. 🛡️ 20mm 쌍발 기관포탑 (Twin 20mm Turret Mount)
	# 360도 독립 회전 포탑 링
	draw_circle(Vector2.ZERO, 4.0, Color(0.18, 0.20, 0.22))
	
	# 5. 🔫 20mm 쌍열 강철 포신 (Twin Autocannon Barrels with Recoil)
	var aim_dir = Vector2.RIGHT.rotated(turret_aim_angle)
	var normal = Vector2(-aim_dir.y, aim_dir.x) * 2.8
	var b_len = 13.0 - barrel_recoil
	
	var barrel1_start = normal
	var barrel1_end = normal + aim_dir * b_len
	var barrel2_start = -normal
	var barrel2_end = -normal + aim_dir * b_len
	
	# 좌우 포신
	draw_line(barrel1_start, barrel1_end, Color(0.12, 0.13, 0.15), 2.2)
	draw_line(barrel2_start, barrel2_end, Color(0.12, 0.13, 0.15), 2.2)
	# 포구 소염기 (Muzzle Brakes)
	draw_line(barrel1_end - normal * 0.4, barrel1_end + normal * 0.4, Color(0.08, 0.08, 0.09), 2.0)
	draw_line(barrel2_end - normal * 0.4, barrel2_end + normal * 0.4, Color(0.08, 0.08, 0.09), 2.0)
	
	# 6. 발사 순간 포구 화염 (Twin Muzzle Flash Glow)
	if muzzle_flash_timer > 0.0:
		draw_circle(barrel1_end, 4.5, Color(3.5, 2.0, 0.4))
		draw_circle(barrel2_end, 4.5, Color(3.5, 2.0, 0.4))
		draw_circle(barrel1_end, 2.0, Color(4.5, 4.0, 2.0))
		draw_circle(barrel2_end, 2.0, Color(4.5, 4.0, 2.0))
