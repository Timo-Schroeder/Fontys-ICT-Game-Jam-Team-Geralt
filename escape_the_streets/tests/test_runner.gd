extends Node
## Automated checks for the core systems. Run headless from the project folder:
##   godot --headless --path . --fixed-fps 60 res://tests/test_runner.tscn
## Exit code = number of failed checks (0 = all good).
##
## 1. Street geometry: what surface is where.
## 2. Traffic lights: phases never give conflicting greens; push button works.
## 3. Traffic simulation for all 30 levels: no crashes between AI vehicles, no deadlocks.
## 4. Rules: walking on the road, red light, forcing a car to brake, zebra yield, give way.
## 5. Autopilot: plays level 1-1 start to finish with the real player controller.

const LEVEL_SCENE := preload("res://scenes/level.tscn")

var failures := 0
var checks := 0
var _violations: Array[int] = []
var _finished: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.save_enabled = false
	EventBus.violation.connect(func(t: int, _c: Dictionary) -> void: _violations.append(t))
	EventBus.level_finished.connect(func(ok: bool, stars: int) -> void: _finished.append([ok, stars]))
	await get_tree().process_frame
	_test_layout()
	_test_lights()
	if not OS.has_environment("SKIP_TRAFFIC"):
		await _test_traffic_all_levels()
	await _test_rules()
	await _test_autopilot_level_1_1()
	await _test_autopilot_bike_2_1()
	await _test_van_3_1()
	await _test_free_look()
	print("\n==== %d checks, %d failed ====" % [checks, failures])
	get_tree().quit(failures)


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("  FAIL: ", what)


func section(title: String) -> void:
	print("\n-- ", title)


# --- 1. Geometry ---------------------------------------------------------------------------

func _test_layout() -> void:
	section("Street layout")
	var lvl := _custom_level(true)
	var L := StreetLayout.new(lvl)
	var S := StreetLayout.Surface
	check(L.classify(Vector2(1.75, 30)).surface == S.ROAD, "lane centre is road")
	check(L.classify(Vector2(5.0, 30)).surface == S.BIKE_PATH, "x=5 is bike path")
	check(L.classify(Vector2(7.0, 30)).surface == S.SIDEWALK, "x=7 is sidewalk")
	check(L.classify(Vector2(12.0, 30)).surface == S.GRASS, "x=12 is grass")
	var c := L.classify(Vector2(0.0, -7.0))
	check(c.surface == S.CROSSING and c.on_crossing_road and c.crossing.arm == "N", "north crossing, road part")
	check(L.classify(Vector2(5.0, -7.0)).surface == S.CROSSING and not L.classify(Vector2(5.0, -7.0)).on_crossing_road, "north crossing, bike part")
	check(L.classify(Vector2(0, 0)).in_junction, "centre is junction")
	check(L.expected_direction(Vector2(5, 30), StreetLayout.Axis.NS) == Vector2(0, -1), "east side goes north")
	check(StreetLayout.parse_spot("S-W-30")["side"] == -1, "parse spot")
	check(StreetLayout.parse_spot("N-N-30").is_empty(), "reject bad spot side")
	for ld in L.lanes:
		check(ld.stop_offset > 50.0 and ld.stop_offset < ld.junction_enter, "%s stop line before junction" % ld.name)
		check(ld.crossings.size() == 2, "%s passes 2 crossings" % ld.name)
	var no_bike := StreetLayout.new(_custom_level(false))
	check(no_bike.classify(Vector2(5.0, 30)).surface == S.SIDEWALK, "no bike path: x=5 is sidewalk")
	check(no_bike.lanes.size() == 4, "no bike path: only road lanes")


# --- 2. Lights ----------------------------------------------------------------------------

func _test_lights() -> void:
	section("Traffic lights")
	var lvl := _custom_level(true)
	var L := StreetLayout.new(lvl)
	var lights := TrafficLightController.new()
	lights.setup(L.crossings)
	var G := TrafficLightController.Light.GREEN
	var conflict := false
	var ped_green_seen := false
	for i in 1200:   # 60 s
		lights.tick(0.05)
		if lights.vehicle_state(0) != TrafficLightController.Light.RED and lights.vehicle_state(1) != TrafficLightController.Light.RED:
			conflict = true
		for cr in L.crossings:
			if lights.ped_state(cr) == G:
				ped_green_seen = true
				if lights.vehicle_state(cr.road_axis) != TrafficLightController.Light.RED:
					conflict = true
	check(not conflict, "never two conflicting greens")
	check(not ped_green_seen, "no pedestrian green without pressing the button")
	var north: StreetLayout.Crossing = L.crossings[0]
	lights.press_button(north)
	var got_green := false
	for i in 1200:
		lights.tick(0.05)
		if lights.ped_state(north) == G:
			got_green = true
			break
	check(got_green, "pedestrian green after pressing the button")
	lights.preempt_axis = StreetLayout.Axis.EW
	for i in 200:
		lights.tick(0.05)
	check(lights.vehicle_state(StreetLayout.Axis.EW) == G and lights.vehicle_state(StreetLayout.Axis.NS) == TrafficLightController.Light.RED,
			"emergency pre-emption gives green to its axis")
	lights.free()


# --- 3. Traffic on all levels --------------------------------------------------------------

func _test_traffic_all_levels() -> void:
	section("Traffic simulation, all levels (180 s each)")
	for data in GameState.levels:
		var level := await _load_level(data)
		var traffic: TrafficManager = level.traffic
		traffic.player_active = false
		var crashes := 0
		var order_errors := 0
		var spawned := {}
		var head_wait := 0.0          # longest wait at a stop line (front of a queue)
		var crossed := {}             # lane name -> vehicles that drove through the junction
		var counted := {}
		for i in 3600:
			traffic.tick(0.05, true)
			for lane in traffic.lanes:
				var prev: Vehicle = null
				for v: Vehicle in lane.vehicles:
					var id := v.get_instance_id()
					spawned[id] = true
					if prev and prev.rear() < v.front() - 0.05:
						order_errors += 1
					prev = v
					if absf(v.front() - lane.def.stop_offset) < 1.0:
						head_wait = maxf(head_wait, v.waiting_time)
					if v.rear() > lane.def.junction_exit and not counted.has(id):
						counted[id] = true
						crossed[lane.def.name] = int(crossed.get(lane.def.name, 0)) + 1
			crashes += _junction_overlaps(traffic.vehicles_in_junction)
		var stuck_lanes: Array[String] = []
		for lane in traffic.lanes:
			var density := data.car_density if lane.def.kind == "road" else data.bike_density
			if density > 0.0 and int(crossed.get(lane.def.name, 0)) == 0:
				stuck_lanes.append(lane.def.name)
		var id_text := data.level_id()
		check(crashes == 0, "%s: no crashes in junction (got %d overlap frames)" % [id_text, crashes])
		check(order_errors == 0, "%s: vehicles keep their distance (got %d)" % [id_text, order_errors])
		check(head_wait < 60.0, "%s: nobody waits more than 60 s at a stop line (longest %.0f s)" % [id_text, head_wait])
		check(stuck_lanes.is_empty(), "%s: traffic gets through on every lane (stuck: %s)" % [id_text, ", ".join(stuck_lanes)])
		var ok := crashes == 0 and order_errors == 0 and head_wait < 60.0 and stuck_lanes.is_empty()
		print("  %-5s %-28s vehicles %3d  longest wait at line %4.1f s  %s" % [id_text, data.title, spawned.size(), head_wait, "ok" if ok else "PROBLEM"])
		await _unload(level)


func _junction_overlaps(vs: Array) -> int:
	var n := 0
	for i in vs.size():
		for j in range(i + 1, vs.size()):
			var a: Vehicle = vs[i]
			var b: Vehicle = vs[j]
			if a.lane.def.axis == b.lane.def.axis:
				continue
			if _footprint(a).grow(-0.05).intersects(_footprint(b).grow(-0.05)):
				n += 1
	return n


func _footprint(v: Vehicle) -> Rect2:
	var d := v.lane.def.dir.abs()
	var lat := Vector2(d.y, d.x)
	var size := d * v.spec.length + lat * v.spec.width
	var c := StreetLayout.to_2d(v.global_position)
	return Rect2(c - size * 0.5, size)


# --- 4. Rules -------------------------------------------------------------------------------

func _test_rules() -> void:
	section("Rules")
	# Walking on the road -> police stop, star lost, back on the sidewalk.
	var data := _custom_level(false)
	var level := await _load_level(data)
	level._on_popup_action("start")
	var courier: Courier = level.courier
	_violations.clear()
	courier.teleport(Vector3(1.75, 0, 30), Vector3.FORWARD)
	await _physics_frames(40)
	check(_violations.has(RuleBook.Violation.WALKING_ON_ROAD), "walking on the road is reported")
	check(level.rules.stars == 2, "police stop costs a star (stars=%d)" % level.rules.stars)
	check(level.popup.is_open and level.state == level.State.POLICE_STOP, "police popup shown")
	level._on_popup_action("continue")
	await _physics_frames(2)
	var surf: int = level.layout.classify(StreetLayout.to_2d(courier.global_position)).surface
	check(surf in [StreetLayout.Surface.SIDEWALK, StreetLayout.Surface.PAD, StreetLayout.Surface.GRASS], "put back somewhere safe")

	# Red light: step onto the signalled crossing while the pedestrian light is red.
	_violations.clear()
	level.rules.restart_cooldowns()
	var lights: TrafficLightController = level.traffic.lights
	lights.phase = 0   # NS green -> crossing the NS road (north crossing) is red
	lights.phase_time = 0.0
	courier.teleport(Vector3(-4.6, 0, -5.25), Vector3.RIGHT)   # waiting area of the north crossing
	level.monitor.reset()
	await _physics_frames(5)
	courier.teleport(Vector3(-2.0, 0, -5.25), Vector3.RIGHT)  # on the crossing, road part
	await _physics_frames(3)
	check(_violations.has(RuleBook.Violation.RED_LIGHT), "crossing on red is reported")
	if level.popup.is_open:
		level._on_popup_action("continue")
	await _unload(level)

	# Unmarked crossing: stepping out 10 m in front of a car -> it brakes hard (FORCED_BRAKE)
	# but manages to stop.
	var unmarked := _custom_level(true)
	unmarked.junction_control = LevelData.JunctionControl.PRIORITY_ROAD
	unmarked.crossing_type = LevelData.CrossingType.NONE
	level = await _load_level(unmarked)
	level._on_popup_action("start")
	courier = level.courier
	var traffic: TrafficManager = level.traffic
	var lane: TrafficLane = traffic.lanes[2]   # eastbound main road, z = +1.75
	var player_pos := Vector3(-7.25, 0, 1.75)  # on the west crossing, in the eastbound lane
	var player_offset := lane.project(player_pos).x
	var car := traffic._spawn_vehicle(lane, VehicleSpec.create("car", 8.33, traffic.rng, false))
	car.offset = player_offset - 10.0 - car.spec.length * 0.5
	car.speed = 8.33
	_violations.clear()
	courier.teleport(player_pos, Vector3.BACK)
	await _physics_frames(150)
	check(_violations.has(RuleBook.Violation.FORCED_BRAKE), "stepping in front of a car is reported as FORCED_BRAKE")
	check(not _violations.has(RuleBook.Violation.COLLISION), "the car manages to stop (no collision)")
	check(not _violations.has(RuleBook.Violation.WALKING_ON_ROAD), "standing on a crossing is not 'walking on the road'")
	await _unload(level)

	# Zebra: a pedestrian waiting next to the zebra makes cars stop.
	var zebra := _custom_level(true)
	zebra.junction_control = LevelData.JunctionControl.PRIORITY_ROAD
	zebra.crossing_type = LevelData.CrossingType.ZEBRA
	level = await _load_level(zebra)
	level._on_popup_action("start")
	courier = level.courier
	traffic = level.traffic
	lane = traffic.lanes[2]   # eastbound road lane (main road)
	var entry: Dictionary = lane.def.crossings[0]
	car = traffic._spawn_vehicle(lane, VehicleSpec.create("car", 8.33, traffic.rng, false))
	car.offset = 15.0
	car.speed = 8.33
	# Wait on the sidewalk next to the west crossing.
	var cr: StreetLayout.Crossing = entry["crossing"]
	courier.teleport(Vector3(-7.25, 0, -6.8), Vector3.BACK)
	_violations.clear()
	await _physics_frames(600)
	check(cr.claimed, "standing next to the zebra claims it")
	check(car.speed < 0.2 and car.front() < entry["enter"], "car stops before the zebra (speed %.1f)" % car.speed)
	check(_violations.is_empty(), "waiting at the zebra is not a violation")
	await _unload(level)

	# Give way: a side-road car waits for main-road traffic.
	level = await _load_level(zebra)
	traffic = level.traffic
	var side_lane: TrafficLane = traffic.lanes[0]   # southbound = side road
	var main_lane: TrafficLane = traffic.lanes[2]   # eastbound = main road
	var side_car := traffic._spawn_vehicle(side_lane, VehicleSpec.create("car", 8.33, traffic.rng, false))
	side_car.offset = side_lane.def.stop_offset - 4.0
	side_car.speed = 0.0
	var main_car := traffic._spawn_vehicle(main_lane, VehicleSpec.create("car", 8.33, traffic.rng, false))
	main_car.offset = main_lane.def.junction_enter - 30.0
	main_car.speed = 8.33
	check(not traffic.is_clear_for(side_car), "side road must wait for an approaching main-road car")
	main_car.offset = main_lane.def.junction_exit + 10.0
	check(traffic.is_clear_for(side_car), "side road may go when the main road is clear")
	await _unload(level)


# --- 5. Autopilot ---------------------------------------------------------------------------

func _test_autopilot_level_1_1() -> void:
	section("Autopilot plays level 1-1")
	var data: LevelData = GameState.levels[0].duplicate()
	data.walkers = 0   # the autopilot does not walk around people
	var level := await _load_level(data)
	level._on_popup_action("start")
	var courier: Courier = level.courier
	var traffic: TrafficManager = level.traffic
	var L: StreetLayout = level.layout
	var west: StreetLayout.Crossing = _crossing(L, "W")
	var north: StreetLayout.Crossing = _crossing(L, "N")
	var mid := (L.walk_inner + L.walk_outer) * 0.5
	var pickup := L.spot(data.pickup_spot)
	var delivery := L.spot(data.delivery_spot)
	# Waypoints: [position, crossing to press and wait for (or null)]
	var route := [
		[Vector3(-mid, 0, 30), null],
		[Vector3(-mid, 0, L.walk_inner + 0.6), west],
		[Vector3(-mid, 0, -(L.walk_inner + 0.6)), null],
		[Vector3(-mid, 0, pickup.distance * -1.0), null],
		[pickup.pad_center, null],
		[Vector3(-mid, 0, -pickup.distance), null],
		[Vector3(-(L.walk_inner + 0.6), 0, -mid), north],
		[Vector3(L.walk_inner + 0.6, 0, -mid), null],
		[Vector3(mid, 0, -delivery.distance), null],
		[delivery.pad_center, null],
	]
	_violations.clear()
	_finished.clear()
	var frames := 0
	for wp: Array in route:
		var target: Vector3 = wp[0]
		var button: StreetLayout.Crossing = wp[1]
		frames += await _walk_to(courier, target)
		if button:
			traffic.press_button(button)
			while traffic.lights.ped_state(button) != TrafficLightController.Light.GREEN or traffic.lights.phase_time > 2.0:
				await get_tree().physics_frame
				frames += 1
				if frames > 60 * 400 or level.state != level.State.PLAYING:
					break
		if level.state != level.State.PLAYING:
			break
	await _physics_frames(10)
	Input.action_release("move_forward")
	var names: Array[String] = []
	for v in _violations:
		names.append(RuleBook.name_of(v))
	check(_violations.is_empty(), "no rules broken by the autopilot (%s)" % ", ".join(names))
	check(not _finished.is_empty() and _finished[0][0] == true, "level 1-1 completed")
	if not _finished.is_empty():
		print("  finished: success=%s stars=%d after %.0f s of play" % [_finished[0][0], _finished[0][1], frames / 60.0])
	await _unload(level)


func _test_autopilot_bike_2_1() -> void:
	section("Autopilot rides level 2-1 on the bike")
	var data: LevelData = GameState.levels[10].duplicate()
	data.walkers = 0
	var level := await _load_level(data)
	level._on_popup_action("start")
	var c: Courier = level.courier
	var traffic: TrafficManager = level.traffic
	_violations.clear()
	_finished.clear()
	var playing := func() -> bool: return level.state == level.State.PLAYING
	var log_violation := func(t: int, ctx: Dictionary) -> void:
		print("    [bike] %s %s at %s speed %.1f" % [RuleBook.name_of(t), ctx, c.global_position, c.forward_speed])
	EventBus.violation.connect(log_violation)
	# Out of the depot via the driveway, onto the bike path (east side, northbound).
	await _ride_to(c, Vector3(5, 0, 40), 2.0)
	await _ride_to(c, Vector3(5, 0, 24), 4.0, traffic)
	await _brake(c)
	var waited := 0
	while playing.call() and waited < 60 * 120 and not (traffic.lights.vehicle_state(StreetLayout.Axis.NS) == TrafficLightController.Light.GREEN and traffic.lights.phase_time < 1.0):
		await get_tree().physics_frame
		waited += 1
	# Straight through the junction on green, then into the driveway of B.
	await _ride_to(c, Vector3(5, 0, -30), 5.0, traffic)
	await _ride_to(c, Vector3(11, 0, -30), 2.0)
	await _brake(c)
	check(level.has_package, "bike: package picked up at B")
	# Back to the driveway, wait for a gap, cross the road straight to the west bike path.
	await _ride_to(c, Vector3(7.2, 0, -30), 1.5)
	await _brake(c)
	waited = 0
	while playing.call() and waited < 60 * 120 and not _road_clear_at(traffic, -30.0):
		await get_tree().physics_frame
		waited += 1
	await _ride_to(c, Vector3(-5, 0, -30), 4.5)
	await _ride_to(c, Vector3(-5, 0, -24), 2.5)
	await _ride_to(c, Vector3(-11, 0, -24), 2.0)
	await _brake(c)
	await _physics_frames(10)
	var names: Array[String] = []
	for v in _violations:
		names.append(RuleBook.name_of(v))
	check(_violations.is_empty(), "bike: no rules broken by the autopilot (%s)" % ", ".join(names))
	check(not _finished.is_empty() and _finished[0][0] == true, "bike: level 2-1 completed")
	if not _finished.is_empty():
		print("  finished: success=%s stars=%d" % [_finished[0][0], _finished[0][1]])
	EventBus.violation.disconnect(log_violation)
	await _unload(level)


func _test_van_3_1() -> void:
	section("Van drives through the junction in level 3-1")
	var data: LevelData = GameState.levels[20].duplicate()
	data.walkers = 0
	var level := await _load_level(data)
	level._on_popup_action("start")
	var c: Courier = level.courier
	var traffic: TrafficManager = level.traffic
	var lane: TrafficLane = traffic.lanes[1]   # northbound road lane, x = +1.75
	var waited := 0
	while waited < 60 * 60:
		var free := true
		for v: Vehicle in lane.vehicles:
			if absf(v.global_position.z - 45.0) < 14.0:
				free = false
		if free:
			break
		await get_tree().physics_frame
		waited += 1
	_violations.clear()
	var log_violation := func(t: int, ctx: Dictionary) -> void:
		print("    [van] %s %s at %s speed %.1f phase %d t=%.1f" % [RuleBook.name_of(t), ctx, c.global_position, c.forward_speed, traffic.lights.phase, traffic.lights.phase_time])
		for l in traffic.lanes:
			for o: Vehicle in l.vehicles:
				if o.global_position.distance_to(c.global_position) < 9.0:
					print("       near: %s %s pos=%s speed=%.1f off=%.1f" % [o.spec.kind, o.lane.def.name, o.global_position, o.speed, o.offset])
	EventBus.violation.connect(log_violation)
	c.teleport(Vector3(1.75, 0, 45), Vector3.FORWARD)
	level.monitor.reset()
	await _ride_to(c, Vector3(1.75, 0, 22), 7.0, traffic)
	await _ride_to(c, Vector3(1.75, 0, 13.5), 3.0, traffic)
	await _brake(c)
	waited = 0
	while waited < 60 * 120 and not (traffic.lights.vehicle_state(StreetLayout.Axis.NS) == TrafficLightController.Light.GREEN and traffic.lights.phase_time < 1.0):
		await get_tree().physics_frame
		waited += 1
	await _ride_to(c, Vector3(1.75, 0, -40), 7.5, traffic)
	await _brake(c)
	var names: Array[String] = []
	for v in _violations:
		names.append(RuleBook.name_of(v))
	check(_violations.is_empty(), "van: driving legally breaks no rules (%s)" % ", ".join(names))
	check(c.global_position.z < -30.0, "van: got through the junction (z=%.1f)" % c.global_position.z)
	EventBus.violation.disconnect(log_violation)
	await _unload(level)


func _test_free_look() -> void:
	section("First-person view and free look")
	# Bike: the mouse turns the head, not the bike.
	var bike: LevelData = GameState.levels[10]
	var level := await _load_level(bike)
	level._on_popup_action("start")
	var c: Courier = level.courier
	await _physics_frames(2)
	check(c.is_first_person(), "bike is first person")
	var eye_offset := c.camera.global_position - c.global_position
	check(eye_offset.y > 1.4 and Vector2(eye_offset.x, eye_offset.z).length() < 0.5, "bike camera sits at the rider's eyes (%s)" % eye_offset)
	check(c.camera.cull_mask & Courier.LAYER_OWN_BODY == 0, "first-person camera hides your own body")
	var heading_before := c.heading
	c.add_look(Vector2(-500, 0))   # move the mouse to the left
	await get_tree().process_frame
	check(is_equal_approx(c.heading, heading_before), "looking around does not steer the bike")
	check(c.look_yaw > 1.0, "head turned left (yaw %.2f)" % c.look_yaw)
	var angle := rad_to_deg(c.forward().signed_angle_to(c.view_direction(), Vector3.UP))
	check(angle > 60.0, "camera looks to the left of the bike (%.0f degrees)" % angle)
	c.add_look(Vector2(-5000, 0))
	check(c.look_yaw <= deg_to_rad(150.0) + 0.001, "head turn is limited to 150 degrees")
	c.add_look(Vector2(0, -5000))
	check(c.look_pitch <= deg_to_rad(55.0) + 0.001, "looking up is limited")
	c.look_forward()
	await _physics_frames(60)
	check(absf(c.look_yaw) < 0.02, "C turns the head back to the front (yaw %.3f)" % c.look_yaw)
	await _unload(level)

	# Van: driver's seat on the left, cockpit, two working mirrors.
	level = await _load_level(GameState.levels[20])
	level._on_popup_action("start")
	c = level.courier
	await _physics_frames(3)
	var local_eye := c.to_local(c.camera.global_position)
	check(local_eye.x < -0.3 and local_eye.y > 1.7, "van camera is in the driver's seat on the left (%s)" % local_eye)
	var mirrors := c.find_children("*", "SideMirror", true, false)
	check(mirrors.size() == 2, "van has two side mirrors (%d)" % mirrors.size())
	for m: SideMirror in mirrors:
		check(m.texture() != null, "mirror renders a picture")
	c.add_look(Vector2(0, 0))
	heading_before = c.heading
	c.add_look(Vector2(800, 0))   # look right, towards the passenger side
	check(is_equal_approx(c.heading, heading_before) and c.look_yaw < -1.0, "van: looking right does not steer")
	await _unload(level)

	# On foot: the mouse still turns the walker.
	level = await _load_level(GameState.levels[0])
	level._on_popup_action("start")
	c = level.courier
	await _physics_frames(2)
	check(not c.is_first_person(), "on foot is third person")
	heading_before = c.heading
	c.add_look(Vector2(-200, 120))
	check(c.heading > heading_before, "on foot the mouse turns you")
	await _unload(level)


func _ride_to(c: Courier, target: Vector3, speed: float, traffic: TrafficManager = null) -> void:
	var frames := 0
	while frames < 60 * 90 and not get_tree().paused:
		var to := target - c.global_position
		to.y = 0.0
		if to.length() < 0.6:
			break
		c.heading = atan2(-to.x, -to.z)
		var want := minf(speed, maxf(1.2, to.length()))
		if traffic:
			# Keep distance to whoever is riding in front of us.
			for lane in traffic.lanes:
				for v: Vehicle in lane.vehicles:
					var rel := v.global_position - c.global_position
					var ahead := rel.dot(c.forward())
					var side := absf(rel.dot(Vector3(-c.forward().z, 0, c.forward().x)))
					if ahead > 0.0 and ahead < 15.0 and side < 1.2:
						want = minf(want, maxf(0.0, ahead - v.spec.length * 0.5 - 2.5))
		Input.action_release("move_forward")
		Input.action_release("move_back")
		if c.forward_speed < want - 0.2:
			Input.action_press("move_forward")
		elif c.forward_speed > want + 0.3:
			Input.action_press("move_back")
		await get_tree().physics_frame
		frames += 1
	Input.action_release("move_forward")
	Input.action_release("move_back")


func _brake(c: Courier) -> void:
	Input.action_release("move_forward")
	Input.action_press("move_back")
	var frames := 0
	while c.forward_speed > 0.05 and frames < 300 and not get_tree().paused:
		await get_tree().physics_frame
		frames += 1
	Input.action_release("move_back")


## No traffic on the north-south road and bike paths coming towards z within 40 m.
func _road_clear_at(traffic: TrafficManager, z: float) -> bool:
	for lane in traffic.lanes:
		if lane.def.axis != StreetLayout.Axis.NS:
			continue
		for v: Vehicle in lane.vehicles:
			var vz := v.global_position.z
			if absf(vz - z) < 5.0:
				return false
			if (z - vz) * lane.def.dir.y > 0.0 and absf(vz - z) < 40.0:
				return false
	return true


func _walk_to(courier: Courier, target: Vector3) -> int:
	var frames := 0
	while frames < 60 * 120:
		var to := target - courier.global_position
		to.y = 0.0
		if to.length() < 0.35:
			break
		courier.heading = atan2(-to.x, -to.z)
		Input.action_press("move_forward")
		await get_tree().physics_frame
		frames += 1
		if courier.get_tree().paused:
			break
	Input.action_release("move_forward")
	return frames


func _crossing(L: StreetLayout, arm: String) -> StreetLayout.Crossing:
	for c in L.crossings:
		if c.arm == arm:
			return c
	return null


# --- Helpers ----------------------------------------------------------------------------

func _custom_level(bike_paths: bool) -> LevelData:
	var d := LevelData.new()
	d.title = "Test"
	d.has_bike_paths = bike_paths
	d.car_density = 0.0
	d.bike_density = 0.0
	d.walkers = 0
	d.start_spot = "S-W-30"
	d.pickup_spot = "N-W-26"
	d.delivery_spot = "N-E-30"
	return d


func _load_level(data: LevelData) -> Node:
	GameState.current_level = data
	var level := LEVEL_SCENE.instantiate()
	level.get_node("Traffic").fixed_seed = 1234
	add_child(level)
	await get_tree().process_frame
	return level


func _unload(level: Node) -> void:
	get_tree().paused = false
	Input.action_release("move_forward")
	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
