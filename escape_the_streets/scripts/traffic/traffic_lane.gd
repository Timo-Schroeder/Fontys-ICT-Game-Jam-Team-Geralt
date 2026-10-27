class_name TrafficLane
extends RefCounted
## Runtime state of one lane: the vehicles on it (front-most first) and its spawn timer.
## Vehicles only use position_at(), direction() and project(), so replacing the straight
## line with a Curve3D (for turning lanes) only means changing these three functions.

var def: StreetLayout.LaneDef
var vehicles: Array = []          ## Vehicle, index 0 is furthest along the lane
var spawn_timer := 0.0
var pending_group := 0            ## remaining riders of a race-bike group to spawn


func _init(lane_def: StreetLayout.LaneDef) -> void:
	def = lane_def


func position_at(offset: float) -> Vector3:
	var p := def.start + def.dir * offset
	return Vector3(p.x, 0.0, p.y)


func direction() -> Vector3:
	return Vector3(def.dir.x, 0.0, def.dir.y)


## Returns Vector2(offset along the lane, lateral distance from the lane centre line).
func project(world_pos: Vector3) -> Vector2:
	var rel := Vector2(world_pos.x, world_pos.z) - def.start
	var along := rel.dot(def.dir)
	var lateral := rel.dot(Vector2(-def.dir.y, def.dir.x))
	return Vector2(along, lateral)


## Free space at the start of the lane (distance to the rear of the last vehicle).
func entry_space() -> float:
	if vehicles.is_empty():
		return INF
	return vehicles[-1].rear()
