extends CharacterBody2D
class_name EnemyBase

## 🚜 2차대전 일본군 97식 중전차 치하 (Type 97 Chi-Ha Medium Tank)
## CoH / Gates of Hell 스타일 독립 회전 포탑 & 57mm 전차포 & 파괴 시 불타는 전차 잔해

@export var max_hp: float = 65.0
@export var current_hp: float = 65.0
@export var move_speed: float = 85.0
@export var contact_damage: float = 14.0
@export var gem_scene: PackedScene = preload("res://scenes/entities/drops/Gem.tscn")
@export var faction: String = "JAPANESE_ARMOR"

var target: Node2D = null
var flash_timer: float = 0.0

# 360도 독립 선회 주포탑 & 57mm 전차포
var turret_rotation: float = 0.0
var cannon_cooldown: float = 2.8
var muzzle_flash_timer: float = 0.0
var recoil_offset: float = 0.0
var tread_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	collision_layer = 4 # Enemy layer
	collision_mask = 7  # Head (1), Body Segments (2), Projectile
	add_to_group("enemies")
	add_to_group("heavy_armor") # 장갑 도탄 특성 부여
	current_hp = max_hp
	turret_rotation = rotation
	
	var heads = get_tree().get_nodes_in_group("player_head")
	if not heads.is_empty():
		target = heads[0]

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		var heads = get_tree().get_nodes_in_group("player_head")
		if not heads.is_empty():
			target = heads[0]
		return
	
	var dist = global_position.distance_to(target.global_position)
	var dir = (target.global_position - global_position).normalized()
	
	# 1. 차체 궤도 기동 (치하 전차 이동)
	rotation = lerp_angle(rotation, dir.angle(), 4.5 * delta)
	velocity = dir * move_speed
	move_and_slide()
	
	# 무한궤도 자국
	tread_timer -= delta
	if tread_timer <= 0.0:
		tread_timer = 0.16
		var main_scene = get_tree().current_scene
		if main_scene and main_scene.has_method("add_tread_mark"):
			main_scene.add_tread_mark(global_position, rotation, 20.0)
	
	# 2. 독립 선회 57mm 전차 포탑 (플레이어 머리를 실시간 조준)
	turret_rotation = lerp_angle(turret_rotation, dir.angle(), 7.0 * delta)
	
	# 3. 57mm 전차포 사격 (사거리 420px 이내)
	cannon_cooldown -= delta
	if cannon_cooldown <= 0.0 and dist <= 420.0:
		cannon_cooldown = randf_range(3.2, 4.4)
		_fire_57mm_cannon(dir)
	
	# 반동 복원
	if recoil_offset > 0.0:
		recoil_offset = maxf(0.0, recoil_offset - delta * 30.0)
	if muzzle_flash_timer > 0.0:
		muzzle_flash_timer -= delta
		
	# 플레이어와 접촉 체크
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.is_in_group("player_head"):
			if collider.has_method("take_damage"):
				collider.take_damage(contact_damage * delta)
	
	if flash_timer > 0.0:
		flash_timer -= delta
		if sprite:
			sprite.modulate = Color(2.5, 2.5, 2.5)
	elif sprite:
		sprite.modulate = Color.WHITE
		
	queue_redraw()

func _fire_57mm_cannon(dir: Vector2) -> void:
	var main_scene = get_tree().current_scene
	if not main_scene:
		return
		
	AudioManager.play_sfx("flak", 2.0, 0.25)
	muzzle_flash_timer = 0.12
	recoil_offset = 6.0
	
	var fire_dir = Vector2.RIGHT.rotated(turret_rotation)
	var muzzle = global_position + fire_dir * 28.0
	
	if main_scene.has_method("spawn_projectile"):
		main_scene.spawn_projectile(muzzle, fire_dir, 24.0, Color(1.0, 0.70, 0.15), true)
	if main_scene.has_method("eject_casing"):
		main_scene.eject_casing(global_position, Vector2(-fire_dir.y, fire_dir.x), "20mm")

func take_damage(amount: float) -> void:
	current_hp -= amount
	flash_timer = 0.08
	
	if current_hp <= 0.0:
		_die()

func _die() -> void:
	EventBus.enemy_killed.emit(global_position, faction)
	
	var main_scene = get_tree().current_scene
	if main_scene:
		# 💥 CoH 불타는 전차 잔해 생성 (18초간 지속 연기 및 화염)
		if main_scene.has_method("spawn_vehicle_hulk"):
			main_scene.spawn_vehicle_hulk(global_position, rotation, "chiha")
		if main_scene.has_method("spawn_heavy_explosion"):
			main_scene.spawn_heavy_explosion(global_position, 90.0)
		if main_scene.has_method("spawn_tactical_popup"):
			main_scene.spawn_tactical_popup(global_position, "💥 TANK DESTROYED!", Color(1.0, 0.4, 0.2))
	
	AudioManager.play_sfx("explosion", 2.2)
	
	# 경험치 보급품 드롭
	if gem_scene:
		for i in range(2):
			var gem = gem_scene.instantiate()
			gem.global_position = global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
			get_parent().call_deferred("add_child", gem)
	
	queue_free()

func _draw() -> void:
	# =========================================================================
	# 1. 360도 독립 회전 57mm 주포탑 렌더링 (Local space)
	# =========================================================================
	var rel_turret_angle = turret_rotation - rotation
	var t_dir = Vector2.RIGHT.rotated(rel_turret_angle)
	var t_normal = Vector2(-t_dir.y, t_dir.x)
	var turret_center = Vector2.ZERO
	
	# 57mm 단포신
	var barrel_start = turret_center + t_dir * 8.0 - t_dir * recoil_offset
	var barrel_end = barrel_start + t_dir * 18.0
	draw_line(barrel_start, barrel_end, Color(0.18, 0.20, 0.22), 4.5)
	draw_line(barrel_start, barrel_end, Color(0.35, 0.38, 0.40), 2.5) # 금속광 하이라이트
	# 포구 소염기
	draw_line(barrel_end - t_normal * 3.5, barrel_end + t_normal * 3.5, Color(0.12, 0.12, 0.14), 3.0)
	
	# 포구 화염
	if muzzle_flash_timer > 0.0:
		draw_circle(barrel_end + t_dir * 4.0, 10.0, Color(3.5, 2.5, 1.0))
		draw_circle(barrel_end + t_dir * 8.0, 14.0, Color(2.8, 0.9, 0.1, 0.8))
	
	# 원형 주포탑 몸체
	draw_circle(turret_center + Vector2(2, 3), 11.5, Color(0.04, 0.06, 0.04, 0.45)) # 포탑 그림자
	draw_circle(turret_center, 11.0, Color(0.34, 0.38, 0.26)) # 국방색 위장
	draw_circle(turret_center, 9.5, Color(0.42, 0.46, 0.32)) # 상부 장갑판
	# 전차장 해치
	draw_circle(turret_center - t_dir * 3.0, 4.0, Color(0.24, 0.26, 0.20))
	
	# =========================================================================
	# 2. 🎖️ CoH 스타일 마름모 전차 장갑 뱃지 & 체력바 (Tactical Armor Shield)
	# =========================================================================
	var badge_pos = Vector2(0, -28)
	var badge_pts = PackedVector2Array([
		badge_pos + Vector2(0, -6),
		badge_pos + Vector2(7, 0),
		badge_pos + Vector2(0, 6),
		badge_pos + Vector2(-7, 0)
	])
	draw_colored_polygon(badge_pts, Color(0.15, 0.18, 0.22, 0.9))
	draw_polyline(badge_pts, Color(0.9, 0.75, 0.2, 0.95), 1.8)
	
	# 미니 체력바
	var hp_ratio = clampf(current_hp / max_hp, 0.0, 1.0)
	var bar_w = 26.0
	var bar_rect = Rect2(-bar_w * 0.5, -34, bar_w, 3.5)
	draw_rect(bar_rect, Color(0.1, 0.1, 0.1, 0.8))
	draw_rect(Rect2(-bar_w * 0.5, -34, bar_w * hp_ratio, 3.5), Color(0.2, 0.85, 0.3))

