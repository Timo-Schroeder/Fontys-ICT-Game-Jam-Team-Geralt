extends Node
## Renders a few screenshots of levels for a quick visual check (needs a real renderer, not --headless).
##   godot --path . --rendering-method gl_compatibility res://tests/screenshots.tscn -- <output_dir>

const LEVEL_SCENE := preload("res://scenes/level.tscn")
const MENU_SCENE := preload("res://scenes/main_menu.tscn")

# [level id, player position, facing, file name, popup to show]
var shots := [
	["1-1", Vector3(-5.25, 0, 14), Vector3.FORWARD, "walk_day", ""],
	["1-1", Vector3(-5.25, 0, 14), Vector3.FORWARD, "briefing", "briefing"],
	["1-3", Vector3(-7.25, 0, 16), Vector3.FORWARD, "zebra", ""],
	["1-9", Vector3(-7.25, 0, 16), Vector3.FORWARD, "walk_evening", ""],
	["2-7", Vector3(5.0, 0, 24), Vector3.FORWARD, "bike_rain", ""],
	["2-6", Vector3(5.0, 0, 24), Vector3.FORWARD, "bike_evening", "police"],
	["3-1", Vector3(1.75, 0, 30), Vector3.FORWARD, "van_day", ""],
	["3-9", Vector3(1.75, 0, 30), Vector3.FORWARD, "van_fog", ""],
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
		await _physics(150)
		match shot[4]:
			"briefing":
				level.popup.show_briefing(data)
			"police":
				level.popup.show_police(RuleBook.Violation.NO_LIGHTS, 2)
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
