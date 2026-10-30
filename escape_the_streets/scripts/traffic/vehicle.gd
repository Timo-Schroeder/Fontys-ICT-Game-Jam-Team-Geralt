class_name Vehicle
extends AnimatableBody3D
## A car, bus, bike, ... driving along one TrafficLane.
##
## Driving model, every physics tick:
##   1. Collect the nearest point it must stop before: the vehicle ahead, the stop line
##      (red light / give way), a zebra crossing with a pedestrian, a crossing-road
##      vehicle in the junction, or the player.
##   2. Drive at the speed from which it can still stop comfortably before that point.
##   3. If the player forces it to brake harder than comfortable, report FORCED_BRAKE.
## Drivers notice the player only after their reaction time, so stepping out
## right in front of a vehicle is dangerous, just like in real life.
##
## A few road users break the rules (spec.misbehaviour, see VehicleSpec). They never
## cost the player a life when they have to brake; if they pass close by while the
## player waited safely, the player gets praise (EventBus.bad_actor).

const DETECT_RANGE := 60.0

var spec: VehicleSpec
var lane: TrafficLane
var traffic: TrafficManager
var offset := 0.0
var speed := 0.0
## Seconds this vehicle has been standing still (impatient drivers accept smaller gaps).
var waiting_time := 0.0
## Red-light runners decide once: 0 = not yet, 1 = run it, -1 = stop after all.
var red_decision := 0

## Where (offset) this rule breaker actually broke the rule, or -1.
var _broke_rule_at := -1.0
var _closest_to_player := INF
var _close_call := false
var _bad_actor_reported := false
var _player_seen_time := 0.0
var _player_reported := false
var _blocked_time := 0.0
var _flash_time := 0.0
var _beacons: Array[MeshInstance3D] = []
var _siren: ToneSynth


func setup(p_spec: VehicleSpec, p_lane: TrafficLane, p_traffic: TrafficManager, p_offset: float, p_speed: float) -> void:
	spec = p_spec
	lane = p_lane
	traffic = p_traffic
	offset = p_offset
	speed = p_speed
	collision_layer = 4    # vehicles
	collision_mask = 0
	sync_to_physics = false
	add_to_group("vehicles")
	_build_visual()
	_build_collision()
	_place()
	if spec.is_emergency:
		_siren = ToneSynth.new()
		add_child(_siren)
		_siren.position = Vector3(0, 2.0, 0)
		_siren.play_pattern(ToneSynth.Pattern.SIREN)


func front() -> float:
	return offset + spec.length * 0.5


func rear() -> float:
	return offset - spec.length * 0.5


func tick(delta: float, leader: Vehicle) -> void:
	var fr := front()
	var other_limit := INF       # nearest required stop, not caused by the player
	# 1a. Vehicle ahead in the same lane.
	if leader:
		other_limit = minf(other_limit, leader.rear() - fr - spec.min_gap)
	# 1b. Stop line: red light or give way.
	if fr <= lane.def.stop_offset + 0.3 and traffic.must_stop_at_line(self):
		other_limit = minf(other_limit, lane.def.stop_offset - fr)
	# 1c. Zebra crossings with a pedestrian on or next to them (emergency vehicles go on).
	if not spec.is_emergency and spec.misbehaviour != VehicleSpec.Misbehaviour.IGNORES_ZEBRA:
		for entry: Dictionary in lane.def.crossings:
			var c: StreetLayout.Crossing = entry["crossing"]
			if c.type != LevelData.CrossingType.ZEBRA or not c.claimed:
				continue
			var dist: float = entry["enter"] - 1.0 - fr
			if fr > entry["enter"] - 0.5:
				continue
			# Stop if we still can; a driver who is already too close drives on.
			if dist <= 0.0 or speed * speed / (2.0 * dist) <= spec.max_decel * 0.8:
				other_limit = minf(other_limit, maxf(dist, 0.0))
	# 1d. Do not enter the junction while crossing traffic is still on it
	#     (a slow cyclist who went through on orange, say).
	if fr < lane.def.junction_enter and traffic.junction_busy_for(self):
		var stop_at := lane.def.stop_offset if fr <= lane.def.stop_offset + 0.3 else lane.def.junction_enter - 0.3
		var dist := stop_at - fr
		if dist <= 0.0 or speed * speed / (2.0 * dist) <= spec.max_decel:
			other_limit = minf(other_limit, maxf(dist, 0.0))
	# 1e. Crossing-road vehicles inside the junction (safety net against crashes).
	for o: Vehicle in traffic.vehicles_in_junction:
		if o == self or o.lane.def.axis == lane.def.axis:
			continue
		other_limit = minf(other_limit, _obstacle_distance(o.global_position, o.spec.width * 0.5, o.spec.length * 0.5))
	# 1f. The player.
	var player_limit := INF
	var player_same_direction := false
	var pd := _player_distance()
	if pd < INF:
		_player_seen_time += delta
		# A player on a bike or in the van driving our way is simply the vehicle in front.
		var pl: Courier = traffic.player
		player_same_direction = pl.mode != Courier.Mode.WALK and pl.forward().dot(lane.direction()) > 0.7
		if player_same_direction or _player_seen_time >= spec.reaction_time:
			player_limit = pd
	else:
		_player_seen_time = 0.0
		_player_reported = false
		_blocked_time = 0.0

	var limit := minf(other_limit, player_limit)
	var limited_by_player := player_limit < other_limit

	# 2. Speed control.
	var desired := minf(spec.max_speed, traffic.speed_cap_for(self))
	var safe := sqrt(2.0 * spec.comfort_decel * maxf(limit, 0.0)) if limit < INF else INF
	var target := minf(desired, safe)
	var v_before := speed
	if speed < target:
		speed = minf(target, speed + spec.accel * delta)
	elif speed > target:
		var need := spec.comfort_decel
		if limit < INF:
			need = speed * speed / (2.0 * maxf(limit, 0.05))
		var decel := clampf(maxf(need, spec.comfort_decel), 0.0, spec.max_decel)
		speed = maxf(target, speed - decel * delta)
		# 3. Hard braking because of the player.
		if limited_by_player and not player_same_direction and not _player_reported \
				and need > spec.comfort_decel * 1.4 and v_before > 1.5:
			_player_reported = true
			_close_call = spec.misbehaviour != VehicleSpec.Misbehaviour.NONE
			_react_to_player()
			var kind := RuleBook.Violation.BLOCKED_EMERGENCY if spec.is_emergency else RuleBook.Violation.FORCED_BRAKE
			traffic.report_violation(kind, self)
	speed = maxf(speed, 0.0)

	# Standing still because the player is in the way while the road is otherwise free.
	if limited_by_player and not player_same_direction and speed < 0.3 and other_limit > 6.0:
		_blocked_time += delta
		if _blocked_time > 3.0 and not _player_reported:
			_player_reported = true
			_react_to_player()
			traffic.report_violation(RuleBook.Violation.BLOCKING_TRAFFIC, self)
	else:
		_blocked_time = 0.0

	waiting_time = waiting_time + delta if speed < 0.1 else 0.0
	var front_before := front()
	offset += speed * delta
	_place()
	if spec.misbehaviour != VehicleSpec.Misbehaviour.NONE:
		_track_rule_breaking(front_before)
	if spec.is_emergency:
		_flash_time += delta
		var on := fmod(_flash_time, 0.5) < 0.25
		for i in _beacons.size():
			_beacons[i].visible = on if i % 2 == 0 else not on


## Notice the moment this rule breaker actually breaks the rule, then check whether the
## player was close by and safe (praise) once it has driven on.
func _track_rule_breaking(front_before: float) -> void:
	var fr := front()
	if _broke_rule_at < 0.0:
		match spec.misbehaviour:
			VehicleSpec.Misbehaviour.RUNS_RED:
				if traffic.lights and front_before <= lane.def.stop_offset and fr > lane.def.stop_offset \
						and traffic.lights.vehicle_state(lane.def.axis) == TrafficLightController.Light.RED:
					_broke_rule_at = fr
			VehicleSpec.Misbehaviour.IGNORES_ZEBRA:
				for entry: Dictionary in lane.def.crossings:
					var c: StreetLayout.Crossing = entry["crossing"]
					if c.type == LevelData.CrossingType.ZEBRA and c.claimed \
							and front_before <= entry["enter"] and fr > entry["enter"]:
						_broke_rule_at = fr
			VehicleSpec.Misbehaviour.IGNORES_PRIORITY:
				# It only broke the rule if a careful driver would have waited for the player.
				if front_before <= lane.def.junction_enter and fr > lane.def.junction_enter \
						and traffic.player_active and not traffic.is_clear_for(self):
					_broke_rule_at = fr
		return
	if _bad_actor_reported or not traffic.player_active:
		return
	var p: Courier = traffic.player
	# Walkers only count when they were waiting at (or on) a crossing, not just walking by.
	if p.mode != Courier.Mode.WALK or _player_at_crossing(p):
		var gap := p.global_position - global_position
		_closest_to_player = minf(_closest_to_player, Vector2(gap.x, gap.z).length())
	if fr < _broke_rule_at + 22.0:
		return
	# Driven on: was the player nearby (waiting, or riding towards it) without being hit?
	_bad_actor_reported = true
	var nearby := 10.0 if p.mode == Courier.Mode.WALK else 14.0
	if not _close_call and _closest_to_player < nearby:
		EventBus.bad_actor.emit(spec.misbehaviour, spec.display_name, false)


func _player_at_crossing(p: Courier) -> bool:
	var p2 := StreetLayout.to_2d(p.global_position)
	for c in traffic.layout.crossings:
		if c.claim_rect.grow(1.0).has_point(p2):
			return true
	return false


## Distance from our front to an obstacle in our path, or INF if it is not in our path.
func _obstacle_distance(pos: Vector3, half_along: float, half_lateral: float) -> float:
	var proj := lane.project(pos)
	if absf(proj.y) > spec.width * 0.5 + half_lateral + 0.3:
		return INF
	if proj.x + half_along < rear():
		return INF   # behind us
	var d := proj.x - half_along - front() - 0.8
	if d > DETECT_RANGE:
		return INF
	return maxf(d, 0.0)


func _player_distance() -> float:
	var p: Courier = traffic.player
	if p == null or not traffic.player_active:
		return INF
	var ext := p.obstacle_extents(lane.direction())
	return _obstacle_distance(p.global_position, ext.x, ext.y)


func _react_to_player() -> void:
	if spec.is_bike:
		ToneSynth.one_shot(self, ToneSynth.Pattern.BELL, 0.5)
	else:
		ToneSynth.one_shot(self, ToneSynth.Pattern.HORN, 0.5)


func _place() -> void:
	var dir := lane.direction()
	global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), lane.position_at(offset))


func _on_hitbox_body_entered(body: Node3D) -> void:
	if not (body is Courier):
		return
	var courier := body as Courier
	if speed <= 0.8 and courier.get_real_velocity().length() <= 2.5:
		return   # walking into a parked car is not a crash
	# Double-check with the real positions: right after a level starts or the player is
	# teleported, the physics engine can report an overlap at the player's old position.
	var local := to_local(courier.global_position)
	var ext := courier.obstacle_extents(lane.direction())
	if absf(local.z) > spec.length * 0.5 + ext.x + 0.5 or absf(local.x) > spec.width * 0.5 + ext.y + 0.5:
		return
	traffic.report_violation(RuleBook.Violation.COLLISION, self)


# --- Building the greybox model ------------------------------------------------

func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(spec.width, spec.height, spec.length)
	shape.shape = box
	shape.position = Vector3(0, spec.height * 0.5, 0)
	add_child(shape)

	var hitbox := Area3D.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2   # player
	hitbox.monitorable = false
	var hshape := CollisionShape3D.new()
	var hbox := BoxShape3D.new()
	hbox.size = Vector3(spec.width + 0.2, spec.height, spec.length + 0.3)
	hshape.shape = hbox
	hshape.position = Vector3(0, spec.height * 0.5, 0)
	hitbox.add_child(hshape)
	add_child(hitbox)
	hitbox.body_entered.connect(_on_hitbox_body_entered)


func _build_visual() -> void:
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	if spec.visual_scene:
		visual.add_child(spec.visual_scene.instantiate())
		return
	if spec.is_bike:
		_build_bike(visual)
	else:
		_build_motor_vehicle(visual)
	if spec.misbehaviour == VehicleSpec.Misbehaviour.DISTRACTED:
		_build_phone_glow(visual)
	if traffic.show_bad_actors and spec.misbehaviour != VehicleSpec.Misbehaviour.NONE:
		var mark := Label3D.new()
		mark.text = "! " + VehicleSpec.Misbehaviour.keys()[spec.misbehaviour]
		mark.modulate = Color("ff3030")
		mark.font_size = 48
		mark.pixel_size = 0.01
		mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		mark.position = Vector3(0, spec.height + 0.8, 0)
		visual.add_child(mark)


func _build_motor_vehicle(v: Node3D) -> void:
	var L := spec.length
	var W := spec.width
	var H := spec.height
	var body := Greybox.mat(spec.color, 0.45)
	var glass := Greybox.mat(Color("1d2733"), 0.15)
	var tyre := Greybox.mat(Color("151515"))
	var wheel_r := 0.33 if L < 6.0 else 0.5
	match spec.kind:
		"bus":
			Greybox.box(v, Vector3(W, H - 0.4, L), Vector3(0, 0.4 + (H - 0.4) * 0.5, 0), body)
			Greybox.box(v, Vector3(W + 0.02, 0.9, L - 1.0), Vector3(0, H - 1.1, 0.3), glass)
		"truck", "fire":
			Greybox.box(v, Vector3(W, H - 0.5, 2.2), Vector3(0, 0.5 + (H - 0.5) * 0.5, -L * 0.5 + 1.1), body)
			Greybox.box(v, Vector3(W + 0.02, 0.8, 1.0), Vector3(0, H - 0.9, -L * 0.5 + 0.6), glass)
			var cargo_color := Greybox.mat(Color("b0b0b0") if spec.kind == "truck" else spec.color.darkened(0.15))
			Greybox.box(v, Vector3(W, H - 0.4, L - 2.4), Vector3(0, 0.4 + (H - 0.4) * 0.5, 1.2), cargo_color)
		"motorbike":
			Greybox.box(v, Vector3(0.35, 0.5, L * 0.8), Vector3(0, 0.6, 0), body)
			Greybox.capsule(v, 0.22, 0.9, Vector3(0, 1.15, 0.1), Greybox.mat(Color("333a44")))
			Greybox.sphere(v, 0.17, Vector3(0, 1.6, 0.05), Greybox.mat(Color("101010"), 0.3))
			wheel_r = 0.32
		_:
			# Car, van, ambulance, police: lower body + cabin.
			var lower_h := H * 0.5
			Greybox.box(v, Vector3(W, lower_h, L), Vector3(0, 0.25 + lower_h * 0.5, 0), body)
			var cabin_len := L * (0.55 if spec.kind == "car" or spec.kind == "police" else 0.75)
			var cabin_z := 0.2 if spec.kind == "car" or spec.kind == "police" else 0.35
			Greybox.box(v, Vector3(W * 0.9, H - lower_h - 0.25, cabin_len),
					Vector3(0, 0.25 + lower_h + (H - lower_h - 0.25) * 0.5, cabin_z), glass)
			if spec.kind == "police":
				Greybox.box(v, Vector3(W + 0.02, 0.18, L * 0.9), Vector3(0, 0.6, 0), Greybox.mat(Color("1f4fa0")))
				Greybox.box(v, Vector3(W + 0.03, 0.08, L * 0.9), Vector3(0, 0.45, 0), Greybox.mat(Color("f28c1c")))
			if spec.kind == "ambulance":
				Greybox.box(v, Vector3(W + 0.02, 0.2, L * 0.9), Vector3(0, 0.75, 0), Greybox.mat(Color("2457b5")))
	# Wheels (not for the motorbike, which gets two thin ones).
	var axle_front := -L * 0.5 + maxf(0.8, L * 0.18)
	var axle_rear := L * 0.5 - maxf(0.8, L * 0.18)
	if spec.kind == "motorbike":
		for z: float in [axle_front + 0.1, axle_rear - 0.1]:
			var w := Greybox.cylinder(v, wheel_r, 0.12, Vector3(0, wheel_r, z), tyre)
			w.rotation.z = PI * 0.5
	else:
		for x: float in [-W * 0.5 + 0.05, W * 0.5 - 0.05]:
			for z: float in [axle_front, axle_rear]:
				var w := Greybox.cylinder(v, wheel_r, 0.25, Vector3(x, wheel_r, z), tyre)
				w.rotation.z = PI * 0.5
	# Lights. Front is -Z.
	var head := Greybox.glow(Color("fff6d8"), 3.0 if traffic.is_dark else 0.6)
	var tail := Greybox.glow(Color("ff2a1a"), 2.0 if traffic.is_dark else 0.5)
	for x: float in [-W * 0.35, W * 0.35]:
		Greybox.box(v, Vector3(0.25, 0.12, 0.05), Vector3(x, 0.65, -L * 0.5 - 0.01), head)
		Greybox.box(v, Vector3(0.25, 0.12, 0.05), Vector3(x, 0.65, L * 0.5 + 0.01), tail)
	if traffic.is_dark and spec.kind != "motorbike":
		var lamp := SpotLight3D.new()
		lamp.position = Vector3(0, 0.7, -L * 0.5 - 0.1)
		lamp.spot_range = 22.0
		lamp.spot_angle = 32.0
		lamp.light_energy = 2.5
		lamp.light_color = Color("fff3d6")
		lamp.rotation.x = -0.12
		v.add_child(lamp)
	if spec.is_emergency:
		var blue := Greybox.glow(Color("2a6bff"), 6.0)
		var roof_y := H + 0.08 if spec.kind != "police" else H + 0.12
		for x: float in [-W * 0.3, W * 0.3]:
			_beacons.append(Greybox.box(v, Vector3(0.35, 0.16, 0.25), Vector3(x, roof_y, -L * 0.3), blue))


## The tell of a distracted road user: the blue glow of a phone. Riders hold it in their hand;
## in a car the glow shows on the windscreen and side windows at the driver's seat.
func _build_phone_glow(v: Node3D) -> void:
	var glow := Greybox.glow(Color("3aa8ff"), 2.2)
	if spec.is_bike:
		Greybox.box(v, Vector3(0.08, 0.13, 0.02), Vector3(0.12, 1.4, -0.3), glow)
		return
	if spec.kind == "motorbike":
		Greybox.box(v, Vector3(0.08, 0.13, 0.02), Vector3(0.18, 1.25, -0.2), glow)
		return
	# Same cabin shape as _build_motor_vehicle() for cars and vans.
	var L := spec.length
	var W := spec.width
	var H := spec.height
	var short_cabin := spec.kind == "car" or spec.kind == "police"
	var cabin_len := L * (0.55 if short_cabin else 0.75)
	var cabin_z := 0.2 if short_cabin else 0.35
	var cabin_front := cabin_z - cabin_len * 0.5
	var y := 0.25 + H * 0.5 + (H * 0.5 - 0.25) * 0.5
	var x := -W * 0.22   # the driver sits on the left
	Greybox.box(v, Vector3(0.3, 0.2, 0.02), Vector3(x, y, cabin_front - 0.015), glow)
	Greybox.box(v, Vector3(0.02, 0.2, 0.32), Vector3(-W * 0.45 - 0.015, y, cabin_front + 0.45), glow)
	Greybox.box(v, Vector3(0.02, 0.12, 0.2), Vector3(W * 0.45 + 0.015, y, cabin_front + 0.45), Greybox.glow(Color("3aa8ff"), 1.2))


func _build_bike(v: Node3D) -> void:
	var tyre := Greybox.mat(Color("151515"))
	var wheel_w := 0.2 if spec.kind == "fatbike" else 0.06
	var wheel_r := 0.28 if spec.kind == "fatbike" else 0.34
	for z: float in [-0.6, 0.6]:
		var w := Greybox.cylinder(v, wheel_r, wheel_w, Vector3(0, wheel_r, z), tyre)
		w.rotation.z = PI * 0.5
	Greybox.box(v, Vector3(0.06, 0.06, 1.1), Vector3(0, 0.6, 0), Greybox.mat(Color("5a5a5a")))
	var lean := 0.3 if spec.kind == "racebike" else 0.0
	var rider := Greybox.person(v, spec.color, 1.65)
	rider.position = Vector3(0, 0.35, 0.15)
	rider.rotation.x = -lean
	if spec.kind == "racebike":
		Greybox.sphere(v, 0.16, Vector3(0, 1.82, -0.3), Greybox.mat(Color("ffffff"), 0.3))
	if traffic.is_dark:
		Greybox.sphere(v, 0.06, Vector3(0, 0.9, -0.75), Greybox.glow(Color("fffbe6"), 4.0))
		Greybox.sphere(v, 0.05, Vector3(0, 0.8, 0.75), Greybox.glow(Color("ff2a1a"), 3.0))
