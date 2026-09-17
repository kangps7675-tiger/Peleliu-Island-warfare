extends Node2D
class_name FallingBomb

@export var bomb_tex: Texture2D = preload("res://assets/sprites/aerial_bomb.png")

var target_pos: Vector2 = Vector2.ZERO
var start_pos: Vector2 = Vector2.ZERO
var fall_time: float = 0.85 # 낙하 소요 시간
var elapsed: float = 0.0
var damage: float = 450.0
var blast_radius: float = 180.0

func initialize(ground_pos: Vector2, bomber_pos: Vector2) -> void:
	target_pos = ground_pos
	# 고공 폭격기에서 비스듬히 투하
	start_pos = bomber_pos
	global_position = start_pos
	fall_time = randf_range(0.7, 1.0)
	elapsed = 0.0

func _process(delta: float) -> void:
	elapsed += delta
	var progress = clampf(elapsed / fall_time, 0.0, 1.0)
	
	# 중력 가속도 곡선
	var t = progress * progress
	global_position = start_pos.lerp(target_pos, t)
	
	# 폭탄 각도: 지면을 향해 살짝 회전
	rotation = lerp_angle(PI * 0.5, PI * 0.55, progress)
	
	queue_redraw()
	
	if progress >= 1.0:
		_detonate()

func _detonate() -> void:
	var main_scene = get_tree().current_scene
	if main_scene:
		# 1. 지면에 영구/지속 포탄 분화구 데칼 각인
		if main_scene.has_method("add_crater_decal"):
			main_scene.add_crater_decal(target_pos, randf_range(38.0, 52.0))
			
		# 2. 컴퍼니 오브 히어로즈 급 카타스트로픽 대폭발 이펙트 스폰
		if main_scene.has_method("spawn_heavy_explosion"):
			main_scene.spawn_heavy_explosion(target_pos, blast_radius)
	
	# 반경 내 적들 궤멸
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			var d = target_pos.distance_to(enemy.global_position)
			if d <= blast_radius:
				var falloff = 1.0 - (d / blast_radius) * 0.3
				if enemy.has_method("take_damage"):
					enemy.take_damage(damage * falloff)
				if enemy is CharacterBody2D:
					var knock = (enemy.global_position - target_pos).normalized()
					enemy.velocity += knock * 450.0
	
	queue_free()

func _draw() -> void:
	var progress = clampf(elapsed / fall_time, 0.0, 1.0)
	
	# 1. 지면에 비치는 폭탄 그림자 (낙하할수록 폭탄과 가까워짐)
	var shadow_offset = (target_pos - global_position) * 0.4
	draw_circle(shadow_offset, 14.0 * (1.0 - progress * 0.5), Color(0.0, 0.0, 0.0, 0.4 * progress))
	
	# 2. 공기 마찰 스피드 라인 (고속 낙하 잔상)
	draw_line(Vector2(0, -25), Vector2(0, -60), Color(1.0, 0.9, 0.7, 0.5 * progress), 3.0)
	
	# 3. 500lb 고폭탄 본체 스프라이트
	if bomb_tex:
		var w = 24.0
		var h = 42.0
		draw_texture_rect(bomb_tex, Rect2(-w * 0.5, -h * 0.5, w, h), false)
	else:
		draw_circle(Vector2.ZERO, 10.0, Color(0.3, 0.35, 0.25))
