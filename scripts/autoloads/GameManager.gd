extends Node

## 전역 게임 매니저: 펠렐리우 1944 (Project Iron Serpent)

# 15분 결전 카운트다운 (900초)
var countdown_time: float = 15.0 * 60.0
var session_time: float = 0.0
var kill_count: int = 0
var total_supplies: int = 0 # 군수 보급품 (골드/젬 대체)
var current_snake_length: int = 5
var is_game_active: bool = true

# 단계적 거대화 티어 (Tier 1 ~ Tier 4)
var current_scale_tier: int = 1
var snake_scale_multiplier: float = 1.0

# 엔딩 피날레 트리거 플래그
var is_nuclear_triggered: bool = false

func _ready() -> void:
	EventBus.gem_collected.connect(_on_supply_collected)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.segment_added.connect(_on_segment_added)

func _process(delta: float) -> void:
	if not is_game_active:
		return
		
	session_time += delta
	countdown_time = maxf(0.0, countdown_time - delta)
	
	# 15분 경과 ➔ 00:00 도달 시 핵폭탄(Nuclear Strike) 투하 및 최후 승리!
	if countdown_time <= 0.0 and not is_nuclear_triggered:
		is_nuclear_triggered = true
		_trigger_nuclear_strike()

func _trigger_nuclear_strike() -> void:
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("trigger_nuclear_strike"):
		main_scene.trigger_nuclear_strike()

func _on_supply_collected(amount: int) -> void:
	total_supplies += amount
	_check_scale_tier_upgrade()

func _check_scale_tier_upgrade() -> void:
	# 단계적 거대화 판정 (기하급수적이 아닌 정해진 보급량 임계치)
	var new_tier = 1
	if total_supplies >= 120:
		new_tier = 4
		snake_scale_multiplier = 2.0
	elif total_supplies >= 60:
		new_tier = 3
		snake_scale_multiplier = 1.6
	elif total_supplies >= 20:
		new_tier = 2
		snake_scale_multiplier = 1.3
	else:
		new_tier = 1
		snake_scale_multiplier = 1.0
	
	if new_tier != current_scale_tier:
		current_scale_tier = new_tier
		var heads = get_tree().get_nodes_in_group("player_head")
		if not heads.is_empty() and heads[0].has_method("apply_scale_tier"):
			heads[0].apply_scale_tier(snake_scale_multiplier, current_scale_tier)

func _on_enemy_killed(_pos: Vector2, _type: String) -> void:
	kill_count += 1

func _on_segment_added(length: int) -> void:
	current_snake_length = length

func reset_game() -> void:
	countdown_time = 15.0 * 60.0
	session_time = 0.0
	kill_count = 0
	total_supplies = 0
	current_snake_length = 5
	current_scale_tier = 1
	snake_scale_multiplier = 1.0
	is_game_active = true
	is_nuclear_triggered = false
