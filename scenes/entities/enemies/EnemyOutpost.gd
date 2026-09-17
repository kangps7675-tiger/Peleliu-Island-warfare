extends StaticBody2D
class_name EnemyOutpost

@export var max_hp: float = 180.0
@export var current_hp: float = 180.0
@export var respawn_time: float = 15.0 # 15초 뒤 지하에서 재건축 부활!
@export var soldier_scene: PackedScene = preload("res://scenes/entities/enemies/JapaneseSoldier.tscn")
@export var officer_scene: PackedScene = preload("res://scenes/entities/enemies/JapaneseOfficer.tscn")
@export var gem_scene: PackedScene = preload("res://scenes/entities/drops/Gem.tscn")

var is_destroyed: bool = false
var respawn_timer: float = 0.0
var spawn_soldier_timer: float = 2.0
var flash_timer: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	collision_layer = 4 # Enemy/Obstacle layer
	collision_mask = 3  # Player Head & Body
	add_to_group("outposts")
	add_to_group("enemies")
	add_to_group("heavy_armor")
	current_hp = max_hp

var smoke_timer: float = 0.0

func _process(delta: float) -> void:
	if is_destroyed:
		respawn_timer -= delta
		smoke_timer -= delta
		if smoke_timer <= 0.0:
			smoke_timer = 0.12
			var main_scene = get_tree().current_scene
			if main_scene and main_scene.has_method("add_exhaust_smoke"):
				main_scene.add_exhaust_smoke(global_position + Vector2(randf_range(-20, 20), randf_range(-15, 15)), Vector2(0, -45))
		
		if respawn_timer <= 0.0:
			_respawn()
		queue_redraw()
		return
	
	spawn_soldier_timer -= delta
	if spawn_soldier_timer <= 0.0:
		spawn_soldier_timer = 3.5
		_spawn_infantry_reinforcement()
		
	if flash_timer > 0.0:
		flash_timer -= delta
		if sprite:
			sprite.modulate = Color(2.0, 2.0, 2.0)
	elif sprite and not is_destroyed:
		sprite.modulate = Color.WHITE
	
	queue_redraw()

func _spawn_infantry_reinforcement() -> void:
	# 벙커에서 일본군 보병 혹은 장교 출격
	if randf() < 0.25 and officer_scene:
		var officer = officer_scene.instantiate()
		officer.global_position = global_position + Vector2(randf_range(-25, 25), 45.0)
		get_parent().add_child(officer)
	elif soldier_scene:
		var soldier = soldier_scene.instantiate()
		soldier.global_position = global_position + Vector2(randf_range(-30, 30), 45.0)
		get_parent().add_child(soldier)

func take_damage(amount: float) -> void:
	if is_destroyed:
		return
	current_hp -= amount
	flash_timer = 0.08
	queue_redraw()
	
	if current_hp <= 0.0:
		_destroy()

func _destroy() -> void:
	is_destroyed = true
	respawn_timer = respawn_time
	collision_shape.set_deferred("disabled", true)
	AudioManager.play_sfx("explosion", 2.0)
	
	if sprite:
		sprite.modulate = Color(0.18, 0.16, 0.15, 0.85) # 검게 탄 콘크리트 폐허
	
	var main_scene = get_tree().current_scene
	if main_scene:
		if main_scene.has_method("spawn_heavy_explosion"):
			main_scene.spawn_heavy_explosion(global_position, 130.0)
		if main_scene.has_method("spawn_tactical_popup"):
			main_scene.spawn_tactical_popup(global_position, "💥 BUNKER DESTROYED!", Color(1.0, 0.4, 0.2))
	
	# 대량 보급품 드롭
	if gem_scene:
		for i in range(4):
			var g = gem_scene.instantiate()
			g.global_position = global_position + Vector2(randf_range(-25, 25), randf_range(-25, 25))
			get_parent().call_deferred("add_child", g)
			
	EventBus.enemy_killed.emit(global_position, "OUTPOST")

func _respawn() -> void:
	is_destroyed = false
	current_hp = max_hp
	collision_shape.set_deferred("disabled", false)
	if sprite:
		sprite.modulate = Color.WHITE

func _draw() -> void:
	if is_destroyed:
		# 1. 불타는 폐허 화염 혀 (Flickering Ruin Flames)
		var f_time = Time.get_ticks_msec() * 0.015
		for fi in range(4):
			var fx = -25.0 + fi * 16.0
			var fy = 8.0 + sin(f_time + fi * 1.5) * 4.0
			draw_circle(Vector2(fx, fy), 12.0 + sin(f_time + fi) * 3.0, Color(2.8, 0.9, 0.1, 0.85))
			draw_circle(Vector2(fx, fy - 4), 6.0, Color(3.5, 2.5, 1.0, 0.95))
		
		# 15초 언데드 재건축 진행도 원형 게이지
		var prog = 1.0 - (respawn_timer / respawn_time)
		draw_arc(Vector2.ZERO, 52.0, -PI * 0.5, -PI * 0.5 + TAU * prog, 32, Color(1.0, 0.85, 0.2), 4.0)
	else:
		# 2. 펄럭이는 일본 해군 욱일기 / 깃발 (Waving Rising Sun Flag)
		var flag_base = Vector2(25, -30)
		var flag_pole_top = flag_base + Vector2(0, -38)
		# 깃대 (Flagpole)
		draw_line(flag_base, flag_pole_top, Color(0.18, 0.18, 0.2), 3.0)
		
		# 펄럭이는 깃발 천
		var wave = sin(Time.get_ticks_msec() * 0.008 + global_position.x * 0.05) * 4.0
		var flag_rect = Rect2(flag_pole_top.x, flag_pole_top.y, 28.0 + wave * 0.5, 18.0)
		draw_rect(flag_rect, Color.WHITE)
		# 중앙 붉은 태양원
		var center_sun = flag_rect.position + Vector2(10.0 + wave * 0.2, 9.0)
		draw_circle(center_sun, 5.5, Color(0.85, 0.12, 0.15))
		# 욱일기 16방 방사 광선 빗살
		for ri in range(8):
			var r_angle = ri * (PI / 4.0)
			draw_line(center_sun, center_sun + Vector2.RIGHT.rotated(r_angle) * 11.0, Color(0.85, 0.12, 0.15), 1.5)
			
		# 3. 🎖️ CoH 벙커 요새 뱃지 & 체력바
		var bar_w = 42.0
		var hp_r = clampf(current_hp / max_hp, 0.0, 1.0)
		draw_rect(Rect2(-bar_w * 0.5, -46, bar_w, 4.0), Color(0.1, 0.1, 0.1, 0.85))
		draw_rect(Rect2(-bar_w * 0.5, -46, bar_w * hp_r, 4.0), Color(0.2, 0.85, 0.3))
		draw_rect(Rect2(-bar_w * 0.5, -46, bar_w, 4.0), Color.BLACK, false, 1.0)
