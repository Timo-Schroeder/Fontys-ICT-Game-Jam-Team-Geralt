class_name RuleMonitor
extends Node
## Watches what the player does and reports broken rules to the EventBus.
## (What other road users experience, like hard braking or being hit, is reported
## by the vehicles themselves.)
##
## Each check is a small "condition held for N seconds" timer, so brushing
## the edge of a bike path for one frame does not count as walking on it.

var layout: StreetLayout
var player: Courier
var traffic: TrafficManager
var level: LevelData
## Where the police put the player back after a stop.
var last_safe_position: Vector3
var last_safe_direction: Vector3 = Vector3.FORWARD

var _timers: Dictionary = {}
var _prev: StreetLayout.SurfaceInfo
var _was_in_conflict := false
var _safe_timer := 0.0


func setup(p_layout: StreetLayout, p_player: Courier, p_traffic: TrafficManager, p_level: LevelData) -> void:
	layout = p_layout
	player = p_player
	traffic = p_traffic
	level = p_level
	set_safe_spot(player.global_position, player.forward())


func set_safe_spot(pos: Vector3, dir: Vector3) -> void:
	last_safe_position = pos
	last_safe_direction = dir


## Call after teleporting the player, so old timers do not fire.
func reset() -> void:
	_timers.clear()
	_prev = null
	_was_in_conflict = layout.in_conflict_zone(StreetLayout.to_2d(player.global_position))


## Returns what the player is standing on (the level uses it for hints).
func tick(delta: float) -> StreetLayout.SurfaceInfo:
	var p := StreetLayout.to_2d(player.global_position)
	var info := layout.classify(p)
	var v3 := player.get_real_velocity()
	var vel := Vector2(v3.x, v3.z)
	match player.mode:
		Courier.Mode.WALK:
			_check_walk(info, delta)
		Courier.Mode.BIKE:
			_check_bike(info, p, vel, delta)
		Courier.Mode.CAR:
			_check_car(info, p, vel, delta)
	if player.mode == Courier.Mode.WALK:
		_safe_timer += delta
		if _safe_timer > 0.25:
			_safe_timer = 0.0
			if info.surface in [StreetLayout.Surface.SIDEWALK, StreetLayout.Surface.PAD, StreetLayout.Surface.GRASS]:
				set_safe_spot(player.global_position, player.forward())
	_prev = info
	_was_in_conflict = layout.in_conflict_zone(p)
	return info


func _check_walk(info: StreetLayout.SurfaceInfo, delta: float) -> void:
	_fire_after("road", info.surface == StreetLayout.Surface.ROAD, delta, 0.35, RuleBook.Violation.WALKING_ON_ROAD)
	_fire_after("bikepath", info.surface == StreetLayout.Surface.BIKE_PATH, delta, 0.6, RuleBook.Violation.WALKING_ON_BIKE_PATH)
	# Stepping onto the car lanes of a signalled crossing while the pedestrian light is not green.
	if info.surface == StreetLayout.Surface.CROSSING and info.on_crossing_road \
			and info.crossing.type == LevelData.CrossingType.SIGNAL and traffic.lights:
		var entering := _prev == null or _prev.crossing != info.crossing or not _prev.on_crossing_road
		if entering and traffic.lights.ped_state(info.crossing) != TrafficLightController.Light.GREEN:
			_violate(RuleBook.Violation.RED_LIGHT)


func _check_bike(info: StreetLayout.SurfaceInfo, p: Vector2, vel: Vector2, delta: float) -> void:
	_fire_after("sidewalk", info.surface == StreetLayout.Surface.SIDEWALK, delta, 0.6, RuleBook.Violation.CYCLING_ON_SIDEWALK)
	if layout.has_bike_paths:
		# Riding along the road is not allowed when there is a bike path;
		# crossing the road straight to the other side is.
		var along := absf(vel.y) if info.axis == StreetLayout.Axis.NS else absf(vel.x)
		var riding_along := vel.length() > 1.0 and along > 0.7 * vel.length()
		var on_road := info.surface == StreetLayout.Surface.ROAD and not info.in_junction and riding_along
		_fire_after("bike_on_road", on_road, delta, 1.2, RuleBook.Violation.BIKE_ON_ROAD)
	_check_wrong_way(info, p, vel, delta)
	_check_red_light_entering_junction(p, vel)
	var dark_without_light := level.is_dark() and not player.bike_light_on and vel.length() > 1.0
	_fire_after("no_lights", dark_without_light, delta, 5.0, RuleBook.Violation.NO_LIGHTS)


func _check_car(info: StreetLayout.SurfaceInfo, p: Vector2, vel: Vector2, delta: float) -> void:
	var s := info.surface
	var off_road := s in [StreetLayout.Surface.SIDEWALK, StreetLayout.Surface.BIKE_PATH, StreetLayout.Surface.GRASS] \
			or (s == StreetLayout.Surface.CROSSING and not info.on_crossing_road)
	_fire_after("off_road", off_road, delta, 0.3, RuleBook.Violation.CAR_OFF_ROAD)
	_check_wrong_way(info, p, vel, delta)
	_check_red_light_entering_junction(p, vel)
	var too_fast := player.speed_kmh() > level.speed_limit_kmh + 4.0
	_fire_after("speeding", too_fast, delta, 2.0, RuleBook.Violation.SPEEDING)


func _check_wrong_way(info: StreetLayout.SurfaceInfo, p: Vector2, vel: Vector2, delta: float) -> void:
	var wrong := false
	var on_lane := info.surface in [StreetLayout.Surface.ROAD, StreetLayout.Surface.BIKE_PATH]
	if on_lane and not info.in_junction and info.axis != -1 and vel.length() > 1.5:
		var expected := layout.expected_direction(p, info.axis)
		wrong = vel.normalized().dot(expected) < -0.5
	_fire_after("wrong_way", wrong, delta, 1.0, RuleBook.Violation.WRONG_WAY)


func _check_red_light_entering_junction(p: Vector2, vel: Vector2) -> void:
	if traffic.lights == null:
		return
	var in_conflict := layout.in_conflict_zone(p)
	if in_conflict and not _was_in_conflict and vel.length() > 0.5:
		var axis := StreetLayout.Axis.NS if absf(vel.y) > absf(vel.x) else StreetLayout.Axis.EW
		if traffic.lights.vehicle_state(axis) == TrafficLightController.Light.RED:
			_violate(RuleBook.Violation.RED_LIGHT)


func _fire_after(key: String, active: bool, delta: float, seconds: float, violation: int) -> void:
	if not active:
		_timers[key] = 0.0
		return
	_timers[key] = float(_timers.get(key, 0.0)) + delta
	if _timers[key] >= seconds:
		_timers[key] = 0.0
		_violate(violation)


func _violate(type: int) -> void:
	EventBus.violation.emit(type, {"position": player.global_position})
