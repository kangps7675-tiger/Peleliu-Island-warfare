extends CanvasLayer
class_name HUD

@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/TopBar/HPBar
@onready var kill_label: Label = $MarginContainer/VBoxContainer/TopBar/KillLabel
@onready var supply_label: Label = $MarginContainer/VBoxContainer/TopBar/SupplyLabel
@onready var time_label: Label = $MarginContainer/VBoxContainer/TopBar/TimeBox/Margin/TimeLabel
@onready var tier_badge: Label = $MarginContainer/VBoxContainer/TopBar/TierBadge

@onready var event_banner: PanelContainer = $MarginContainer/VBoxContainer/EventBannerContainer/EventBanner
@onready var event_label: Label = $MarginContainer/VBoxContainer/EventBannerContainer/EventBanner/Margin/EventLabel

@onready var victory_panel: PanelContainer = $VictoryPanel
@onready var victory_stats: Label = $VictoryPanel/Margin/VBox/StatsLabel
@onready var encircle_flash: ColorRect = $EncircleFlash

var banner_timer: float = 0.0
var banner_tween: Tween = null
var last_reported_tier: int = 1
var kamikaze_announced: bool = false

func _ready() -> void:
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.loop_completed.connect(_on_loop_completed)
	
	event_banner.visible = false
	event_banner.modulate.a = 0.0
	victory_panel.visible = false
	encircle_flash.modulate.a = 0.0
	
	# 작전 개시 시점에만 15분 결전 작전 목표 안내문 출력!
	show_event_banner("⏱️ [작전 개시] 펠렐리우 15분 결전: 최후까지 생존하라!", Color(1.0, 0.9, 0.3), 5.0)

func _process(delta: float) -> void:
	# 1. 상단 중앙 15분 카운트다운 & 1분 공습 카운트다운 동시 표시
	var mins = int(GameManager.countdown_time) / 60
	var secs = int(GameManager.countdown_time) % 60
	
	var main_scene = get_tree().current_scene
	var air_time: float = 60.0
	if main_scene and "airstrike_countdown" in main_scene:
		air_time = maxf(0.0, main_scene.airstrike_countdown)
	var air_mins = int(air_time) / 60
	var air_secs = int(air_time) % 60
	
	time_label.text = "⏱ 작전 %02d:%02d  |  ✈️ 공습 %02d:%02d" % [mins, secs, air_mins, air_secs]
	
	# 2. 전투 통계 표시
	kill_label.text = "🎯 격파: %d" % GameManager.kill_count
	supply_label.text = "📦 보급: %d" % GameManager.total_supplies
	
	# 3. 티어 배지는 1티어 초과 업그레이드 시에만 깔끔하게 표시
	if GameManager.current_scale_tier > 1:
		tier_badge.visible = true
		tier_badge.text = "TIER %d" % GameManager.current_scale_tier
	else:
		tier_badge.visible = false
		
	# 6. 배너 타이머 관리
	if banner_timer > 0.0:
		banner_timer -= delta
		if banner_timer <= 0.0:
			_fade_out_banner()

## 이벤트 발생 시에만 그때그때 나타나는 다이내믹 알림 배너
func show_event_banner(message: String, col: Color, duration: float = 3.5) -> void:
	event_label.text = message
	event_label.modulate = col
	event_banner.visible = true
	banner_timer = duration
	
	if banner_tween and banner_tween.is_valid():
		banner_tween.kill()
		
	banner_tween = create_tween()
	banner_tween.tween_property(event_banner, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _fade_out_banner() -> void:
	if banner_tween and banner_tween.is_valid():
		banner_tween.kill()
	banner_tween = create_tween()
	banner_tween.tween_property(event_banner, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	banner_tween.tween_callback(func(): event_banner.visible = false)

func show_victory() -> void:
	victory_panel.visible = true
	victory_stats.text = "최종 격파 수: %d | 획득 군수품: %d | 최종 전차 등급: TIER %d" % [
		GameManager.kill_count,
		GameManager.total_supplies,
		GameManager.current_scale_tier
	]

func _on_player_damaged(curr_hp: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = curr_hp

func _on_loop_completed(_polygon: PackedVector2Array, _enemies: Array) -> void:
	var tween = create_tween()
	encircle_flash.color = Color(1.0, 0.9, 0.3)
	encircle_flash.modulate.a = 0.5
	tween.tween_property(encircle_flash, "modulate:a", 0.0, 0.3)
