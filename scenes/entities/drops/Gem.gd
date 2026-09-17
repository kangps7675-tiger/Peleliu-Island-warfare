extends Area2D
class_name Gem

@export var xp_value: int = 1
@export var base_color: Color = Color(0.1, 0.9, 0.9)

var is_being_attracted: bool = false
var target_node: Node2D = null
var current_speed: float = 80.0
var max_speed: float = 650.0

func _ready() -> void:
	collision_layer = 16 # Drops layer
	collision_mask = 9   # Magnet (8) & Head (1)
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if is_being_attracted and is_instance_valid(target_node):
		current_speed = move_toward(current_speed, max_speed, 1200.0 * delta)
		var dir = (target_node.global_position - global_position).normalized()
		global_position += dir * current_speed * delta
		
		if global_position.distance_to(target_node.global_position) < 20.0:
			_collect()

func _on_area_entered(area: Area2D) -> void:
	# 자석 영역 진입 시 흡수 시작
	if area.is_in_group("magnet"):
		is_being_attracted = true
		target_node = area.get_parent()

func _on_body_entered(body: Node2D) -> void:
	# 플레이어 머리와 접촉 시 수집
	if body.is_in_group("player_head"):
		_collect()

func _collect() -> void:
	EventBus.gem_collected.emit(xp_value)
	queue_free()
