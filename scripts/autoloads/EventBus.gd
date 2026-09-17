extends Node

## 전역 이벤트 버스 (우로보로스 서바이벌)

# 뱀 및 조작 관련
signal segment_added(current_length: int)
signal tail_bitten(ghost_trajectory: Array)
signal loop_completed(polygon: PackedVector2Array, enemies_inside: Array)

# 드롭 및 파밍 관련
signal gem_collected(amount: int)
signal organ_ingested(organ_type: String)

# 전투 및 생명 주기 관련
signal enemy_killed(enemy_pos: Vector2, enemy_type: String)
signal player_damaged(current_hp: int, max_hp: int)
signal game_over
signal game_cleared
