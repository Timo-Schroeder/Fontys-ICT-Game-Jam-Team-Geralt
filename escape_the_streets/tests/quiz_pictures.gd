extends Node
## Renders the pictures for the bike quiz (first person on the bike, HUD hidden).
## Needs a real renderer (not --headless):
##   godot --path . res://tests/quiz_pictures.tscn -- <output_dir>
## Each scene: a level, where the bike stands, where you look, the traffic light phase,
## and the road users placed for the question.

const LEVEL_SCENE := preload("res://scenes/level.tscn")

var out_dir := "user://quiz"
## Optional second argument: comma-separated picture names, to render only those.
var only: PackedStringArray = []
var M := VehicleSpec.Misbehaviour


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.save_enabled = false
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		only = args[1].split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame

	# 1. Red bike light, nobody coming.
	await _shot("q01_rood", "2-2", Vector3(5, 0, 16), 0.0, -0.02, 3, func(_l: Node, _t: TrafficManager) -> void: pass)
	# 2. Light turns orange, a few metres before the line.
	await _shot("q02_oranje", "2-2", Vector3(5, 0, 13.5), 0.0, -0.02, 1, func(_l: Node, _t: TrafficManager) -> void: pass)
	# 3. Shark teeth on the bike path, a car on the main road.
	await _shot("q03_haaientanden", "2-3", Vector3(5, 0, 17), 0.0, -0.12, -1, func(_l: Node, t: TrafficManager) -> void:
		_park(t, "road_eastbound", -16.0, "car", Color("3f6fb5")))
	# 4. On the priority road, a car waiting on the right at the side street.
	await _shot("q04_voorrangsweg", "2-4", Vector3(-17, 0, 5), 0.0, -0.05, -1, func(_l: Node, t: TrafficManager) -> void:
		_park(t, "road_northbound", 11.0, "car", Color("b33a3a")), Vector3.RIGHT)
	# 5. You have green; a car from the left is not slowing down.
	await _shot("q05_groen_auto", "2-2", Vector3(5, 0, 11.2), 0.9, -0.05, 0, func(_l: Node, t: TrafficManager) -> void:
		# Past its stop line and in the junction: driving through red towards your crossing.
		var car := _park(t, "road_eastbound", -12.0, "car", Color("2f5597"))
		car.lane.vehicles.erase(car)   # take it out of the traffic so it stays where we put it
		car.global_position = Vector3(-3.0, 0, 1.75))
	# 6. Someone waiting at the zebra.
	await _shot("q06_zebrapad", "2-3", Vector3(5, 0, 15.5), 0.0, -0.08, -1, func(l: Node, _t: TrafficManager) -> void:
		var p := Greybox.person(l, Color("7b4fb0"), 1.7)
		p.position = Vector3(7.3, 0.01, 7.2)
		p.rotation.y = PI * 0.5)
	# 7. No bike path: on the road.
	await _shot("q07_geen_fietspad", "2-8", Vector3(2.6, 0, 26), 0.0, -0.06, 0, func(_l: Node, _t: TrafficManager) -> void: pass)
	# 8. Dark, bike light off.
	await _shot("q08_donker", "2-6", Vector3(5, 0, 26), 0.0, -0.06, 0, func(_l: Node, _t: TrafficManager) -> void: pass,
			Vector3.FORWARD, LevelData.TimeOfDay.NIGHT)
	# 9. Ambulance behind you (looking back over your left shoulder).
	await _shot("q09_ambulance", "2-9", Vector3(5, 0, 20), 2.6, 0.0, 0, func(_l: Node, t: TrafficManager) -> void:
		_park(t, "road_northbound", 28.5, "ambulance", Color.WHITE))
	# 10. A cyclist next to you looking at a phone.
	await _shot("q10_telefoon", "2-5", Vector3(5.75, 0, 21.0), 0.1, -0.12, -1, func(_l: Node, t: TrafficManager) -> void:
		_park(t, "bike_northbound", 17.2, "bike", Color("2e8b57"), M.DISTRACTED))
	get_tree().quit()


func _shot(file_name: String, level_id: String, pos: Vector3, yaw: float, pitch: float, phase: int,
		setup: Callable, facing: Vector3 = Vector3.FORWARD, time_of_day: int = -1) -> void:
	if not only.is_empty() and not only.has(file_name):
		return
	var d: LevelData = _find(level_id).duplicate()
	if time_of_day >= 0:
		d.time_of_day = time_of_day
	d.car_density = 0.0
	d.bike_density = 0.0
	d.walkers = 0
	d.runners = 0
	d.bad_actor_chance = 0.0
	d.emergency_times = PackedFloat32Array()
	GameState.current_level = d
	var level := LEVEL_SCENE.instantiate()
	level.get_node("Traffic").fixed_seed = 7
	add_child(level)
	await _frames(3)
	level._on_popup_action("start")
	level.hud.visible = false
	for marker: Node3D in level.streets.markers.values():
		marker.visible = false   # no floating A/B/C labels in the quiz pictures
	for child in level.streets.get_children():
		if child is Label3D and (child as Label3D).font_size == 96:
			child.visible = false   # nor the family names above the delivery doors
	var traffic: TrafficManager = level.traffic
	if traffic.lights and phase >= 0:
		# Freeze the lights in the phase this question needs.
		traffic.lights.green_time = 1e6
		traffic.lights.yellow_time = 1e6
		traffic.lights.all_red_time = 1e6
		traffic.lights.phase = phase
		traffic.lights.phase_time = 0.0
		traffic._update_heads()
	setup.call(level, traffic)
	var courier: Courier = level.courier
	courier.teleport(pos, facing)
	courier.look_yaw = yaw
	courier.look_pitch = pitch
	courier._apply_look()
	await _physics(40)
	await _frames(6)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(file_name + ".png"))
	print("saved ", file_name)
	get_tree().paused = false
	level.queue_free()
	await _frames(3)


## A road user standing still on the named lane, at that z (north/south lanes) or x (east/west lanes).
func _park(t: TrafficManager, lane_name: String, z_or_x: float, kind: String, color: Color, bad: int = 0) -> Vehicle:
	for lane in t.lanes:
		if lane.def.name != lane_name:
			continue
		var spec := VehicleSpec.create(kind, 8.33, t.rng, false)
		if kind == "car" or kind == "bike":
			spec.color = color
		if bad != 0:
			spec.make_bad(bad, t.rng)
		spec.max_speed = 0.0
		var v := t._spawn_vehicle(lane, spec)
		# The lane runs along z for north/south lanes and along x for east/west lanes.
		var target := Vector3(lane.def.start.x, 0, z_or_x) if lane.def.axis == StreetLayout.Axis.NS \
				else Vector3(z_or_x, 0, lane.def.start.y)
		v.offset = lane.project(target).x
		v.speed = 0.0
		v._place()
		return v
	push_error("no lane called " + lane_name)
	return null


func _find(id: String) -> LevelData:
	for l in GameState.levels:
		if l.level_id() == id:
			return l
	return GameState.levels[0]


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
