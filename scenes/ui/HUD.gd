extends CanvasLayer
class_name HUD

@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/TopBar/HPBar
@onready var length_label: Label = $MarginContainer/VBoxContainer/TopBar/LengthLabel
@onready var time_box: PanelContainer = $MarginContainer/VBoxContainer/TopBar/TimeBox
@onready var time_label: Label = $MarginContainer/VBoxContainer/TopBar/TimeBox/Margin/TimeLabel
@onready var tier_label: Label = $MarginContainer/VBoxContainer/TopBar/TierLabel
@onready var airstrike_label: Label = $MarginContainer/VBoxContainer/TopBar/AirstrikeLabel
@onready var kill_label: Label = $MarginContainer/VBoxContainer/TopBar/KillLabel
@onready var air_raid_banner: Label = $MarginContainer/VBoxContainer/AirRaidBanner
@onready var grand_airstrike_banner: Label = $MarginContainer/VBoxContainer/GrandAirstrikeBanner
@onready var bite_ready_label: Label = $MarginContainer/VBoxContainer/BiteReadyLabel
@onready var encircle_flash: ColorRect = $EncircleFlash

func _ready() -> void:
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.segment_added.connect(_on_segment_added)
	EventBus.tail_bitten.connect(_on_tail_bitten)
	EventBus.loop_completed.connect(_on_loop_completed)
	
	bite_ready_label.visible = false
	air_raid_banner.visible = false
	grand_airstrike_banner.visible = false
	encircle_flash.modulate.a = 0.0

func _process(_delta: float) -> void:
	# 15분 카운트다운 표시 (상단 중앙 제한시간 창)
	var mins = int(GameManager.countdown_time) / 60
	var secs = int(GameManager.countdown_time) % 60
	time_label.text = "⏱ 작전 제한시간: %02d:%02d" % [mins, secs]
	
	kill_label.text = "격파: %d" % GameManager.kill_count
	length_label.text = "마디: %d개" % GameManager.current_snake_length
	tier_label.text = "거대화: TIER %d" % GameManager.current_scale_tier
	
	# 1분 주기 연합군 대공습 타이머
	var main_scene = get_tree().current_scene
	if main_scene and "airstrike_countdown" in main_scene:
		var air_secs = int(main_scene.airstrike_countdown)
		airstrike_label.text = "✈️ 공습 대기: %02d초" % air_secs
		
		# 250대 무차별 폭격 중일 때
		if main_scene.get("is_airstrike_active"):
			grand_airstrike_banner.visible = true
			var pulse_gold = (sin(Time.get_ticks_msec() * 0.02) + 1.0) * 0.5
			grand_airstrike_banner.modulate = Color(1.0, 0.9, 0.2 + pulse_gold * 0.3)
		else:
			grand_airstrike_banner.visible = false
	
	# 꼬리물기 인디케이터
	if GameManager.is_bite_ready():
		bite_ready_label.visible = true
		var pulse = (sin(Time.get_ticks_msec() * 0.008) + 1.0) * 0.5
		bite_ready_label.modulate = Color(1.0, 0.85 + pulse * 0.15, 0.1, 0.8 + pulse * 0.2)
	else:
		bite_ready_label.visible = false
		
	# 가미카제 경보 배너
	var kamikazes = get_tree().get_nodes_in_group("kamikaze")
	if not kamikazes.is_empty():
		air_raid_banner.visible = true
		var pulse_red = (sin(Time.get_ticks_msec() * 0.015) + 1.0) * 0.5
		air_raid_banner.modulate = Color(1.0, 0.2 + pulse_red * 0.4, 0.2, 0.9)
	else:
		air_raid_banner.visible = false

func _on_player_damaged(curr_hp: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = curr_hp

func _on_segment_added(length: int) -> void:
	length_label.text = "마디: %d개" % length

func _on_tail_bitten(_trajectory: Array) -> void:
	var tween = create_tween()
	encircle_flash.color = Color(0.2, 0.8, 1.0)
	encircle_flash.modulate.a = 0.6
	tween.tween_property(encircle_flash, "modulate:a", 0.0, 0.4)

func _on_loop_completed(_polygon: PackedVector2Array, _enemies: Array) -> void:
	var tween = create_tween()
	encircle_flash.color = Color(1.0, 0.9, 0.3)
	encircle_flash.modulate.a = 0.5
	tween.tween_property(encircle_flash, "modulate:a", 0.0, 0.3)
