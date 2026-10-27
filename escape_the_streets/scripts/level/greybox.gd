class_name Greybox
extends RefCounted
## Helpers for placeholder geometry and materials. Everything in the prototype is built
## from boxes, cylinders and spheres; swap in real models later without touching game logic.

static var _materials: Dictionary = {}


static func mat(c: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var key := "%s|%.2f" % [c.to_html(), roughness]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = roughness
		_materials[key] = m
	return _materials[key]


static func glow(c: Color, energy: float = 2.0) -> StandardMaterial3D:
	var key := "glow|%s|%.2f" % [c.to_html(), energy]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = energy
		_materials[key] = m
	return _materials[key]


static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = material
	parent.add_child(mi)
	return mi


static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = material
	parent.add_child(mi)
	return mi


static func sphere(parent: Node3D, radius: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = material
	parent.add_child(mi)
	return mi


static func capsule(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = material
	parent.add_child(mi)
	return mi


## A flat surface (road, sidewalk...) covering a Rect2 in XZ at height y.
static func flat(parent: Node3D, rect: Rect2, y: float, material: Material, thickness: float = 0.02) -> MeshInstance3D:
	return box(parent, Vector3(rect.size.x, thickness, rect.size.y),
			Vector3(rect.get_center().x, y, rect.get_center().y), material)


## Greybox person: body capsule + head. Returns the root node.
static func person(parent: Node3D, shirt: Color, height: float = 1.6) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var body_h := height * 0.62
	capsule(root, 0.22, body_h, Vector3(0, height * 0.18 + body_h * 0.5, 0), mat(shirt))
	sphere(root, 0.14, Vector3(0, height - 0.14, 0), mat(Color("e8c4a0")))
	return root
