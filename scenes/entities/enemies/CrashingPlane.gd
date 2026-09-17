extends Node2D
class_name CrashingPlane

@export var plane_tex: Texture2D = preload("res://assets/sprites/kamikaze_plane.png")

var velocity: Vector2 = Vector2.ZERO
var spin_speed: float = 12.0
var crash_duration: float = 1.2
var elapsed: float = 0.0
var smoke_timer: float = 0.0
var blast_radius: float = 160.0
var crash_damage_enemies: float = 450.0
var crash_damage_player: float = 30.0

func initialize(start_pos: Vector2, initial_vel: Vector2) -> void:
	global_position = start_pos
	velocity = initial_vel * 0.85
	spin_speed = randf_range(10.0, 18.0) * (1.0 if randf() > 0.5 else -1.0)
	crash_duration = randf_range(0.9, 1.3)
	elapsed = 0.0
	AudioManager.play_sfx("dive_siren", 1.0)

func _process(delta: float) -> void:
	elapsed += delta
	var progress = clampf(elapsed / crash_duration, 0.0, 1.0)
	
	# 중력 가속도 및 전진
	velocity.y += 480.0 * delta
	global_position += velocity * delta
	rotation += spin_speed * delta
	
	# 화염 및 짙은 검은색 연기 배기
	smoke_timer -= delta
	if smoke_timer <= 0.0:
		smoke_timer = 0.04
		var main_scene = get_tree().current_scene
		if main_scene and main_scene.has_method("add_exhaust_smoke"):
			main_scene.add_exhaust_smoke(global_position, -velocity * 0.3)
			
	queue_redraw()
	
	if progress >= 1.0:
		_impact_ground()

func _impact_ground() -> void:
	AudioManager.play_sfx("plane_crash", 4.0)
	var main_scene = get_tree().current_scene
	if main_scene:
		if main_scene.has_method("spawn_heavy_explosion"):
			main_scene.spawn_heavy_explosion(global_position, blast_radius)
		if main_scene.has_method("add_crater_decal"):
			main_scene.add_crater_decal(global_position, 48.0)
			
	# 💥 주변 적 유닛 절멸
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy != self:
			var d = global_position.distance_to(enemy.global_position)
			if d <= blast_radius:
				if enemy.has_method("take_damage"):
					enemy.take_damage(crash_damage_enemies * (1.0 - d / blast_radius * 0.4))
				if enemy is CharacterBody2D:
					var knock = (enemy.global_position - global_position).normalized()
					enemy.velocity += knock * 500.0
					
	# 💥 유저의 뱀도 폭발 반경 안에 있으면 피해를 입음!
	var heads = get_tree().get_nodes_in_group("player_head")
	if not heads.is_empty():
		var head = heads[0]
		var dist_to_player = global_position.distance_to(head.global_position)
		if dist_to_player <= blast_radius:
			if head.has_method("take_damage"):
				head.take_damage(crash_damage_player * (1.0 - dist_to_player / blast_radius * 0.5))
		if head.get("camera_shake_amount") != null:
			head.camera_shake_amount = 16.0
			
	queue_free()

func _draw() -> void:
	# 1. 기체 동체 (불길에 휩싸여 검붉게 그을림)
	if plane_tex:
		draw_texture_rect(plane_tex, Rect2(-35, -35, 70, 70), false, Color(1.2, 0.4, 0.2))
	
	# 2. 날개와 엔진에서 뿜어져 나오는 화염 혀
	var f_time = Time.get_ticks_msec() * 0.02
	draw_circle(Vector2(-15, 0), 16.0 + sin(f_time) * 4.0, Color(2.5, 0.8, 0.1, 0.85))
	draw_circle(Vector2(-15, 0), 8.0, Color(3.5, 2.5, 1.0, 0.95))
	draw_line(Vector2(-10, -12), Vector2(-35, -12 + sin(f_time) * 6.0), Color(2.5, 0.5, 0.1), 4.0)
	draw_line(Vector2(-10, 12), Vector2(-35, 12 - sin(f_time) * 6.0), Color(2.5, 0.5, 0.1), 4.0)
