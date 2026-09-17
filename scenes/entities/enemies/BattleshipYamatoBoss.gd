extends CharacterBody2D
class_name BattleshipYamatoBoss

@export var max_hp: float = 3200.0
@export var current_hp: float = 3200.0
@export var gem_scene: PackedScene = preload("res://scenes/entities/drops/Gem.tscn")

var patrol_angle: float = 0.0
var patrol_radius: float = 1950.0
var center_pos: Vector2 = Vector2(1800, 1400)
var salvo_timer: float = 4.0
var target_player: Node2D = null
var flash_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 7
	add_to_group("enemies")
	add_to_group("bosses")
	current_hp = max_hp
	
	var heads = get_tree().get_nodes_in_group("player_head")
	if not heads.is_empty():
		target_player = heads[0]

var muzzle_flash_timer: float = 0.0
var is_sinking: bool = false
var sinking_timer: float = 0.0
const SINKING_DURATION: float = 4.2
var sinking_explosion_timer: float = 0.0

func _physics_process(delta: float) -> void:
	if is_sinking:
		_process_sinking(delta)
		queue_redraw()
		return
		
	# 1. 섬 외곽 바다를 따라 항해
	patrol_angle += 0.08 * delta
	var target_x = center_pos.x + cos(patrol_angle) * patrol_radius
	var target_y = center_pos.y + sin(patrol_angle) * (patrol_radius * 0.75)
	var new_pos = Vector2(target_x, target_y)
	
	var move_dir = (new_pos - global_position).normalized()
	if move_dir.length_squared() > 0.01:
		rotation = lerp_angle(rotation, move_dir.angle(), 4.0 * delta)
	global_position = new_pos
	
	# 2. 460mm 3연장 주포 3문 일제사격
	salvo_timer -= delta
	if salvo_timer <= 0.0:
		salvo_timer = 5.2
		_fire_triple_460mm_salvo()
		
	if muzzle_flash_timer > 0.0:
		muzzle_flash_timer -= delta
		
	if flash_timer > 0.0:
		flash_timer -= delta
		if sprite:
			sprite.modulate = Color(2.5, 2.0, 2.0)
	elif sprite:
		sprite.modulate = Color.WHITE
		
	queue_redraw()

func _fire_triple_460mm_salvo() -> void:
	var main_scene = get_tree().current_scene
	if not main_scene or not is_instance_valid(target_player):
		return
		
	# 🔊 야마토 460mm 굉음 사운드 재생
	AudioManager.play_sfx("yamato", 3.5)
	muzzle_flash_timer = 0.28
	
	var target_center = target_player.global_position
	# 3개 주포탑 위치에서 3발의 거대 포탄 사출
	var turret_offsets = [-70.0, 20.0, 110.0]
	for i in range(3):
		var offset = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40.0, 150.0)
		var aim_pos = target_center + offset
		var fire_dir = (aim_pos - global_position).normalized()
		
		if main_scene.has_method("spawn_cannon_shell"):
			var muzzle = global_position + Vector2.RIGHT.rotated(rotation) * turret_offsets[i] + fire_dir * 80.0
			main_scene.spawn_cannon_shell(muzzle, fire_dir)
			
	var heads = get_tree().get_nodes_in_group("player_head")
	if not heads.is_empty() and heads[0].get("camera_shake_amount") != null:
		heads[0].camera_shake_amount = 20.0

func take_damage(amount: float) -> void:
	if is_sinking:
		return
	current_hp -= amount * 0.55
	flash_timer = 0.08
	if current_hp <= 0.0:
		_start_sinking()

func _start_sinking() -> void:
	is_sinking = true
	sinking_timer = SINKING_DURATION
	collision_layer = 0
	collision_mask = 0
	EventBus.enemy_killed.emit(global_position, "BOSS_YAMATO")
	
	# 침몰 시작 굉음
	AudioManager.play_sfx("heavy_explosion", 4.0)

func _process_sinking(delta: float) -> void:
	sinking_timer -= delta
	var progress = 1.0 - (sinking_timer / SINKING_DURATION)
	
	# 연쇄 유폭 대폭발
	sinking_explosion_timer -= delta
	if sinking_explosion_timer <= 0.0:
		sinking_explosion_timer = 0.35
		AudioManager.play_sfx("explosion", 2.0)
		var main_scene = get_tree().current_scene
		if main_scene and main_scene.has_method("spawn_heavy_explosion"):
			var explode_offset = Vector2.RIGHT.rotated(rotation) * randf_range(-140, 140) + Vector2.UP.rotated(rotation) * randf_range(-25, 25)
			main_scene.spawn_heavy_explosion(global_position + explode_offset, randf_range(120, 180))
			if main_scene.has_method("add_exhaust_smoke"):
				main_scene.add_exhaust_smoke(global_position + explode_offset, Vector2(0, -60))
				
	# 선체 전복 및 해수면 침몰 시각 효과 (기울어지고 어두워지며 잠김)
	rotation += 0.35 * delta
	if sprite:
		var sink_col = Color(0.15, 0.25, 0.4, 1.0).lerp(Color(0.05, 0.1, 0.2, 0.0), progress)
		sprite.modulate = sink_col
		
	if sinking_timer <= 0.0:
		_finish_sinking()

func _finish_sinking() -> void:
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("spawn_heavy_explosion"):
		main_scene.spawn_heavy_explosion(global_position, 280.0)
		
	# 대량 보급품 투하 (8개 탄약 상자)
	if gem_scene:
		for i in range(8):
			var gem = gem_scene.instantiate()
			gem.global_position = global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40.0, 140.0)
			get_parent().call_deferred("add_child", gem)
			
	queue_free()

func _draw() -> void:
	# 1. 전함 항적
	var stern_pos = -Vector2.RIGHT * 180.0
	draw_line(stern_pos, stern_pos - Vector2(80, -25), Color(0.9, 0.95, 1.0, 0.4), 6.0)
	draw_line(stern_pos, stern_pos - Vector2(80, 25), Color(0.9, 0.95, 1.0, 0.4), 6.0)
	
	# 2. 460mm 거포 발사 시 포구 화염 및 수면 충격파 (HDR 글로우)
	if muzzle_flash_timer > 0.0:
		var turret_offsets = [-70.0, 20.0, 110.0]
		for toff in turret_offsets:
			var m_pos = Vector2.RIGHT * toff + Vector2.UP * 45.0
			draw_circle(m_pos, 35.0, Color(3.5, 1.8, 0.4, 0.95))
			draw_circle(m_pos, 20.0, Color(4.0, 3.5, 2.0, 1.0))
			draw_arc(m_pos, 65.0, 0, TAU, 24, Color(2.0, 1.5, 0.8, 0.8), 5.0)
			# 해수면 거대 포말 파도
			draw_arc(m_pos, 90.0, 0, TAU, 32, Color(0.85, 0.95, 1.0, 0.7), 6.0)
			
	# 3. 침몰 중 거대 소용돌이 포말 링
	if is_sinking:
		var s_prog = 1.0 - (sinking_timer / SINKING_DURATION)
		draw_arc(Vector2.ZERO, 150.0 + s_prog * 80.0, 0, TAU, 32, Color(0.6, 0.9, 1.0, 0.6 * (1.0 - s_prog)), 8.0)
