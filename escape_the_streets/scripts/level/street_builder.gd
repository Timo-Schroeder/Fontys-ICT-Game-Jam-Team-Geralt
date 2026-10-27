class_name StreetBuilder
extends Node3D
## Builds the greybox crossroads from a StreetLayout: ground, road, bike paths (red asphalt,
## like in the Netherlands), sidewalks, zebra/signal markings, shark teeth (haaientanden),
## signs, street lights, buildings and the A/B/C delivery spots.
## Pure visuals and static collision; no game logic lives here.

const Y_ROAD := 0.005
const Y_BIKE := 0.008
const Y_WALK := 0.010
const Y_MARK := 0.018

var layout: StreetLayout
var level: LevelData
var rng := RandomNumberGenerator.new()
## spot string -> checkpoint marker Node3D (so the level can highlight the current target).
var markers: Dictionary = {}

var _m: Dictionary = {}


func build(p_layout: StreetLayout, p_level: LevelData) -> void:
	layout = p_layout
	level = p_level
	rng.seed = hash(level.level_id())   # same buildings every attempt
	_make_materials()
	_build_ground()
	_build_roads()
	_build_bike_paths()
	_build_sidewalks()
	_build_crossings()
	_build_stop_markings()
	_build_signs()
	_build_buildings()
	_build_spots()
	_build_street_lights()
	_build_bounds()


func _make_materials() -> void:
	var wet := level.weather == LevelData.Weather.RAIN
	_m["grass"] = Greybox.mat(Color("6f9a4f"))
	_m["road"] = Greybox.mat(Color("2c2e32") if wet else Color("3c3f43"), 0.25 if wet else 0.9)
	_m["bike"] = Greybox.mat(Color("8c3a33") if wet else Color("a8463d"), 0.3 if wet else 0.9)
	_m["walk"] = Greybox.mat(Color("a29e97") if wet else Color("b8b4ac"), 0.4 if wet else 0.9)
	_m["curb"] = Greybox.mat(Color("8f8f8f"))
	_m["pad"] = Greybox.mat(Color("d1c7b5"))
	_m["driveway"] = Greybox.mat(Color("9c9890"))
	_m["white"] = Greybox.mat(Color("f2f2f2"), 0.6)
	_m["pole"] = Greybox.mat(Color("5b6066"), 0.5)


func _build_ground() -> void:
	var size := StreetLayout.ARM_LENGTH * 2.0 + 60.0
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, 1.0, size)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	body.add_child(shape)
	Greybox.box(body, Vector3(size, 0.1, size), Vector3(0, -0.05, 0), _m["grass"])


func _build_roads() -> void:
	var L := StreetLayout.ARM_LENGTH
	var h := StreetLayout.ROAD_HALF
	Greybox.flat(self, Rect2(-h, -L, h * 2.0, L * 2.0), Y_ROAD, _m["road"])
	Greybox.flat(self, Rect2(-L, -h, L * 2.0, h * 2.0), Y_ROAD + 0.001, _m["road"])
	# Curb strips between road and bike path / sidewalk.
	var wi := layout.walk_inner
	for s: float in [-1.0, 1.0]:
		var x0: float = s * h
		var x1: float = s * layout.bike_inner
		for z_range: Vector2 in [Vector2(-L, -wi), Vector2(wi, L)]:
			Greybox.flat(self, Rect2(Vector2(minf(x0, x1), z_range.x), Vector2(absf(x1 - x0), z_range.y - z_range.x)), Y_WALK, _m["curb"])
			Greybox.flat(self, Rect2(Vector2(z_range.x, minf(x0, x1)), Vector2(z_range.y - z_range.x, absf(x1 - x0))), Y_WALK, _m["curb"])
	# Dashed centre lines.
	var d := layout.walk_outer + 2.0
	while d < L - 2.0:
		for arm: String in StreetLayout.ARMS:
			var a: Vector2 = StreetLayout.ARM_DIR[arm]
			var lat := StreetLayout.lateral_axis(arm)
			var p := a * (d + 1.5)
			var size := a.abs() * 3.0 + lat * 0.12
			Greybox.flat(self, Rect2(p - size * 0.5, size), Y_MARK, _m["white"])
		d += 9.0


func _build_bike_paths() -> void:
	if not layout.has_bike_paths:
		return
	var L := StreetLayout.ARM_LENGTH
	var h := StreetLayout.ROAD_HALF
	var bi := layout.bike_inner
	var bo := layout.bike_outer
	for s: float in [-1.0, 1.0]:
		var x0: float = minf(s * bi, s * bo)
		for z_range: Vector2 in [Vector2(-L, -h), Vector2(h, L)]:
			Greybox.flat(self, Rect2(Vector2(x0, z_range.x), Vector2(bo - bi, z_range.y - z_range.x)), Y_BIKE, _m["bike"])
			Greybox.flat(self, Rect2(Vector2(z_range.x, x0), Vector2(z_range.y - z_range.x, bo - bi)), Y_BIKE + 0.001, _m["bike"])
		# Red bike crossings over the other road, with white block markings on both edges.
		Greybox.flat(self, Rect2(Vector2(x0, -h), Vector2(bo - bi, h * 2.0)), Y_MARK - 0.004, _m["bike"])
		Greybox.flat(self, Rect2(Vector2(-h, x0), Vector2(h * 2.0, bo - bi)), Y_MARK - 0.004, _m["bike"])
		var t := -h + 0.25
		while t < h:
			for edge: float in [bi, bo]:
				var e: float = s * edge
				Greybox.flat(self, Rect2(Vector2(e - 0.15, t - 0.15), Vector2(0.3, 0.3)), Y_MARK, _m["white"])
				Greybox.flat(self, Rect2(Vector2(t - 0.15, e - 0.15), Vector2(0.3, 0.3)), Y_MARK, _m["white"])
			t += 0.8


func _build_sidewalks() -> void:
	var L := StreetLayout.ARM_LENGTH
	var wi := layout.walk_inner
	var wo := layout.walk_outer
	for s: float in [-1.0, 1.0]:
		var x0: float = minf(s * wi, s * wo)
		for z_range: Vector2 in [Vector2(-L, -wi), Vector2(wi, L)]:
			Greybox.flat(self, Rect2(Vector2(x0, z_range.x), Vector2(wo - wi, z_range.y - z_range.x)), Y_WALK, _m["walk"])
			Greybox.flat(self, Rect2(Vector2(z_range.x, x0), Vector2(z_range.y - z_range.x, wo - wi)), Y_WALK + 0.001, _m["walk"])


func _build_crossings() -> void:
	for c in layout.crossings:
		var a: Vector2 = StreetLayout.ARM_DIR[c.arm]
		var lat := c.walk_dir
		var d0 := layout.walk_inner
		var d1 := layout.walk_outer
		match c.type:
			LevelData.CrossingType.ZEBRA:
				# White bars across the whole crossing (road and bike paths).
				var t := -layout.walk_inner + 0.5
				while t < layout.walk_inner - 0.3:
					var p := a * ((d0 + d1) * 0.5) + lat * t
					var size := a.abs() * (d1 - d0) + lat * 0.5
					Greybox.flat(self, Rect2(p - size * 0.5, size), Y_MARK + 0.002, _m["white"])
					t += 1.0
				_zebra_sign(c)
			LevelData.CrossingType.SIGNAL:
				# Signalled crossing: two rows of white blocks.
				var t := -StreetLayout.ROAD_HALF + 0.3
				while t < StreetLayout.ROAD_HALF:
					for d: float in [d0 + 0.2, d1 - 0.2]:
						var p: Vector2 = a * d + lat * t
						Greybox.flat(self, Rect2(p - Vector2(0.2, 0.2), Vector2(0.4, 0.4)), Y_MARK + 0.002, _m["white"])
					t += 0.9
			_:
				pass   # unmarked crossing place: no paint, cars do not have to stop


func _build_stop_markings() -> void:
	for ld in layout.lanes:
		var dir := ld.dir
		var lat := Vector2(-dir.y, dir.x)
		var half := (StreetLayout.LANE_WIDTH if ld.kind == "road" else StreetLayout.BIKE_WIDTH) * 0.5
		var p := ld.start + dir * (ld.stop_offset + 0.2)
		if level.junction_control == LevelData.JunctionControl.TRAFFIC_LIGHTS:
			var size := dir.abs() * 0.3 + lat.abs() * (half * 2.0 - 0.2)
			Greybox.flat(self, Rect2(p - size * 0.5, size), Y_MARK, _m["white"])
		elif ld.axis == StreetLayout.Axis.NS:
			# Shark teeth: the points face the drivers who must give way.
			var n := int(half * 2.0 / 0.6)
			for i in n:
				var q := p + lat * (-half + 0.3 + i * 0.6)
				var tooth := Node3D.new()
				add_child(tooth)
				tooth.position = StreetLayout.to_3d(q, Y_MARK)
				tooth.basis = Basis.looking_at(StreetLayout.to_3d(-dir), Vector3.UP)
				var mi := MeshInstance3D.new()
				var prism := PrismMesh.new()
				prism.size = Vector3(0.45, 0.55, 0.02)
				mi.mesh = prism
				mi.rotation.x = -PI * 0.5
				mi.material_override = _m["white"]
				tooth.add_child(mi)


func _build_signs() -> void:
	for ld in layout.lanes:
		if ld.kind != "road":
			continue
		var dir := StreetLayout.to_3d(ld.dir)
		var right := Vector3(-dir.z, 0.0, dir.x)
		# Speed limit sign at the start of each arm.
		var pos := StreetLayout.to_3d(ld.start + ld.dir * 22.0) + right * (StreetLayout.LANE_WIDTH * 0.5 + 2.6)
		_speed_sign(pos, -dir)
		if level.junction_control == LevelData.JunctionControl.PRIORITY_ROAD:
			var at_stop := StreetLayout.to_3d(ld.start + ld.dir * (ld.stop_offset - 3.0)) + right * (StreetLayout.LANE_WIDTH * 0.5 + 2.6)
			if ld.axis == StreetLayout.Axis.NS:
				_give_way_sign(at_stop, -dir)
			else:
				_priority_road_sign(at_stop, -dir)


func _sign_post(pos: Vector3, height: float = 2.4) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	Greybox.cylinder(root, 0.04, height, Vector3(0, height * 0.5, 0), _m["pole"])
	return root


func _speed_sign(pos: Vector3, faces: Vector3) -> void:
	var root := _sign_post(pos)
	var head := Node3D.new()
	root.add_child(head)
	head.basis = Basis.looking_at(faces, Vector3.UP)
	var rim := Greybox.cylinder(head, 0.32, 0.03, Vector3(0, 2.6, -0.03), Greybox.mat(Color("d01818")))
	rim.rotation.x = PI * 0.5
	var face := Greybox.cylinder(head, 0.25, 0.035, Vector3(0, 2.6, -0.04), Greybox.mat(Color.WHITE))
	face.rotation.x = PI * 0.5
	var label := Label3D.new()
	label.text = str(level.speed_limit_kmh)
	label.font_size = 64
	label.pixel_size = 0.005
	label.modulate = Color.BLACK
	label.outline_size = 0
	label.position = Vector3(0, 2.6, -0.06)
	label.rotation.y = PI
	head.add_child(label)


func _give_way_sign(pos: Vector3, faces: Vector3) -> void:
	var root := _sign_post(pos)
	var head := Node3D.new()
	root.add_child(head)
	head.basis = Basis.looking_at(faces, Vector3.UP)
	var outer := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.75, 0.65, 0.03)
	outer.mesh = prism
	outer.material_override = Greybox.mat(Color("d01818"))
	outer.position = Vector3(0, 2.55, -0.03)
	outer.rotation.z = PI   # point down
	head.add_child(outer)
	var inner := MeshInstance3D.new()
	var prism2 := PrismMesh.new()
	prism2.size = Vector3(0.5, 0.43, 0.035)
	inner.mesh = prism2
	inner.material_override = Greybox.mat(Color.WHITE)
	inner.position = Vector3(0, 2.6, -0.04)
	inner.rotation.z = PI
	head.add_child(inner)


func _priority_road_sign(pos: Vector3, faces: Vector3) -> void:
	var root := _sign_post(pos)
	var head := Node3D.new()
	root.add_child(head)
	head.basis = Basis.looking_at(faces, Vector3.UP)
	var outer := Greybox.box(head, Vector3(0.5, 0.5, 0.03), Vector3(0, 2.6, -0.03), Greybox.mat(Color.WHITE))
	outer.rotation.z = PI * 0.25
	var inner := Greybox.box(head, Vector3(0.34, 0.34, 0.035), Vector3(0, 2.6, -0.04), Greybox.mat(Color("f5c400")))
	inner.rotation.z = PI * 0.25


func _zebra_sign(c: StreetLayout.Crossing) -> void:
	# Blue square sign with a walking figure (greybox: a white triangle) at both ends.
	var a: Vector2 = StreetLayout.ARM_DIR[c.arm]
	for side: float in [-1.0, 1.0]:
		var p := a * (layout.walk_outer + 0.4) + c.walk_dir * (side * (layout.walk_inner + 0.4))
		var root := _sign_post(StreetLayout.to_3d(p), 2.3)
		var head := Node3D.new()
		root.add_child(head)
		head.basis = Basis.looking_at(StreetLayout.to_3d(a), Vector3.UP)
		Greybox.box(head, Vector3(0.6, 0.6, 0.03), Vector3(0, 2.5, -0.03), Greybox.mat(Color("1f5bc4")))
		var tri := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.45, 0.4, 0.035)
		tri.mesh = prism
		tri.material_override = Greybox.mat(Color.WHITE)
		tri.position = Vector3(0, 2.48, -0.04)
		head.add_child(tri)


func _build_buildings() -> void:
	var setback := level.building_setback
	var bricks := [Color("9b4a32"), Color("b5653e"), Color("7d3b2a"), Color("c9b79c"), Color("8c5a3c")]
	for arm: String in StreetLayout.ARMS:
		var a: Vector2 = StreetLayout.ARM_DIR[arm]
		var lat_axis := StreetLayout.lateral_axis(arm)
		for side: int in [-1, 1]:
			var d := layout.walk_outer + setback
			var color: Color = bricks[rng.randi() % bricks.size()]
			while d < StreetLayout.ARM_LENGTH - 4.0:
				var width := rng.randf_range(6.0, 11.0)
				if _spot_blocks(arm, side, d, d + width):
					d += 2.0
					continue
				var depth := rng.randf_range(8.0, 13.0)
				var height := rng.randf_range(6.0, 13.0)
				if rng.randf() < 0.35:
					color = bricks[rng.randi() % bricks.size()]
				var l0 := side * (layout.walk_outer + setback)
				var l1 := side * (layout.walk_outer + setback + depth)
				var p1 := a * d + lat_axis * l0
				var p2 := a * (d + width - 0.3) + lat_axis * l1
				var rect := Rect2(p1, Vector2.ZERO).expand(p2)
				_building(rect, height, color)
				d += width
			if setback >= 3.0:
				# Front gardens get a few trees, which also block the view a bit.
				var t := layout.walk_outer + setback + rng.randf_range(2.0, 8.0)
				while t < StreetLayout.ARM_LENGTH - 5.0:
					if not _spot_blocks(arm, side, t - 2.0, t + 2.0):
						var tp := a * t + lat_axis * (side * (layout.walk_outer + setback * 0.5))
						_tree(StreetLayout.to_3d(tp))
					t += rng.randf_range(10.0, 18.0)


func _spot_blocks(arm: String, side: int, d0: float, d1: float) -> bool:
	for s: StreetLayout.Spot in layout.spots.values():
		if s.arm == arm and s.side == side:
			if d1 > s.distance - StreetLayout.PAD_WIDTH * 0.5 - 1.5 and d0 < s.distance + StreetLayout.PAD_WIDTH * 0.5 + 1.5:
				return true
	return false


func _building(rect: Rect2, height: float, color: Color) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	body.position = StreetLayout.to_3d(rect.get_center())
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(rect.size.x, height, rect.size.y)
	shape.shape = box
	shape.position.y = height * 0.5
	body.add_child(shape)
	Greybox.box(body, Vector3(rect.size.x, height, rect.size.y), Vector3(0, height * 0.5, 0), Greybox.mat(color))
	Greybox.box(body, Vector3(rect.size.x + 0.3, 0.4, rect.size.y + 0.3), Vector3(0, height + 0.2, 0), Greybox.mat(Color("3a3a3a")))


func _tree(pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	body.position = pos
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.25
	cyl.height = 2.5
	shape.shape = cyl
	shape.position.y = 1.25
	body.add_child(shape)
	Greybox.cylinder(body, 0.18, 2.6, Vector3(0, 1.3, 0), Greybox.mat(Color("5a4030")))
	Greybox.sphere(body, rng.randf_range(1.4, 2.0), Vector3(0, 3.6, 0), Greybox.mat(Color("3f7a35")))


func _build_spots() -> void:
	var names := {
		level.start_spot: ["A", "Depot", Color("ff7a00")],
		level.pickup_spot: ["B", level.pickup_name, Color("2a7fff")],
		level.delivery_spot: ["C", level.delivery_name, Color("2ec45a")],
	}
	for key: String in names:
		var s := layout.spot(key)
		if s == null:
			continue
		var info: Array = names[key]
		Greybox.flat(self, s.pad_rect, Y_WALK + 0.002, _m["pad"])
		if layout.has_driveways:
			Greybox.flat(self, s.driveway_rect, Y_WALK + 0.003, _m["driveway"])
		# Small building behind the pad with a sign.
		var back := s.pad_center - s.to_street * (StreetLayout.PAD_DEPTH * 0.5 + 3.0)
		var a := StreetLayout.to_3d(StreetLayout.ARM_DIR[s.arm]).abs()
		var size_xz := a * StreetLayout.PAD_WIDTH + s.to_street.abs() * 6.0
		var rect := Rect2(Vector2(back.x, back.z) - Vector2(size_xz.x, size_xz.z) * 0.5, Vector2(size_xz.x, size_xz.z))
		_building(rect, 4.5, (info[2] as Color).darkened(0.35))
		var door := back + s.to_street * 3.02
		var door_node := Greybox.box(self, Vector3(1.2, 2.1, 1.2), door + Vector3(0, 1.05, 0), Greybox.mat(Color("3b2a1e")))
		door_node.scale = a + Vector3(0, 1, 0) + s.to_street.abs() * 0.05
		var sign := Label3D.new()
		sign.text = info[1]
		sign.font_size = 96
		sign.pixel_size = 0.006
		sign.outline_size = 12
		sign.position = back + s.to_street * 3.1 + Vector3(0, 3.4, 0)
		sign.basis = Basis.looking_at(-s.to_street, Vector3.UP)
		add_child(sign)
		markers[key] = _marker(s.pad_center, info[0], info[2])


func _marker(pos: Vector3, letter: String, color: Color) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	var ring := Greybox.cylinder(root, 1.4, 0.04, Vector3(0, 0.03, 0), Greybox.glow(color, 1.5))
	ring.name = "Ring"
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(color, 0.25)
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var beam := Greybox.cylinder(root, 1.2, 8.0, Vector3(0, 4.0, 0), beam_mat)
	beam.name = "Beam"
	var label := Label3D.new()
	label.name = "Letter"
	label.text = letter
	label.font_size = 160
	label.pixel_size = 0.01
	label.outline_size = 24
	label.modulate = color.lightened(0.3)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0, 3.2, 0)
	root.add_child(label)
	return root


func _build_street_lights() -> void:
	var dark := level.is_dark()
	var lamp_mat := Greybox.glow(Color("ffe2a8"), 5.0) if dark else Greybox.mat(Color("dddddd"), 0.3)
	for arm: String in StreetLayout.ARMS:
		var a: Vector2 = StreetLayout.ARM_DIR[arm]
		var lat := StreetLayout.lateral_axis(arm)
		var side := 1.0
		var d := layout.walk_outer + 4.0
		while d < StreetLayout.ARM_LENGTH - 5.0:
			var p := StreetLayout.to_3d(a * d + lat * (side * (layout.walk_outer - 0.3)))
			var root := Node3D.new()
			add_child(root)
			root.position = p
			Greybox.cylinder(root, 0.07, 6.0, Vector3(0, 3.0, 0), _m["pole"])
			var inward := -StreetLayout.to_3d(lat) * side
			Greybox.box(root, Vector3(0.5, 0.15, 0.5), Vector3(0, 6.0, 0) + inward * 0.6, lamp_mat)
			if dark:
				var light := OmniLight3D.new()
				light.position = Vector3(0, 5.6, 0) + inward * 1.2
				light.omni_range = 16.0
				light.light_energy = 1.6
				light.light_color = Color("ffd59a")
				root.add_child(light)
			side = -side
			d += 16.0


func _build_bounds() -> void:
	var L := StreetLayout.ARM_LENGTH - 1.0
	var body := StaticBody3D.new()
	body.name = "PlayerBounds"
	body.collision_layer = 16
	body.collision_mask = 0
	add_child(body)
	for i in 4:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var horizontal := i < 2
		box.size = Vector3(L * 2.0, 6.0, 1.0) if horizontal else Vector3(1.0, 6.0, L * 2.0)
		shape.shape = box
		var s := -1.0 if i % 2 == 0 else 1.0
		shape.position = Vector3(0, 3.0, s * L) if horizontal else Vector3(s * L, 3.0, 0)
		body.add_child(shape)
