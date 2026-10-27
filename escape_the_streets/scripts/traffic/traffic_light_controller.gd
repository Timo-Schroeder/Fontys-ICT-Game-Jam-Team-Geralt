class_name TrafficLightController
extends Node
## State machine for a signalled crossroads with pedestrian lights and push buttons (drukknop).
##
## Phases: NS green -> NS yellow -> all red -> EW green -> EW yellow -> all red -> ...
## Pedestrians crossing the north-south road get green while east-west traffic has green
## (traffic only goes straight on, so those never conflict), and vice versa.
## Pedestrian green stops `ped_clearance` seconds before the cars' green ends,
## so a child who starts crossing on green always reaches the other side.

signal changed

enum Light { GREEN, YELLOW, RED }

@export var green_time := 10.0
@export var yellow_time := 3.0
@export var all_red_time := 2.0
@export var ped_clearance := 4.0
## When true, pedestrians only get green after pressing the button.
@export var push_buttons := true

var phase := 0
var phase_time := 0.0
## An emergency vehicle asked for green on this axis (-1 = none). Everything else stays red.
var preempt_axis := -1

var _crossings: Array = []      ## StreetLayout.Crossing (signalled)
var _granted: Dictionary = {}   ## Crossing -> true while it has pedestrian green this cycle
var _signature := ""


func setup(crossings: Array) -> void:
	_crossings = crossings
	_signature = _make_signature()


func _durations() -> Array[float]:
	return [green_time, yellow_time, all_red_time, green_time, yellow_time, all_red_time]


func vehicle_state(axis: int) -> int:
	match phase:
		0:
			return Light.GREEN if axis == StreetLayout.Axis.NS else Light.RED
		1:
			return Light.YELLOW if axis == StreetLayout.Axis.NS else Light.RED
		3:
			return Light.GREEN if axis == StreetLayout.Axis.EW else Light.RED
		4:
			return Light.YELLOW if axis == StreetLayout.Axis.EW else Light.RED
	return Light.RED


func ped_state(c: StreetLayout.Crossing) -> int:
	if preempt_axis != -1:
		return Light.RED
	if phase != _ped_phase_for(c):
		return Light.RED
	if phase_time > green_time - ped_clearance:
		return Light.RED
	if push_buttons and not _granted.get(c, false):
		return Light.RED
	return Light.GREEN


## Pedestrians crossing road X get green during the phase where the *other* road has green.
func _ped_phase_for(c: StreetLayout.Crossing) -> int:
	return 3 if c.road_axis == StreetLayout.Axis.NS else 0


func press_button(c: StreetLayout.Crossing) -> void:
	c.requested = true
	_try_grant_now()


func tick(delta: float) -> void:
	if preempt_axis != -1:
		var target := 0 if preempt_axis == StreetLayout.Axis.NS else 3
		var other_green := 3 if target == 0 else 0
		if phase == target:
			phase_time = 0.0   # hold green for the emergency vehicle
			_emit_if_changed()
			return
		if phase == other_green:
			_enter_phase(phase + 1)   # cut the other green short: go to yellow now
			_emit_if_changed()
			return
	phase_time += delta
	if phase_time >= _durations()[phase]:
		_enter_phase((phase + 1) % 6)
	_emit_if_changed()


func _enter_phase(p: int) -> void:
	phase = p
	phase_time = 0.0
	_granted.clear()
	if p == 0 or p == 3:
		for c: StreetLayout.Crossing in _crossings:
			if _ped_phase_for(c) == p and (c.requested or not push_buttons):
				_granted[c] = true
				c.requested = false


## A button pressed in the first seconds of the right green phase still gets green this cycle.
func _try_grant_now() -> void:
	if preempt_axis != -1 or phase_time > 3.0:
		return
	for c: StreetLayout.Crossing in _crossings:
		if c.requested and _ped_phase_for(c) == phase:
			_granted[c] = true
			c.requested = false


func _make_signature() -> String:
	var s := "%d|%d|%d" % [phase, vehicle_state(0), vehicle_state(1)]
	for c: StreetLayout.Crossing in _crossings:
		s += "|%d%d" % [ped_state(c), int(c.requested)]
	return s


func _emit_if_changed() -> void:
	var s := _make_signature()
	if s != _signature:
		_signature = s
		changed.emit()
