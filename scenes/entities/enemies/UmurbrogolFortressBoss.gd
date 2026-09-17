extends CharacterBody2D
class_name UmurbrogolFortressBoss

@export var max_hp: float = 1600.0
@export var current_hp: float = 1600.0
@export var gem_scene: PackedScene = preload("res://scenes/entities/drops/Gem.tscn")

var fire_timer: float = 2.5
var hmg_timer: float = 0.4
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
	if not is_instance_valid(target_player):
		var heads = get_tree().get_nodes_in_group("player_head")
		if not heads.is_empty():
			target_player = heads[0]
		return
		
	# 1. 140mm 해안포 주포 사격 루프 (플레이어 위치로 거대 곡사 유탄 포격)
	fire_timer -= delta
	if fire_timer <= 0.0:
		fire_timer = 3.2
		_fire_coastal_cannon()
		
	# 2. 92식 중기관포 근접 방어 사격
	var dist = global_position.distance_to(target_player.global_position)
	if dist < 600.0:
		hmg_timer -= delta
		if hmg_timer <= 0.0:
			hmg_timer = 0.2
			_fire_hmg_burst()
			
	if flash_timer > 0.0:
		flash_timer -= delta
		if sprite:
			sprite.modulate = Color(2.5, 2.0, 2.0)
	elif sprite:
		sprite.modulate = Color.WHITE

func _fire_coastal_cannon() -> void:
	var main_scene = get_tree().current_scene
	if not main_scene or not is_instance_valid(target_player):
		return
		
	var dir = (target_player.global_position - global_position).normalized()
	if main_scene.has_method("spawn_cannon_shell"):
		var muzzle = global_position + dir * 65.0
		main_scene.spawn_cannon_shell(muzzle, dir)
		# 화면 진동
		var heads = get_tree().get_nodes_in_group("player_head")
		if not heads.is_empty() and heads[0].get("camera_shake_amount") != null:
			heads[0].camera_shake_amount = 8.0

func _fire_hmg_burst() -> void:
	var main_scene = get_tree().current_scene
	if not main_scene or not is_instance_valid(target_player):
		return
		
	var dir = (target_player.global_position - global_position).normalized()
	dir = dir.rotated(randf_range(-0.15, 0.15))
	if main_scene.has_method("spawn_projectile"):
		main_scene.spawn_projectile(global_position + dir * 40.0, dir, 12.0, Color(1.0, 0.4, 0.1))

func take_damage(amount: float) -> void:
	# 요새 강화 콘크리트 장갑 (피해 40% 경감)
	current_hp -= amount * 0.6
	flash_timer = 0.08
	if current_hp <= 0.0:
		_die()

func _die() -> void:
	EventBus.enemy_killed.emit(global_position, "BOSS_FORTRESS")
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("spawn_heavy_explosion"):
		main_scene.spawn_heavy_explosion(global_position, 220.0)
		
	# 대량 보급품 투하 (5개 탄약 상자)
	if gem_scene:
		for i in range(5):
			var gem = gem_scene.instantiate()
			gem.global_position = global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(30.0, 80.0)
			get_parent().call_deferred("add_child", gem)
			
	queue_free()
