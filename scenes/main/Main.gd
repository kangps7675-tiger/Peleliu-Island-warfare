extends Node2D
class_name Main

@export var enemy_scene: PackedScene = preload("res://scenes/entities/enemies/EnemyBase.tscn")
@export var soldier_scene: PackedScene = preload("res://scenes/entities/enemies/JapaneseSoldier.tscn")
@export var officer_scene: PackedScene = preload("res://scenes/entities/enemies/JapaneseOfficer.tscn")
@export var proj_tscn: PackedScene = preload("res://scenes/weapons/Projectile.tscn")
@export var cannon_tscn: PackedScene = preload("res://scenes/weapons/CannonShell.tscn")
@export var kamikaze_scene: PackedScene = preload("res://scenes/entities/enemies/KamikazePlane.tscn")
@export var outpost_scene: PackedScene = preload("res://scenes/entities/enemies/EnemyOutpost.tscn")
@export var falling_bomb_scene: PackedScene = preload("res://scenes/weapons/FallingBomb.tscn")
@export var fortress_boss_scene: PackedScene = preload("res://scenes/entities/enemies/UmurbrogolFortressBoss.tscn")
@export var yamato_boss_scene: PackedScene = preload("res://scenes/entities/enemies/BattleshipYamatoBoss.tscn")

@export var b29_tex: Texture2D = preload("res://assets/sprites/b29_bomber.png")
@export var corsair_tex: Texture2D = preload("res://assets/sprites/corsair_bomber.png")

# 🌴 CoH / Gates of Hell 포토리얼리스틱 실사 지형 & 수목 텍스처
@export var tex_jungle_mud: Texture2D = preload("res://assets/sprites/terrain_jungle_mud.png")
@export var tex_beach_sand: Texture2D = preload("res://assets/sprites/terrain_beach_sand.png")
@export var tex_ocean_water: Texture2D = preload("res://assets/sprites/terrain_ocean_water.png")
@export var tex_runway: Texture2D = preload("res://assets/sprites/runway_asphalt.png")
@export var tex_rock_cliff: Texture2D = preload("res://assets/sprites/rock_cliff_face.png")
@export var tex_tree_palm: Texture2D = preload("res://assets/sprites/tree_palm_realistic.png")
@export var tex_tree_rainforest: Texture2D = preload("res://assets/sprites/tree_rainforest_realistic.png")

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

# 🎖️ Company of Heroes / Gates of Hell 전술 FX 시스템
var tactical_popups: Array = []        # 전술 플로팅 텍스트 [{pos: Vector2, text: String, col: Color, elapsed: float, dur: float, vel: Vector2}]
var ejected_casings: Array = []        # 황동 탄피 배출 [{pos: Vector2, vel: Vector2, rot: float, rot_vel: float, col: Color, alpha: float, bounces: int, life: float, l: float, w: float}]
var dirt_shrapnel: Array = []          # 흙먼지 & 비산 파편 [{pos: Vector2, vel: Vector2, r: float, col: Color, life: float, max_life: float}]
var vehicle_hulks: Array = []          # 불타는 전차/차량 잔해 [{pos: Vector2, rot: float, type: String, elapsed: float, duration: float, smoke_timer: float}]
var ambient_dust_particles: Array = [] # 전선 부유 흙먼지 [{pos: Vector2, vel: Vector2, r: float, alpha: float}]
var barbed_wires: Array = []           # 가시 철조망 방어선 [{p1: Vector2, p2: Vector2}]
var ammo_caches: Array = []            # 군수품 탄약 상자/드럼통 [{pos: Vector2, rot: float, type: int}]

# 포위 섬멸 마법진 시각 효과
var current_seal_polygon: PackedVector2Array = PackedVector2Array()
var seal_alpha: float = 0.0

# 🌴 3D RTS 전장 지형 피처들 (수많은 나무들, 동굴들, 흙길들, 강, 언덕, 참호, 대공포좌)
var jungle_trees: Array = []
var dirt_roads: Array = []
var river_points: PackedVector2Array = PackedVector2Array()
var hills: Array = []
var caves: Array = []
var trenches: Array = []
var flak_positions: Array = []

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if snake_head:
		snake_head.add_to_group("player_head")
		snake_head.global_position = island_center + Vector2(0, 150)
	EventBus.loop_completed.connect(_on_loop_completed)
	GameManager.reset_game()
	
	_setup_peleliu_island_outposts()
	_setup_environment_features()

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

func _setup_environment_features() -> void:
	# 1. 🌊 흐르는 강 (River) 좌표
	river_points = PackedVector2Array([
		island_center + Vector2(-180, -680),
		island_center + Vector2(-280, -480),
		island_center + Vector2(-480, -220),
		island_center + Vector2(-780, -20),
		island_center + Vector2(-1150, 180),
		island_center + Vector2(-1550, 280),
		island_center + Vector2(-1950, 320)
	])
	
	# 2. 흙길 (Dirt Supply Roads)
	dirt_roads = [
		# 활주로 ➔ 북부 움루브로골 산악
		PackedVector2Array([
			island_center + Vector2(0, -180),
			island_center + Vector2(40, -380),
			island_center + Vector2(-30, -560),
			island_center + Vector2(0, -720)
		]),
		# 활주로 ➔ 남부 해안선 상륙지
		PackedVector2Array([
			island_center + Vector2(0, 180),
			island_center + Vector2(-60, 420),
			island_center + Vector2(20, 680),
			island_center + Vector2(0, 920)
		]),
		# 활주로 ➔ 동부 전초기지
		PackedVector2Array([
			island_center + Vector2(320, 0),
			island_center + Vector2(580, 80),
			island_center + Vector2(860, 120),
			island_center + Vector2(1150, 180)
		])
	]
	
	# 3. 언덕 (Hills with contour elevations)
	hills = [
		{"pos": island_center + Vector2(720, -480), "r": 230.0},
		{"pos": island_center + Vector2(-760, 520), "r": 210.0},
		{"pos": island_center + Vector2(820, 460), "r": 200.0}
	]
	
	# 4. 동굴들 (Caves in the Limestone Ridge)
	caves = [
		island_center + Vector2(-320, -760),
		island_center + Vector2(-120, -920),
		island_center + Vector2(140, -890),
		island_center + Vector2(360, -750)
	]
	
	# 5. 참호선 (Zigzag Trenches)
	trenches = [
		PackedVector2Array([
			island_center + Vector2(-450, -480),
			island_center + Vector2(-420, -450),
			island_center + Vector2(-460, -420),
			island_center + Vector2(-430, -390)
		]),
		PackedVector2Array([
			island_center + Vector2(450, -480),
			island_center + Vector2(480, -450),
			island_center + Vector2(440, -420),
			island_center + Vector2(470, -390)
		]),
		PackedVector2Array([
			island_center + Vector2(-220, 520),
			island_center + Vector2(-180, 550),
			island_center + Vector2(-230, 580),
			island_center + Vector2(-190, 610)
		])
	]
	
	# 6. 96식 25mm 쌍열 대공화기 포좌 (Flak AA Pits)
	flak_positions = [
		island_center + Vector2(-460, -280),
		island_center + Vector2(460, -280),
		island_center + Vector2(-420, 260),
		island_center + Vector2(420, 260),
		island_center + Vector2(0, -560),
		island_center + Vector2(0, 520)
	]
	
	# 7. 🌴 270그루 3D RTS 수직 입체 열대 수목 (수직 높이감 & Y-소팅)
	var rng = RandomNumberGenerator.new()
	rng.seed = 19440915 # 고정 시드로 매 판 균일하고 아름다운 전장 지형 형성
	
	for i in range(270):
		var angle = rng.randf() * TAU
		var dist_x = rng.randf_range(280.0, island_radius_x - 70.0)
		var dist_y = rng.randf_range(220.0, island_radius_y - 70.0)
		var t_pos = island_center + Vector2(cos(angle) * dist_x, sin(angle) * dist_y)
		
		# 활주로 중심부(길이 650) 피하기
		if t_pos.distance_to(island_center) < 320.0:
			continue
			
		var tree_type = rng.randi_range(0, 2) # 0: 야자수, 1: 빽빽한 정글목, 2: 거목
		var r = rng.randf_range(20.0, 36.0)
		var col = Color(rng.randf_range(0.12, 0.22), rng.randf_range(0.28, 0.45), rng.randf_range(0.12, 0.2))
		
		# 수직 3D 높이 (야자수는 키가 크고, 거목은 웅장함)
		var t_height = rng.randf_range(52.0, 82.0) if tree_type == 0 else (rng.randf_range(60.0, 90.0) if tree_type == 2 else rng.randf_range(40.0, 62.0))
		var trunk_curve = rng.randf_range(-8.0, 8.0)
		
		jungle_trees.append({
			"pos": t_pos,
			"r": r,
			"type": tree_type,
			"col": col,
			"height": t_height,
			"trunk_curve": trunk_curve,
			"shadow_offset": Vector2(t_height * 0.65, t_height * 0.85) # 태양광 방향 장대 그림자
		})
		
	# 3D RTS 아이소메트릭 Y-소팅: 위쪽(북쪽) 나무부터 아래쪽(남쪽) 나무 순서대로 렌더링하여 자연스러운 입체 차폐 구현
	jungle_trees.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)
	
	# 8. 🎖️ CoH / GoH 가시 철조망 방어선 & 군수품 탄약 상자 & 전선 흙먼지 파티클
	_setup_battlefield_props()

func _setup_battlefield_props() -> void:
	# 가시 철조망 (Barbed Wire entanglements)
	barbed_wires = [
		{"p1": island_center + Vector2(-550, -320), "p2": island_center + Vector2(-380, -320)},
		{"p1": island_center + Vector2(380, -320), "p2": island_center + Vector2(550, -320)},
		{"p1": island_center + Vector2(-520, 360), "p2": island_center + Vector2(-350, 360)},
		{"p1": island_center + Vector2(350, 360), "p2": island_center + Vector2(520, 360)},
		{"p1": island_center + Vector2(-150, 680), "p2": island_center + Vector2(150, 680)},
		{"p1": island_center + Vector2(-180, -620), "p2": island_center + Vector2(180, -620)}
	]
	
	# 목재 탄약 상자 & 철제 캔 & 드럼통 (Ammo Caches & Fuel Drums)
	for i in range(24):
		var ang = randf() * TAU
		var dist = randf_range(300.0, 1100.0)
		var p = island_center + Vector2(cos(ang) * dist, sin(ang) * (dist * 0.75))
		ammo_caches.append({
			"pos": p,
			"rot": randf() * TAU,
			"type": randi() % 3 # 0: 대형 목재 상자, 1: 녹색 금속 탄약캔, 2: 철제 연료 드럼통
		})
		
	# 전선 대기 흙먼지 부유 입자
	for i in range(45):
		ambient_dust_particles.append({
			"pos": island_center + Vector2(randf_range(-1600, 1600), randf_range(-1100, 1100)),
			"vel": Vector2(randf_range(15, 35), randf_range(-8, 8)),
			"r": randf_range(1.5, 3.5),
			"alpha": randf_range(0.12, 0.32)
		})

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
	# 남은 시간 08:00 이하 ➔ 움루브로골 동굴 요새포 보스 출현!
	if GameManager.countdown_time <= 480.0 and not is_fortress_spawned:
		is_fortress_spawned = true
		_spawn_fortress_boss()
		
	# 남은 시간 03:00 이하 ➔ 전함 야마토 해안 출현!
	if GameManager.countdown_time <= 180.0 and not is_yamato_spawned:
		is_yamato_spawned = true
		_spawn_yamato_boss()

func _spawn_fortress_boss() -> void:
	if fortress_boss_scene:
		var boss = fortress_boss_scene.instantiate()
		boss.global_position = island_center + Vector2(0, -820)
		enemies_container.add_child(boss)

func _spawn_yamato_boss() -> void:
	if yamato_boss_scene:
		var boss = yamato_boss_scene.instantiate()
		boss.global_position = island_center + Vector2(0, 1900)
		enemies_container.add_child(boss)

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
	AudioManager.start_propeller_sound()
	if hud and hud.has_method("show_event_banner"):
		hud.show_event_banner("✈️ [1분 주기 공습] 연합군 250대 대편대 B-29 융단폭격 개시!", Color(1.0, 0.85, 0.2), 5.0)

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
		AudioManager.stop_propeller_sound()

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
	AudioManager.stop_propeller_sound()
	AudioManager.play_sfx("explosion", 5.0)
	
	if hud and hud.has_method("show_event_banner"):
		hud.show_event_banner("☢️ [작전 만료] 15분 결전 제한시간 만료! 연합군 원자폭탄 투하 승인!", Color(1.0, 0.9, 0.1), 6.0)
	
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
	
	var squad_center_angle = randf() * TAU
	var squad_center_dist = randf_range(680.0, 920.0)
	var squad_center = snake_head.global_position + Vector2.RIGHT.rotated(squad_center_angle) * squad_center_dist
	
	var dx = (squad_center.x - island_center.x) / (island_radius_x + 150.0)
	var dy = (squad_center.y - island_center.y) / (island_radius_y + 150.0)
	if (dx * dx + dy * dy) > 1.0:
		return
		
	# 1. 🎖️ 일본군 분대장: 100식 기관단총 장교 1명
	if officer_scene:
		var officer = officer_scene.instantiate()
		officer.global_position = squad_center
		enemies_container.add_child(officer)
		
	# 2. 🪖 일본군 보병: 30년식 총검 아리사카 소총병 3~5명
	if soldier_scene:
		var soldier_count = randi_range(3, 5)
		for s_idx in range(soldier_count):
			var soldier = soldier_scene.instantiate()
			var s_offset = Vector2(randf_range(-65, 65), randf_range(-65, 65))
			soldier.global_position = squad_center + s_offset
			enemies_container.add_child(soldier)
			
	# 3. 🚜 25% 확률로 치하 전차 1대 화력 지원 증원
	if randf() < 0.25 and enemy_scene:
		var tank = enemy_scene.instantiate()
		tank.global_position = squad_center + Vector2(randf_range(-80, 80), randf_range(-80, 80))
		enemies_container.add_child(tank)

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

func spawn_projectile(pos: Vector2, dir: Vector2, dmg: float, col: Color, enemy_shot: bool = false) -> void:
	if proj_tscn:
		var p = proj_tscn.instantiate()
		if p.has_method("initialize"):
			p.initialize(pos, dir, dmg, col, enemy_shot)
		projectiles_container.add_child(p)

func spawn_cannon_shell(pos: Vector2, dir: Vector2) -> void:
	if cannon_tscn:
		var shell = cannon_tscn.instantiate()
		if shell.has_method("initialize"):
			shell.initialize(pos, dir)
		projectiles_container.add_child(shell)

# 💥 컴퍼니 오브 히어로즈 급 카타스트로픽 대폭발 연출 (충격파 진동 & 비산 흙먼지)
func spawn_heavy_explosion(pos: Vector2, max_radius: float) -> void:
	heavy_explosions.append({
		"pos": pos,
		"max_r": max_radius,
		"elapsed": 0.0,
		"duration": 0.55
	})
	add_crater_decal(pos, max_radius * 0.35)
	spawn_dirt_eruption(pos, int(max_radius * 0.12), max_radius * 1.5)
	trigger_screen_shake(pos, minf(max_radius * 0.25, 30.0), 1100.0)

# 📯 CoH 전술 플로팅 텍스트 팝업 (도탄, 반자이, 점사 등)
func spawn_tactical_popup(pos: Vector2, text: String, col: Color = Color.WHITE, dur: float = 1.1) -> void:
	tactical_popups.append({
		"pos": pos + Vector2(randf_range(-12, 12), -15.0),
		"text": text,
		"col": col,
		"elapsed": 0.0,
		"dur": dur,
		"vel": Vector2(0, -38.0)
	})
	if tactical_popups.size() > 50:
		tactical_popups.pop_front()

# 🔫 실시간 황동 탄피 배출 시스템 (20mm 오토캐논, 7.7mm 아리사카, 8mm 남부)
func eject_casing(pos: Vector2, eject_dir: Vector2, caliber: String = "20mm") -> void:
	var speed = randf_range(80.0, 160.0)
	var casing_vel = eject_dir.rotated(randf_range(-0.4, 0.4)) * speed
	var l = 7.5 if caliber == "20mm" else (5.5 if caliber == "7.7mm" else 4.2)
	var w = 2.6 if caliber == "20mm" else 1.8
	var col = Color(0.95, 0.78, 0.28) if caliber == "20mm" else Color(0.88, 0.70, 0.24)
	ejected_casings.append({
		"pos": pos,
		"vel": casing_vel,
		"rot": randf() * TAU,
		"rot_vel": randf_range(-15.0, 15.0),
		"col": col,
		"alpha": 0.95,
		"life": 7.0,
		"l": l,
		"w": w
	})
	if ejected_casings.size() > 180:
		ejected_casings.pop_front()

# 🌋 고폭탄/포탄 착탄 흙먼지 기둥 & 암석 비산 파편
func spawn_dirt_eruption(pos: Vector2, count: int = 8, max_speed: float = 180.0) -> void:
	for i in range(count):
		var angle = randf() * TAU
		var spd = randf_range(35.0, max_speed)
		var r = randf_range(2.5, 6.0)
		var life = randf_range(0.35, 0.65)
		var c_val = randf_range(0.18, 0.38)
		var dirt_col = Color(c_val * 1.3, c_val, c_val * 0.7)
		dirt_shrapnel.append({
			"pos": pos,
			"vel": Vector2.RIGHT.rotated(angle) * spd,
			"r": r,
			"col": dirt_col,
			"life": life,
			"max_life": life
		})
	if dirt_shrapnel.size() > 180:
		dirt_shrapnel = dirt_shrapnel.slice(dirt_shrapnel.size() - 180)

# 🚜 불타는 전차/차량 잔해 (CoH Burning Wreck Hulks)
func spawn_vehicle_hulk(pos: Vector2, rot: float, type: String = "chiha") -> void:
	vehicle_hulks.append({
		"pos": pos,
		"rot": rot,
		"type": type,
		"elapsed": 0.0,
		"duration": 18.0,
		"smoke_timer": 0.0
	})
	if vehicle_hulks.size() > 25:
		vehicle_hulks.pop_front()

# 🫨 거리 비례 카메라 충격파 진동 (Distance-Attenuated Screen Shake)
func trigger_screen_shake(pos: Vector2, intensity: float = 16.0, max_dist: float = 900.0) -> void:
	if not is_instance_valid(snake_head):
		return
	var d = snake_head.global_position.distance_to(pos)
	if d <= max_dist:
		var factor = 1.0 - (d / max_dist)
		var shake = intensity * factor
		if snake_head.get("camera_shake_amount") != null:
			snake_head.camera_shake_amount = maxf(snake_head.camera_shake_amount, shake)

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
	
	# 3. 전술 플로팅 텍스트 업데이트
	var active_popups: Array = []
	for pop in tactical_popups:
		pop["elapsed"] += delta
		pop["pos"] += pop["vel"] * delta
		if pop["elapsed"] < pop["dur"]:
			active_popups.append(pop)
	tactical_popups = active_popups
	
	# 4. 황동 탄피 배출 물리 (감속 및 바닥 안착)
	var active_casings: Array = []
	for c in ejected_casings:
		c["pos"] += c["vel"] * delta
		c["vel"] *= 0.88 # 지면 마찰 감속
		c["rot"] += c["rot_vel"] * delta
		c["rot_vel"] *= 0.90
		c["life"] -= delta
		if c["life"] < 1.5:
			c["alpha"] = c["life"] / 1.5 * 0.95
		if c["life"] > 0.0:
			active_casings.append(c)
	ejected_casings = active_casings
	
	# 5. 흙먼지 & 비산 파편 업데이트
	var active_shrapnel: Array = []
	for sh in dirt_shrapnel:
		sh["pos"] += sh["vel"] * delta
		sh["vel"] *= 0.92
		sh["life"] -= delta
		if sh["life"] > 0.0:
			active_shrapnel.append(sh)
	dirt_shrapnel = active_shrapnel
	
	# 6. 불타는 전차 잔해 업데이트 (흑색 오일 연기 방출)
	var active_hulks: Array = []
	for h in vehicle_hulks:
		h["elapsed"] += delta
		h["smoke_timer"] -= delta
		if h["smoke_timer"] <= 0.0:
			h["smoke_timer"] = randf_range(0.12, 0.22)
			add_exhaust_smoke(h["pos"] + Vector2(randf_range(-12, 12), randf_range(-10, 10)), Vector2(randf_range(-10, 20), -65.0))
		if h["elapsed"] < h["duration"]:
			active_hulks.append(h)
	vehicle_hulks = active_hulks
	
	# 7. 전선 부유 흙먼지 입자 이동
	for dp in ambient_dust_particles:
		dp["pos"] += dp["vel"] * delta
		if dp["pos"].x > island_center.x + island_radius_x + 200.0:
			dp["pos"].x = island_center.x - island_radius_x - 100.0
			dp["pos"].y = island_center.y + randf_range(-island_radius_y, island_radius_y)

func _on_loop_completed(polygon: PackedVector2Array, _enemies: Array) -> void:
	current_seal_polygon = polygon
	seal_alpha = 1.0
	queue_redraw()

func _draw() -> void:
	# =========================================================================
	# 1. 🌊 태평양 3D 심해 바다 (Photorealistic Ocean with Caustics & Swells)
	# =========================================================================
	# 심해 해구 (Deep Pacific Ocean Tiled Texture)
	var ocean_poly = PackedVector2Array([
		Vector2(-2500, -2500),
		Vector2(6500, -2500),
		Vector2(6500, 5500),
		Vector2(-2500, 5500)
	])
	_draw_textured_poly(ocean_poly, tex_ocean_water, 768.0, Color(0.55, 0.70, 0.90))
	
	# 심해 거대 파도 너울
	var wave_time = Time.get_ticks_msec() * 0.001
	for wy in range(-1200, 4200, 240):
		var offset_x = sin(wave_time * 1.1 + wy * 0.01) * 45.0
		draw_line(Vector2(-1200 + offset_x, wy), Vector2(4800 + offset_x, wy), Color(0.05, 0.11, 0.22, 0.45), 6.0)
	
	# =========================================================================
	# 2. 🪸 에메랄드 산호초 장벽 (Barrier Reef Shelf - Caustic Reef Shallows)
	# =========================================================================
	var reef_pts = _get_ellipse_points(island_center, ocean_limit_x, ocean_limit_y, 64)
	_draw_textured_poly(reef_pts, tex_ocean_water, 480.0, Color(0.35, 0.92, 0.85, 0.92))
	
	# 수중 암초/산호 군락 실루엣 (Underwater Reef Silhouettes)
	for ri in range(28):
		var r_angle = ri * (TAU / 28.0)
		var r_pos = island_center + Vector2(cos(r_angle) * (ocean_limit_x - 140.0), sin(r_angle) * (ocean_limit_y - 140.0))
		draw_circle(r_pos, 52.0, Color(0.03, 0.20, 0.26, 0.6))
	
	# 해안선 쇄파 백색 포말선 (Rolling Surf Foam Waves)
	var surf_pulse = sin(wave_time * 2.4) * 14.0
	var surf_pts1 = _get_ellipse_points(island_center, ocean_limit_x - 55.0 + surf_pulse, ocean_limit_y - 55.0 + surf_pulse, 64)
	draw_polyline(surf_pts1, Color(0.70, 0.92, 1.0, 0.55), 14.0)
	draw_polyline(surf_pts1, Color(1.0, 1.0, 1.0, 0.75), 4.0)
	
	# =========================================================================
	# 3. 🏖️ 펠렐리우 섬 해안 백사장 (CoH Photorealistic Coral Sand & Shallows)
	# =========================================================================
	# 얕은 여울 청록빛 바다 (Nearshore Turquoise Shallows)
	var shallow_pts = _get_ellipse_points(island_center, island_radius_x + 130.0, island_radius_y + 130.0, 64)
	_draw_textured_poly(shallow_pts, tex_ocean_water, 360.0, Color(0.50, 1.05, 0.98, 0.82))
	
	# 젖은 모래 백사장 (Wet Sand Tide Wash with Ripple Texture)
	var wet_sand_pts = _get_ellipse_points(island_center, island_radius_x + 85.0, island_radius_y + 85.0, 64)
	_draw_textured_poly(wet_sand_pts, tex_beach_sand, 420.0, Color(0.75, 0.68, 0.56))
	
	# 마른 열대 백사장 (Dry Golden Coral Sand Texture)
	var dry_sand_pts = _get_ellipse_points(island_center, island_radius_x + 35.0, island_radius_y + 35.0, 64)
	_draw_textured_poly(dry_sand_pts, tex_beach_sand, 360.0, Color(1.05, 1.0, 0.92))
	
	# 해안선 파도 거품 라인
	var beach_foam = _get_ellipse_points(island_center, island_radius_x + 95.0 + sin(wave_time * 2.0) * 8.0, island_radius_y + 95.0 + sin(wave_time * 2.0) * 8.0, 64)
	draw_polyline(beach_foam, Color(1.0, 1.0, 1.0, 0.65), 5.0)
	
	# 해안 대전차 장애물 (3D Czech Hedgehogs with Cast Shadows)
	for angle_idx in range(24):
		var a = angle_idx * (TAU / 24.0)
		var h_pos = island_center + Vector2(cos(a) * (island_radius_x + 35.0), sin(a) * (island_radius_y + 35.0))
		# 지면 그림자
		draw_line(h_pos + Vector2(5, 7) - Vector2(10, 8), h_pos + Vector2(5, 7) + Vector2(10, 8), Color(0.04, 0.06, 0.04, 0.4), 4.0)
		# 대전차 철 십자가 3D 입체빔
		draw_line(h_pos - Vector2(10, 10), h_pos + Vector2(10, 10), Color(0.18, 0.20, 0.22), 4.5)
		draw_line(h_pos - Vector2(-10, 10), h_pos + Vector2(-10, 10), Color(0.24, 0.26, 0.28), 4.5)
		draw_line(h_pos, h_pos - Vector2(0, 14), Color(0.35, 0.38, 0.40), 3.5) # 수직 빔
	
	# =========================================================================
	# 4. 🌴 울창한 열대 정글 숲 기저 지형 (Photorealistic Mud, Roots & Foliage Base)
	# =========================================================================
	var jungle_pts = _get_ellipse_points(island_center, island_radius_x, island_radius_y, 64)
	_draw_textured_poly(jungle_pts, tex_jungle_mud, 480.0, Color(0.95, 1.0, 0.9))
	
	# 정글 내부 수풀 텍스처 톤 변화 (3D RTS 명암 덤불)
	for i in range(40):
		var j_pos = island_center + Vector2(sin(i * 13.0) * 1100.0, cos(i * 29.0) * 800.0)
		var r = 90.0 + sin(i) * 30.0
		draw_circle(j_pos, r, Color(0.10, 0.18, 0.10, 0.35))
		draw_circle(j_pos + Vector2(8, 8), r * 0.7, Color(0.18, 0.28, 0.16, 0.25))
	
	# =========================================================================
	# 4-B. 🚜 보급 흙길 (3 Winding Dirt Supply Roads with Tire Ruts)
	# =========================================================================
	_draw_dirt_roads()
	
	# =========================================================================
	# 4-C. 🌊 흐르는 강 (Animated Flowing River with Mud Banks & Wave Ripples)
	# =========================================================================
	_draw_flowing_river(wave_time)
	
	# =========================================================================
	# 4-D. ⛰️ 등고선 입체 언덕 (3 Topographic Elevation Hills with Shaded Relief)
	# =========================================================================
	_draw_elevation_hills()
	
	# =========================================================================
	# 4-E. ⛰️ 북부 움루브로골 산악 지대 (3D Bloody Nose Ridge Mountain & Caves)
	# =========================================================================
	_draw_bloody_nose_ridge()
	_draw_limestone_caves()
	
	# =========================================================================
	# 4-F. 🪖 지그재그 방어 참호선 (Zigzag Defense Trenches & Sandbags)
	# =========================================================================
	_draw_trenches()
	
	# =========================================================================
	# 4-G. 🛡️ 96식 25mm 대공화기 포좌 (Flak AA Gun Pits & Sandbag Berms)
	# =========================================================================
	_draw_flak_pits()
	
	# =========================================================================
	# 4-H. 🪖 가시 철조망 방어선 & 📦 군수품 탄약 상자/드럼통 (Barbed Wire & Ammo Caches)
	# =========================================================================
	_draw_barbed_wires()
	_draw_ammo_caches()
	
	# =========================================================================
	# 5. 🛩️ 펠렐리우 십자 비행장 (실사 콘크리트 슬래브 활주로 + 유도로 + 엄체호)
	# =========================================================================
	var runway1_start = island_center + Vector2(-650, -420)
	var runway1_end = island_center + Vector2(650, 420)
	var runway2_start = island_center + Vector2(-550, 380)
	var runway2_end = island_center + Vector2(550, -380)
	
	# 1) 활주로 하부 자갈/흙 숄더 (Shoulder Base)
	draw_line(runway1_start, runway1_end, Color(0.24, 0.22, 0.18, 0.8), 86.0)
	draw_line(runway2_start, runway2_end, Color(0.24, 0.22, 0.18, 0.8), 76.0)
	
	# 2) 실사 균열 콘크리트 슬래브 텍스처 (Photorealistic Runway Slabs)
	var r1_quad = _get_line_quad(runway1_start, runway1_end, 74.0)
	var r2_quad = _get_line_quad(runway2_start, runway2_end, 64.0)
	_draw_textured_poly(r1_quad, tex_runway, 256.0, Color(0.95, 0.95, 0.95))
	_draw_textured_poly(r2_quad, tex_runway, 256.0, Color(0.95, 0.95, 0.95))
	
	# 3) 활주로 콘크리트 외곽 연석선
	draw_line(runway1_start, runway1_end, Color(0.15, 0.15, 0.16, 0.6), 76.0)
	draw_line(runway2_start, runway2_end, Color(0.15, 0.15, 0.16, 0.6), 66.0)
	
	# 4) 활주로 중앙 점선 유도선
	draw_line(runway1_start, runway1_end, Color(0.88, 0.88, 0.82, 0.8), 3.0)
	draw_line(runway2_start, runway2_end, Color(0.88, 0.88, 0.82, 0.8), 3.0)
	
	# 5) 활주로 양단 피아노 건반형 착륙 유도 마킹 (Threshold Piano Keys)
	var r1_dir = (runway1_end - runway1_start).normalized()
	var r2_dir = (runway2_end - runway2_start).normalized()
	_draw_runway_threshold(runway1_start, r1_dir, 70.0)
	_draw_runway_threshold(runway1_end, -r1_dir, 70.0)
	_draw_runway_threshold(runway2_start, r2_dir, 60.0)
	_draw_runway_threshold(runway2_end, -r2_dir, 60.0)
	
	# 6) 전투기 격납고 & 유도로 엄체호 (Revets & Hangars with Concrete Pads & Blast Berms)
	var hangar1_rect = Rect2(island_center.x + 280, island_center.y - 160, 130, 90)
	var h1_quad = PackedVector2Array([
		hangar1_rect.position,
		hangar1_rect.position + Vector2(hangar1_rect.size.x, 0),
		hangar1_rect.position + hangar1_rect.size,
		hangar1_rect.position + Vector2(0, hangar1_rect.size.y)
	])
	_draw_textured_poly(h1_quad, tex_runway, 180.0, Color(0.9, 0.9, 0.9))
	draw_rect(hangar1_rect, Color(0.12, 0.12, 0.14), false, 2.5)
	# 모래주머니/토사 방폭벽 (Revetment Berm)
	draw_line(hangar1_rect.position, hangar1_rect.position + Vector2(hangar1_rect.size.x, 0), Color(0.48, 0.42, 0.32), 7.0)
	draw_line(hangar1_rect.position + Vector2(hangar1_rect.size.x, 0), hangar1_rect.position + hangar1_rect.size, Color(0.48, 0.42, 0.32), 7.0)
	draw_line(hangar1_rect.position, hangar1_rect.position + Vector2(0, hangar1_rect.size.y), Color(0.48, 0.42, 0.32), 7.0)
	
	var hangar2_rect = Rect2(island_center.x - 380, island_center.y + 110, 110, 80)
	var h2_quad = PackedVector2Array([
		hangar2_rect.position,
		hangar2_rect.position + Vector2(hangar2_rect.size.x, 0),
		hangar2_rect.position + hangar2_rect.size,
		hangar2_rect.position + Vector2(0, hangar2_rect.size.y)
	])
	_draw_textured_poly(h2_quad, tex_runway, 180.0, Color(0.9, 0.9, 0.9))
	draw_rect(hangar2_rect, Color(0.12, 0.12, 0.14), false, 2.5)
	draw_line(hangar2_rect.position, hangar2_rect.position + Vector2(hangar2_rect.size.x, 0), Color(0.48, 0.42, 0.32), 7.0)
	draw_line(hangar2_rect.position + Vector2(0, hangar2_rect.size.y), hangar2_rect.position + hangar2_rect.size, Color(0.48, 0.42, 0.32), 7.0)
	draw_line(hangar2_rect.position, hangar2_rect.position + Vector2(0, hangar2_rect.size.y), Color(0.48, 0.42, 0.32), 7.0)
	
	# =========================================================================
	# 6. 🚜 무한궤도 자국 & 🌑 포탄 분화구 & 🔫 황동 탄피 & 🔥 불타는 전차 잔해
	# =========================================================================
	_draw_tread_marks_and_craters()
	_draw_ejected_casings()
	_draw_vehicle_hulks()
	
	# =========================================================================
	# 7. 🌴 270그루 3D RTS 열대 수목 (야자수 & 정글림 입체 투영 그림자 + 수관)
	# =========================================================================
	_draw_jungle_trees(wave_time)
	
	# =========================================================================
	# 8. 💨 디젤 배기 연무 파티클
	# =========================================================================
	for sm in exhaust_smokes:
		draw_circle(sm["pos"], sm["r"], Color(0.18, 0.18, 0.2, sm["alpha"] * 0.6))
		draw_circle(sm["pos"], sm["r"] * 0.5, Color(0.1, 0.1, 0.12, sm["alpha"] * 0.75))
		
	# =========================================================================
	# 9. 💥 다단계 카타스트로픽 대폭발 & 🌋 흙먼지 비산 파편
	# =========================================================================
	_draw_dirt_shrapnel()
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
			
	# =========================================================================
	# 13. 🎖️ 전선 부유 흙먼지 & CoH 전술 플로팅 텍스트 팝업 (Top-Level Tactical Popups)
	# =========================================================================
	_draw_ambient_dust()
	_draw_tactical_popups()

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

# 🎨 CoH / Gates of Hell 스타일 실사 텍스처 폴리곤 렌더링 헬퍼 (Seamless Hardware Tiling)
func _draw_textured_poly(pts: PackedVector2Array, tex: Texture2D, tile_scale: float = 512.0, tint: Color = Color.WHITE) -> void:
	if pts.size() < 3:
		return
	if not tex:
		draw_colored_polygon(pts, tint)
		return
	var uvs = PackedVector2Array()
	var cols = PackedColorArray()
	for pt in pts:
		uvs.append(pt / tile_scale)
		cols.append(tint)
	draw_polygon(pts, cols, uvs, tex)

func _get_line_quad(start: Vector2, end: Vector2, width: float) -> PackedVector2Array:
	var dir = (end - start).normalized()
	var normal = Vector2(-dir.y, dir.x) * (width * 0.5)
	return PackedVector2Array([
		start - normal,
		end - normal,
		end + normal,
		start + normal
	])

func _draw_runway_threshold(end_pt: Vector2, heading_dir: Vector2, width: float) -> void:
	var norm = Vector2(-heading_dir.y, heading_dir.x)
	var num_stripes = 6
	for i in range(num_stripes):
		var t = (float(i) / float(num_stripes - 1) - 0.5) * (width * 0.72)
		var p1 = end_pt + norm * t
		var p2 = p1 + heading_dir * 32.0
		draw_line(p1, p2, Color(0.92, 0.92, 0.88, 0.85), 3.5)

func _draw_dirt_roads() -> void:
	for road in dirt_roads:
		if road.size() < 2:
			continue
		# 3D 굴착 흙길: 가장자리 둑 그림자
		draw_polyline(road, Color(0.18, 0.14, 0.10, 0.5), 42.0)
		# 갈색 토양 베이스
		draw_polyline(road, Color(0.44, 0.34, 0.22), 36.0)
		# 내부 마모된 흙길
		draw_polyline(road, Color(0.50, 0.40, 0.27), 26.0)
		# 차량 바퀴 궤적 (좌우 2줄 흙길 바퀴 자국)
		for i in range(road.size() - 1):
			var p1 = road[i]
			var p2 = road[i + 1]
			var dir = (p2 - p1).normalized()
			var normal = Vector2(-dir.y, dir.x) * 6.5
			draw_line(p1 + normal, p2 + normal, Color(0.26, 0.18, 0.11, 0.7), 3.2)
			draw_line(p1 - normal, p2 - normal, Color(0.26, 0.18, 0.11, 0.7), 3.2)

func _draw_flowing_river(wave_time: float) -> void:
	if river_points.size() < 2:
		return
	# 1. 3D 강바닥 굴착 절벽 둑 (Deep river mud embankment walls)
	draw_polyline(river_points, Color(0.16, 0.12, 0.08), 64.0)
	draw_polyline(river_points, Color(0.32, 0.24, 0.16), 56.0)
	# 2. 강 수면 기저부 (청록빛 물)
	draw_polyline(river_points, Color(0.08, 0.26, 0.32), 44.0)
	# 3. 얕은 여울 반사광
	draw_polyline(river_points, Color(0.14, 0.46, 0.52, 0.8), 28.0)
	# 4. 실시간으로 굽이쳐 흐르는 물결 애니메이션 (Wave Rapids)
	for i in range(river_points.size() - 1):
		var p1 = river_points[i]
		var p2 = river_points[i + 1]
		var flow_offset = sin(wave_time * 3.5 + i * 1.6) * 8.0
		var flow_p1 = p1.lerp(p2, 0.2) + Vector2(flow_offset, flow_offset * 0.5)
		var flow_p2 = p1.lerp(p2, 0.8) + Vector2(flow_offset, flow_offset * 0.5)
		draw_line(flow_p1, flow_p2, Color(0.70, 0.95, 1.0, 0.6), 3.5)
		# 물방울 포말
		draw_circle(flow_p2, 3.0, Color(1.0, 1.0, 1.0, 0.7))

func _draw_elevation_hills() -> void:
	for hill in hills:
		var pos: Vector2 = hill["pos"]
		var r: float = hill["r"]
		var h_height: float = 46.0 # 수직 단차 높이
		
		# 1. 지면 남동쪽 거대 입체 그림자
		draw_circle(pos + Vector2(26, 36), r * 1.08, Color(0.04, 0.08, 0.04, 0.45))
		
		# 2. 기저부 사면 (텍스처 정글 토양)
		var base_pts = _get_ellipse_points(pos, r, r, 32)
		_draw_textured_poly(base_pts, tex_jungle_mud, 320.0, Color(0.85, 0.88, 0.80))
		
		# 3. 남쪽 깎아지른 수직 단차 암벽 (South Cliff Escarpment with Real Rock Strata)
		var cliff_quad = PackedVector2Array([
			Vector2(pos.x - r * 0.85, pos.y),
			Vector2(pos.x + r * 0.85, pos.y),
			Vector2(pos.x + r * 0.85, pos.y - h_height),
			Vector2(pos.x - r * 0.85, pos.y - h_height)
		])
		_draw_textured_poly(cliff_quad, tex_rock_cliff, 180.0, Color(0.88, 0.84, 0.78))
		# 암벽 단층 라인 & 깊은 그림자
		draw_line(Vector2(pos.x - r * 0.85, pos.y - h_height * 0.5), Vector2(pos.x + r * 0.85, pos.y - h_height * 0.5), Color(0.24, 0.20, 0.15, 0.8), 2.5)
		draw_line(Vector2(pos.x - r * 0.85, pos.y), Vector2(pos.x + r * 0.85, pos.y), Color(0.08, 0.06, 0.04, 0.9), 3.5)
		
		# 4. 공중에 솟아오른 고지 정상 평지 (Elevated Summit Mesa with Lush Jungle Soil)
		var top_pos = pos + Vector2(0, -h_height)
		var top_pts = _get_ellipse_points(top_pos, r * 0.85, r * 0.85, 32)
		_draw_textured_poly(top_pts, tex_jungle_mud, 260.0, Color(1.05, 1.15, 0.98))
		# 정상부 2단계 능선
		var top_ridge = _get_ellipse_points(top_pos + Vector2(-r * 0.1, -r * 0.1), r * 0.5, r * 0.5, 24)
		_draw_textured_poly(top_ridge, tex_jungle_mud, 200.0, Color(1.15, 1.25, 1.05))
		# 북서쪽 햇빛 강렬한 능선 하이라이트 림
		draw_arc(top_pos, r * 0.85, PI * 0.8, PI * 1.8, 24, Color(0.85, 0.95, 0.75, 0.9), 3.5)
		draw_arc(top_pos + Vector2(-r * 0.1, -r * 0.1), r * 0.5, PI * 0.8, PI * 1.8, 20, Color(0.95, 1.0, 0.85, 0.8), 2.5)

func _draw_bloody_nose_ridge() -> void:
	# =========================================================================
	# ⛰️ 북부 움루브로골 산악 암벽 (3D Bloody Nose Ridge Limestone Mountain)
	# =========================================================================
	var ridge_base = PackedVector2Array([
		island_center + Vector2(-540, -740),
		island_center + Vector2(-240, -1040),
		island_center + Vector2(260, -1000),
		island_center + Vector2(540, -740),
		island_center + Vector2(200, -620),
		island_center + Vector2(-280, -640)
	])
	
	var summit_offset = Vector2(0, -90.0) # 수직 90px 고지대 솟구침
	var ridge_summit = PackedVector2Array()
	for pt in ridge_base:
		ridge_summit.append(pt + summit_offset)
		
	# 1. 산악 남동쪽 지면 거대 투영 그림자
	var mountain_shadow = PackedVector2Array()
	for pt in ridge_base:
		mountain_shadow.append(pt + Vector2(45, 60))
	draw_colored_polygon(mountain_shadow, Color(0.04, 0.08, 0.04, 0.55))
	
	# 2. 깎아지른 수직 석회암 절벽면 (Vertical Limestone Cliff Face with Real Rock Texture)
	var cliff_pts = PackedVector2Array([
		ridge_base[4], # 남동쪽 기저부
		ridge_base[5], # 남서쪽 기저부
		ridge_base[0], # 서쪽 기저부
		ridge_summit[0], # 서쪽 능선 정상
		ridge_summit[5], # 남서쪽 능선 정상
		ridge_summit[4], # 남동쪽 능선 정상
		ridge_summit[3], # 동쪽 능선 정상
		ridge_base[3]  # 동쪽 기저부
	])
	_draw_textured_poly(cliff_pts, tex_rock_cliff, 220.0, Color(0.92, 0.88, 0.84))
	
	# 수직 암석 층리(Strata) 및 암벽 절벽 단면 디테일
	for s_step in range(1, 5):
		var factor = float(s_step) / 5.0
		var layer_pts = PackedVector2Array()
		for pt in [ridge_base[0], ridge_base[5], ridge_base[4], ridge_base[3]]:
			layer_pts.append(pt + summit_offset * factor)
		draw_polyline(layer_pts, Color(0.28, 0.24, 0.18, 0.85), 3.0)
		
	# 수직 크랙 및 흘러내린 바위 균열선
	for i in range(-4, 5):
		var cx = island_center.x + float(i) * 110.0
		var c_bot = Vector2(cx, island_center.y - 650.0)
		var c_top = c_bot + summit_offset
		draw_line(c_bot, c_top, Color(0.10, 0.08, 0.06, 0.8), 2.5)
		# 덩굴 및 이끼
		draw_line(c_top, c_top + Vector2(0, 35.0), Color(0.18, 0.28, 0.12, 0.7), 3.0)
	
	# 3. 3D 산악 정상 능선 고원 평지 (Summit Plateau with Mud & Moss Texture)
	_draw_textured_poly(ridge_summit, tex_jungle_mud, 240.0, Color(1.05, 1.15, 0.95))
	# 북서쪽 햇빛 강렬한 능선 암석 림 하이라이트
	draw_polyline(ridge_summit, Color(0.85, 0.92, 0.75, 0.9), 4.0)

func _draw_limestone_caves() -> void:
	for c_pos in caves:
		# 수직 절벽면에 파고든 3D 동굴 요새 입구
		# 1. 지면 그림자
		draw_circle(c_pos + Vector2(8, 12), 24.0, Color(0.04, 0.06, 0.04, 0.6))
		# 2. 깎아낸 석회암 암석 아치 포털
		draw_circle(c_pos, 24.0, Color(0.42, 0.38, 0.32))
		draw_circle(c_pos + Vector2(-3, -4), 22.0, Color(0.55, 0.50, 0.44)) # 상부 돌출 암석
		# 3. 칠흑 같은 3D 석굴 내부 (Deep Cave Tunnel)
		draw_rect(Rect2(c_pos.x - 16, c_pos.y - 14, 32, 28), Color(0.02, 0.02, 0.02))
		draw_circle(c_pos, 13.0, Color(0.0, 0.0, 0.0))
		# 4. 3D 돌출 목재 보강 기둥 (Timber Shoring Frame)
		# 좌우 지지대
		draw_rect(Rect2(c_pos.x - 16, c_pos.y - 18, 5, 34), Color(0.32, 0.20, 0.10))
		draw_rect(Rect2(c_pos.x + 11, c_pos.y - 18, 5, 34), Color(0.32, 0.20, 0.10))
		# 상부 가로보 (Lintel beam)
		draw_rect(Rect2(c_pos.x - 18, c_pos.y - 18, 36, 6), Color(0.40, 0.26, 0.14))
		draw_line(Vector2(c_pos.x - 18, c_pos.y - 18), Vector2(c_pos.x + 18, c_pos.y - 18), Color(0.60, 0.42, 0.25), 1.5)

func _draw_trenches() -> void:
	for trench in trenches:
		if trench.size() < 2:
			continue
		# 1. 3D 깊이 굴착된 참호 구덩이 (어두운 토양)
		draw_polyline(trench, Color(0.12, 0.09, 0.06), 18.0)
		# 2. 바닥 통나무 발판 (Duckboards)
		draw_polyline(trench, Color(0.32, 0.24, 0.16), 8.0)
		# 3. 참호 전면 3D 모래주머니 방벽 (Sandbag parapets with elevation)
		for i in range(trench.size()):
			var p = trench[i]
			draw_circle(p + Vector2(-6, -8), 5.5, Color(0.75, 0.70, 0.55))
			draw_circle(p + Vector2(6, -8), 5.5, Color(0.70, 0.65, 0.50))
			draw_circle(p + Vector2(-6, -5), 4.5, Color(0.55, 0.50, 0.38)) # 모래주머니 음영

func _draw_flak_pits() -> void:
	for f_pos in flak_positions:
		# 1. 3D 원형 모래주머니/토사 방호벽 (Revetment with Height)
		draw_circle(f_pos + Vector2(10, 14), 26.0, Color(0.04, 0.06, 0.04, 0.5)) # 지면 그림자
		draw_circle(f_pos, 25.0, Color(0.66, 0.60, 0.48)) # 모래주머니 외벽
		draw_circle(f_pos + Vector2(-2, -3), 23.0, Color(0.78, 0.72, 0.58)) # 상부 햇빛 하이라이트
		draw_circle(f_pos, 18.0, Color(0.14, 0.12, 0.10)) # 포좌 내부 깊은 구덩이
		# 2. 강철 포가 회전 베이스
		draw_circle(f_pos, 7.5, Color(0.32, 0.34, 0.36))
		# 3. 96식 25mm 쌍열 대공포신 (공중을 향해 솟아오름)
		draw_line(f_pos + Vector2(-3, 2), f_pos + Vector2(-3, -24), Color(0.12, 0.13, 0.15), 3.2)
		draw_line(f_pos + Vector2(3, 2), f_pos + Vector2(3, -24), Color(0.12, 0.13, 0.15), 3.2)
		# 소염기
		draw_line(f_pos + Vector2(-5, -24), f_pos + Vector2(-1, -24), Color(0.08, 0.08, 0.09), 2.5)
		draw_line(f_pos + Vector2(1, -24), f_pos + Vector2(5, -24), Color(0.08, 0.08, 0.09), 2.5)

func _draw_jungle_trees(wave_time: float) -> void:
	# =========================================================================
	# 1단계: 모든 수목의 남동쪽 지면 사선 장대 그림자 (Pass 1: Canopy Projected Shadows)
	# =========================================================================
	for t in jungle_trees:
		var root: Vector2 = t["pos"]
		var h: float = t.get("height", 55.0)
		var r: float = t["r"]
		var s_vec: Vector2 = t.get("shadow_offset", Vector2(30.0, 42.0))
		var shadow_pos = root + s_vec
		var t_type: int = t["type"]
		
		# 나무 줄기 그림자 선
		draw_line(root, shadow_pos, Color(0.01, 0.03, 0.01, 0.35), 4.0)
		# 공중 수관이 지면에 드리우는 실제 수관 텍스처 투영 그림자
		var shadow_tex = tex_tree_palm if t_type == 0 else tex_tree_rainforest
		var s_size = r * 2.8
		var s_rect = Rect2(shadow_pos.x - s_size * 0.5, shadow_pos.y - s_size * 0.45, s_size, s_size * 0.9)
		if shadow_tex:
			draw_texture_rect(shadow_tex, s_rect, false, Color(0.0, 0.0, 0.0, 0.42))
		else:
			draw_circle(shadow_pos, r * 1.15, Color(0.02, 0.05, 0.02, 0.38))
		
	# =========================================================================
	# 2단계: 3D 수직 기둥 & 포토리얼리스틱 수관 (Pass 2: 3D Upright Trees with Y-Sorting)
	# =========================================================================
	for i in range(jungle_trees.size()):
		var t = jungle_trees[i]
		var root: Vector2 = t["pos"]
		var r: float = t["r"]
		var t_type: int = t["type"]
		var base_col: Color = t["col"]
		var h: float = t.get("height", 55.0)
		var curve: float = t.get("trunk_curve", 0.0)
		
		# 바람에 반응하는 공중 상부 흔들림
		var sway = sin(wave_time * 2.2 + float(i) * 0.8) * (h * 0.08)
		var canopy_pos = root + Vector2(curve + sway, -h)
		
		# A. 지면 뿌리 안착부 (Tree Base Flairs)
		draw_circle(root, r * 0.28, Color(0.24, 0.16, 0.10))
		draw_line(root, root + Vector2(-6, 4), Color(0.22, 0.14, 0.08), 3.0)
		draw_line(root, root + Vector2(6, 4), Color(0.22, 0.14, 0.08), 3.0)
		
		# B. 우뚝 솟은 3D 수직 원통형 나무 기둥 (Vertical Shaded Trunk)
		# 음영 측 (우측 어두운 바크)
		draw_line(root + Vector2(1.5, 0), canopy_pos + Vector2(1.0, 0), Color(0.18, 0.12, 0.08), 5.5)
		# 햇빛 측 (좌측 밝은 갈색 바크)
		draw_line(root - Vector2(1.5, 0), canopy_pos - Vector2(1.0, 0), Color(0.44, 0.34, 0.22), 4.5)
		# 중심 코어
		draw_line(root, canopy_pos, Color(0.32, 0.24, 0.15), 5.0)
		
		# C. 공중 높이 솟아있는 포토리얼리스틱 3D RTS 수관 (Elevated Photorealistic Canopy)
		if t_type == 0:
			# 🌴 펠렐리우 로열 야자수 (Photorealistic Palm Canopy)
			if tex_tree_palm:
				var palm_size = r * 3.2
				var palm_rect = Rect2(canopy_pos.x - palm_size * 0.5, canopy_pos.y - palm_size * 0.5, palm_size, palm_size)
				draw_texture_rect(tex_tree_palm, palm_rect, false, base_col.lightened(0.2))
			else:
				for leaf_idx in range(8):
					var angle = leaf_idx * (TAU / 8.0) + (sway * 0.04)
					var leaf_length = r * 1.35
					var leaf_end = canopy_pos + Vector2.RIGHT.rotated(angle) * leaf_length
					draw_line(canopy_pos, leaf_end, base_col.lightened(0.25), 3.8)
		elif t_type == 1:
			# 🌳 빽빽한 열대우림 벵골보리수 (Volumetric Banyan Foliage)
			if tex_tree_rainforest:
				var banyan_size = r * 2.8
				var banyan_rect = Rect2(canopy_pos.x - banyan_size * 0.5, canopy_pos.y - banyan_size * 0.5, banyan_size, banyan_size)
				draw_texture_rect(tex_tree_rainforest, banyan_rect, false, base_col)
			else:
				draw_circle(canopy_pos, r * 0.95, base_col)
		else:
			# 🌲 고대 거목 (Ancient Giant Tree)
			if tex_tree_rainforest:
				var giant_size = r * 3.5
				var giant_rect = Rect2(canopy_pos.x - giant_size * 0.5, canopy_pos.y - giant_size * 0.5, giant_size, giant_size)
				draw_texture_rect(tex_tree_rainforest, giant_rect, false, base_col.darkened(0.12))
			else:
				draw_circle(canopy_pos, r * 1.2, base_col.darkened(0.45))

func _draw_barbed_wires() -> void:
	for wire in barbed_wires:
		var p1: Vector2 = wire["p1"]
		var p2: Vector2 = wire["p2"]
		# 그림자
		draw_line(p1 + Vector2(3, 4), p2 + Vector2(3, 4), Color(0.04, 0.06, 0.04, 0.35), 3.0)
		# 메인 가시철선 케이블
		draw_line(p1, p2, Color(0.28, 0.30, 0.32), 2.2)
		draw_line(p1, p2, Color(0.48, 0.50, 0.52), 1.2)
		
		# X자형 목재 지지대 & 철조망 나선 코일
		var count = int(p1.distance_to(p2) / 28.0)
		for i in range(count + 1):
			var t = float(i) / maxf(1.0, float(count))
			var post_pos = p1.lerp(p2, t)
			# X자 지지대 (Crossed wooden pickets)
			draw_line(post_pos + Vector2(-4, -6), post_pos + Vector2(4, 6), Color(0.32, 0.22, 0.12), 2.5)
			draw_line(post_pos + Vector2(-4, 6), post_pos + Vector2(4, -6), Color(0.38, 0.26, 0.15), 2.5)
			# 가시 코일 링 (Razor coil loop)
			draw_arc(post_pos, 7.0, 0, TAU, 12, Color(0.45, 0.48, 0.52, 0.8), 1.6)

func _draw_ammo_caches() -> void:
	for cache in ammo_caches:
		var pos: Vector2 = cache["pos"]
		var rot: float = cache["rot"]
		var type: int = cache["type"]
		
		# 지면 그림자
		draw_circle(pos + Vector2(4, 5), 10.0, Color(0.04, 0.06, 0.04, 0.4))
		
		if type == 0:
			# 📦 대형 목재 탄약 상자 (Wooden Ammo Crate)
			var w = 22.0
			var h = 14.0
			var rect = Rect2(-w * 0.5, -h * 0.5, w, h)
			draw_set_transform(pos, rot, Vector2.ONE)
			draw_rect(rect, Color(0.40, 0.28, 0.16))
			draw_rect(rect, Color(0.18, 0.12, 0.08), false, 2.0)
			# 보강 띠 철물 & 스텐실 라인
			draw_line(Vector2(-w * 0.3, -h * 0.5), Vector2(-w * 0.3, h * 0.5), Color(0.2, 0.2, 0.22), 2.0)
			draw_line(Vector2(w * 0.3, -h * 0.5), Vector2(w * 0.3, h * 0.5), Color(0.2, 0.2, 0.22), 2.0)
			draw_line(Vector2(-w * 0.2, 0), Vector2(w * 0.2, 0), Color(0.9, 0.85, 0.6, 0.8), 1.5)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif type == 1:
			# 🧰 녹색 금속 탄약캔 (Olive Metal Ammo Can)
			var w = 15.0
			var h = 9.0
			var rect = Rect2(-w * 0.5, -h * 0.5, w, h)
			draw_set_transform(pos, rot, Vector2.ONE)
			draw_rect(rect, Color(0.28, 0.34, 0.20))
			draw_rect(rect, Color(0.12, 0.16, 0.08), false, 1.8)
			draw_line(Vector2(-w * 0.3, -1), Vector2(w * 0.3, -1), Color(0.85, 0.75, 0.2, 0.7), 1.2) # 황색 규격 마킹
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			# 🛢️ 55갤런 철제 연료 드럼통 (Oil Drum)
			draw_circle(pos, 8.0, Color(0.22, 0.25, 0.28))
			draw_circle(pos, 7.0, Color(0.32, 0.36, 0.40))
			draw_arc(pos, 5.0, 0, TAU, 16, Color(0.18, 0.20, 0.22), 2.0)
			draw_circle(pos + Vector2(2.5, -2.5), 2.0, Color(0.12, 0.12, 0.14)) # 주유구 캡

func _draw_tread_marks_and_craters() -> void:
	for tm in tread_marks:
		var dir = Vector2.RIGHT.rotated(tm["rot"])
		var normal = Vector2(-dir.y, dir.x) * (tm["w"] * 0.5)
		draw_line(tm["pos"] - normal, tm["pos"] + normal, Color(0.1, 0.08, 0.06, tm["alpha"] * 0.6), 4.0)
		
	for cr in craters:
		draw_circle(cr["pos"], cr["r"], Color(0.08, 0.07, 0.06, cr["alpha"] * 0.85))
		draw_circle(cr["pos"], cr["r"] * 0.55, Color(0.04, 0.03, 0.02, cr["alpha"] * 0.95))
		draw_arc(cr["pos"], cr["r"], 0, TAU, 16, Color(0.18, 0.14, 0.1, cr["alpha"] * 0.7), 2.0)

func _draw_ejected_casings() -> void:
	for c in ejected_casings:
		var rot: float = c["rot"]
		var l: float = c["l"]
		var w: float = c["w"]
		var col: Color = c["col"]
		var alpha: float = c["alpha"]
		var casing_col = Color(col.r, col.g, col.b, alpha)
		var p = c["pos"]
		
		# 남동쪽 미세 그림자
		var p_dir = Vector2.RIGHT.rotated(rot) * (l * 0.5)
		draw_line(p + Vector2(1.5, 2.0) - p_dir, p + Vector2(1.5, 2.0) + p_dir, Color(0.02, 0.03, 0.02, alpha * 0.5), w)
		# 황동 탄피 본체
		draw_line(p - p_dir, p + p_dir, casing_col, w)
		# 탄피 림 (후면 뇌관 테두리)
		draw_circle(p - p_dir, w * 0.6, casing_col.darkened(0.4))

func _draw_vehicle_hulks() -> void:
	var f_time = Time.get_ticks_msec() * 0.015
	for h in vehicle_hulks:
		var pos: Vector2 = h["pos"]
		var rot: float = h["rot"]
		var p_dir = Vector2.RIGHT.rotated(rot)
		
		# 1. 지면 화재 그을림 (Scorched earth burn decal)
		draw_circle(pos + Vector2(5, 7), 28.0, Color(0.04, 0.03, 0.03, 0.85))
		
		# 2. 검게 탄 전차 차체 잔해 (Charred Tank Hull)
		draw_set_transform(pos, rot, Vector2.ONE)
		draw_rect(Rect2(-24, -15, 48, 30), Color(0.12, 0.11, 0.10))
		draw_rect(Rect2(-24, -15, 48, 30), Color(0.05, 0.05, 0.05), false, 2.5)
		# 뒤틀린 포탑
		draw_circle(Vector2(-3, 2), 11.0, Color(0.10, 0.09, 0.08))
		# 부러진 57mm 주포신
		draw_line(Vector2(6, 2), Vector2(19, -3), Color(0.08, 0.08, 0.08), 3.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		
		# 3. 맹렬하게 타오르는 붉은 화염 & 탄약 스파크 (Flickering Ruin Flames)
		for fi in range(3):
			var f_offset = Vector2(sin(f_time + fi * 2.0) * 8.0, cos(f_time * 1.5 + fi) * 6.0)
			var fire_pos = pos + f_offset
			var fire_r = 9.0 + sin(f_time * 2.0 + fi) * 4.0
			draw_circle(fire_pos, fire_r, Color(2.6, 0.8, 0.1, 0.85))
			draw_circle(fire_pos - Vector2(0, 3), fire_r * 0.55, Color(3.5, 2.2, 1.0, 0.95))
			# 튀는 탄약 불꽃
			var spark_pos = pos + Vector2(sin(f_time * 4.0 + fi) * 14.0, -12.0 - sin(f_time * 3.0 + fi) * 8.0)
			draw_circle(spark_pos, 2.2, Color(3.8, 2.5, 0.8))

func _draw_dirt_shrapnel() -> void:
	for sh in dirt_shrapnel:
		var p: float = sh["life"] / sh["max_life"]
		var col: Color = sh["col"]
		draw_circle(sh["pos"], sh["r"] * (0.5 + p * 0.5), Color(col.r, col.g, col.b, p))

func _draw_ambient_dust() -> void:
	for dp in ambient_dust_particles:
		draw_circle(dp["pos"], dp["r"], Color(0.88, 0.82, 0.68, dp["alpha"]))

func _draw_tactical_popups() -> void:
	var font = ThemeDB.fallback_font
	var font_size = 14
	for pop in tactical_popups:
		var text: String = pop["text"]
		var col: Color = pop["col"]
		var alpha: float = clampf(1.0 - (pop["elapsed"] / pop["dur"]), 0.0, 1.0)
		var txt_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var draw_pos = pop["pos"] - txt_size * 0.5 + Vector2(0, font.get_ascent(font_size))
		
		# 묵직한 군사 스텐실 드롭 섀도우 (Military Stencil Drop Shadow)
		draw_string(font, draw_pos + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.0, 0.0, 0.0, alpha * 0.95))
		draw_string(font, draw_pos + Vector2(-1.0, 1.0), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.0, 0.0, 0.0, alpha * 0.75))
		# 전면 발광 텍스트
		draw_string(font, draw_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(col.r, col.g, col.b, alpha))

