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

func _physics_process(delta: float) -> void:
	# 1. 섬 외곽 바다를 따라 항해 (시계 방향 순항)
	patrol_angle += 0.08 * delta
	var target_x = center_pos.x + cos(patrol_angle) * patrol_radius
	var target_y = center_pos.y + sin(patrol_angle) * (patrol_radius * 0.75)
	var new_pos = Vector2(target_x, target_y)
	
	var move_dir = (new_pos - global_position).normalized()
	if move_dir.length_squared() > 0.01:
		rotation = lerp_angle(rotation, move_dir.angle(), 4.0 * delta)
	global_position = new_pos
	
	# 2. 460mm 3연장 주포 3문 일제사격 (Triple 460mm Salvo)
	salvo_timer -= delta
	if salvo_timer <= 0.0:
		salvo_timer = 5.0
		_fire_triple_460mm_salvo()
		
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
		
	var target_center = target_player.global_position
	# 3발의 460mm 철갑유탄이 뱀 주변으로 맹렬히 낙하!
	for i in range(3):
		var offset = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30.0, 140.0)
		var aim_pos = target_center + offset
		var fire_dir = (aim_pos - global_position).normalized()
		
		# 거대한 주포탄 사출
		if main_scene.has_method("spawn_cannon_shell"):
			var muzzle = global_position + fire_dir * 120.0 + Vector2.RIGHT.rotated(rotation) * (i * 35.0 - 35.0)
			main_scene.spawn_cannon_shell(muzzle, fire_dir)
			
	# 거포 일제사격 화면 대진동
	var heads = get_tree().get_nodes_in_group("player_head")
	if not heads.is_empty() and heads[0].get("camera_shake_amount") != null:
		heads[0].camera_shake_amount = 16.0

func take_damage(amount: float) -> void:
	# 야마토 410mm 측면 중장갑 벨트 (피해 45% 경감)
	current_hp -= amount * 0.55
	flash_timer = 0.08
	if current_hp <= 0.0:
		_die()

func _die() -> void:
	EventBus.enemy_killed.emit(global_position, "BOSS_YAMATO")
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("spawn_heavy_explosion"):
		for i in range(4):
			main_scene.spawn_heavy_explosion(global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(20, 100), 250.0)
			
	# 대량 보급품 투하 (8개 탄약 상자)
	if gem_scene:
		for i in range(8):
			var gem = gem_scene.instantiate()
			gem.global_position = global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40.0, 140.0)
			get_parent().call_deferred("add_child", gem)
			
	queue_free()

func _draw() -> void:
	# 전함 항적 (Water Wake - 포말 파도)
	var stern_pos = -Vector2.RIGHT * 180.0
	draw_line(stern_pos, stern_pos - Vector2(80, -25), Color(0.9, 0.95, 1.0, 0.4), 6.0)
	draw_line(stern_pos, stern_pos - Vector2(80, 25), Color(0.9, 0.95, 1.0, 0.4), 6.0)
