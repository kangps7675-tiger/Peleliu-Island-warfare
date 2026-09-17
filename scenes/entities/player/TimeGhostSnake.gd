extends Node2D
class_name TimeGhostSnake

var trajectory: Array = []
var duration: float = 10.0 # 10초간 유지
var elapsed: float = 0.0
var attack_timer: float = 0.0
var attack_interval: float = 0.4 # 0.4초마다 전방위 탄환 난사

func initialize(recorded_trajectory: Array, _segment_count: int) -> void:
	trajectory = recorded_trajectory.duplicate()
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		# 수명 종료 시 페이드아웃 후 소멸
		queue_free()
		return
	
	attack_timer -= delta
	if attack_timer <= 0.0:
		attack_timer = attack_interval
		_fire_ghost_barrage()
	
	queue_redraw()

func _fire_ghost_barrage() -> void:
	if trajectory.is_empty():
		return
	
	# 궤적 상의 몇 개 포인트를 선정하여 사방으로 에테르 탄환 발사
	var step = maxi(1, trajectory.size() / 6)
	var main_scene = get_tree().current_scene
	
	for i in range(0, trajectory.size(), step):
		var pt = trajectory[i]["pos"]
		var rot = trajectory[i]["rot"]
		# 좌우 2방향으로 관통 에테르 투사체 발사
		var dir1 = Vector2.RIGHT.rotated(rot + PI * 0.5)
		var dir2 = Vector2.RIGHT.rotated(rot - PI * 0.5)
		
		if main_scene and main_scene.has_method("spawn_projectile"):
			main_scene.spawn_projectile(pt, dir1, 40.0, Color(0.2, 0.8, 1.0))
			main_scene.spawn_projectile(pt, dir2, 40.0, Color(0.2, 0.8, 1.0))

func _draw() -> void:
	if trajectory.size() < 2:
		return
	
	var alpha = clampf(1.0 - (elapsed / duration), 0.0, 1.0)
	var points = PackedVector2Array()
	
	for entry in trajectory:
		points.append(entry["pos"])
	
	# 환영 뱀의 푸른 에테르 궤적 선 그리기 (외부 글로우 + 내부 코어)
	draw_polyline(points, Color(0.1, 0.6, 1.0, 0.4 * alpha), 28.0)
	draw_polyline(points, Color(0.3, 0.9, 1.0, 0.8 * alpha), 12.0)
	draw_polyline(points, Color(0.9, 1.0, 1.0, 0.95 * alpha), 4.0)
	
	# 머리 부분 발광 구체
	if not points.is_empty():
		draw_circle(points[0], 18.0, Color(0.2, 0.8, 1.0, 0.9 * alpha))
		draw_circle(points[0], 8.0, Color(1.0, 1.0, 1.0, 1.0 * alpha))
