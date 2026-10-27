class_name SignalHead
extends Node3D
## Greybox traffic light on a pole: 3 lamps for vehicles, 2 for pedestrians,
## or a push button (drukknop) with a "WACHT" lamp.

enum Kind { VEHICLE, BIKE, PEDESTRIAN, BUTTON }

var kind: Kind
var _lamps: Dictionary = {}     ## TrafficLightController.Light (or 0/1 for the button) -> MeshInstance3D
var _on: Dictionary = {}        ## same keys -> lit material
var _off: Material
var _state := -99


func build(p_kind: Kind, faces: Vector3) -> void:
	kind = p_kind
	_off = Greybox.mat(Color("2a2a2a"), 0.6)
	var pole_mat := Greybox.mat(Color("5b6066"), 0.5)
	var housing := Greybox.mat(Color("1b1b1b"), 0.6)
	var head := Node3D.new()
	add_child(head)
	# Lamps sit on the side of the housing that faces the road users.
	if faces.length() > 0.01:
		head.basis = Basis.looking_at(faces, Vector3.UP)
	match kind:
		Kind.VEHICLE, Kind.BIKE:
			var scale_f := 1.0 if kind == Kind.VEHICLE else 0.6
			var top := 3.0 if kind == Kind.VEHICLE else 2.2
			Greybox.cylinder(self, 0.06, top, Vector3(0, top * 0.5, 0), pole_mat)
			Greybox.box(head, Vector3(0.35, 0.95, 0.25) * scale_f, Vector3(0, top + 0.1, 0), housing)
			var colors := {
				TrafficLightController.Light.RED: Color("ff2a1a"),
				TrafficLightController.Light.YELLOW: Color("ffb21a"),
				TrafficLightController.Light.GREEN: Color("2aff5a"),
			}
			var y := top + 0.1 + 0.3 * scale_f
			for light: int in [TrafficLightController.Light.RED, TrafficLightController.Light.YELLOW, TrafficLightController.Light.GREEN]:
				_lamps[light] = Greybox.sphere(head, 0.11 * scale_f, Vector3(0, y, -0.14 * scale_f), _off)
				_on[light] = Greybox.glow(colors[light], 4.0)
				y -= 0.3 * scale_f
		Kind.PEDESTRIAN:
			Greybox.cylinder(self, 0.05, 2.6, Vector3(0, 1.3, 0), pole_mat)
			Greybox.box(head, Vector3(0.3, 0.62, 0.2), Vector3(0, 2.75, 0), housing)
			_lamps[TrafficLightController.Light.RED] = Greybox.box(head, Vector3(0.22, 0.22, 0.04), Vector3(0, 2.9, -0.11), _off)
			_lamps[TrafficLightController.Light.GREEN] = Greybox.box(head, Vector3(0.22, 0.22, 0.04), Vector3(0, 2.6, -0.11), _off)
			_on[TrafficLightController.Light.RED] = Greybox.glow(Color("ff2a1a"), 4.0)
			_on[TrafficLightController.Light.GREEN] = Greybox.glow(Color("2aff5a"), 4.0)
		Kind.BUTTON:
			Greybox.box(head, Vector3(0.18, 0.28, 0.12), Vector3(0, 1.05, -0.08), Greybox.mat(Color("f2c200"), 0.5))
			_lamps[1] = Greybox.box(head, Vector3(0.12, 0.06, 0.03), Vector3(0, 1.13, -0.15), _off)
			_on[1] = Greybox.glow(Color("ff3b2e"), 4.0)
			var label := Label3D.new()
			label.text = "DRUK"
			label.font_size = 28
			label.pixel_size = 0.004
			label.position = Vector3(0, 0.95, -0.15)
			label.rotation.y = PI
			label.modulate = Color.BLACK
			label.outline_size = 0
			head.add_child(label)


## For VEHICLE/BIKE/PEDESTRIAN: a TrafficLightController.Light. For BUTTON: 1 = waiting, 0 = idle.
func set_state(state: int) -> void:
	if state == _state:
		return
	_state = state
	for key: int in _lamps:
		(_lamps[key] as MeshInstance3D).material_override = _on[key] if key == state else _off
