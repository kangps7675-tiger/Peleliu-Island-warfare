extends Area2D
class_name Projectile

@export var speed: float = 480.0
@export var damage: float = 25.0
@export var lifetime: float = 2.5
@export var bullet_color: Color = Color(0.2, 0.9, 0.4)

var direction: Vector2 = Vector2.RIGHT

var is_enemy: bool = false

func _ready() -> void:
	collision_layer = 0
	_update_collision_mask()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _update_collision_mask() -> void:
	if is_enemy:
		collision_mask = 3 # Player Head (1) + Segments (2)
	else:
		collision_mask = 4 # Enemy layer (4)

func initialize(pos: Vector2, dir: Vector2, dmg: float, col: Color, enemy_shot: bool = false) -> void:
	global_position = pos
	direction = dir.normalized()
	damage = dmg
	bullet_color = col
	is_enemy = enemy_shot
	rotation = direction.angle()
	_update_collision_mask()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	_hit_target(body)

func _on_area_entered(area: Area2D) -> void:
	_hit_target(area)

func _hit_target(target_node: Node2D) -> void:
	var main_scene = get_tree().current_scene
	
	# 🛡️ CoH / GoH 장갑 도탄 (Ricochet / Deflection) 판정
	var did_ricochet = false
	if is_enemy and (target_node.is_in_group("player_head") or target_node.is_in_group("segments")):
		# 아군 강철 뱀(Landship)의 중장갑에 보병 소총탄/기관총탄 피탄 시 70% 확률로 튕겨냄
		if damage <= 20.0 and randf() < 0.70:
			did_ricochet = true
			damage = 2.0 # 도탄 시 미미한 긁힘 피해만 전달
			AudioManager.play_sfx("ricochet", -2.0, 0.3)
			if main_scene and main_scene.has_method("spawn_tactical_popup"):
				main_scene.spawn_tactical_popup(global_position, "CLANG! 도탄", Color(1.0, 0.85, 0.2))
	elif not is_enemy and target_node.has_method("is_in_group") and target_node.is_in_group("heavy_armor"):
		if damage < 30.0 and randf() < 0.4:
			did_ricochet = true
			damage *= 0.2
			AudioManager.play_sfx("ricochet", -2.0, 0.3)
			if main_scene and main_scene.has_method("spawn_tactical_popup"):
				main_scene.spawn_tactical_popup(global_position, "도탄 (DEFLECT)", Color(1.0, 0.6, 0.2))
				
	if target_node.has_method("take_damage"):
		target_node.take_damage(damage)
		
	# 착탄 스파크 및 파편
	if main_scene and main_scene.has_method("spawn_dirt_eruption"):
		main_scene.spawn_dirt_eruption(global_position, 3 if did_ricochet else 2, 12.0)
		
	queue_free()

func _draw() -> void:
	# =========================================================================
	# 🚀 극사실주의 고속 예광탄 (High-Velocity Incandescent Tracer Streak)
	# =========================================================================
	var trail_length = 22.0
	var back_offset = -Vector2(trail_length, 0.0)
	
	# 1. 외곽 빛 번짐 광선 (Tapered Outer Glow)
	draw_line(back_offset, Vector2(3.0, 0.0), Color(bullet_color.r, bullet_color.g, bullet_color.b, 0.45), 4.5)
	# 2. 중심 고온 탄도 줄기 (Bright Tracer Core)
	draw_line(back_offset * 0.7, Vector2(2.0, 0.0), bullet_color.lightened(0.3), 2.8)
	# 3. 초고온 플라즈마 탄두 팁 (High-Temp White Head)
	draw_line(back_offset * 0.25, Vector2.ZERO, Color(1.0, 1.0, 1.0, 0.95), 1.8)
	draw_circle(Vector2.ZERO, 2.2, Color.WHITE)
