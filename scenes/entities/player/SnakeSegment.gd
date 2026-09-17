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

var tread_timer: float = 0.0

func _process(delta: float) -> void:
	var prev_pos = global_position
	global_position = global_position.lerp(target_position, 20.0 * delta)
	rotation = lerp_angle(rotation, target_rotation, 15.0 * delta)
	
	# 무한궤도 자국 스폰
	if prev_pos.distance_squared_to(global_position) > 4.0:
		tread_timer -= delta
		if tread_timer <= 0.0:
			tread_timer = 0.16
			var main_scene = get_tree().current_scene
			if main_scene and main_scene.has_method("add_tread_mark"):
				main_scene.add_tread_mark(global_position, rotation, 18.0)
	
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

var turret_aim_angle: float = 0.0
var flak_flash_timer: float = 0.0

func _fire_30mm_aa_gun() -> void:
	var main_scene = get_tree().current_scene
	if not main_scene or not main_scene.has_method("spawn_projectile"):
		return
		
	# 🎯 스마트 타겟팅 1순위: [가미카제 자폭 비행기] 최우선 집중 요격!
	var kamikazes = get_tree().get_nodes_in_group("kamikaze")
	var target_enemy: Node2D = null
	
	if not kamikazes.is_empty():
		var min_d = 650.0
		for k in kamikazes:
			if is_instance_valid(k):
				var d = global_position.distance_to(k.global_position)
				if d < min_d:
					min_d = d
					target_enemy = k
	
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
		turret_aim_angle = dir.angle() - rotation
		flak_flash_timer = 0.09
		
		# 🔊 30mm 대공기관포 연사 사운드 (낮은 볼륨으로 자연스러운 기관총 래틀)
		AudioManager.play_sfx("flak", -6.0)
		
		var muzzle = global_position + dir * 22.0
		main_scene.spawn_projectile(muzzle, dir, 28.0, Color(1.0, 0.8, 0.2))

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
		turret_aim_angle = dir.angle() - rotation
		AudioManager.play_sfx("fortress", -2.0)
		main_scene.spawn_cannon_shell(global_position + dir * 26.0, dir)

func _draw() -> void:
	# =========================================================================
	# 3D RTS 강철 지상전함 장갑 객차 (Landship Carriage) 렌더링
	# =========================================================================
	# 1. 3D 지면 투영 그림자 (전장 태양광 방향인 남동쪽으로 드리움)
	var global_shadow_dir = Vector2(12.0, 18.0)
	var local_shadow = global_shadow_dir.rotated(-rotation)
	draw_circle(local_shadow, 17.0, Color(0.02, 0.05, 0.03, 0.42))
	
	# 2. 좌우 강철 무한궤도 어셈블리 (Caterpillar Tracks)
	var track_w = 26.0
	var track_h = 7.0
	var track_y = 13.0
	
	# 좌측/우측 궤도 기저부
	draw_rect(Rect2(-track_w * 0.5, -track_y - track_h * 0.5, track_w, track_h), Color(0.11, 0.12, 0.14))
	draw_rect(Rect2(-track_w * 0.5, track_y - track_h * 0.5, track_w, track_h), Color(0.11, 0.12, 0.14))
	# 궤도 핀 (Track shoes)
	for i in range(-3, 4):
		var px = float(i) * (track_w / 7.0)
		draw_line(Vector2(px, -track_y - track_h * 0.5), Vector2(px, -track_y + track_h * 0.5), Color(0.24, 0.26, 0.28), 1.8)
		draw_line(Vector2(px, track_y - track_h * 0.5), Vector2(px, track_y + track_h * 0.5), Color(0.24, 0.26, 0.28), 1.8)
	
	# 3. 전후방 유압 연결 커플러 & 장갑 동력 케이블 (Articulated Couplers)
	draw_rect(Rect2(10.0, -3.0, 6.0, 6.0), Color(0.25, 0.27, 0.30)) # 전방 연결 텅
	draw_rect(Rect2(-16.0, -3.0, 6.0, 6.0), Color(0.25, 0.27, 0.30)) # 후방 연결 히치
	draw_circle(Vector2(-14.0, 0), 4.0, Color(0.15, 0.16, 0.18))
	draw_line(Vector2(-12.0, -4.0), Vector2(-16.0, -6.0), Color(0.08, 0.09, 0.10), 2.5) # 유압 호스
	draw_line(Vector2(-12.0, 4.0), Vector2(-16.0, 6.0), Color(0.08, 0.09, 0.10), 2.5)
	
	# 4. 장갑 객차 본체 차체 (Armored Carriage Hull with Bevels)
	draw_rect(Rect2(-11.0, -11.0, 22.0, 22.0), Color(0.22, 0.24, 0.27))
	# 상부/좌측 햇빛 하이라이트 베벨
	draw_line(Vector2(-11.0, -11.0), Vector2(11.0, -11.0), Color(0.48, 0.52, 0.58), 2.0)
	draw_line(Vector2(-11.0, -11.0), Vector2(-11.0, 11.0), Color(0.48, 0.52, 0.58), 2.0)
	# 하부/우측 그림자 베벨
	draw_line(Vector2(11.0, -11.0), Vector2(11.0, 11.0), Color(0.10, 0.11, 0.13), 2.0)
	draw_line(Vector2(-11.0, 11.0), Vector2(11.0, 11.0), Color(0.10, 0.11, 0.13), 2.0)
	
	# 코너 리벳 볼트
	draw_circle(Vector2(-8.0, -8.0), 1.5, Color(0.65, 0.70, 0.75))
	draw_circle(Vector2(8.0, -8.0), 1.5, Color(0.65, 0.70, 0.75))
	draw_circle(Vector2(-8.0, 8.0), 1.5, Color(0.65, 0.70, 0.75))
	draw_circle(Vector2(8.0, 8.0), 1.5, Color(0.65, 0.70, 0.75))
	
	# 5. 마디 상부 원형 장갑 포탑 베이스 (Armored Turret Cupola)
	draw_circle(Vector2.ZERO, 9.5, Color(0.18, 0.20, 0.22))
	draw_arc(Vector2.ZERO, 9.5, 0, TAU, 16, Color(0.10, 0.12, 0.14), 2.0)
	
	# 6. 적을 향해 360도 독립 회전하는 30mm Flak 38 쌍열 대공포신 (Twin Autocannon Barrels)
	var barrel_dir = Vector2.RIGHT.rotated(turret_aim_angle)
	var normal = Vector2(-barrel_dir.y, barrel_dir.x) * 3.5
	var b_len = 17.0
	
	draw_line(normal, normal + barrel_dir * b_len, Color(0.10, 0.11, 0.12), 3.0)
	draw_line(-normal, -normal + barrel_dir * b_len, Color(0.10, 0.11, 0.12), 3.0)
	# 포구 소염기
	draw_line(normal + barrel_dir * (b_len - 1.0) - normal * 0.3, normal + barrel_dir * (b_len - 1.0) + normal * 0.3, Color(0.06, 0.07, 0.08), 2.0)
	draw_line(-normal + barrel_dir * (b_len - 1.0) - normal * 0.3, -normal + barrel_dir * (b_len - 1.0) + normal * 0.3, Color(0.06, 0.07, 0.08), 2.0)
	
	# 7. 발사 시 포구 화염 (Muzzle Flash)
	if flak_flash_timer > 0.0:
		var f_pos1 = normal + barrel_dir * (b_len + 4.0)
		var f_pos2 = -normal + barrel_dir * (b_len + 4.0)
		draw_circle(f_pos1, 7.0, Color(3.5, 2.0, 0.4, 0.95))
		draw_circle(f_pos2, 7.0, Color(3.5, 2.0, 0.4, 0.95))
		draw_circle(f_pos1, 3.0, Color(4.5, 4.0, 2.0, 1.0))
		draw_circle(f_pos2, 3.0, Color(4.5, 4.0, 2.0, 1.0))
