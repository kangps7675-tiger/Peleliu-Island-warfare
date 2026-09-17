extends CharacterBody2D
class_name JapaneseSoldier

## 🪖 2차대전 일본군 보병 (소총병)
## 무장: 38식/99식 아리사카 소총 + 30년식 총검 (Arisaka Rifle & Bayonet)

@export var max_hp: float = 32.0
@export var current_hp: float = 32.0
@export var base_move_speed: float = 95.0
@export var charge_speed: float = 165.0
@export var contact_damage: float = 24.0 # 총검 찌르기 피해
@export var gem_scene: PackedScene = preload("res://scenes/entities/drops/Gem.tscn")

var target: Node2D = null
var flash_timer: float = 0.0
var walk_cycle: float = 0.0

# 전투 행동 상태
var is_bayonet_charging: bool = false
var jab_animation_timer: float = 0.0
var rifle_aim_timer: float = 2.0
var is_aiming: bool = false

func _ready() -> void:
	collision_layer = 4
	collision_mask = 7
	add_to_group("enemies")
	add_to_group("infantry")
	current_hp = max_hp
	walk_cycle = randf() * TAU
	
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
	rotation = lerp_angle(rotation, dir.angle(), 10.0 * delta)
	
	# 1. 근접 거리(240px 이하) 진입 시 ➔ 반자이 총검 돌격 (Bayonet Charge)!
	if dist < 240.0:
		is_bayonet_charging = true
		is_aiming = false
		velocity = dir * charge_speed
		walk_cycle += delta * 18.0
	else:
		is_bayonet_charging = false
		# 중거리: 주기적으로 멈춰 서서 아리사카 소총 조준 사격
		rifle_aim_timer -= delta
		if rifle_aim_timer <= 0.6 and not is_aiming:
			is_aiming = true
		
		if is_aiming:
			velocity = Vector2.ZERO
			if rifle_aim_timer <= 0.0:
				_fire_arisaka_rifle(dir)
				rifle_aim_timer = randf_range(2.8, 4.2)
				is_aiming = false
		else:
			velocity = dir * base_move_speed
			walk_cycle += delta * 9.0
			
	move_and_slide()
	
	# 총검 접촉 찌르기 판정
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.is_in_group("player_head"):
			jab_animation_timer = 0.25
			if collider.has_method("take_damage"):
				collider.take_damage(contact_damage * delta)
				
	if jab_animation_timer > 0.0:
		jab_animation_timer -= delta
		
	if flash_timer > 0.0:
		flash_timer -= delta
		
	queue_redraw()

func _fire_arisaka_rifle(dir: Vector2) -> void:
	var main_scene = get_tree().current_scene
	if not main_scene or not main_scene.has_method("spawn_projectile"):
		return
		
	AudioManager.play_sfx("flak", -9.0, 0.4)
	jab_animation_timer = 0.15 # 반동 모션
	var muzzle = global_position + dir * 36.0
	main_scene.spawn_projectile(muzzle, dir.rotated(randf_range(-0.06, 0.06)), 15.0, Color(1.0, 0.85, 0.4))

func take_damage(amount: float) -> void:
	current_hp -= amount
	flash_timer = 0.08
	if current_hp <= 0.0:
		_die()

func _die() -> void:
	EventBus.enemy_killed.emit(global_position, "JAPANESE_SOLDIER")
	if gem_scene:
		var gem = gem_scene.instantiate()
		gem.global_position = global_position
		get_parent().call_deferred("add_child", gem)
	queue_free()

func _draw() -> void:
	# =========================================================================
	# 3D RTS 탑다운 일본군 보병 (소총병) 렌더링
	# =========================================================================
	var hit_color = Color(3.0, 3.0, 3.0) if flash_timer > 0.0 else Color.WHITE
	
	# 1. 지면 투영 그림자 (남동쪽 오프셋)
	var shadow_offset = Vector2(4.0, 6.0)
	draw_circle(shadow_offset, 12.0, Color(0.04, 0.08, 0.04, 0.4))
	
	# 2. 다리 보행 애니메이션
	var leg_swing = sin(walk_cycle) * 5.0
	draw_circle(Vector2(-4.0, -5.0 + leg_swing), 3.5, Color(0.35, 0.30, 0.20) * hit_color)
	draw_circle(Vector2(-4.0, 5.0 - leg_swing), 3.5, Color(0.35, 0.30, 0.20) * hit_color)
	
	# 3. 국방색 군복 몸통 및 탄약 파우치 벨트
	draw_circle(Vector2.ZERO, 9.0, Color(0.46, 0.42, 0.28) * hit_color)
	draw_line(Vector2(-6, -4), Vector2(6, 4), Color(0.28, 0.18, 0.10) * hit_color, 2.5) # 가죽 교차 멜빵
	draw_rect(Rect2(2, -4, 4, 8), Color(0.32, 0.22, 0.12) * hit_color) # 전면 탄약낭
	
	# 4. 아리사카 38식/99식 소총 (목재 개머리판 + 총열)
	var jab_offset = Vector2(10.0, 0.0) if jab_animation_timer > 0.0 else Vector2.ZERO
	var rifle_start = Vector2(2, 4) + jab_offset
	var rifle_barrel_end = Vector2(24, 3) + jab_offset
	
	# 목재 총몸
	draw_line(rifle_start, rifle_barrel_end - Vector2(6, 0), Color(0.42, 0.25, 0.12) * hit_color, 3.0)
	# 강철 총열
	draw_line(rifle_barrel_end - Vector2(8, 0), rifle_barrel_end, Color(0.2, 0.22, 0.25) * hit_color, 2.0)
	
	# 5. 🗡️ 30년식 총검 (Bayonet) - 서슬 퍼런 강철 날
	var bayonet_tip = rifle_barrel_end + Vector2(12.0, 0.0)
	draw_line(rifle_barrel_end, bayonet_tip, Color(0.9, 0.95, 1.0) * hit_color, 2.5)
	# 총검 혈조(Blood groove) & 칼날 반사광
	draw_line(rifle_barrel_end + Vector2(2, 0), bayonet_tip - Vector2(2, 0), Color(1.8, 1.9, 2.0), 1.2)
	
	# 6. 90식 철모 (Type 90 Helmet) & 수건 차양포
	# 철모 뒤편 차양포 (목 뒤를 덮는 3장의 천)
	var flap_sway = sin(walk_cycle * 0.8) * 2.0
	draw_line(Vector2(-6, -3), Vector2(-12 + flap_sway, -5), Color(0.55, 0.52, 0.38) * hit_color, 2.5)
	draw_line(Vector2(-7, 0), Vector2(-13 + flap_sway, 0), Color(0.55, 0.52, 0.38) * hit_color, 2.5)
	draw_line(Vector2(-6, 3), Vector2(-12 + flap_sway, 5), Color(0.55, 0.52, 0.38) * hit_color, 2.5)
	
	# 둥근 카키색 강철 철모 본체
	draw_circle(Vector2(-1, 0), 7.0, Color(0.38, 0.42, 0.26) * hit_color)
	draw_arc(Vector2(-1, 0), 7.0, 0, TAU, 16, Color(0.22, 0.26, 0.16) * hit_color, 1.5)
	# 철모 전면 일본군 노란색 오각별(★) 군표
	draw_circle(Vector2(4, 0), 1.6, Color(1.0, 0.85, 0.1) * hit_color)
