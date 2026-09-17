extends CharacterBody2D
class_name EnemyBase

@export var max_hp: float = 35.0
@export var current_hp: float = 35.0
@export var move_speed: float = 90.0
@export var contact_damage: float = 10.0
@export var gem_scene: PackedScene = preload("res://scenes/entities/drops/Gem.tscn")
@export var faction: String = "UNDEAD" # UNDEAD / INSECT / GOLEM

var target: Node2D = null
var flash_timer: float = 0.0

func _ready() -> void:
	collision_layer = 4 # Enemy layer
	collision_mask = 7  # Head (1), Body Segments (2), Projectile (0, hit by projectile)
	add_to_group("enemies")
	current_hp = max_hp
	
	# 플레이어 머리를 타겟으로 설정
	var heads = get_tree().get_nodes_in_group("player_head")
	if not heads.is_empty():
		target = heads[0]

@onready var sprite: Sprite2D = $Sprite2D

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		var heads = get_tree().get_nodes_in_group("player_head")
		if not heads.is_empty():
			target = heads[0]
		return
	
	# 플레이어 방향으로 회전 및 전진 (치하 전차 기동)
	var dir = (target.global_position - global_position).normalized()
	rotation = lerp_angle(rotation, dir.angle(), 8.0 * delta)
	velocity = dir * move_speed
	move_and_slide()
	
	# 플레이어와 접촉 체크
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.is_in_group("player_head"):
			if collider.has_method("take_damage"):
				collider.take_damage(contact_damage * delta)
	
	if flash_timer > 0.0:
		flash_timer -= delta
		if sprite:
			sprite.modulate = Color(2.5, 2.5, 2.5)
	elif sprite:
		sprite.modulate = Color.WHITE

func take_damage(amount: float) -> void:
	current_hp -= amount
	flash_timer = 0.08
	
	if current_hp <= 0.0:
		_die()

func _die() -> void:
	EventBus.enemy_killed.emit(global_position, faction)
	
	# 경험치 보급품 드롭
	if gem_scene:
		var gem = gem_scene.instantiate()
		gem.global_position = global_position
		get_parent().call_deferred("add_child", gem)
	
	queue_free()
