class_name LevelData
extends Resource
## One level, fully described as data. The level scene reads this and builds
## the streets, traffic, weather and route from it, so the 30 levels are
## 30 small .tres files in res://data/levels/ instead of 30 hand-built scenes.
## Open a .tres file in the Godot inspector to tweak a level.

enum Stage { WALK, BIKE, CAR }
enum TimeOfDay { DAY, EVENING, NIGHT }
enum Weather { CLEAR, RAIN, FOG }
## TRAFFIC_LIGHTS: a signalled crossroads.
## PRIORITY_ROAD: east-west is the main road; north-south traffic must give way (haaientanden).
enum JunctionControl { TRAFFIC_LIGHTS, PRIORITY_ROAD }
## SIGNAL needs TRAFFIC_LIGHTS. ZEBRA and NONE need PRIORITY_ROAD.
enum CrossingType { SIGNAL, ZEBRA, NONE }

@export_group("Level")
@export var stage: Stage = Stage.WALK
@export_range(1, 10) var number: int = 1
@export var title: String = "Nieuw level"
## Shown before the level starts. Speak to the child: short sentences.
@export_multiline var briefing: String = ""
## Shown after finishing: the one thing to remember from this level.
@export_multiline var lesson: String = ""

@export_group("Conditions")
@export var time_of_day: TimeOfDay = TimeOfDay.DAY
@export var weather: Weather = Weather.CLEAR

@export_group("Street layout")
@export var junction_control: JunctionControl = JunctionControl.TRAFFIC_LIGHTS
@export var crossing_type: CrossingType = CrossingType.SIGNAL
@export var has_bike_paths: bool = true
## Distance between the sidewalk and the buildings. Small = worse view around corners.
@export_range(0.5, 12.0, 0.5) var building_setback: float = 4.0
@export_range(15, 80, 5) var speed_limit_kmh: int = 30

@export_group("Traffic")
## 0 = empty road, 1 = rush hour.
@export_range(0.0, 1.0, 0.05) var car_density: float = 0.3
@export_range(0.0, 1.0, 0.05) var bike_density: float = 0.3
## Shares of the road traffic that are not ordinary cars.
@export_range(0.0, 1.0, 0.05) var bus_share: float = 0.0
@export_range(0.0, 1.0, 0.05) var truck_share: float = 0.0
@export_range(0.0, 1.0, 0.05) var motorbike_share: float = 0.0
## Shares of the bike-path traffic.
@export_range(0.0, 1.0, 0.05) var fatbike_share: float = 0.0
@export_range(0.0, 1.0, 0.05) var race_group_share: float = 0.0
## Seconds after the start at which an ambulance/fire engine/police car comes through.
@export var emergency_times: PackedFloat32Array = PackedFloat32Array()
@export_range(0, 20) var walkers: int = 2
@export_range(0, 10) var runners: int = 0

@export_group("Bad actors")
## Chance (0..1) that a new car, motorbike or cyclist breaks the rules: runs a red light,
## ignores the zebra crossing, does not give way, speeds or looks at a phone.
## Keep it low (0.02 - 0.06): children should learn to stay alert, not to be afraid.
@export_range(0.0, 0.3, 0.01) var bad_actor_chance: float = 0.0

@export_group("Route")
## Spot format: ARM-SIDE-DISTANCE, e.g. "S-W-30" = south arm, west side, 30 m from the crossroads.
## Arms N/S take side W or E; arms E/W take side N or S. Distance 16..60.
@export var start_spot: String = "S-W-30"
@export var pickup_spot: String = "N-W-30"
@export var delivery_spot: String = "N-E-35"
@export var pickup_name: String = "Winkel"
@export var delivery_name: String = "Huis"
@export_range(30.0, 900.0, 5.0) var time_limit: float = 240.0


func level_id() -> String:
	return "%d-%d" % [stage + 1, number]


func stage_name() -> String:
	return ["Te voet", "Op de fiets", "Met het busje"][stage]


func is_dark() -> bool:
	return time_of_day != TimeOfDay.DAY


## Returns an empty string when valid, otherwise what is wrong (used by the level generator and tests).
func validate() -> String:
	if crossing_type == CrossingType.SIGNAL and junction_control != JunctionControl.TRAFFIC_LIGHTS:
		return "SIGNAL crossings need a TRAFFIC_LIGHTS junction"
	if crossing_type != CrossingType.SIGNAL and junction_control == JunctionControl.TRAFFIC_LIGHTS:
		return "a TRAFFIC_LIGHTS junction needs SIGNAL crossings"
	for spot: String in [start_spot, pickup_spot, delivery_spot]:
		if StreetLayout.parse_spot(spot).is_empty():
			return "bad spot '%s'" % spot
	return ""
