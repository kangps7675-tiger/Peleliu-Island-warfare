extends CharacterBody2D
class_name SnakeHead

@export var base_move_speed: float = 230.0
@export var turn_speed: float = 7.0
@export var head_radius: float = 20.0
@export var segment_scene: PackedScene = preload("res://scenes/entities/player/SnakeSegment.tscn")
@export var snakeling_scene: PackedScene = preload("res://scenes/entities/player/Snakeling.tscn")

# 💣 800mm 구스타프 열차포 (Schwerer Gustav)
var gustav_cooldown: float = 0.0
const GUSTAV_INTERVAL: float = 4.5 # 4.5초 주기 거대 철갑탄
var gustav_recoil_offset: float = 0.0
var gustav_flash_timer: float = 0.0
var camera_shake_amount: float = 0.0

# 🚜 전차 무한궤도 자국 & 디젤 배기 연무
var tread_mark_timer: float = 0.0
var exhaust_timer: float = 0.0

# 🐍 새끼 뱀 (Snakelings) 주기적 사출
var snakeling_spawn_timer: float = 3.0
const SNAKELING_INTERVAL: float = 4.0

# 마디 관리
var segments: Array = []
var initial_segments_count: int = 6
var segment_spacing_dist: float = 24.0

# 위치 히스토리 큐: [{pos: Vector2, rot: float, time: float}]
var history: Array = []
var max_history_duration: float = 12.0
var history_timer: float = 0.0

# 포위 섬멸 체크 쿨다운
var encircle_check_timer: float = 0.0
const ENCIRCLE_CHECK_INTERVAL: float = 0.15

# 철벽 체력
var max_hp: float = 250.0
var current_hp: float = 250.0

# 거대화 스케일
var current_tier: int = 1

@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	collision_layer = 1 # Player Head
	collision_mask = 4  # Enemy layer
	add_to_group("player_head")
	
	EventBus.gem_collected.connect(_on_gem_collected)
	
	for i in range(initial_segments_count):
		add_segment()

func apply_scale_tier(scale_factor: float, tier: int) -> void:
	current_tier = tier
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * scale_factor, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	segment_spacing_dist = 24.0 * scale_factor
	
	for seg in segments:
		if is_instance_valid(seg):
			create_tween().tween_property(seg, "scale", Vector2.ONE * scale_factor, 0.6)

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_gustav_cannon(delta)
	_handle_snakelings(delta)
	_record_history(delta)
	_update_segments()
	_handle_treads_and_exhaust(delta)
	
	encircle_check_timer -= delta
	if encircle_check_timer <= 0.0:
		encircle_check_timer = ENCIRCLE_CHECK_INTERVAL
		_check_encircle_trap()
	
	if camera_shake_amount > 0.0:
		camera_shake_amount = maxf(0.0, camera_shake_amount - delta * 20.0)
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * camera_shake_amount
	else:
		camera.offset = Vector2.ZERO
	
	queue_redraw()

func _handle_treads_and_exhaust(delta: float) -> void:
	if velocity.length() > 20.0:
		tread_mark_timer -= delta
		if tread_mark_timer <= 0.0:
			tread_mark_timer = 0.12
			var main_scene = get_tree().current_scene
			if main_scene and main_scene.has_method("add_tread_mark"):
				main_scene.add_tread_mark(global_position, rotation, 22.0)
	
	exhaust_timer -= delta
	if exhaust_timer <= 0.0:
		exhaust_timer = 0.08
		var main_scene = get_tree().current_scene
		if main_scene and main_scene.has_method("add_exhaust_smoke"):
			var exhaust_pos = global_position - Vector2.RIGHT.rotated(rotation) * 20.0
			main_scene.add_exhaust_smoke(exhaust_pos, -velocity.normalized())

func _handle_movement(delta: float) -> void:
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	input_vector = input_vector.normalized()
	
	if input_vector != Vector2.ZERO:
		var target_angle = input_vector.angle()
		rotation = lerp_angle(rotation, target_angle, turn_speed * delta)
		velocity = velocity.move_toward(Vector2.RIGHT.rotated(rotation) * base_move_speed, 1000.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.RIGHT.rotated(rotation) * (base_move_speed * 0.4), 350.0 * delta)
	
	move_and_slide()

func _handle_gustav_cannon(delta: float) -> void:
	gustav_cooldown -= delta
	gustav_recoil_offset = move_toward(gustav_recoil_offset, 0.0, 30.0 * delta)
	if gustav_flash_timer > 0.0:
		gustav_flash_timer -= delta
	
	var manual_fire = Input.is_action_just_pressed("active_skill")
	if (gustav_cooldown <= 0.0) or (manual_fire and gustav_cooldown <= 0.5):
		_fire_gustav()

func _fire_gustav() -> void:
	gustav_cooldown = GUSTAV_INTERVAL
	gustav_recoil_offset = 24.0 # 육중한 유압 블로우백 후퇴
	gustav_flash_timer = 0.18
	camera_shake_amount = 16.0 # 화면 대진동!
	
	# 🔊 800mm 구스타프 열차포 굉음 사운드 재생
	AudioManager.play_sfx("gustav", 3.2)
	
	# 💥 800mm 살인적인 반동: 뱀 머리가 순간 뒤로 쾅! 튕겨나감
	var fire_dir = Vector2.RIGHT.rotated(rotation)
	velocity -= fire_dir * 600.0
	
	var muzzle_pos = global_position + fire_dir * (head_radius + 32.0)
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("spawn_cannon_shell"):
		main_scene.spawn_cannon_shell(muzzle_pos, fire_dir)

func _handle_snakelings(delta: float) -> void:
	snakeling_spawn_timer -= delta
	if snakeling_spawn_timer <= 0.0:
		snakeling_spawn_timer = SNAKELING_INTERVAL
		_spawn_snakelings_burst()

func _spawn_snakelings_burst() -> void:
	if not snakeling_scene:
		return
	
	# 마디 주변에서 3마리의 새끼 뱀 사출
	var spawn_count = 3
	for i in range(spawn_count):
		var child = snakeling_scene.instantiate()
		var offset = Vector2.RIGHT.rotated(randf() * TAU) * 35.0
		child.global_position = global_position + offset
		get_parent().call_deferred("add_child", child)

func _record_history(delta: float) -> void:
	history_timer += delta
	history.push_front({
		"pos": global_position,
		"rot": rotation,
		"time": history_timer
	})
	while history.size() > 0 and (history_timer - history.back()["time"]) > max_history_duration:
		history.pop_back()

func _update_segments() -> void:
	if history.is_empty():
		return
	
	var accumulated_dist: float = 0.0
	var history_idx: int = 0
	
	for i in range(segments.size()):
		var target_dist = (i + 1) * segment_spacing_dist
		while history_idx < history.size() - 1 and accumulated_dist < target_dist:
			var curr_pos = history[history_idx]["pos"]
			var next_pos = history[history_idx + 1]["pos"]
			accumulated_dist += curr_pos.distance_to(next_pos)
			history_idx += 1
		
		if history_idx < history.size():
			var entry = history[history_idx]
			if segments[i].has_method("set_target_state"):
				segments[i].set_target_state(entry["pos"], entry["rot"])

func add_segment() -> void:
	var segment_node = segment_scene.instantiate()
	get_parent().call_deferred("add_child", segment_node)
	
	var idx = segments.size()
	segment_node.set("segment_index", idx)
	segment_node.global_position = global_position - Vector2.RIGHT.rotated(rotation) * ((idx + 1) * segment_spacing_dist)
	segments.append(segment_node)
	
	_refresh_tail_tips()
	EventBus.segment_added.emit(segments.size() + 1)

func _refresh_tail_tips() -> void:
	for i in range(segments.size()):
		if segments[i].has_method("set_tail_tip"):
			segments[i].set_tail_tip(i == segments.size() - 1)

func _check_encircle_trap() -> void:
	if segments.size() < 12 or history.size() < 40:
		return
	
	for i in range(12, segments.size()):
		var seg = segments[i]
		var dist = global_position.distance_to(seg.global_position)
		if dist < 50.0:
			_trigger_encircle_annihilation(i)
			break

func _trigger_encircle_annihilation(loop_end_idx: int) -> void:
	var polygon = PackedVector2Array()
	polygon.append(global_position)
	for j in range(loop_end_idx + 1):
		polygon.append(segments[j].global_position)
	
	if polygon.size() < 4:
		return
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	var trapped_enemies: Array = []
	
	for enemy in enemies:
		if is_instance_valid(enemy):
			if Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
				trapped_enemies.append(enemy)
	
	if not trapped_enemies.is_empty():
		EventBus.loop_completed.emit(polygon, trapped_enemies)
		for e in trapped_enemies:
			if is_instance_valid(e) and e.has_method("take_damage"):
				e.take_damage(999.0)

func _on_gem_collected(_amount: int) -> void:
	if GameManager.total_supplies % 2 == 0:
		add_segment()

func take_damage(amount: float) -> void:
	# 철벽 장갑: 소구경 피해 35% 기본 경감
	var mitigated = amount * 0.65
	current_hp -= mitigated
	EventBus.player_damaged.emit(int(current_hp), int(max_hp))
	if current_hp <= 0.0:
		EventBus.game_over.emit()

func _draw() -> void:
	# =========================================================================
	# 3D RTS 강철 지상전함 (Super-Heavy Landship) 머리 렌더링
	# =========================================================================
	# 1. 3D 지면 투영 그림자 (항상 전장 태양광 방향인 남동쪽으로 드리움)
	var global_shadow_dir = Vector2(16.0, 22.0)
	var local_shadow = global_shadow_dir.rotated(-rotation)
	draw_circle(local_shadow, head_radius * 1.15, Color(0.02, 0.05, 0.03, 0.45))
	
	# 2. 좌우 육중한 강철 무한궤도 (Caterpillar Tracks & Road Wheels)
	var track_w = head_radius * 1.7
	var track_h = 10.0
	var track_y_offset = head_radius * 0.78
	
	# 좌측 궤도
	draw_rect(Rect2(-track_w * 0.5, -track_y_offset - track_h * 0.5, track_w, track_h), Color(0.12, 0.13, 0.15))
	# 우측 궤도
	draw_rect(Rect2(-track_w * 0.5, track_y_offset - track_h * 0.5, track_w, track_h), Color(0.12, 0.13, 0.15))
	# 궤도 강철 패드 핀 (Track Shoes)
	for i in range(-5, 6):
		var px = float(i) * (track_w / 11.0)
		draw_line(Vector2(px, -track_y_offset - track_h * 0.5), Vector2(px, -track_y_offset + track_h * 0.5), Color(0.25, 0.27, 0.30), 2.0)
		draw_line(Vector2(px, track_y_offset - track_h * 0.5), Vector2(px, track_y_offset + track_h * 0.5), Color(0.25, 0.27, 0.30), 2.0)
	
	# 3. 후방 유압 커플러 힌지 & 장갑 동력 케이블 (다음 마디 연결부)
	draw_circle(Vector2(-head_radius * 0.85, 0), 7.0, Color(0.15, 0.16, 0.18))
	draw_rect(Rect2(-head_radius * 1.1, -4.0, head_radius * 0.35, 8.0), Color(0.28, 0.30, 0.32))
	draw_line(Vector2(-head_radius * 0.7, -6), Vector2(-head_radius * 1.1, -8), Color(0.08, 0.09, 0.10), 3.0) # 동력 케이블 1
	draw_line(Vector2(-head_radius * 0.7, 6), Vector2(-head_radius * 1.1, 8), Color(0.08, 0.09, 0.10), 3.0)  # 동력 케이블 2
	
	# 4. 800mm 구스타프 초대형 주포 포신 및 유압 후퇴기 (블로우백 모션)
	var barrel_start = Vector2(10.0 - gustav_recoil_offset, 0)
	var barrel_end = Vector2(48.0 - gustav_recoil_offset, 0)
	
	# 중장갑 포신 기저부 & 800mm 초대형 구경 강철 포신
	draw_line(barrel_start, barrel_end, Color(0.14, 0.15, 0.16), 20.0)
	draw_line(barrel_start, barrel_end, Color(0.28, 0.30, 0.33), 15.0)
	# 포구 제퇴기 (Muzzle Brake)
	draw_rect(Rect2(barrel_end.x - 5.0, -10.0, 10.0, 20.0), Color(0.16, 0.17, 0.18))
	draw_line(barrel_end - Vector2(2, 0), barrel_end + Vector2(2, 0), Color(0.05, 0.05, 0.05), 14.0) # 포구 구멍
	# 포신 하부 크롬 도금 유압 완충기 실린더 (Hydraulic Recoil Damper)
	draw_line(barrel_start + Vector2(0, 9), barrel_start + Vector2(24, 9), Color(0.55, 0.58, 0.62), 4.0)
	draw_line(barrel_start + Vector2(0, -9), barrel_start + Vector2(24, -9), Color(0.55, 0.58, 0.62), 4.0)
	
	# 5. 장갑 만틀렛 방패 (Armored Gun Mantlet) & 볼트 리벳
	draw_rect(Rect2(head_radius * 0.15, -head_radius * 0.5, head_radius * 0.35, head_radius * 1.0), Color(0.24, 0.26, 0.28))
	draw_line(Vector2(head_radius * 0.15, -head_radius * 0.5), Vector2(head_radius * 0.5, -head_radius * 0.5), Color(0.55, 0.60, 0.65), 2.5) # 상부 하이라이트
	draw_line(Vector2(head_radius * 0.5, head_radius * 0.5), Vector2(head_radius * 0.15, head_radius * 0.5), Color(0.10, 0.11, 0.12), 2.5) # 하부 음영
	
	# 6. 전방 야간 탐조 서치라이트 빔 콘 (Searchlight Beam)
	var searchlight_start = Vector2(head_radius * 0.6, -head_radius * 0.4)
	var beam_pts = PackedVector2Array([
		searchlight_start,
		searchlight_start + Vector2(160.0, -55.0),
		searchlight_start + Vector2(175.0, 25.0)
	])
	draw_colored_polygon(beam_pts, Color(1.0, 0.95, 0.7, 0.12))
	draw_circle(searchlight_start, 4.0, Color(2.5, 2.5, 2.0))
	
	# 7. 800mm 구스타프 발사 순간 포구 화염 폭풍 (HDR 글로우)
	if gustav_flash_timer > 0.0:
		var flash_pos = barrel_end + Vector2(10.0, 0)
		draw_circle(flash_pos, 42.0, Color(3.5, 1.2, 0.2, 0.95))
		draw_circle(flash_pos, 24.0, Color(4.5, 3.8, 1.8, 1.0))
		draw_line(flash_pos, flash_pos + Vector2(65.0, -25.0), Color(3.0, 1.5, 0.3), 7.0)
		draw_line(flash_pos, flash_pos + Vector2(80.0, 0.0), Color(4.0, 4.0, 3.0), 9.0)
		draw_line(flash_pos, flash_pos + Vector2(65.0, 25.0), Color(3.0, 1.5, 0.3), 7.0)
		# 포구 가스 충격파 링
		draw_arc(flash_pos, 55.0, 0, TAU, 24, Color(3.0, 2.0, 0.8, 0.8), 4.0)
