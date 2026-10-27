class_name SideMirror
extends Node3D
## A working side mirror for the van. A small camera looks backwards from the mirror and
## renders into the mirror glass, so players can (and must) check their mirrors before
## pulling away or turning, just like a real driver. A delivery van has no rear window.

## -1 = left (driver's side) mirror, +1 = right mirror.
@export var side := -1.0
@export var resolution := Vector2i(320, 240)
@export var glass_size := Vector2(0.26, 0.34)
@export var fov := 40.0

var _viewport: SubViewport
var _camera: Camera3D


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = resolution
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.fov = fov
	_camera.near = 0.1
	_camera.far = 250.0
	# The mirror sees the world and the outside of the van, but not the cockpit or the glass itself.
	_camera.cull_mask = Courier.LAYER_WORLD | Courier.LAYER_OWN_BODY
	_viewport.add_child(_camera)
	_camera.current = true

	var housing := Greybox.box(self, Vector3(glass_size.x + 0.06, glass_size.y + 0.06, 0.08), Vector3(0, 0, -0.045), Greybox.mat(Color("2a2a2a"), 0.5))
	housing.layers = Courier.LAYER_WORLD   # others can see the mirror housing
	var arm := Greybox.box(self, Vector3(0.18, 0.04, 0.04), Vector3(-side * 0.12, -0.1, -0.03), Greybox.mat(Color("2a2a2a"), 0.5))
	arm.layers = Courier.LAYER_WORLD

	var glass := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = glass_size
	glass.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _viewport.get_texture()
	# A mirror shows the image flipped left-right.
	mat.uv1_scale = Vector3(-1, 1, 1)
	mat.uv1_offset = Vector3(1, 0, 0)
	glass.material_override = mat
	glass.layers = Courier.LAYER_COCKPIT
	glass.position = Vector3(0, 0, 0.0)
	add_child(glass)


func _process(_delta: float) -> void:
	if _camera == null:
		return
	# Look backwards along the van, angled slightly outwards and down.
	var van_basis := get_parent_node_3d().global_transform.basis.orthonormalized()
	var look := van_basis * Basis(Vector3.UP, PI + side * 0.16) * Basis(Vector3.RIGHT, -0.07)
	_camera.global_transform = Transform3D(look, global_position)


func texture() -> Texture2D:
	return _viewport.get_texture() if _viewport else null
