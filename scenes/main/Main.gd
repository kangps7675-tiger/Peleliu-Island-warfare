extends Node2D
class_name Main

@export var enemy_scene: PackedScene = preload("res://scenes/entities/enemies/EnemyBase.tscn")
@export var proj_tscn: PackedScene = preload("res://scenes/weapons/Projectile.tscn")
@export var cannon_tscn: PackedScene = preload("res://scenes/weapons/CannonShell.tscn")
@export var kamikaze_scene: PackedScene = preload("res://scenes/entities/enemies/KamikazePlane.tscn")
@export var outpost_scene: PackedScene = preload("res://scenes/entities/enemies/EnemyOutpost.tscn")
@export var falling_bomb_scene: PackedScene = preload("res://scenes/weapons/FallingBomb.tscn")
@export var fortress_boss_scene: PackedScene = preload("res://scenes/entities/enemies/UmurbrogolFortressBoss.tscn")
@export var yamato_boss_scene: PackedScene = preload("res://scenes/entities/enemies/BattleshipYamatoBoss.tscn")

@export var b29_tex: Texture2D = preload("res://assets/sprites/b29_bomber.png")
@export var corsair_tex: Texture2D = preload("res://assets/sprites/corsair_bomber.png")

@onready var snake_head: Node2D = $SnakeHead
@onready var enemies_container: Node2D = $Enemies
@onready var projectiles_container: Node2D = $Projectiles
@onready var drops_container: Node2D = $Drops
@onready var outposts_container: Node2D = $Outposts
@onready var hud: HUD = $HUD

# 웨이브 타이머
var enemy_spawn_timer: float = 0.0
var kamikaze_timer: float = 8.0 # 8초 후 첫 가미카제 공습

# ✈️ 연합군 250대 대편대 1분 주기 공습
var airstrike_interval: float = 60.0
var airstrike_countdown: float = 60.0
var is_airstrike_active: bool = false
var airstrike_run_timer: float = 0.0
var fleet_fly_y: float = -2200.0

# 펠렐리우 섬 크기 및 바다 한계
var island_center: Vector2 = Vector2(1800, 1400)
var island_radius_x: float = 1600.0
var island_radius_y: float = 1200.0
var ocean_limit_x: float = 2350.0
var ocean_limit_y: float = 1850.0

# 보스 스폰 여부
var is_fortress_spawned: bool = false
var is_yamato_spawned: bool = false

# ☢️ 10분 핵폭탄 투하 연출
var is_nuclear_active: bool = false
var nuclear_timer: float = 0.0
var nuclear_flash: float = 0.0
var nuclear_shockwave_r: float = 0.0

# 🎨 전장 비주얼 시스템 (3D RTS 스타일)
var craters: Array = []        # 포탄/폭격 분화구 데칼 [{pos: Vector2, r: float, alpha: float}]
var tread_marks: Array = []    # 무한궤도 자국 [{pos: Vector2, rot: float, w: float, alpha: float}]
var exhaust_smokes: Array = [] # 디젤 배기 연무 [{pos: Vector2, vel: Vector2, r: float, alpha: float, life: float}]
var heavy_explosions: Array = [] # 대폭발 이펙트 [{pos: Vector2, max_r: float, elapsed: float, duration: float}]

# 포위 섬멸 마법진 시각 효과
var current_seal_polygon: PackedVector2Array = PackedVector2Array()
var seal_alpha: float = 0.0

func _ready() -> void:
	if snake_head:
		snake_head.add_to_group("player_head")
		snake_head.global_position = island_center + Vector2(0, 150)
	EventBus.loop_completed.connect(_on_loop_completed)
	GameManager.reset_game()
	
	_setup_peleliu_island_outposts()

func _setup_peleliu_island_outposts() -> void:
	var outpost_positions = [
		island_center + Vector2(-600, -400),
		island_center + Vector2(600, -400),
		island_center + Vector2(-700, 300),
		island_center + Vector2(700, 300),
		island_center + Vector2(-300, -600),
		island_center + Vector2(300, -600),
		island_center + Vector2(0, -750), # 북부 움루브로골 산악 입구
		island_center + Vector2(-800, -50),
		island_center + Vector2(800, -50),
		island_center + Vector2(0, 650)  # 남부 해안가 진지
	]
	
	if outpost_scene:
		for pos in outpost_positions:
			var outpost = outpost_scene.instantiate()
			outpost.global_position = pos
			outposts_container.add_child(outpost)

func _process(delta: float) -> void:
	# 1. 10분 핵폭탄 시퀀스 진행 중일 때
	if is_nuclear_active:
		_process_nuclear_strike(delta)
		queue_redraw()
		return
		
	# 2. 1분 주기 연합군 250대 대편대 공습 카운트다운
	if not is_airstrike_active:
		airstrike_countdown -= delta
		if airstrike_countdown <= 0.0:
			_start_allied_grand_airstrike()
	else:
		_process_allied_grand_airstrike(delta)
		
	# 3. 지상군 스폰 루프
	enemy_spawn_timer -= delta
	if enemy_spawn_timer <= 0.0:
		enemy_spawn_timer = 1.1
		_spawn_enemy_wave()
	
	# 4. 🚨 가미카제 자폭 전투기 공습 스폰 루프
	kamikaze_timer -= delta
	if kamikaze_timer <= 0.0:
		kamikaze_timer = randf_range(6.0, 11.0)
		_spawn_kamikaze_raid()
	
	# 5. 보스 스폰 조건 (시간 기반)
	_check_boss_spawns()
	
	# 6. 플레이어 바다 이탈 한계선 제약
	_constrain_snake_to_ocean_limit()
	
	# 7. 비주얼 파티클 & 데칼 업데이트
	_update_visual_fx(delta)
	
	if seal_alpha > 0.0:
		seal_alpha = maxf(0.0, seal_alpha - delta * 2.0)
	
	queue_redraw()

func _check_boss_spawns() -> void:
	# 남은 시간 05:00 이하 ➔ 움루브로골 동굴 요새포 보스 출현!
	if GameManager.countdown_time <= 300.0 and not is_fortress_spawned:
		is_fortress_spawned = true
		_spawn_fortress_boss()
		
	# 남은 시간 02:00 이하 ➔ 전함 야마토 해안 출현!
	if GameManager.countdown_time <= 120.0 and not is_yamato_spawned:
		is_yamato_spawned = true
		_spawn_yamato_boss()

func _spawn_fortress_boss() -> void:
	if fortress_boss_scene:
		var boss = fortress_boss_scene.instantiate()
		boss.global_position = island_center + Vector2(0, -820)
		enemies_container.add_child(boss)
	if hud and hud.has_method("show_event_banner"):
		hud.show_event_banner("⛰️ [적 요새포 가동] 북부 움루브로골 동굴 요새포가 포격을 시작했습니다!", Color(1.0, 0.4, 0.2), 5.0)

func _spawn_yamato_boss() -> void:
	if yamato_boss_scene:
		var boss = yamato_boss_scene.instantiate()
		boss.global_position = island_center + Vector2(0, 1900)
		enemies_container.add_child(boss)
	if hud and hud.has_method("show_event_banner"):
		hud.show_event_banner("⚓ [거대전함 출현] 해상에 일본 해군 전함 야마토가 나타났습니다!", Color(1.0, 0.3, 0.3), 5.0)

func _constrain_snake_to_ocean_limit() -> void:
	if not is_instance_valid(snake_head):
		return
	var offset = snake_head.global_position - island_center
	var normalized_dist_sq = (offset.x * offset.x) / (ocean_limit_x * ocean_limit_x) + (offset.y * ocean_limit_y)
	if normalized_dist_sq > 1.0:
		var angle = offset.angle()
		snake_head.global_position = island_center + Vector2(cos(angle) * ocean_limit_x, sin(angle) * ocean_limit_y)

func _start_allied_grand_airstrike() -> void:
	is_airstrike_active = true
	airstrike_run_timer = 0.0
	fleet_fly_y = -2200.0
	if hud and hud.has_method("show_event_banner"):
		hud.show_event_banner("💥 [연합군 250대 대편대 공습] B-29 융단폭격 개시! 전장 초토화!", Color(1.0, 0.85, 0.2), 6.5)

func _process_allied_grand_airstrike(delta: float) -> void:
	airstrike_run_timer += delta
	fleet_fly_y += 1600.0 * delta # 250대 편대 남쪽으로 초고속 통과
	
	# 폭격기가 지나갈 때 실제 500lb 항공 폭탄 투하! (초당 6~10발)
	if randf() < 0.8:
		for i in range(2):
			var ground_target = island_center + Vector2(randf_range(-1400, 1400), randf_range(-950, 950))
			var plane_high_pos = Vector2(ground_target.x + randf_range(-40, 40), fleet_fly_y + island_center.y - 200.0)
			spawn_falling_bomb(ground_target, plane_high_pos)
	
	# 공습 7초 후 종료
	if airstrike_run_timer >= 7.5:
		is_airstrike_active = false
		airstrike_countdown = airstrike_interval

func spawn_falling_bomb(ground_pos: Vector2, bomber_pos: Vector2) -> void:
	if falling_bomb_scene:
		var bomb = falling_bomb_scene.instantiate()
		bomb.initialize(ground_pos, bomber_pos)
		projectiles_container.add_child(bomb)

func trigger_nuclear_strike() -> void:
	is_nuclear_active = true
	nuclear_timer = 0.0
	nuclear_flash = 1.0
	nuclear_shockwave_r = 0.0
	
	if hud and hud.has_method("show_event_banner"):
		hud.show_event_banner("☢️ [긴급 경보] 작전 제한시간 만료! 연합군 원자폭탄 투하 승인!", Color(1.0, 0.9, 0.1), 6.0)
	
	# 화면 진동
	if is_instance_valid(snake_head) and snake_head.get("camera_shake_amount") != null:
		snake_head.camera_shake_amount = 35.0

func _process_nuclear_strike(delta: float) -> void:
	nuclear_timer += delta
	nuclear_shockwave_r += 2400.0 * delta
	nuclear_flash = maxf(0.0, nuclear_flash - delta * 0.35)
	
	# 충격파 범위 내 모든 적, 보스, 요새 완전 절멸 (피해 999999)
	for enemy in enemies_container.get_children():
		if is_instance_valid(enemy):
			if enemy.global_position.distance_to(island_center) <= nuclear_shockwave_r:
				if enemy.has_method("take_damage"):
					enemy.take_damage(999999.0)
				else:
					enemy.queue_free()
					
	for outpost in outposts_container.get_children():
		if is_instance_valid(outpost):
			outpost.queue_free()
			
	# 3.5초 경과 시 플레이어 최후 단독 생존 승리 화면 표시!
	if nuclear_timer >= 3.5 and hud:
		hud.show_victory()

func _spawn_enemy_wave() -> void:
	if not is_instance_valid(snake_head):
		return
	
	var spawn_count = randi_range(3, 5)
	for i in range(spawn_count):
		var angle = randf() * TAU
		var dist = randf_range(650.0, 900.0)
		var spawn_pos = snake_head.global_position + Vector2.RIGHT.rotated(angle) * dist
		
		var dx = (spawn_pos.x - island_center.x) / (island_radius_x + 150.0)
		var dy = (spawn_pos.y - island_center.y) / (island_radius_y + 150.0)
		if (dx * dx + dy * dy) <= 1.0:
			var enemy = enemy_scene.instantiate()
			enemy.global_position = spawn_pos
			enemies_container.add_child(enemy)

func _spawn_kamikaze_raid() -> void:
	if not is_instance_valid(snake_head) or not kamikaze_scene:
		return
		
	var count = 1 if GameManager.countdown_time > 400.0 else randi_range(1, 2)
	for i in range(count):
		var angle = randf_range(-PI * 0.85, -PI * 0.15)
		var dist = randf_range(800.0, 1050.0)
		var spawn_pos = snake_head.global_position + Vector2.RIGHT.rotated(angle) * dist
		
		var kami = kamikaze_scene.instantiate()
		kami.global_position = spawn_pos
		enemies_container.add_child(kami)

func spawn_projectile(pos: Vector2, dir: Vector2, dmg: float, col: Color) -> void:
	if proj_tscn:
		var p = proj_tscn.instantiate()
		if p.has_method("initialize"):
			p.initialize(pos, dir, dmg, col)
		projectiles_container.add_child(p)

func spawn_cannon_shell(pos: Vector2, dir: Vector2) -> void:
	if cannon_tscn:
		var shell = cannon_tscn.instantiate()
		if shell.has_method("initialize"):
			shell.initialize(pos, dir)
		projectiles_container.add_child(shell)

# 💥 컴퍼니 오브 히어로즈 급 카타스트로픽 대폭발 연출
func spawn_heavy_explosion(pos: Vector2, max_radius: float) -> void:
	heavy_explosions.append({
		"pos": pos,
		"max_r": max_radius,
		"elapsed": 0.0,
		"duration": 0.55
	})
	add_crater_decal(pos, max_radius * 0.35)

# 🌑 영구 포탄 분화구 데칼
func add_crater_decal(pos: Vector2, r: float) -> void:
	craters.append({
		"pos": pos,
		"r": r,
		"alpha": 0.95
	})
	if craters.size() > 120:
		craters.pop_front()

# 🚜 전차 무한궤도 자국 데칼
func add_tread_mark(pos: Vector2, rot: float, w: float) -> void:
	tread_marks.append({
		"pos": pos,
		"rot": rot,
		"w": w,
		"alpha": 0.75
	})
	if tread_marks.size() > 200:
		tread_marks.pop_front()

# 💨 디젤 배기 연무 파티클
func add_exhaust_smoke(pos: Vector2, vel: Vector2) -> void:
	exhaust_smokes.append({
		"pos": pos,
		"vel": vel + Vector2(randf_range(-15, 15), randf_range(-15, 15)),
		"r": randf_range(8.0, 14.0),
		"alpha": 0.7,
		"life": 0.45
	})
	if exhaust_smokes.size() > 100:
		exhaust_smokes.pop_front()

func _update_visual_fx(delta: float) -> void:
	# 1. 폭발 타이머
	var active_explosions: Array = []
	for ex in heavy_explosions:
		ex["elapsed"] += delta
		if ex["elapsed"] < ex["duration"]:
			active_explosions.append(ex)
	heavy_explosions = active_explosions
	
	# 2. 배기 연무 업데이트
	var active_smokes: Array = []
	for sm in exhaust_smokes:
		sm["pos"] += sm["vel"] * delta
		sm["r"] += 18.0 * delta
		sm["life"] -= delta
		sm["alpha"] = maxf(0.0, sm["life"] / 0.45 * 0.7)
		if sm["life"] > 0.0:
			active_smokes.append(sm)
	exhaust_smokes = active_smokes

func _on_loop_completed(polygon: PackedVector2Array, _enemies: Array) -> void:
	current_seal_polygon = polygon
	seal_alpha = 1.0
	queue_redraw()

func _draw() -> void:
	# =========================================================================
	# 1. 🌊 태평양 심해 바다 (짙은 남색 + 파도 너울)
	# =========================================================================
	draw_rect(Rect2(-1500, -1500, 6600, 5800), Color(0.04, 0.09, 0.18))
	
	# 미세 파도 너울 선
	var wave_time = Time.get_ticks_msec() * 0.001
	for wy in range(-1200, 4200, 280):
		var offset_x = sin(wave_time + wy * 0.01) * 35.0
		draw_line(Vector2(-1200 + offset_x, wy), Vector2(4800 + offset_x, wy), Color(0.08, 0.16, 0.28, 0.35), 4.0)
	
	# =========================================================================
	# 2. 🪸 에메랄드 산호초 여울 (Reef Shelf - 뱀이 자유롭게 기동하는 바다)
	# =========================================================================
	var reef_pts = _get_ellipse_points(island_center, ocean_limit_x, ocean_limit_y, 64)
	draw_colored_polygon(reef_pts, Color(0.08, 0.28, 0.38, 0.82))
	# 암초 브레이크워터 백색 포말선
	draw_polyline(reef_pts, Color(0.4, 0.75, 0.85, 0.45), 18.0)
	draw_polyline(reef_pts, Color(0.85, 0.95, 1.0, 0.6), 4.0)
	
	# =========================================================================
	# 3. 🏖️ 펠렐리우 섬 해안 백사장 (Wet Sand & Dry Sand)
	# =========================================================================
	var wet_sand_pts = _get_ellipse_points(island_center, island_radius_x + 90.0, island_radius_y + 90.0, 64)
	draw_colored_polygon(wet_sand_pts, Color(0.68, 0.62, 0.48)) # 젖은 모래
	var dry_sand_pts = _get_ellipse_points(island_center, island_radius_x + 40.0, island_radius_y + 40.0, 64)
	draw_colored_polygon(dry_sand_pts, Color(0.84, 0.78, 0.58)) # 마른 백사장
	
	# 해안 대전차 장애물 (Czech Hedgehogs) & 철조망
	for angle_idx in range(24):
		var a = angle_idx * (TAU / 24.0)
		var h_pos = island_center + Vector2(cos(a) * (island_radius_x + 35.0), sin(a) * (island_radius_y + 35.0))
		# 대전차 철 십자가 (X자 강철빔)
		draw_line(h_pos - Vector2(10, 10), h_pos + Vector2(10, 10), Color(0.2, 0.22, 0.25), 4.0)
		draw_line(h_pos - Vector2(-10, 10), h_pos + Vector2(-10, 10), Color(0.2, 0.22, 0.25), 4.0)
	
	# =========================================================================
	# 4. 🌴 울창한 열대 정글 숲 & 야자수 수관 (Tropical Jungle Base)
	# =========================================================================
	var jungle_pts = _get_ellipse_points(island_center, island_radius_x, island_radius_y, 64)
	draw_colored_polygon(jungle_pts, Color(0.16, 0.26, 0.15))
	
	# 정글 내부 수풀 텍스처 톤 변화 (3D RTS 명암 덤불)
	for i in range(40):
		var j_pos = island_center + Vector2(sin(i * 13.0) * 1100.0, cos(i * 29.0) * 800.0)
		var r = 90.0 + sin(i) * 30.0
		draw_circle(j_pos, r, Color(0.12, 0.22, 0.12, 0.6))
		draw_circle(j_pos + Vector2(8, 8), r * 0.7, Color(0.2, 0.32, 0.18, 0.45))
	
	# =========================================================================
	# 5. 🛩️ 펠렐리우 십자 비행장 (2개의 교차 아스팔트 활주로 + 유도로 + 엄체호)
	# =========================================================================
	# 활주로 아스팔트 베이스
	var runway1_start = island_center + Vector2(-650, -420)
	var runway1_end = island_center + Vector2(650, 420)
	var runway2_start = island_center + Vector2(-550, 380)
	var runway2_end = island_center + Vector2(550, -380)
	
	# 아스팔트 기저부
	draw_line(runway1_start, runway1_end, Color(0.2, 0.21, 0.22), 70.0)
	draw_line(runway2_start, runway2_end, Color(0.2, 0.21, 0.22), 60.0)
	# 활주로 테두리 연석
	draw_line(runway1_start, runway1_end, Color(0.35, 0.36, 0.38), 74.0)
	draw_line(runway1_start, runway1_end, Color(0.22, 0.23, 0.24), 70.0)
	# 활주로 중앙 점선 (흰색/황색 유도선)
	draw_line(runway1_start, runway1_end, Color(0.85, 0.85, 0.82, 0.75), 3.0)
	draw_line(runway2_start, runway2_end, Color(0.85, 0.85, 0.82, 0.75), 3.0)
	
	# 전투기 격납고 & 유도로 엄체호 (Revets & Hangars)
	draw_rect(Rect2(island_center.x + 280, island_center.y - 160, 130, 90), Color(0.32, 0.33, 0.35))
	draw_rect(Rect2(island_center.x + 280, island_center.y - 160, 130, 90), Color(0.12, 0.12, 0.14), false, 3.0)
	draw_rect(Rect2(island_center.x - 380, island_center.y + 110, 110, 80), Color(0.32, 0.33, 0.35))
	draw_rect(Rect2(island_center.x - 380, island_center.y + 110, 110, 80), Color(0.12, 0.12, 0.14), false, 3.0)
	
	# =========================================================================
	# 6. ⛰️ 북부 움루브로골 산악 지대 (Bloody Nose Ridge 암석 절벽)
	# =========================================================================
	var ridge_pts = PackedVector2Array([
		island_center + Vector2(-520, -780),
		island_center + Vector2(-220, -1080),
		island_center + Vector2(280, -1040),
		island_center + Vector2(520, -780),
		island_center + Vector2(180, -660),
		island_center + Vector2(-260, -680)
	])
	draw_colored_polygon(ridge_pts, Color(0.32, 0.28, 0.24))
	draw_polyline(ridge_pts, Color(0.16, 0.14, 0.12), 6.0)
	
	# =========================================================================
	# 7. 🚜 무한궤도 자국 & 🌑 포탄 분화구 데칼 렌더링
	# =========================================================================
	for tm in tread_marks:
		var dir = Vector2.RIGHT.rotated(tm["rot"])
		var normal = Vector2(-dir.y, dir.x) * (tm["w"] * 0.5)
		draw_line(tm["pos"] - normal, tm["pos"] + normal, Color(0.1, 0.08, 0.06, tm["alpha"] * 0.6), 4.0)
		
	for cr in craters:
		# 검게 탄 포탄 구덩이
		draw_circle(cr["pos"], cr["r"], Color(0.08, 0.07, 0.06, cr["alpha"] * 0.85))
		draw_circle(cr["pos"], cr["r"] * 0.55, Color(0.04, 0.03, 0.02, cr["alpha"] * 0.95))
		draw_arc(cr["pos"], cr["r"], 0, TAU, 16, Color(0.18, 0.14, 0.1, cr["alpha"] * 0.7), 2.0)
	
	# =========================================================================
	# 8. 💨 디젤 배기 연무 파티클
	# =========================================================================
	for sm in exhaust_smokes:
		draw_circle(sm["pos"], sm["r"], Color(0.18, 0.18, 0.2, sm["alpha"] * 0.6))
		draw_circle(sm["pos"], sm["r"] * 0.5, Color(0.1, 0.1, 0.12, sm["alpha"] * 0.75))
		
	# =========================================================================
	# 9. 💥 다단계 카타스트로픽 대폭발 이펙트 (화염구 + 충격파 + 섬광)
	# =========================================================================
	for ex in heavy_explosions:
		var p = ex["elapsed"] / ex["duration"]
		var curr_r = ex["max_r"] * ease(p, 0.25)
		var a = 1.0 - p
		# 외곽 연기 폭풍
		draw_circle(ex["pos"], curr_r, Color(0.2, 0.12, 0.05, 0.6 * a))
		# 오렌지 화염구
		draw_circle(ex["pos"], curr_r * 0.75, Color(2.5, 0.9, 0.1, 0.8 * a))
		# 초고온 백색 코어 (HDR 글로우)
		draw_circle(ex["pos"], curr_r * 0.4, Color(3.5, 3.2, 2.0, 0.95 * a))
		# 충격파 링
		draw_arc(ex["pos"], curr_r, 0, TAU, 32, Color(2.0, 1.8, 1.0, a), 4.0)
	
	# =========================================================================
	# 10. 포위 섬멸 마법진
	# =========================================================================
	if seal_alpha > 0.0 and current_seal_polygon.size() > 2:
		var fill_color = Color(1.0, 0.85, 0.2, 0.25 * seal_alpha)
		var stroke_color = Color(1.0, 0.95, 0.4, 0.9 * seal_alpha)
		draw_colored_polygon(current_seal_polygon, fill_color)
		draw_polyline(current_seal_polygon, stroke_color, 4.0)
	
	# =========================================================================
	# 11. ✈️ 연합군 250대 대편대 (B-29 중폭격기 + F4U 콜세어 / P-51) 고공 렌더링
	# =========================================================================
	if is_airstrike_active:
		var cam_x = snake_head.global_position.x if is_instance_valid(snake_head) else island_center.x
		var fleet_y = island_center.y + fleet_fly_y
		
		# 100대 B-29 슈퍼포트리스 편대 (4발 엔진 비행운 + 은빛 동체 + 그림자)
		for col_idx in range(-5, 6):
			for row_idx in range(4):
				var pos = Vector2(cam_x + col_idx * 210.0 + (row_idx % 2) * 105.0, fleet_y - row_idx * 260.0)
				_draw_high_altitude_b29(pos)
				
		# 50대 F4U 콜세어 전폭기 편대
		for col_idx in range(-4, 5):
			for row_idx in range(2):
				var pos = Vector2(cam_x + col_idx * 180.0, fleet_y - 1150.0 - row_idx * 200.0)
				_draw_high_altitude_corsair(pos)
				
		# 100대 P-51 머스탱 호위 전투기 편대
		for col_idx in range(-7, 8):
			var pos = Vector2(cam_x + col_idx * 130.0, fleet_y - 1600.0)
			_draw_high_altitude_fighter(pos)

	# =========================================================================
	# 12. ☢️ 10분 핵폭탄 투하 시퀀스 (Thermonuclear Detonation)
	# =========================================================================
	if is_nuclear_active:
		# 지면 초고온 충격파 링
		draw_arc(island_center, nuclear_shockwave_r, 0, TAU, 64, Color(3.5, 2.5, 1.0, 1.0), 12.0)
		draw_circle(island_center, nuclear_shockwave_r * 0.45, Color(3.0, 1.2, 0.2, 0.7))
		draw_circle(island_center, nuclear_shockwave_r * 0.25, Color(4.0, 3.8, 3.0, 0.9))
		
		# 화면 전체 백색 섬광 (Nuclear Flash)
		if nuclear_flash > 0.0:
			draw_rect(Rect2(-2000, -2000, 7500, 6500), Color(1.0, 1.0, 0.98, nuclear_flash))

func _draw_high_altitude_b29(pos: Vector2) -> void:
	# 1. 지상 투영 부드러운 그림자 (남동쪽 220px 오프셋)
	var shadow_pos = pos + Vector2(160, 220)
	if b29_tex:
		draw_texture_rect(b29_tex, Rect2(shadow_pos.x - 70, shadow_pos.y - 70, 140, 140), false, Color(0.0, 0.0, 0.0, 0.45))
	
	# 2. 4발 엔진 비행운 (Contrails - 짙은 백색 증기 트레일)
	var wing_span = 55.0
	for eng_offset in [-wing_span, -wing_span * 0.45, wing_span * 0.45, wing_span]:
		var eng_pos = Vector2(pos.x + eng_offset, pos.y - 20.0)
		draw_line(eng_pos, eng_pos - Vector2(0, 320.0), Color(1.0, 1.0, 1.0, 0.65), 5.0)
		draw_line(eng_pos, eng_pos - Vector2(0, 480.0), Color(0.9, 0.95, 1.0, 0.35), 8.0)
	
	# 3. 고공 은빛 B-29 동체 스프라이트
	if b29_tex:
		draw_texture_rect(b29_tex, Rect2(pos.x - 75, pos.y - 75, 150, 150), false, Color(1.05, 1.05, 1.1))

func _draw_high_altitude_corsair(pos: Vector2) -> void:
	# 1. 지상 그림자
	var shadow_pos = pos + Vector2(140, 190)
	if corsair_tex:
		draw_texture_rect(corsair_tex, Rect2(shadow_pos.x - 45, shadow_pos.y - 45, 90, 90), false, Color(0.0, 0.0, 0.0, 0.4))
	
	# 2. 배기 연무
	draw_line(pos - Vector2(0, 15), pos - Vector2(0, 140), Color(0.95, 0.95, 1.0, 0.45), 4.0)
	
	# 3. 네이비 블루 F4U 콜세어 본체
	if corsair_tex:
		draw_texture_rect(corsair_tex, Rect2(pos.x - 45, pos.y - 45, 90, 90), false)

func _draw_high_altitude_fighter(pos: Vector2) -> void:
	var shadow_pos = pos + Vector2(130, 170)
	if corsair_tex:
		draw_texture_rect(corsair_tex, Rect2(shadow_pos.x - 30, shadow_pos.y - 30, 60, 60), false, Color(0.0, 0.0, 0.0, 0.35))
		draw_texture_rect(corsair_tex, Rect2(pos.x - 30, pos.y - 30, 60, 60), false, Color(0.9, 0.9, 0.95))

func _get_ellipse_points(center: Vector2, rx: float, ry: float, segs: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(segs):
		var a = i * (TAU / segs)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
