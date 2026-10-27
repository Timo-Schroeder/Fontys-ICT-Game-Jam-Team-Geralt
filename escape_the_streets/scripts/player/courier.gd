class_name Courier
extends CharacterBody3D
## The player: a delivery courier on foot, on a bike, or in a delivery van.
## One body, three movement modes. Each stage simply calls set_mode().
##
## Views:
##   On foot - third person; the mouse turns you and tilts the camera up and down.
##   Bike    - first person; A/D steer, the mouse turns your head (look over your shoulder!).
##   Van     - first person from the driver's seat (left, as in the Netherlands); A/D steer,
##             the mouse turns your head. The van has no rear window: use the side mirrors.
## C (or the middle mouse button) looks straight ahead again.
##
## Controls: WASD move, mouse look, Shift run, E push button, L bike light,
## B bell / H horn, C look ahead, Esc pause.

signal interact_pressed

enum Mode { WALK, BIKE, CAR }

## Render layers (bit values). The first-person camera hides the player's own body,
## the mirrors do not see the cockpit.
const LAYER_WORLD := 1
const LAYER_OWN_BODY := 2
const LAYER_COCKPIT := 4

## How far you can turn your head left/right (radians) and up/down.
const HEAD_YAW_LIMIT := {Mode.BIKE: deg_to_rad(150.0), Mode.CAR: deg_to_rad(140.0)}
const HEAD_PITCH_MIN := deg_to_rad(-70.0)
const HEAD_PITCH_MAX := deg_to_rad(55.0)
## Default head/camera tilt per mode (slightly down, at the road).
const DEFAULT_PITCH := {Mode.WALK: -0.32, Mode.BIKE: -0.12, Mode.CAR: -0.08}

@export var mouse_sensitivity := 0.0025
## Slowly turn the head back to the front while riding/driving. Off: you look where you left it.
@export var auto_recenter := false
@export var walk_speed := 2.0
@export var run_speed := 4.2
@export var bike_max_speed := 6.5     ## ~23 km/h
@export var car_max_speed := 16.0     ## ~58 km/h, so speeding is possible

var mode: Mode = Mode.WALK
var control_enabled := false
var bike_light_on := false
var carrying := false
## Forward speed for bike and car (m/s, negative = reversing).
var forward_speed := 0.0
## Direction the body / bike / van faces.
var heading := 0.0
## Head direction relative to the body (first person). Positive yaw = looking left.
var look_yaw := 0.0
var look_pitch := -0.32
## 1.0 = dry road. Lower in the rain: longer braking distance.
var grip := 1.0

var _steer := 0.0
var _bike_steer := 0.0
var _recentering := false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _package: Node3D
var _bike_lamp: SpotLight3D
var _bike_lamp_meshes: Array[MeshInstance3D] = []
var _handlebar: Node3D
var _steering_wheel: Node3D
var _mirrors: Array[SideMirror] = []

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _visual: Node3D = $Visual
@onready var _pivot: Node3D = $CameraPivot
@onready var _arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4 | 8 | 16   # world, vehicles, people, bounds
	add_to_group("player")
	_arm.add_excluded_object(get_rid())
	set_mode(mode)


func set_mode(m: Mode) -> void:
	mode = m
	forward_speed = 0.0
	for child in _visual.get_children():
		_visual.remove_child(child)
		child.queue_free()
	_bike_lamp = null
	_bike_lamp_meshes.clear()
	_handlebar = null
	_steering_wheel = null
	_mirrors.clear()
	look_yaw = 0.0
	look_pitch = DEFAULT_PITCH[mode]
	match mode:
		Mode.WALK:
			var capsule := CapsuleShape3D.new()
			capsule.radius = 0.3
			capsule.height = 1.5
			_shape.shape = capsule
			_shape.position = Vector3(0, 0.75, 0)
			_build_walker()
			_set_camera(Vector3(0, 1.6, 0), 4.0, false)
		Mode.BIKE:
			var box := BoxShape3D.new()
			box.size = Vector3(0.6, 1.6, 1.8)
			_shape.shape = box
			_shape.position = Vector3(0, 0.8, 0)
			_build_bike()
			_set_camera(Vector3(0, 1.62, 0.05), 0.0, true)   # rider's eyes
		Mode.CAR:
			var van := BoxShape3D.new()
			van.size = Vector3(2.0, 2.1, 4.9)
			_shape.shape = van
			_shape.position = Vector3(0, 1.05, 0)
			_build_van()
			_set_camera(Vector3(-0.45, 1.95, -0.85), 0.0, true)   # driver's seat, left
	set_carrying(carrying)
	_apply_look()


func is_first_person() -> bool:
	return mode != Mode.WALK


## Half length and half width of the player's footprint.
func half_size() -> Vector2:
	match mode:
		Mode.BIKE:
			return Vector2(0.9, 0.3)
		Mode.CAR:
			return Vector2(2.45, 1.0)
	return Vector2(0.35, 0.35)


## Footprint as seen by a vehicle driving along lane_dir: Vector2(half along the lane, half across it).
func obstacle_extents(lane_dir: Vector3) -> Vector2:
	var hs := half_size()
	var c := absf(forward().dot(lane_dir))
	var s := sqrt(maxf(0.0, 1.0 - c * c))
	return Vector2(c * hs.x + s * hs.y, s * hs.x + c * hs.y)


func teleport(pos: Vector3, face_dir: Vector3) -> void:
	global_position = pos + Vector3(0, 0.05, 0)
	if face_dir.length() > 0.01:
		heading = atan2(-face_dir.x, -face_dir.z)
	rotation.y = heading
	velocity = Vector3.ZERO
	forward_speed = 0.0
	_steer = 0.0
	look_forward(true)


func forward() -> Vector3:
	return Vector3(-sin(heading), 0.0, -cos(heading))


## Where the camera is looking (horizontal), used for the arrow on the HUD.
func view_direction() -> Vector3:
	var f := -camera.global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else forward()


func speed_kmh() -> float:
	var v := get_real_velocity()
	return Vector2(v.x, v.z).length() * 3.6


func set_carrying(value: bool) -> void:
	carrying = value
	if _package and is_instance_valid(_package):
		_package.visible = value


## Mouse movement in pixels. On foot it turns the body; on the bike and in the van it turns the head.
func add_look(relative: Vector2) -> void:
	_recentering = false
	var dx := relative.x * mouse_sensitivity
	var dy := relative.y * mouse_sensitivity
	if mode == Mode.WALK:
		heading -= dx
		look_pitch = clampf(look_pitch - dy, -1.1, 0.15)
	else:
		var limit: float = HEAD_YAW_LIMIT[mode]
		look_yaw = clampf(look_yaw - dx, -limit, limit)
		look_pitch = clampf(look_pitch - dy, HEAD_PITCH_MIN, HEAD_PITCH_MAX)
	_apply_look()


## Turn the head back to the front (smoothly, or at once with instant = true).
func look_forward(instant: bool = false) -> void:
	if instant:
		look_yaw = 0.0
		look_pitch = DEFAULT_PITCH[mode]
		_recentering = false
		_apply_look()
	else:
		_recentering = true


func _unhandled_input(event: InputEvent) -> void:
	if not control_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		add_look((event as InputEventMouseMotion).relative)
	elif event.is_action_pressed("look_forward"):
		look_forward()
	elif event.is_action_pressed("interact"):
		interact_pressed.emit()
	elif event.is_action_pressed("bike_light") and mode == Mode.BIKE:
		set_bike_light(not bike_light_on)
	elif event.is_action_pressed("bell_horn"):
		ToneSynth.one_shot(self, ToneSynth.Pattern.BELL if mode != Mode.CAR else ToneSynth.Pattern.HORN, 0.5)


func set_bike_light(on: bool) -> void:
	bike_light_on = on
	if _bike_lamp:
		_bike_lamp.visible = on
	for m in _bike_lamp_meshes:
		m.material_override = Greybox.glow(m.get_meta("lit_color"), 4.0) if on else Greybox.mat(Color("333333"))


func _process(delta: float) -> void:
	if _recentering or (auto_recenter and is_first_person() and absf(forward_speed) > 2.0):
		var rate := 8.0 if _recentering else 1.5
		look_yaw = lerpf(look_yaw, 0.0, minf(1.0, rate * delta))
		look_pitch = lerpf(look_pitch, DEFAULT_PITCH[mode], minf(1.0, rate * delta))
		if _recentering and absf(look_yaw) < 0.01 and absf(look_pitch - DEFAULT_PITCH[mode]) < 0.01:
			_recentering = false
		_apply_look()
	# Animate the handlebar and the steering wheel.
	if _handlebar:
		_handlebar.rotation.y = -_bike_steer * 0.35
	if _steering_wheel:
		_steering_wheel.rotation.z = -_steer * 4.0


func _apply_look() -> void:
	if not is_node_ready():
		return
	if mode == Mode.WALK:
		_pivot.rotation = Vector3.ZERO
		_arm.rotation = Vector3(look_pitch, 0, 0)
	else:
		_pivot.rotation = Vector3(0, look_yaw, 0)
		_arm.rotation = Vector3(look_pitch, 0, 0)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.5
	var input := Vector2.ZERO
	if control_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	match mode:
		Mode.WALK:
			_walk(input)
		Mode.BIKE:
			_ride(delta, input)
		Mode.CAR:
			_drive(delta, input)
	rotation.y = heading
	move_and_slide()
	if mode != Mode.WALK:
		_check_crash()


func _walk(input: Vector2) -> void:
	var speed := run_speed if Input.is_action_pressed("run") else walk_speed
	var dir := Basis(Vector3.UP, heading) * Vector3(input.x, 0.0, input.y)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed


func _ride(delta: float, input: Vector2) -> void:
	var throttle := -input.y
	if throttle > 0.0:
		forward_speed = move_toward(forward_speed, bike_max_speed, 2.2 * delta)
	elif throttle < 0.0:
		forward_speed = move_toward(forward_speed, 0.0, 5.0 * grip * delta)
	else:
		forward_speed = move_toward(forward_speed, 0.0, 0.5 * delta)
	_bike_steer = move_toward(_bike_steer, input.x, 4.0 * delta)
	var turn_rate := lerpf(1.2, 1.9, clampf(forward_speed / 3.0, 0.0, 1.0))
	heading -= _bike_steer * turn_rate * delta
	var f := forward()
	velocity.x = f.x * forward_speed
	velocity.z = f.z * forward_speed


func _drive(delta: float, input: Vector2) -> void:
	var throttle := -input.y
	if throttle > 0.0:
		var accel := 3.0 if forward_speed >= 0.0 else 7.0 * grip
		forward_speed = move_toward(forward_speed, car_max_speed, accel * delta)
	elif throttle < 0.0:
		if forward_speed > 0.1:
			forward_speed = move_toward(forward_speed, 0.0, 7.0 * grip * delta)
		else:
			forward_speed = move_toward(forward_speed, -3.0, 2.0 * delta)
	else:
		forward_speed = move_toward(forward_speed, 0.0, 1.0 * delta)
	_steer = move_toward(_steer, input.x * 0.6, 2.5 * delta)
	var wheelbase := 3.0
	heading -= forward_speed / wheelbase * tan(_steer) * delta
	var f := forward()
	velocity.x = f.x * forward_speed
	velocity.z = f.z * forward_speed


func _check_crash() -> void:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_normal().y > 0.7:
			continue   # the ground
		var other := col.get_collider()
		var impact := absf(forward_speed)
		if other is Vehicle and impact > 1.5:
			EventBus.violation.emit(RuleBook.Violation.COLLISION, {"by": (other as Vehicle).spec.display_name})
		elif mode == Mode.CAR and impact > 3.5:
			EventBus.violation.emit(RuleBook.Violation.COLLISION, {"by": "muur"})
		forward_speed *= 0.2


func _set_camera(pivot_pos: Vector3, distance: float, first_person: bool) -> void:
	_pivot.position = pivot_pos
	_arm.spring_length = distance
	# First person: no spring arm collisions, and do not draw our own body from the inside.
	_arm.collision_mask = 0 if first_person else 1
	camera.near = 0.03 if first_person else 0.05
	camera.fov = 75.0 if first_person else 70.0
	camera.cull_mask = (0xFFFFF & ~LAYER_OWN_BODY) if first_person else 0xFFFFF
	_apply_look()


## Put every mesh under `node` on one render layer.
static func _set_layers(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer
	for child in node.get_children():
		_set_layers(child, layer)


# --- Greybox visuals ---------------------------------------------------------------

func _build_walker() -> void:
	var uniform := Color("ff7a00")
	Greybox.person(_visual, uniform, 1.45)
	# Thermal delivery backpack (the back is +Z).
	Greybox.box(_visual, Vector3(0.32, 0.34, 0.2), Vector3(0, 1.0, 0.27), Greybox.mat(Color("0f7f76")))
	_package = Greybox.box(_visual, Vector3(0.35, 0.25, 0.3), Vector3(0, 0.85, -0.38), Greybox.mat(Color("c98b45")))


func _build_bike() -> void:
	var tyre := Greybox.mat(Color("151515"))
	var frame_mat := Greybox.mat(Color("ff7a00"))
	for z: float in [-0.6, 0.6]:
		var w := Greybox.cylinder(_visual, 0.34, 0.06, Vector3(0, 0.34, z), tyre)
		w.rotation.z = PI * 0.5
	Greybox.box(_visual, Vector3(0.06, 0.06, 1.1), Vector3(0, 0.6, 0), frame_mat)
	# Steering tube from the front wheel up to the handlebar.
	var tube := Greybox.box(_visual, Vector3(0.05, 0.75, 0.05), Vector3(0, 0.78, -0.58), frame_mat)
	tube.rotation.x = 0.25
	# The rider is only seen by others (and as a shadow); in first person you are the rider.
	var rider := Greybox.person(_visual, Color("ff7a00"), 1.45)
	rider.position = Vector3(0, 0.35, 0.1)
	_set_layers(rider, LAYER_OWN_BODY)
	# Handlebar with hands, bell and front light: what you see when you look down.
	_handlebar = Node3D.new()
	_handlebar.position = Vector3(0, 1.15, -0.55)
	_visual.add_child(_handlebar)
	Greybox.box(_handlebar, Vector3(0.62, 0.035, 0.035), Vector3.ZERO, Greybox.mat(Color("3a3a3a"), 0.4))
	var skin := Greybox.mat(Color("e8c4a0"))
	var sleeve := Greybox.mat(Color("ff7a00"))
	for x: float in [-0.27, 0.27]:
		Greybox.box(_handlebar, Vector3(0.1, 0.045, 0.045), Vector3(x, 0, 0), Greybox.mat(Color("151515")))
		Greybox.sphere(_handlebar, 0.045, Vector3(x, 0.02, 0.0), skin)
		var forearm := Greybox.capsule(_handlebar, 0.028, 0.3, Vector3(x * 1.05, 0.06, 0.16), sleeve)
		forearm.rotation.x = 1.25
	var bell := Greybox.cylinder(_handlebar, 0.03, 0.02, Vector3(-0.16, 0.03, 0), Greybox.mat(Color("c0c0c0"), 0.2))
	bell.rotation.x = 0.0
	_set_layers(_handlebar, LAYER_COCKPIT | LAYER_WORLD)
	# Delivery crate on the rear rack: look over your shoulder and you see it.
	_package = Greybox.box(_visual, Vector3(0.45, 0.35, 0.45), Vector3(0, 1.0, 0.65), Greybox.mat(Color("c98b45")))
	var front := Greybox.sphere(_handlebar, 0.06, Vector3(0, -0.06, -0.08), Greybox.mat(Color("333333")))
	front.set_meta("lit_color", Color("fffbe6"))
	var back := Greybox.sphere(_visual, 0.06, Vector3(0, 0.75, 0.9), Greybox.mat(Color("333333")))
	back.set_meta("lit_color", Color("ff2a1a"))
	_bike_lamp_meshes.assign([front, back])
	_bike_lamp = SpotLight3D.new()
	_bike_lamp.position = Vector3(0, 0.95, -0.8)
	_bike_lamp.spot_range = 14.0
	_bike_lamp.spot_angle = 28.0
	_bike_lamp.light_energy = 2.0
	_bike_lamp.rotation.x = -0.15
	_visual.add_child(_bike_lamp)
	set_bike_light(bike_light_on)


func _build_van() -> void:
	# Outside of the van: seen by other road users and in the mirrors, hidden from the driver.
	var outside := Node3D.new()
	_visual.add_child(outside)
	var body := Greybox.mat(Color("f4f4f4"), 0.4)
	var stripe := Greybox.mat(Color("ff7a00"), 0.5)
	var glass := Greybox.mat(Color("1d2733"), 0.15)
	var tyre := Greybox.mat(Color("151515"))
	Greybox.box(outside, Vector3(2.0, 1.9, 3.6), Vector3(0, 1.25, 0.55), body)
	Greybox.box(outside, Vector3(2.0, 1.2, 1.3), Vector3(0, 0.9, -1.8), body)
	Greybox.box(outside, Vector3(1.9, 0.6, 0.6), Vector3(0, 1.75, -1.4), glass)
	Greybox.box(outside, Vector3(2.02, 0.25, 3.6), Vector3(0, 1.2, 0.55), stripe)
	for x: float in [-0.95, 0.95]:
		for z: float in [-1.6, 1.6]:
			var w := Greybox.cylinder(outside, 0.36, 0.25, Vector3(x, 0.36, z), tyre)
			w.rotation.z = PI * 0.5
	for x: float in [-0.7, 0.7]:
		Greybox.box(outside, Vector3(0.3, 0.14, 0.05), Vector3(x, 0.8, -2.46), Greybox.glow(Color("fff6d8"), 2.0))
	_set_layers(outside, LAYER_OWN_BODY)

	# Cockpit: what the driver sees. Windscreen pillars and the closed load area
	# create real blind spots, so you have to move your head and use the mirrors.
	var cockpit := Node3D.new()
	_visual.add_child(cockpit)
	var dash := Greybox.mat(Color("2b2e33"), 0.8)
	var trim := Greybox.mat(Color("8d929a"), 0.9)
	var paint := Greybox.mat(Color("e9e9e9"), 0.9)
	Greybox.box(cockpit, Vector3(1.95, 0.3, 0.6), Vector3(0, 1.29, -1.45), dash)              # dashboard
	Greybox.box(cockpit, Vector3(2.0, 0.06, 1.05), Vector3(0, 1.16, -2.05), paint)            # bonnet, just visible
	for x: float in [-0.97, 0.97]:
		var pillar := Greybox.box(cockpit, Vector3(0.07, 1.0, 0.09), Vector3(x, 1.88, -1.48), trim)   # A-pillars
		pillar.rotation.x = -0.5
		Greybox.box(cockpit, Vector3(0.08, 1.2, 1.75), Vector3(x * 1.03, 0.95, -0.55), trim)    # doors up to the window
		Greybox.box(cockpit, Vector3(0.1, 0.85, 0.14), Vector3(x * 1.0, 1.95, 0.33), trim)      # B-pillars
	Greybox.box(cockpit, Vector3(2.0, 0.06, 1.85), Vector3(0, 2.38, -0.55), dash)              # roof
	Greybox.box(cockpit, Vector3(1.96, 1.95, 0.06), Vector3(0, 1.28, 0.42), dash)              # wall to the load area
	Greybox.box(cockpit, Vector3(0.5, 0.12, 0.5), Vector3(-0.45, 1.0, -0.6), Greybox.mat(Color("44484f")))   # driver seat
	Greybox.box(cockpit, Vector3(0.5, 0.12, 0.5), Vector3(0.45, 1.0, -0.6), Greybox.mat(Color("44484f")))    # passenger seat
	_steering_wheel = Node3D.new()
	_steering_wheel.position = Vector3(-0.45, 1.55, -1.12)
	_steering_wheel.rotation.x = 0.35
	cockpit.add_child(_steering_wheel)
	var wheel := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.15
	torus.outer_radius = 0.18
	wheel.mesh = torus
	wheel.rotation.x = PI * 0.5
	wheel.material_override = Greybox.mat(Color("151515"), 0.6)
	_steering_wheel.add_child(wheel)
	Greybox.box(_steering_wheel, Vector3(0.3, 0.03, 0.03), Vector3.ZERO, Greybox.mat(Color("151515"), 0.6))
	Greybox.box(_steering_wheel, Vector3(0.03, 0.15, 0.03), Vector3(0, -0.075, 0), Greybox.mat(Color("151515"), 0.6))
	_set_layers(cockpit, LAYER_COCKPIT)

	# Working side mirrors on both doors.
	for s: float in [-1.0, 1.0]:
		var mirror := SideMirror.new()
		mirror.side = s
		mirror.position = Vector3(s * 1.18, 1.72, -1.3)
		# Turn the glass towards the driver, who sits on the left.
		mirror.rotation.y = 0.35 if s < 0.0 else -0.75
		_visual.add_child(mirror)
		_mirrors.append(mirror)

	var lamp := SpotLight3D.new()
	lamp.position = Vector3(0, 0.9, -2.5)
	lamp.spot_range = 25.0
	lamp.spot_angle = 35.0
	lamp.light_energy = 2.5
	lamp.rotation.x = -0.1
	_visual.add_child(lamp)
	_package = Node3D.new()   # the parcel is in the back of the van
	_visual.add_child(_package)
