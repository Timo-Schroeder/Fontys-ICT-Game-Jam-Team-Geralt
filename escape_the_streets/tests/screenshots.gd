extends Node
## Renders a few screenshots of levels for a quick visual check (needs a real renderer, not --headless).
##   godot --path . --rendering-method gl_compatibility res://tests/screenshots.tscn -- <output_dir>

const LEVEL_SCENE := preload("res://scenes/level.tscn")
const MENU_SCENE := preload("res://scenes/main_menu.tscn")

# [level id, player position, facing, file name, popup to show, head turn (radians, + = left)]
var shots := [
	["1-1", Vector3(-5.25, 0, 14), Vector3.FORWARD, "walk_day", "", 0.0],
	["1-1", Vector3(-5.25, 0, 14), Vector3.FORWARD, "briefing", "briefing", 0.0],
	["1-1", Vector3(-5.25, 0, 14), Vector3.FORWARD, "walk_carrying", "carry", 0.0],
	["1-1", Vector3(-5.25, 0, 7.0), Vector3.FORWARD, "walk_look_right", "", -1.2],
	["1-3", Vector3(-7.25, 0, 16), Vector3.FORWARD, "walk_police", "police_walk", 0.0],
	["1-1", Vector3(-5.25, 0, 14), Vector3.FORWARD, "success", "success", 0.0],
	["1-3", Vector3(-7.25, 0, 16), Vector3.FORWARD, "zebra", "", 0.0],
	["1-9", Vector3(-7.25, 0, 16), Vector3.FORWARD, "walk_evening", "", 0.0],
	["2-1", Vector3(5.0, 0, 30), Vector3.FORWARD, "bike_first_person", "", 0.0],
	["2-1", Vector3(5.0, 0, 30), Vector3.FORWARD, "bike_look_back", "", 2.3],
	["2-7", Vector3(5.0, 0, 30), Vector3.FORWARD, "bike_rain", "", 0.0],
	["2-6", Vector3(5.0, 0, 30), Vector3.FORWARD, "bike_evening", "police", 0.0],
	["3-1", Vector3(1.75, 0, 35), Vector3.FORWARD, "van_day", "", 0.0],
	["3-1", Vector3(1.75, 0, 35), Vector3.FORWARD, "van_look_left", "", 1.0],
	["3-1", Vector3(1.75, 0, 35), Vector3.FORWARD, "van_look_right", "", -0.85],
	["3-9", Vector3(1.75, 0, 35), Vector3.FORWARD, "van_fog", "", 0.0],
]
var out_dir := "user://screenshots"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.save_enabled = false
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	var menu := MENU_SCENE.instantiate()
	add_child(menu)
	await _settle(10)
	_save("menu")
	menu.queue_free()
	await get_tree().process_frame
	for shot: Array in shots:
		var data := _find(shot[0])
		GameState.current_level = data
		var level := LEVEL_SCENE.instantiate()
		level.get_node("Traffic").fixed_seed = 99
		add_child(level)
		await _settle(3)
		level._on_popup_action("start")
		var courier: Courier = level.courier
		# Wait until nobody is standing where we want to put the player.
		for i in 1800:
			if _spot_free(level.traffic, shot[1]):
				break
			await get_tree().physics_frame
		courier.teleport(shot[1], shot[2])
		level.monitor.set_safe_spot(shot[1], shot[2])
		if shot[5] != 0.0:
			courier.add_look(Vector2(-shot[5] / courier.mouse_sensitivity, 0))
		await _physics(150)
		match shot[4]:
			"briefing":
				level.popup.show_briefing(data)
			"police":
				level.hud.set_lives(2)
				level.popup.show_police(RuleBook.Violation.NO_LIGHTS, 2)
			"police_walk":
				level.hud.set_lives(2)
				level.popup.show_police(RuleBook.Violation.WALKING_ON_ROAD, 2)
			"carry":
				courier.set_carrying(true)
				level.hud.set_lives(2)
			"success":
				level.popup.show_success(data, 2, true)
		await _settle(8)
		_save(shot[3])
		get_tree().paused = false
		level.queue_free()
		await _settle(2)
	get_tree().quit()


func _spot_free(traffic: TrafficManager, pos: Vector3) -> bool:
	for lane in traffic.lanes:
		for v: Vehicle in lane.vehicles:
			if v.global_position.distance_to(pos) < 12.0:
				return false
	return true


func _find(id: String) -> LevelData:
	for l in GameState.levels:
		if l.level_id() == id:
			return l
	return GameState.levels[0]


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _settle(n: int) -> void:
	for i in n:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _save(file_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(file_name + ".png")
	img.save_png(path)
	print("saved ", path)
