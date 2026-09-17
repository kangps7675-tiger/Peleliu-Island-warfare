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

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		var heads = get_tree().get_nodes_in_group("player_head")
		if not heads.is_empty():
			target = heads[0]
		return
	
	# 플레이어 방향으로 전진
	var dir = (target.global_position - global_position).normalized()
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
		queue_redraw()

func take_damage(amount: float) -> void:
	current_hp -= amount
	flash_timer = 0.08
	queue_redraw()
	
	if current_hp <= 0.0:
		_die()

func _die() -> void:
	EventBus.enemy_killed.emit(global_position, faction)
	
	# 경험치 젬 드롭
	if gem_scene:
		var gem = gem_scene.instantiate()
		gem.global_position = global_position
		get_parent().call_deferred("add_child", gem)
	
	queue_free()

func _draw() -> void:
	var color: Color
	if flash_timer > 0.0:
		color = Color.WHITE
	else:
		# 언데드/슬라임 보라-자주색
		color = Color(0.85, 0.25, 0.45, 0.9)
	
	# 몸체 원형 + 가시
	draw_circle(Vector2.ZERO, 13.0, color)
	draw_circle(Vector2.ZERO, 5.0, Color(0.3, 0.0, 0.1, 1.0)) # 눈
