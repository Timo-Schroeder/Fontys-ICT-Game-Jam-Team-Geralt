extends SceneTree
## Writes the input map into project.godot.
## Run once from the project folder:
##   godot --headless --path . --script res://tools/setup_input_map.gd
## You can also edit the actions afterwards in Project > Project Settings > Input Map.

const KEY_ACTIONS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"run": [KEY_SHIFT],
	"interact": [KEY_E, KEY_SPACE],
	"bike_light": [KEY_L],
	"bell_horn": [KEY_B, KEY_H],
	"pause": [KEY_ESCAPE, KEY_P],
}


func _init() -> void:
	for action: String in KEY_ACTIONS:
		var events: Array = []
		for keycode: Key in KEY_ACTIONS[action]:
			var ev := InputEventKey.new()
			# Physical keys: WASD stays in the same place on AZERTY/QWERTZ keyboards.
			ev.physical_keycode = keycode
			ev.device = -1   # all devices, like actions made in the editor
			events.append(ev)
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": events})
	var err := ProjectSettings.save()
	print("Input map saved: ", error_string(err))
	quit()
