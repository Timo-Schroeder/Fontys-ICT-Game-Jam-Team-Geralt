class_name VehicleSpec
extends RefCounted
## Size, speed and braking of one road user type. Speeds in m/s, accelerations in m/s².
## To give a type a real 3D model later, set `visual_scene` and the Vehicle uses it
## instead of the greybox boxes.

const ROAD_KINDS := ["car", "van", "bus", "truck", "motorbike"]
const BIKE_KINDS := ["bike", "fatbike", "racebike"]
const EMERGENCY_KINDS := ["ambulance", "fire", "police"]

var kind := "car"
var display_name := "auto"      ## Dutch, used in messages
var length := 4.3
var width := 1.8
var height := 1.5
var max_speed := 8.3
var accel := 2.5
var comfort_decel := 3.0
var max_decel := 8.0
var reaction_time := 0.6
var min_gap := 2.0
var color := Color.WHITE
var is_bike := false
var is_emergency := false
var visual_scene: PackedScene = null


static func create(kind_name: String, speed_limit: float, rng: RandomNumberGenerator, wet: bool) -> VehicleSpec:
	var s := VehicleSpec.new()
	s.kind = kind_name
	var car_colors := [Color("d8d8d8"), Color("2b2b2b"), Color("3f6fb5"), Color("b33a3a"),
			Color("e8e2d0"), Color("5a7d5a"), Color("8a8f96")]
	match kind_name:
		"car":
			s.display_name = "auto"
			s.max_speed = speed_limit * rng.randf_range(0.9, 1.05)
			s.color = car_colors[rng.randi() % car_colors.size()]
		"van":
			s.display_name = "bestelbus"
			s.length = 5.2; s.width = 2.0; s.height = 2.3
			s.max_speed = speed_limit * rng.randf_range(0.9, 1.0)
			s.accel = 2.0
			s.color = Color("f2f2f2")
		"bus":
			s.display_name = "bus"
			s.length = 12.0; s.width = 2.55; s.height = 3.1
			s.max_speed = speed_limit * 0.85
			s.accel = 1.2; s.comfort_decel = 2.0; s.max_decel = 5.5; s.min_gap = 2.5
			s.color = Color("2f6db3")
		"truck":
			s.display_name = "vrachtwagen"
			s.length = 9.0; s.width = 2.5; s.height = 3.4
			s.max_speed = speed_limit * 0.85
			s.accel = 1.3; s.comfort_decel = 2.0; s.max_decel = 5.5; s.min_gap = 2.5
			s.color = Color("c9c9c9")
		"motorbike":
			s.display_name = "motor"
			s.length = 2.1; s.width = 0.8; s.height = 1.4
			s.max_speed = speed_limit * rng.randf_range(0.95, 1.05)
			s.accel = 3.5; s.comfort_decel = 3.5; s.max_decel = 7.0; s.min_gap = 1.5
			s.color = Color("1e1e1e")
		"ambulance":
			s.display_name = "ambulance"
			s.length = 6.0; s.width = 2.1; s.height = 2.7
			s.is_emergency = true
			s.color = Color("f5d90a")
		"fire":
			s.display_name = "brandweerauto"
			s.length = 8.5; s.width = 2.5; s.height = 3.2
			s.is_emergency = true
			s.color = Color("c8102e")
		"police":
			s.display_name = "politieauto"
			s.length = 4.7; s.width = 1.85; s.height = 1.5
			s.is_emergency = true
			s.color = Color("f4f4f4")
		"bike":
			s.display_name = "fietser"
			s.is_bike = true
			s.length = 1.8; s.width = 0.6; s.height = 1.7
			s.max_speed = 4.5 * rng.randf_range(0.85, 1.15)
			s.accel = 1.8; s.comfort_decel = 2.0; s.max_decel = 5.0
			s.reaction_time = 0.5; s.min_gap = 1.2
			s.color = Color.from_hsv(rng.randf(), 0.5, 0.8)
		"fatbike":
			s.display_name = "fatbike"
			s.is_bike = true
			s.length = 1.9; s.width = 0.75; s.height = 1.7
			s.max_speed = 7.0 * rng.randf_range(0.9, 1.1)
			s.accel = 2.5; s.comfort_decel = 2.5; s.max_decel = 5.5
			s.reaction_time = 0.6; s.min_gap = 1.2
			s.color = Color("222222")
		"racebike":
			s.display_name = "wielrenner"
			s.is_bike = true
			s.length = 1.8; s.width = 0.5; s.height = 1.6
			s.max_speed = 8.5 * rng.randf_range(0.97, 1.03)
			s.accel = 2.2; s.comfort_decel = 2.5; s.max_decel = 5.0
			s.reaction_time = 0.6; s.min_gap = 0.7
			s.color = Color.from_hsv(rng.randf(), 0.8, 0.9)
		_:
			push_warning("Unknown vehicle kind '%s', using a car" % kind_name)
	if s.is_emergency:
		s.max_speed = speed_limit * 1.5
		s.accel = 3.0; s.comfort_decel = 3.5; s.max_decel = 8.0
	if wet:
		# Wet roads: everyone drives a bit slower and brakes less hard.
		s.max_speed *= 0.9
		s.comfort_decel *= 0.75
		s.max_decel *= 0.7
	return s
