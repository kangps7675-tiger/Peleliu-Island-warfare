extends Area2D
class_name Projectile

@export var speed: float = 480.0
@export var damage: float = 25.0
@export var lifetime: float = 2.5
@export var bullet_color: Color = Color(0.2, 0.9, 0.4)

var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	collision_layer = 0
	collision_mask = 4 # Enemy layer
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func initialize(pos: Vector2, dir: Vector2, dmg: float, col: Color) -> void:
	global_position = pos
	direction = dir.normalized()
	damage = dmg
	bullet_color = col
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	_hit_target(body)

func _on_area_entered(area: Area2D) -> void:
	_hit_target(area)

func _hit_target(target: Node2D) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage)
		queue_free()

func _draw() -> void:
	# 발광 투사체
	draw_circle(Vector2.ZERO, 6.0, bullet_color)
	draw_circle(Vector2.ZERO, 3.0, Color.WHITE)
