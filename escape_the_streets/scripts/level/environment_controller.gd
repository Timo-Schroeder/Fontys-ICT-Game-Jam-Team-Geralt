class_name EnvironmentController
extends Node3D
## Sky, sun, fog and rain for a level: day, evening or night, clear, rain or fog.
## Lower visibility is part of the lesson: in the dark and in the rain you are harder to see.

var _rain: GPUParticles3D
var _follow: Node3D


func apply(level: LevelData) -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0

	match level.time_of_day:
		LevelData.TimeOfDay.DAY:
			sky_mat.sky_top_color = Color("4a86d4")
			sky_mat.sky_horizon_color = Color("b9d3ee")
			sky_mat.ground_horizon_color = Color("b9d3ee")
			sun.light_energy = 1.2
			sun.light_color = Color("fff6e5")
			sun.rotation_degrees = Vector3(-55, -35, 0)
			env.ambient_light_energy = 1.0
		LevelData.TimeOfDay.EVENING:
			sky_mat.sky_top_color = Color("1f2a4d")
			sky_mat.sky_horizon_color = Color("b77a5c")
			sky_mat.ground_horizon_color = Color("3a3440")
			sun.light_energy = 0.3
			sun.light_color = Color("ffb27a")
			sun.rotation_degrees = Vector3(-10, 60, 0)
			env.ambient_light_energy = 0.45
		LevelData.TimeOfDay.NIGHT:
			sky_mat.sky_top_color = Color("070b18")
			sky_mat.sky_horizon_color = Color("1a2235")
			sky_mat.ground_horizon_color = Color("10131a")
			sun.light_energy = 0.08
			sun.light_color = Color("9fb4ff")
			sun.rotation_degrees = Vector3(-40, 20, 0)
			env.ambient_light_energy = 0.25

	env.background_mode = Environment.BG_SKY
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = level.is_dark()

	# A little haze always, so vehicles appearing at the map edge do not pop in.
	env.fog_enabled = true
	env.fog_light_color = sky_mat.sky_horizon_color.lerp(Color("5d6675"), 0.5) if level.is_dark() else sky_mat.sky_horizon_color
	env.fog_density = 0.006
	match level.weather:
		LevelData.Weather.RAIN:
			env.fog_density = 0.02
			sun.light_energy *= 0.5
			sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(Color("5a5f66"), 0.6)
			sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(Color("7a7f86"), 0.6)
			env.fog_light_color = sky_mat.sky_horizon_color
		LevelData.Weather.FOG:
			env.fog_density = 0.055
			env.fog_light_color = Color("b8bcc2") if not level.is_dark() else Color("3a3e45")

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	add_child(sun)
	if level.weather == LevelData.Weather.RAIN:
		_make_rain()


## The rain follows this node (the player).
func follow(target: Node3D) -> void:
	_follow = target


func _process(_delta: float) -> void:
	if _rain and _follow:
		_rain.global_position = _follow.global_position + Vector3(0, 14, 0)


func _make_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = 4000
	_rain.lifetime = 1.0
	_rain.local_coords = false
	_rain.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 40, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(28, 0.5, 28)
	pm.direction = Vector3(0.05, -1, 0)
	pm.spread = 2.0
	pm.initial_velocity_min = 16.0
	pm.initial_velocity_max = 20.0
	pm.gravity = Vector3(0, -9.8, 0)
	_rain.process_material = pm
	var drop := BoxMesh.new()
	drop.size = Vector3(0.015, 0.45, 0.015)
	var drop_mat := StandardMaterial3D.new()
	drop_mat.albedo_color = Color(0.75, 0.82, 0.95, 0.45)
	drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = drop_mat
	_rain.draw_pass_1 = drop
	add_child(_rain)
