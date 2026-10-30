class_name TrafficManager
extends Node3D
## Runs all traffic: lanes and spawning, traffic lights and their visuals, give-way logic,
## emergency vehicles and sidewalk pedestrians.
## The level calls tick() every physics frame, so pausing the level pauses traffic and
## prewarm() can fast-forward traffic before the player starts.

## Extra seconds a give-way driver keeps between itself and main-road traffic.
const SAFETY_MARGIN := 1.2
## On a priority-road junction the side street gets this share of the level's traffic density.
const MINOR_ROAD_SHARE := 0.4

## 0 = different traffic every attempt. Set a number for repeatable traffic (testing/balancing).
@export var fixed_seed := 0
## Testing aid: put a red "!" above road users who break the rules.
@export var show_bad_actors := false

var layout: StreetLayout
var level: LevelData
var player: Courier
## False during the briefing and prewarm: vehicles then ignore the player.
var player_active := false
var lights: TrafficLightController
var lanes: Array[TrafficLane] = []
var vehicles_in_junction: Array = []
var is_dark := false
var wet := false
var speed_limit := 8.33
var rng := RandomNumberGenerator.new()
var play_time := 0.0

var _emergency_queue: Array[float] = []
var _emergencies: Array = []
var _heads: Array[Dictionary] = []
var _npcs: Array[PedestrianNPC] = []


func setup(p_layout: StreetLayout, p_level: LevelData, p_player: Courier) -> void:
	layout = p_layout
	level = p_level
	player = p_player
	is_dark = level.is_dark()
	wet = level.weather == LevelData.Weather.RAIN
	speed_limit = level.speed_limit_kmh / 3.6
	if fixed_seed != 0:
		rng.seed = fixed_seed
	else:
		rng.randomize()
	for ld in layout.lanes:
		var lane := TrafficLane.new(ld)
		lane.spawn_timer = rng.randf_range(0.0, 3.0)
		lanes.append(lane)
	if level.junction_control == LevelData.JunctionControl.TRAFFIC_LIGHTS:
		lights = TrafficLightController.new()
		lights.name = "TrafficLights"
		add_child(lights)
		lights.phase = rng.randi_range(0, 5)
		lights.setup(layout.crossings)
		_build_signal_heads()
		lights.changed.connect(_update_heads)
		_update_heads()
	for t in level.emergency_times:
		_emergency_queue.append(t)
	_emergency_queue.sort()
	for i in level.walkers:
		_spawn_npc(false)
	for i in level.runners:
		_spawn_npc(true)


## Simulate traffic for a while so the streets are not empty when the level starts.
func prewarm(seconds: float) -> void:
	var was_active := player_active
	player_active = false
	var step := 1.0 / 20.0
	for i in int(seconds / step):
		tick(step, false)
	player_active = was_active


func tick(delta: float, playing: bool = true) -> void:
	if playing:
		play_time += delta
		_update_emergency_schedule()
	_update_claims()
	_update_preemption()
	if lights:
		lights.tick(delta)
	vehicles_in_junction = _collect_junction_vehicles()
	for lane in lanes:
		_spawn(lane, delta)
		var leader: Vehicle = null
		for v: Vehicle in lane.vehicles:
			v.tick(delta, leader)
			leader = v
		_despawn(lane)
	for npc in _npcs:
		npc.tick(delta)


# --- Rules for drivers ----------------------------------------------------------

## Must this vehicle stop at its lane's stop line right now?
func must_stop_at_line(v: Vehicle) -> bool:
	if v.spec.is_emergency:
		return false
	var dist := v.lane.def.stop_offset - v.front()
	if dist < -0.1:
		return false
	if lights:
		var state := lights.vehicle_state(v.lane.def.axis)
		if state == TrafficLightController.Light.GREEN:
			return false
		if v.spec.misbehaviour == VehicleSpec.Misbehaviour.RUNS_RED:
			# Decide once, just before a good driver would start to brake: run the red light
			# if no other vehicle can get in the way. (The player is "not seen".)
			if v.red_decision == 0 and dist < maxf(v.speed * 3.0, 8.0):
				v.red_decision = 1 if is_clear_for(v, true) else -1
			if v.red_decision == 1:
				return false
		var need := v.speed * v.speed / (2.0 * maxf(dist, 0.05))
		if state == TrafficLightController.Light.YELLOW:
			return need <= v.spec.comfort_decel * 1.2   # too close to stop: drive on
		return need <= v.spec.max_decel
	# Priority road: east-west has right of way, north-south gives way (haaientanden).
	if v.lane.def.axis == StreetLayout.Axis.EW:
		return false
	return not is_clear_for(v, v.spec.misbehaviour == VehicleSpec.Misbehaviour.IGNORES_PRIORITY)


## Is a vehicle from the crossing road still on the junction, and not yet past my lane?
func junction_busy_for(v: Vehicle) -> bool:
	for o: Vehicle in vehicles_in_junction:
		if o.lane.def.axis == v.lane.def.axis:
			continue
		if o.rear() > _meeting_offset(o.lane.def, v.lane.def) + v.spec.width * 0.5 + 0.5:
			continue   # it has already crossed my path
		return true
	return false


## Give-way traffic slows down when approaching the shark teeth.
func speed_cap_for(v: Vehicle) -> float:
	if v.spec.is_emergency or lights:
		return INF
	if v.lane.def.axis == StreetLayout.Axis.NS:
		var d := v.lane.def.stop_offset - v.front()
		if d > 0.0 and d < 25.0:
			return 3.0 + d * 0.35
	return INF


## Can a give-way vehicle cross the junction safely?
## For every main-road lane it must cross, it compares "how long until I am completely past
## that lane" with "how long until the next main-road vehicle gets there" (gap acceptance).
## ignore_player: a rule breaker who does not look out for the player.
func is_clear_for(v: Vehicle, ignore_player: bool = false) -> bool:
	var my := v.lane.def
	# Do not drive onto the junction if the exit is blocked by a pedestrian on the zebra.
	if v.spec.misbehaviour != VehicleSpec.Misbehaviour.IGNORES_ZEBRA:
		for entry: Dictionary in my.crossings:
			var c: StreetLayout.Crossing = entry["crossing"]
			if entry["enter"] > my.junction_exit - 0.1 and c.type == LevelData.CrossingType.ZEBRA and c.claimed:
				return false
	var my_half := v.spec.width * 0.5
	# Drivers who have waited a long time accept slightly smaller gaps.
	var margin := lerpf(SAFETY_MARGIN, 0.3, clampf(v.waiting_time / 20.0, 0.0, 1.0))
	for lane in lanes:
		if lane.def.axis == my.axis:
			continue
		var lane_half := (StreetLayout.LANE_WIDTH if lane.def.kind == "road" else StreetLayout.BIKE_WIDTH) * 0.5
		var meet_mine := _meeting_offset(my, lane.def)
		var meet_theirs := _meeting_offset(lane.def, my)
		var t_clear := _time_to_cover(meet_mine + lane_half + v.spec.length - v.front(), v.speed, v.spec.accel, v.spec.max_speed)
		for o: Vehicle in lane.vehicles:
			if o.rear() > meet_theirs + my_half + 0.5:
				continue   # already past my lane
			var d := meet_theirs - my_half - 0.5 - o.front()
			if d <= 0.0:
				return false   # it is on my path right now
			if _time_to_cover(d, o.speed, o.spec.accel, o.spec.max_speed) < t_clear + margin:
				return false
	# The player riding or driving on the main road also has right of way.
	if player_active and player.mode != Courier.Mode.WALK and not ignore_player:
		var p := StreetLayout.to_2d(player.global_position)
		if layout.in_conflict_zone(p):
			return false
		if absf(p.y) < layout.walk_inner and absf(p.x) >= layout.walk_inner:
			var vel := player.get_real_velocity()
			var toward := -signf(p.x) * vel.x
			var t_clear_all := _time_to_cover(my.junction_exit + v.spec.length - v.front(), v.speed, v.spec.accel, v.spec.max_speed)
			if toward > 0.5 and (absf(p.x) - layout.walk_inner) / toward < t_clear_all + SAFETY_MARGIN:
				return false
	return true


## Offset along lane `a` where it crosses the centre line of the perpendicular lane `b`.
static func _meeting_offset(a: StreetLayout.LaneDef, b: StreetLayout.LaneDef) -> float:
	if a.axis == StreetLayout.Axis.NS:
		return (b.start.y - a.start.y) * a.dir.y
	return (b.start.x - a.start.x) * a.dir.x


## Time to drive distance d, starting at speed v0, accelerating at a up to vmax.
static func _time_to_cover(d: float, v0: float, a: float, vmax: float) -> float:
	if d <= 0.0:
		return 0.0
	if v0 >= vmax:
		return d / maxf(v0, 0.1)
	var t_acc := (vmax - v0) / a
	var d_acc := v0 * t_acc + 0.5 * a * t_acc * t_acc
	if d <= d_acc:
		return (-v0 + sqrt(v0 * v0 + 2.0 * a * d)) / a
	return t_acc + (d - d_acc) / vmax


func report_violation(type: int, by: Vehicle) -> void:
	if not player_active:
		return
	var m := by.spec.misbehaviour
	if m != VehicleSpec.Misbehaviour.NONE and type in [RuleBook.Violation.FORCED_BRAKE, RuleBook.Violation.BLOCKING_TRAFFIC]:
		# A rule breaker had to brake for you: that is their fault, so no police stop,
		# but it was a close call worth explaining.
		EventBus.bad_actor.emit(m, by.spec.display_name, true)
		return
	EventBus.violation.emit(type, {"by": by.spec.display_name, "position": by.global_position, "bad": m})


# --- Push buttons ------------------------------------------------------------------

## Returns the signalled crossing whose push button is within reach, or null.
func button_near(pos: Vector3, reach: float = 1.8) -> StreetLayout.Crossing:
	if lights == null or not lights.push_buttons:
		return null
	for c in layout.crossings:
		for b in c.buttons:
			if Vector2(b.x - pos.x, b.z - pos.z).length() < reach:
				return c
	return null


func press_button(c: StreetLayout.Crossing) -> void:
	if lights:
		lights.press_button(c)
		_update_heads()


# --- Internals -----------------------------------------------------------------------

func _update_claims() -> void:
	var walking := player_active and player.mode == Courier.Mode.WALK
	var p := StreetLayout.to_2d(player.global_position)
	for c in layout.crossings:
		c.claimed = walking and c.claim_rect.has_point(p)


func _update_preemption() -> void:
	if lights == null:
		return
	var axis := -1
	for v in _emergencies:
		if not is_instance_valid(v):
			continue
		var ld: StreetLayout.LaneDef = v.lane.def
		if v.front() > ld.junction_enter - 90.0 and v.rear() < ld.junction_exit:
			axis = ld.axis
			break
	lights.preempt_axis = axis


func _collect_junction_vehicles() -> Array:
	var result: Array = []
	for lane in lanes:
		for v: Vehicle in lane.vehicles:
			if v.front() > lane.def.junction_enter - 0.5 and v.rear() < lane.def.junction_exit:
				result.append(v)
	return result


func _spawn(lane: TrafficLane, delta: float) -> void:
	lane.spawn_timer -= delta
	if lane.pending_group > 0:
		if lane.entry_space() > 1.8 + 0.8:
			_spawn_vehicle(lane, VehicleSpec.create("racebike", speed_limit, rng, wet))
			lane.pending_group -= 1
		return
	if lane.spawn_timer > 0.0:
		return
	var is_road := lane.def.kind == "road"
	var density := level.car_density if is_road else level.bike_density
	if lights == null and lane.def.axis == StreetLayout.Axis.NS:
		density *= MINOR_ROAD_SHARE   # a side street is quieter than the main road
	if density <= 0.0:
		lane.spawn_timer = 1e9
		return
	var kind := _pick_road_kind(lane) if is_road else _pick_bike_kind()
	var spec := VehicleSpec.create(kind, speed_limit, rng, wet)
	_maybe_make_bad(spec, lane)
	if lane.entry_space() < spec.length + 4.0:
		lane.spawn_timer = 0.5
		return
	_spawn_vehicle(lane, spec)
	if kind == "racebike":
		lane.pending_group = rng.randi_range(2, 5)
	var base := lerpf(16.0, 2.5, density) if is_road else lerpf(14.0, 2.0, density)
	lane.spawn_timer = base * rng.randf_range(0.6, 1.4)


func _spawn_vehicle(lane: TrafficLane, spec: VehicleSpec) -> Vehicle:
	var v := Vehicle.new()
	v.name = "%s_%d" % [spec.kind, rng.randi() % 100000]
	# Place it before it enters the tree; otherwise its physics body sits at the
	# origin for one physics step and can hit whoever is standing on the crossroads.
	v.sync_to_physics = false
	v.transform = Transform3D(Basis.looking_at(lane.direction(), Vector3.UP), lane.position_at(spec.length * 0.5))
	add_child(v)
	var start_speed := spec.max_speed
	if not lane.vehicles.is_empty() and lane.entry_space() < 30.0:
		start_speed = minf(start_speed, lane.vehicles[-1].speed)
	v.setup(spec, lane, self, spec.length * 0.5, start_speed)
	lane.vehicles.append(v)
	return v


func _despawn(lane: TrafficLane) -> void:
	while not lane.vehicles.is_empty() and lane.vehicles[0].rear() > lane.def.length:
		var v: Vehicle = lane.vehicles.pop_front()
		if v.spec.is_emergency:
			_emergencies.erase(v)
			if _emergencies.is_empty():
				EventBus.emergency_state_changed.emit(false)
		v.queue_free()


## With a small chance (LevelData.bad_actor_chance) a new road user becomes a rule breaker.
## Only misbehaviours that make sense at this junction are picked.
func _maybe_make_bad(spec: VehicleSpec, lane: TrafficLane) -> void:
	if level.bad_actor_chance <= 0.0 or spec.kind not in VehicleSpec.CAN_MISBEHAVE:
		return
	if rng.randf() >= level.bad_actor_chance:
		return
	var options := {}   # misbehaviour -> weight
	if lights:
		options[VehicleSpec.Misbehaviour.RUNS_RED] = 4
	else:
		if level.crossing_type == LevelData.CrossingType.ZEBRA:
			options[VehicleSpec.Misbehaviour.IGNORES_ZEBRA] = 3
		if lane.def.axis == StreetLayout.Axis.NS:
			options[VehicleSpec.Misbehaviour.IGNORES_PRIORITY] = 3
	options[VehicleSpec.Misbehaviour.SPEEDING] = 2
	options[VehicleSpec.Misbehaviour.DISTRACTED] = 1
	var total := 0
	for w: int in options.values():
		total += w
	var r := rng.randi_range(1, total)
	for m: int in options:
		r -= options[m]
		if r <= 0:
			spec.make_bad(m, rng)
			return


func _pick_road_kind(lane: TrafficLane) -> String:
	var r := rng.randf()
	if lights == null and lane.def.axis == StreetLayout.Axis.NS:
		# Side streets: no buses or lorries.
		return "van" if r < 0.15 else ("motorbike" if r < 0.15 + level.motorbike_share else "car")
	if r < level.bus_share:
		return "bus"
	r -= level.bus_share
	if r < level.truck_share:
		return "truck"
	r -= level.truck_share
	if r < level.motorbike_share:
		return "motorbike"
	return "van" if rng.randf() < 0.15 else "car"


func _pick_bike_kind() -> String:
	var r := rng.randf()
	if r < level.fatbike_share:
		return "fatbike"
	r -= level.fatbike_share
	if r < level.race_group_share:
		return "racebike"
	return "bike"


func _update_emergency_schedule() -> void:
	while not _emergency_queue.is_empty() and play_time >= _emergency_queue[0]:
		if not _spawn_emergency():
			return   # no room right now, try again next tick
		_emergency_queue.pop_front()


func _spawn_emergency() -> bool:
	var candidates: Array[TrafficLane] = []
	for lane in lanes:
		if lane.def.kind == "road" and lane.entry_space() > 15.0:
			candidates.append(lane)
	if candidates.is_empty():
		return false
	# In the car stage, send it along the crossing road so the player has to stop and let it pass.
	if player.mode == Courier.Mode.CAR:
		var p := StreetLayout.to_2d(player.global_position)
		var player_axis := StreetLayout.Axis.NS if absf(p.x) < absf(p.y) else StreetLayout.Axis.EW
		var crossing_lanes := candidates.filter(func(l: TrafficLane) -> bool: return l.def.axis != player_axis)
		if not crossing_lanes.is_empty():
			candidates.assign(crossing_lanes)
	var lane: TrafficLane = candidates[rng.randi() % candidates.size()]
	var kind: String = VehicleSpec.EMERGENCY_KINDS[rng.randi() % VehicleSpec.EMERGENCY_KINDS.size()]
	var v := _spawn_vehicle(lane, VehicleSpec.create(kind, speed_limit, rng, wet))
	_emergencies.append(v)
	EventBus.emergency_state_changed.emit(true)
	return true


func _spawn_npc(runner: bool) -> void:
	var arm: String = StreetLayout.ARMS[rng.randi() % 4]
	var side := -1 if rng.randf() < 0.5 else 1
	var a2: Vector2 = StreetLayout.ARM_DIR[arm]
	var lat := StreetLayout.lateral_axis(arm) * (side * ((layout.walk_inner + layout.walk_outer) * 0.5 + rng.randf_range(-0.5, 0.5)))
	var d0 := layout.walk_outer + 3.0
	var d1 := StreetLayout.ARM_LENGTH - 6.0
	var npc := PedestrianNPC.new()
	npc.sync_to_physics = false
	npc.position = StreetLayout.to_3d(a2 * d0 + lat)
	add_child(npc)
	npc.setup(self, StreetLayout.to_3d(a2 * d0 + lat), StreetLayout.to_3d(a2 * d1 + lat), runner, rng)
	_npcs.append(npc)


func _build_signal_heads() -> void:
	for lane in lanes:
		var dir := lane.direction()
		var right := Vector3(-dir.z, 0.0, dir.x)
		var is_road := lane.def.kind == "road"
		var head := SignalHead.new()
		add_child(head)
		head.position = lane.position_at(lane.def.stop_offset) + right * (2.35 if is_road else 1.25)
		head.build(SignalHead.Kind.VEHICLE if is_road else SignalHead.Kind.BIKE, -dir)
		_heads.append({"node": head, "axis": lane.def.axis})
	for c in layout.crossings:
		if c.type != LevelData.CrossingType.SIGNAL:
			continue
		for b in c.buttons:
			var ped := SignalHead.new()
			add_child(ped)
			ped.position = b
			# Like in the Netherlands, you look at the light on the other side of the road:
			# each pole's pedestrian light faces across the crossing.
			var lat3 := StreetLayout.to_3d(c.walk_dir)
			var across := -lat3 * signf(lat3.dot(b - c.center))
			ped.build(SignalHead.Kind.PEDESTRIAN, across)
			_heads.append({"node": ped, "crossing": c})
			# The push button faces the waiting area next to the crossing.
			var button := SignalHead.new()
			add_child(button)
			button.position = b
			button.build(SignalHead.Kind.BUTTON, -StreetLayout.to_3d(StreetLayout.ARM_DIR[c.arm]))
			_heads.append({"node": button, "crossing": c, "button": true})


func _update_heads() -> void:
	if lights == null:
		return
	for h in _heads:
		var node: SignalHead = h["node"]
		if h.has("axis"):
			node.set_state(lights.vehicle_state(h["axis"]))
		elif h.get("button", false):
			node.set_state(1 if (h["crossing"] as StreetLayout.Crossing).requested else 0)
		else:
			node.set_state(lights.ped_state(h["crossing"]))
