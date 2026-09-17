extends Node2D
class_name Main

@export var enemy_scene: PackedScene = preload("res://scenes/entities/enemies/EnemyBase.tscn")
@export var proj_tscn: PackedScene = preload("res://scenes/weapons/Projectile.tscn")
@export var cannon_tscn: PackedScene = preload("res://scenes/weapons/CannonShell.tscn")
@export var kamikaze_scene: PackedScene = preload("res://scenes/entities/enemies/KamikazePlane.tscn")
@export var outpost_scene: PackedScene = preload("res://scenes/entities/enemies/EnemyOutpost.tscn")

@onready var snake_head: Node2D = $SnakeHead
@onready var enemies_container: Node2D = $Enemies
@onready var projectiles_container: Node2D = $Projectiles
@onready var drops_container: Node2D = $Drops
@onready var outposts_container: Node2D = $Outposts

# 웨이브 타이머
var enemy_spawn_timer: float = 0.0
var kamikaze_timer: float = 8.0 # 8초 후 첫 가미카제 공습

# ✈️ 연합군 250대 대편대 (폭격기 100 + 전투기 100 + 전폭기 50) 1분 주기 공습
var airstrike_interval: float = 60.0 # 1분에 1번씩 무차별 융단폭격!
var airstrike_countdown: float = 60.0
var is_airstrike_active: bool = false
var airstrike_run_timer: float = 0.0
var fleet_fly_y: float = -2200.0

# 포위 섬멸 마법진 시각 효과
var current_seal_polygon: PackedVector2Array = PackedVector2Array()
var seal_alpha: float = 0.0

# 펠렐리우 섬 크기
var island_center: Vector2 = Vector2(1800, 1400)
var island_radius_x: float = 1600.0
var island_radius_y: float = 1200.0

# 🌊 바다 확장 경계 (어느 정도 바다로 헤엄쳐 나갈 수 있음!)
var ocean_limit_x: float = 2300.0
var ocean_limit_y: float = 1800.0

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
	# 1. 1분 주기 연합군 250대 대편대 공습 카운트다운
	if not is_airstrike_active:
		airstrike_countdown -= delta
		if airstrike_countdown <= 0.0:
			_start_allied_grand_airstrike()
	else:
		_process_allied_grand_airstrike(delta)
		
	# 2. 지상군 스폰 루프
	enemy_spawn_timer -= delta
	if enemy_spawn_timer <= 0.0:
		enemy_spawn_timer = 1.2
		_spawn_enemy_wave()
	
	# 3. 🚨 가미카제 자폭 전투기 공습 스폰 루프
	kamikaze_timer -= delta
	if kamikaze_timer <= 0.0:
		kamikaze_timer = randf_range(7.0, 12.0)
		_spawn_kamikaze_raid()
	
	# 4. 플레이어 바다 이탈 한계선 제약 (너무 멀리 심해로 나가면 밀어냄)
	_constrain_snake_to_ocean_limit()
	
	# 마법진 페이드아웃
	if seal_alpha > 0.0:
		seal_alpha = maxf(0.0, seal_alpha - delta * 2.0)
	
	queue_redraw()

func _constrain_snake_to_ocean_limit() -> void:
	if not is_instance_valid(snake_head):
		return
	var offset = snake_head.global_position - island_center
	var normalized_dist_sq = (offset.x * offset.x) / (ocean_limit_x * ocean_limit_x) + (offset.y * offset.y) / (ocean_limit_y * ocean_limit_y)
	if normalized_dist_sq > 1.0:
		# 바다 너무 깊은 곳으로 나가지 못하게 바깥 경계에서 부드럽게 복귀
		var angle = offset.angle()
		snake_head.global_position = island_center + Vector2(cos(angle) * ocean_limit_x, sin(angle) * ocean_limit_y)

func _start_allied_grand_airstrike() -> void:
	is_airstrike_active = true
	airstrike_run_timer = 0.0
	fleet_fly_y = -1800.0

func _process_allied_grand_airstrike(delta: float) -> void:
	airstrike_run_timer += delta
	fleet_fly_y += 1800.0 * delta # 250대 편대 초고속 상공 통과
	
	# 전장 전역에 무차별 융단폭격 (1초에 10~15발씩 고폭탄 낙하!)
	for i in range(3):
		var bomb_pos = island_center + Vector2(randf_range(-1400, 1400), randf_range(-950, 950))
		spawn_cannon_shell(bomb_pos, Vector2.ZERO)
		
	# 적들 대량 폭사
	for enemy in enemies_container.get_children():
		if is_instance_valid(enemy) and randf() < 0.35:
			if enemy.has_method("take_damage"):
				enemy.take_damage(999.0)
				
	# 공습 6초 지속 후 종료 ➔ 다시 60초 카운트다운 시작!
	if airstrike_run_timer >= 6.5:
		is_airstrike_active = false
		airstrike_countdown = airstrike_interval

func _spawn_enemy_wave() -> void:
	if not is_instance_valid(snake_head):
		return
	
	var spawn_count = randi_range(3, 6)
	for i in range(spawn_count):
		var angle = randf() * TAU
		var dist = randf_range(650.0, 850.0)
		var spawn_pos = snake_head.global_position + Vector2.RIGHT.rotated(angle) * dist
		
		# 섬 및 주변 얕은 바다까지 스폰 허용
		var dx = (spawn_pos.x - island_center.x) / (island_radius_x + 200.0)
		var dy = (spawn_pos.y - island_center.y) / (island_radius_y + 200.0)
		if (dx * dx + dy * dy) <= 1.0:
			var enemy = enemy_scene.instantiate()
			enemy.global_position = spawn_pos
			enemies_container.add_child(enemy)

func _spawn_kamikaze_raid() -> void:
	if not is_instance_valid(snake_head) or not kamikaze_scene:
		return
		
	var count = 1 if GameManager.countdown_time > 600.0 else randi_range(1, 2)
	for i in range(count):
		var angle = randf_range(-PI * 0.8, -PI * 0.2)
		var dist = randf_range(800.0, 1000.0)
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

func _on_loop_completed(polygon: PackedVector2Array, _enemies: Array) -> void:
	current_seal_polygon = polygon
	seal_alpha = 1.0
	queue_redraw()

func _draw() -> void:
	# 1. 🌊 바깥 태평양 심해 바다 (짙은 남색)
	draw_rect(Rect2(-1200, -1200, 6000, 5200), Color(0.06, 0.12, 0.22))
	
	# 2. 🪸 얕은 바다 / 산호초 여울 (뱀이 자유롭게 나갈 수 있는 에메랄드 바다 구역!)
	draw_colored_polygon(_get_ellipse_points(island_center, ocean_limit_x, ocean_limit_y, 48), Color(0.12, 0.32, 0.44, 0.75))
	
	# 3. 🏖️ 펠렐리우 섬 해안선 백사장 (모래사장 링)
	draw_colored_polygon(_get_ellipse_points(island_center, island_radius_x + 50.0, island_radius_y + 50.0, 48), Color(0.88, 0.82, 0.62))
	
	# 4. 🌴 울창한 열대 정글 숲 (짙은 국방 녹색)
	draw_colored_polygon(_get_ellipse_points(island_center, island_radius_x, island_radius_y, 48), Color(0.18, 0.32, 0.2))
	
	# 5. 🛩️ 펠렐리우 중앙 비행장 (2개의 교차 아스팔트 활주로)
	var runway_col = Color(0.25, 0.26, 0.28)
	draw_line(island_center + Vector2(-500, -350), island_center + Vector2(500, 350), runway_col, 50.0)
	draw_line(island_center + Vector2(-500, -350), island_center + Vector2(500, 350), Color.WHITE, 2.0)
	draw_line(island_center + Vector2(-450, 300), island_center + Vector2(450, -300), runway_col, 40.0)
	draw_line(island_center + Vector2(-450, 300), island_center + Vector2(450, -300), Color.WHITE, 2.0)
	draw_rect(Rect2(island_center.x + 220, island_center.y - 120, 100, 70), Color(0.35, 0.36, 0.38))
	draw_rect(Rect2(island_center.x + 220, island_center.y - 120, 100, 70), Color(0.1, 0.1, 0.1), false, 2.0)
	
	# 6. ⛰️ 북부 움루브로골 산악 지대 (Bloody Nose Ridge 암석)
	var ridge_pts = PackedVector2Array([
		island_center + Vector2(-400, -750),
		island_center + Vector2(-150, -950),
		island_center + Vector2(250, -920),
		island_center + Vector2(450, -720),
		island_center + Vector2(150, -620),
		island_center + Vector2(-200, -640)
	])
	draw_colored_polygon(ridge_pts, Color(0.38, 0.35, 0.32))
	draw_polyline(ridge_pts, Color(0.2, 0.18, 0.16), 3.0)
	
	# 7. 포위 섬멸 마법진
	if seal_alpha > 0.0 and current_seal_polygon.size() > 2:
		var fill_color = Color(1.0, 0.85, 0.2, 0.25 * seal_alpha)
		var stroke_color = Color(1.0, 0.95, 0.4, 0.9 * seal_alpha)
		draw_colored_polygon(current_seal_polygon, fill_color)
		draw_polyline(current_seal_polygon, stroke_color, 4.0)
	
	# 8. ✈️ 연합군 250대 대편대 (폭격기 100 + 전투기 100 + 전폭기 50) 무차별 융단폭격 그림자
	if is_airstrike_active:
		var cam_x = snake_head.global_position.x if is_instance_valid(snake_head) else island_center.x
		var fleet_y = island_center.y + fleet_fly_y
		
		# 100대 B-29 중폭격기 (대형)
		for col_idx in range(-6, 7):
			for row_idx in range(4):
				var pos = Vector2(cam_x + col_idx * 180.0 + (row_idx % 2) * 90.0, fleet_y - row_idx * 240.0)
				_draw_bomber_shadow(pos)
				
		# 50대 F4U 콜세어 전폭기 (중형 로켓 장착기)
		for col_idx in range(-5, 6):
			for row_idx in range(2):
				var pos = Vector2(cam_x + col_idx * 160.0, fleet_y - 1000.0 - row_idx * 180.0)
				_draw_fighter_bomber_shadow(pos)
				
		# 100대 P-51 머스탱 호위 전투기 (소형)
		for col_idx in range(-8, 9):
			var pos = Vector2(cam_x + col_idx * 120.0, fleet_y - 1400.0)
			_draw_fighter_shadow(pos)

func _draw_bomber_shadow(pos: Vector2) -> void:
	var shadow_col = Color(0.0, 0.0, 0.0, 0.5)
	draw_rect(Rect2(pos.x - 7, pos.y - 32, 14, 64), shadow_col)
	draw_line(Vector2(pos.x - 60, pos.y - 6), Vector2(pos.x + 60, pos.y - 6), shadow_col, 11.0)
	draw_line(Vector2(pos.x - 24, pos.y + 26), Vector2(pos.x + 24, pos.y + 26), shadow_col, 7.0)

func _draw_fighter_bomber_shadow(pos: Vector2) -> void:
	var shadow_col = Color(0.0, 0.0, 0.0, 0.45)
	draw_rect(Rect2(pos.x - 5, pos.y - 20, 10, 40), shadow_col)
	# 콜세어 역갈매기익 실루엣
	draw_line(Vector2(pos.x - 35, pos.y - 2), Vector2(pos.x + 35, pos.y - 2), shadow_col, 7.0)

func _draw_fighter_shadow(pos: Vector2) -> void:
	var shadow_col = Color(0.0, 0.0, 0.0, 0.35)
	draw_rect(Rect2(pos.x - 3, pos.y - 15, 6, 30), shadow_col)
	draw_line(Vector2(pos.x - 24, pos.y - 3), Vector2(pos.x + 24, pos.y - 3), shadow_col, 5.0)

func _get_ellipse_points(center: Vector2, rx: float, ry: float, segs: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(segs):
		var a = i * (TAU / segs)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
