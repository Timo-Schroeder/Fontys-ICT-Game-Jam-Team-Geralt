class_name Courier
extends CharacterBody3D
## The player: a delivery courier on foot, on a bike, or in a delivery van.
## One body, three movement modes. Each stage simply calls set_mode().
##
## Controls: WASD move, mouse turn/steer, Shift run, E push button, L bike light,
## B bell/horn, Esc pause.

signal interact_pressed

enum Mode { WALK, BIKE, CAR }

@export var mouse_sensitivity := 0.0025
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
var heading := 0.0
## 1.0 = dry road. Lower in the rain: longer braking distance.
var grip := 1.0

var _steer := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _package: Node3D
var _bike_lamp: SpotLight3D
var _bike_lamp_meshes: Array[MeshInstance3D] = []

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _visual: Node3D = $Visual
@onready var _pivot: Node3D = $CameraPivot
@onready var _arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4 | 8 | 16   # world, vehicles, people, bounds
	add_to_group("player")
	set_mode(mode)


func set_mode(m: Mode) -> void:
	mode = m
	forward_speed = 0.0
	for child in _visual.get_children():
		child.queue_free()
	_bike_lamp = null
	_bike_lamp_meshes.clear()
	match mode:
		Mode.WALK:
			var capsule := CapsuleShape3D.new()
			capsule.radius = 0.3
			capsule.height = 1.5
			_shape.shape = capsule
			_shape.position = Vector3(0, 0.75, 0)
			_build_walker()
			_set_camera(1.6, 4.0, -0.32)
		Mode.BIKE:
			var box := BoxShape3D.new()
			box.size = Vector3(0.6, 1.6, 1.8)
			_shape.shape = box
			_shape.position = Vector3(0, 0.8, 0)
			_build_bike()
			_set_camera(1.8, 5.0, -0.3)
		Mode.CAR:
			var van := BoxShape3D.new()
			van.size = Vector3(2.0, 2.1, 4.9)
			_shape.shape = van
			_shape.position = Vector3(0, 1.05, 0)
			_build_van()
			_set_camera(2.4, 8.0, -0.26)
	set_carrying(carrying)


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


func forward() -> Vector3:
	return Vector3(-sin(heading), 0.0, -cos(heading))


func speed_kmh() -> float:
	var v := get_real_velocity()
	return Vector2(v.x, v.z).length() * 3.6


func set_carrying(value: bool) -> void:
	carrying = value
	if _package and is_instance_valid(_package):
		_package.visible = value


func _unhandled_input(event: InputEvent) -> void:
	if not control_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var dx: float = event.relative.x * mouse_sensitivity
		match mode:
			Mode.WALK:
				heading -= dx
			_:
				# Mouse steering only works while moving, like a real handlebar or wheel.
				heading -= dx * clampf(absf(forward_speed) / 3.0, 0.0, 1.0) * signf(forward_speed if forward_speed != 0.0 else 1.0)
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
	var turn_rate := lerpf(1.2, 1.9, clampf(forward_speed / 3.0, 0.0, 1.0))
	heading -= input.x * turn_rate * delta
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


func _set_camera(height: float, distance: float, pitch: float) -> void:
	_pivot.position = Vector3(0, height, 0)
	_arm.spring_length = distance
	_arm.rotation = Vector3(pitch, 0, 0)
	_arm.add_excluded_object(get_rid())


# --- Greybox visuals ---------------------------------------------------------------

func _build_walker() -> void:
	var uniform := Color("ff7a00")
	Greybox.person(_visual, uniform, 1.45)
	# Thermal delivery backpack (the back is +Z).
	Greybox.box(_visual, Vector3(0.32, 0.34, 0.2), Vector3(0, 1.0, 0.27), Greybox.mat(Color("0f7f76")))
	_package = Greybox.box(_visual, Vector3(0.35, 0.25, 0.3), Vector3(0, 0.85, -0.38), Greybox.mat(Color("c98b45")))


func _build_bike() -> void:
	var tyre := Greybox.mat(Color("151515"))
	for z: float in [-0.6, 0.6]:
		var w := Greybox.cylinder(_visual, 0.34, 0.06, Vector3(0, 0.34, z), tyre)
		w.rotation.z = PI * 0.5
	Greybox.box(_visual, Vector3(0.06, 0.06, 1.1), Vector3(0, 0.6, 0), Greybox.mat(Color("ff7a00")))
	var rider := Greybox.person(_visual, Color("ff7a00"), 1.45)
	rider.position = Vector3(0, 0.35, 0.1)
	# Delivery crate on the rear rack.
	_package = Greybox.box(_visual, Vector3(0.45, 0.35, 0.45), Vector3(0, 1.0, 0.65), Greybox.mat(Color("c98b45")))
	var front := Greybox.sphere(_visual, 0.07, Vector3(0, 0.95, -0.72), Greybox.mat(Color("333333")))
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
	var body := Greybox.mat(Color("f4f4f4"), 0.4)
	var stripe := Greybox.mat(Color("ff7a00"), 0.5)
	var glass := Greybox.mat(Color("1d2733"), 0.15)
	var tyre := Greybox.mat(Color("151515"))
	Greybox.box(_visual, Vector3(2.0, 1.9, 3.6), Vector3(0, 1.25, 0.55), body)
	Greybox.box(_visual, Vector3(2.0, 1.2, 1.3), Vector3(0, 0.9, -1.8), body)
	Greybox.box(_visual, Vector3(1.9, 0.6, 0.6), Vector3(0, 1.75, -1.4), glass)
	Greybox.box(_visual, Vector3(2.02, 0.25, 3.6), Vector3(0, 1.2, 0.55), stripe)
	for x: float in [-0.95, 0.95]:
		for z: float in [-1.6, 1.6]:
			var w := Greybox.cylinder(_visual, 0.36, 0.25, Vector3(x, 0.36, z), tyre)
			w.rotation.z = PI * 0.5
	for x: float in [-0.7, 0.7]:
		Greybox.box(_visual, Vector3(0.3, 0.14, 0.05), Vector3(x, 0.8, -2.46), Greybox.glow(Color("fff6d8"), 2.0))
	var lamp := SpotLight3D.new()
	lamp.position = Vector3(0, 0.9, -2.5)
	lamp.spot_range = 25.0
	lamp.spot_angle = 35.0
	lamp.light_energy = 2.5
	lamp.rotation.x = -0.1
	_visual.add_child(lamp)
	_package = Node3D.new()   # the parcel is in the back of the van
	_visual.add_child(_package)
