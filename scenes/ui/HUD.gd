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
	
	# 작전 개시 시점에만 첫 4.5초간 작전 목표 안내문 출력!
	show_event_banner("⚔️ [작전 개시] 펠렐리우 섬 상륙: 10분간 생존하여 섬을 장악하라!", Color(1.0, 0.9, 0.3), 4.5)

func _process(delta: float) -> void:
	# 1. 상단 중앙 10분 카운트다운 타이머
	var mins = int(GameManager.countdown_time) / 60
	var secs = int(GameManager.countdown_time) % 60
	time_label.text = "⏱ %02d:%02d" % [mins, secs]
	
	# 2. 전투 통계 표시
	kill_label.text = "🎯 격파: %d" % GameManager.kill_count
	supply_label.text = "📦 보급: %d" % GameManager.total_supplies
	
	# 3. 티어 배지는 1티어 초과 업그레이드 시에만 깔끔하게 표시
	if GameManager.current_scale_tier > 1:
		tier_badge.visible = true
		tier_badge.text = "TIER %d" % GameManager.current_scale_tier
	else:
		tier_badge.visible = false
		
	# 4. 거대화 티어 변경 시점에만 안내문 팝업
	if GameManager.current_scale_tier > last_reported_tier:
		last_reported_tier = GameManager.current_scale_tier
		show_event_banner("⭐ [전차 강화] 보급 달성! 차체 TIER %d 거대화 완료!" % last_reported_tier, Color(0.4, 0.9, 1.0), 3.5)
	
	# 5. 가미카제 출현 시점에만 안내문 팝업
	var kamikazes = get_tree().get_nodes_in_group("kamikaze")
	if not kamikazes.is_empty():
		if not kamikaze_announced:
			kamikaze_announced = true
			show_event_banner("🚨 [공습 경보] 제로센 가미카제 급강하 중! 30MM 대공포 집중 사격!", Color(1.0, 0.3, 0.3), 3.5)
	else:
		kamikaze_announced = false
		
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
