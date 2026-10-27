extends Node
## Global game state (autoload "GameState"): level list, the level being played,
## and saved progress (best stars per level).

const LEVEL_DIR := "res://data/levels"
const SAVE_PATH := "user://progress.cfg"
const LEVEL_SCENE := "res://scenes/level.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"

## All levels, sorted by stage and number.
var levels: Array[LevelData] = []
## The level being played. Null when the level scene is run directly from the editor (F6);
## the level then falls back to the first level.
var current_level: LevelData
## level_id -> best stars (0..3). 0 or missing means not finished.
var best_stars: Dictionary = {}
## In debug builds (running from the editor) every level is playable, which helps testing.
var unlock_all: bool = OS.is_debug_build()
## The automated tests switch this off so they do not change your saved stars.
var save_enabled := true


func _ready() -> void:
	_load_levels()
	_load_progress()


func _load_levels() -> void:
	levels.clear()
	# list_directory also works in exported builds, where .tres files are remapped.
	for file_name in ResourceLoader.list_directory(LEVEL_DIR):
		if not (file_name.ends_with(".tres") or file_name.ends_with(".res")):
			continue
		var res := load(LEVEL_DIR.path_join(file_name))
		if res is LevelData:
			levels.append(res)
	levels.sort_custom(func(a: LevelData, b: LevelData) -> bool:
		return a.stage < b.stage or (a.stage == b.stage and a.number < b.number))


func levels_for_stage(stage: int) -> Array[LevelData]:
	var result: Array[LevelData] = []
	for level in levels:
		if level.stage == stage:
			result.append(level)
	return result


func first_level() -> LevelData:
	return levels[0] if not levels.is_empty() else null


func next_level_after(level: LevelData) -> LevelData:
	var i := levels.find(level)
	if i >= 0 and i + 1 < levels.size():
		return levels[i + 1]
	return null


func is_unlocked(level: LevelData) -> bool:
	if unlock_all:
		return true
	var i := levels.find(level)
	if i <= 0:
		return true
	return stars_for(levels[i - 1]) > 0


func stars_for(level: LevelData) -> int:
	return int(best_stars.get(level.level_id(), 0))


func total_stars() -> int:
	var total := 0
	for v in best_stars.values():
		total += int(v)
	return total


func record_result(level: LevelData, stars: int) -> void:
	if stars > stars_for(level):
		best_stars[level.level_id()] = stars
		_save_progress()


func start_level(level: LevelData) -> void:
	current_level = level
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVEL_SCENE)


func restart_level() -> void:
	start_level(current_level)


func go_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MENU_SCENE)


func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for key in cfg.get_section_keys("stars") if cfg.has_section("stars") else PackedStringArray():
		best_stars[key] = int(cfg.get_value("stars", key, 0))


func _save_progress() -> void:
	if not save_enabled:
		return
	var cfg := ConfigFile.new()
	for key: String in best_stars:
		cfg.set_value("stars", key, best_stars[key])
	cfg.save(SAVE_PATH)
