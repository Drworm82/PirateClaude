extends Node

func get_player_id() -> String:
	return GameManager.player_id

func get_current_island_id() -> String:
	return GameManager.home_island_id

func get_current_island_lat() -> float:
	return GameManager.home_lat

func get_current_island_lng() -> float:
	return GameManager.home_lng

func get_doblones_onboard() -> int:
	return GameManager.doblones

func set_current_island_id(island_id: String) -> void:
	GameManager.home_island_id = island_id

func get_distance_to(target_island_id: String) -> float:
	for island in GameManager.islands_cache:
		if str(island.get("id", "")) == target_island_id:
			return _haversine(
				GameManager.home_lat,
				GameManager.home_lng,
				float(island.get("lat", 0.0)),
				float(island.get("lng", 0.0))
			)
	return 0.0

func _haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
	var r: float = 6371.0
	var d_lat: float = deg_to_rad(lat2 - lat1)
	var d_lng: float = deg_to_rad(lng2 - lng1)
	var a: float = sin(d_lat / 2.0) * sin(d_lat / 2.0) + \
		cos(deg_to_rad(lat1)) * cos(deg_to_rad(lat2)) * \
		sin(d_lng / 2.0) * sin(d_lng / 2.0)
	var c: float = 2.0 * atan2(sqrt(a), sqrt(1.0 - a))
	return r * c