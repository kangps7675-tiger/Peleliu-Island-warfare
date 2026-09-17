extends CharacterBody2D
class_name JapaneseOfficer

## 🎖️ 2차대전 일본군 장교 (Officer)
## 무장: 100식 기관단총 (Type 100 SMG) + 98식 군도 (Guntō)

@export var max_hp: float = 65.0
@export var current_hp: float = 65.0
@export var move_speed: float = 110.0
@export var contact_damage: float = 18.0
@export var gem_scene: PackedScene = preload("res://scenes/entities/drops/Gem.tscn")

var target: Node2D = null
var flash_timer: float = 0.0
var walk_cycle: float = 0.0

# 100식 기관단총 점사 시스템
var burst_timer: float = 2.0
var is_bursting: bool = false
var burst_shots_remaining: int = 0
var shot_interval_timer: float = 0.0
var muzzle_flash_timer: float = 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 7
	add_to_group("enemies")
	add_to_group("infantry")
	add_to_group("officers")
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
	rotation = lerp_angle(rotation, dir.angle(), 8.0 * delta)
	
	# 전술적 사거리 유지 (280~380px 거리에서 사격 및 전술 기동)
	if dist > 380.0:
		velocity = dir * move_speed
		walk_cycle += delta * 10.0
	elif dist < 220.0:
		# 너무 가까우면 뒤로 물러서며 거리 확보
		velocity = -dir * (move_speed * 0.85)
		walk_cycle += delta * 8.0
	else:
		# 사거리 내에서 좌우 측면 기동 (Strafe)
		var strafe_dir = Vector2(-dir.y, dir.x) * (1.0 if sin(walk_cycle * 0.5) > 0.0 else -1.0)
		velocity = strafe_dir * (move_speed * 0.6)
		walk_cycle += delta * 6.0
		
	move_and_slide()
	
	# 100식 기관단총 점사 관리
	if not is_bursting:
		burst_timer -= delta
		if burst_timer <= 0.0:
			burst_timer = randf_range(2.2, 3.2)
			is_bursting = true
			burst_shots_remaining = 6
			shot_interval_timer = 0.0
			var main_scene = get_tree().current_scene
			if main_scene and main_scene.has_method("spawn_tactical_popup"):
				main_scene.spawn_tactical_popup(global_position, "🎯 FIRE BURST!", Color(1.0, 0.85, 0.2))
	else:
		shot_interval_timer -= delta
		if shot_interval_timer <= 0.0 and burst_shots_remaining > 0:
			shot_interval_timer = 0.09 # 초당 11발의 고속 연사
			burst_shots_remaining -= 1
			_fire_type_100_smg_bullet(dir)
			if burst_shots_remaining <= 0:
				is_bursting = false
				
	if muzzle_flash_timer > 0.0:
		muzzle_flash_timer -= delta
		
	if flash_timer > 0.0:
		flash_timer -= delta
		
	queue_redraw()

func _fire_type_100_smg_bullet(dir: Vector2) -> void:
	var main_scene = get_tree().current_scene
	if not main_scene or not main_scene.has_method("spawn_projectile"):
		return
		
	AudioManager.play_sfx("flak", -6.0, 0.45)
	muzzle_flash_timer = 0.06
	
	var spread_dir = dir.rotated(randf_range(-0.1, 0.1))
	var muzzle = global_position + dir * 30.0 + Vector2(-dir.y, dir.x) * 4.0
	main_scene.spawn_projectile(muzzle, spread_dir, 12.0, Color(1.0, 0.7, 0.2), true)
	
	# 8mm 남부 황동 탄피 배출
	if main_scene.has_method("eject_casing"):
		main_scene.eject_casing(global_position, Vector2(-dir.y, dir.x), "8mm")

func take_damage(amount: float) -> void:
	current_hp -= amount
	flash_timer = 0.08
	if current_hp <= 0.0:
		_die()

func _die() -> void:
	EventBus.enemy_killed.emit(global_position, "JAPANESE_OFFICER")
	# 장교 처치 시 2개의 보급 젬 드롭
	if gem_scene:
		for i in range(2):
			var gem = gem_scene.instantiate()
			gem.global_position = global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
			get_parent().call_deferred("add_child", gem)
	queue_free()

func _draw() -> void:
	# =========================================================================
	# 3D RTS 탑다운 일본군 장교 (Officer) 렌더링
	# =========================================================================
	var hit_color = Color(3.0, 3.0, 3.0) if flash_timer > 0.0 else Color.WHITE
	
	# 1. 지면 투영 그림자 (남동쪽 오프셋)
	var shadow_offset = Vector2(5.0, 7.0)
	draw_circle(shadow_offset, 13.0, Color(0.04, 0.08, 0.04, 0.45))
	
	# 2. 다리 보행 애니메이션 (장교 장화)
	var leg_swing = sin(walk_cycle) * 4.5
	draw_circle(Vector2(-4.0, -5.0 + leg_swing), 3.5, Color(0.2, 0.16, 0.12) * hit_color) # 흑색 가죽 장화
	draw_circle(Vector2(-4.0, 5.0 - leg_swing), 3.5, Color(0.2, 0.16, 0.12) * hit_color)
	
	# 3. 짙은 올리브 장교 군복 & 샘 브라운 벨트
	draw_circle(Vector2.ZERO, 9.5, Color(0.36, 0.38, 0.25) * hit_color)
	# 적색 칼라 계급장 (Collar rank tabs)
	draw_line(Vector2(4, -3), Vector2(6, -3), Color(0.85, 0.15, 0.15), 2.0)
	draw_line(Vector2(4, 3), Vector2(6, 3), Color(0.85, 0.15, 0.15), 2.0)
	# 사선 가죽 벨트
	draw_line(Vector2(-6, -5), Vector2(6, 5), Color(0.24, 0.15, 0.08) * hit_color, 2.5)
	
	# 4. 🗡️ 98식 군도 (Guntō Sword in scabbard) - 좌측 허리 패용
	draw_line(Vector2(-4, -6), Vector2(-16, -12), Color(0.18, 0.12, 0.06) * hit_color, 3.0) # 칼집
	draw_line(Vector2(-4, -6), Vector2(0, -4), Color(0.85, 0.75, 0.2) * hit_color, 2.5)     # 황동 코등이 & 칼자루
	
	# 5. 🔫 100식 기관단총 (Type 100 Submachine Gun)
	var smg_start = Vector2(2, 3)
	var smg_end = Vector2(22, 3)
	# 목재 개머리판 및 리시버
	draw_line(smg_start, smg_end, Color(0.40, 0.22, 0.10) * hit_color, 3.0)
	# 방열 구멍이 뚫린 총열 커버
	draw_line(smg_end - Vector2(8, 0), smg_end, Color(0.2, 0.22, 0.24) * hit_color, 2.5)
	# 100식 기관단총 특유의 좌측 수평 장착 곡선형 탄창 (Curved side magazine)
	draw_arc(Vector2(10, 3), 9.0, -PI * 0.75, -PI * 0.25, 8, Color(0.12, 0.13, 0.15) * hit_color, 2.5)
	
	# 사격 시 총구 화염 (Muzzle flash)
	if muzzle_flash_timer > 0.0:
		var flash_pos = smg_end + Vector2(6, 0)
		draw_circle(flash_pos, 8.0, Color(3.5, 2.0, 0.4))
		draw_line(flash_pos, flash_pos + Vector2(10, 0), Color(4.0, 3.5, 1.5), 3.0)
		
	# 6. 🎖️ 일본군 장교 정모 (Officer Peaked Visor Cap)
	# 원형 차양모 윗면 (올리브 그린)
	draw_circle(Vector2(-1, 0), 7.5, Color(0.32, 0.35, 0.22) * hit_color)
	# 모자 붉은 테두리 밴드
	draw_arc(Vector2(-1, 0), 7.5, 0, TAU, 16, Color(0.75, 0.18, 0.18) * hit_color, 2.0)
	# 전면 흑색 광택 가죽 챙 (Visor)
	draw_arc(Vector2(-1, 0), 9.0, -PI * 0.3, PI * 0.3, 12, Color(0.08, 0.08, 0.08) * hit_color, 3.0)
	# 전면 황금색 장교 별 문장 (Gold Star Insignia)
	draw_circle(Vector2(5, 0), 1.8, Color(1.0, 0.85, 0.15) * hit_color)
	
	# =========================================================================
	# 7. 🎖️ CoH 지휘관 황금성(★) 뱃지 & 장교 체력바 (Tactical Commander Badge)
	# =========================================================================
	var badge_y = -24.0
	# 지휘관 황금성
	draw_circle(Vector2(0, badge_y), 4.0, Color(1.0, 0.85, 0.15))
	draw_arc(Vector2(0, badge_y), 5.5, 0, TAU, 12, Color(0.85, 0.65, 0.1), 1.2)
	
	# 장교 체력바
	var hp_ratio = clampf(current_hp / max_hp, 0.0, 1.0)
	var bar_w = 22.0
	var bar_rect = Rect2(-bar_w * 0.5, badge_y - 8, bar_w, 3.0)
	draw_rect(bar_rect, Color(0.1, 0.1, 0.1, 0.8))
	draw_rect(Rect2(-bar_w * 0.5, badge_y - 8, bar_w * hp_ratio, 3.0), Color(0.9, 0.8, 0.2))

