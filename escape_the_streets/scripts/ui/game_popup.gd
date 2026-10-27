class_name GamePopup
extends CanvasLayer
## Full-screen message that pauses the game: briefing, police stop, level failed,
## level complete and pause menu. Emits `action` with the chosen button's id.

signal action(id: String)

@onready var _header: Label = %Header
@onready var _subtitle: Label = %Subtitle
@onready var _body: Label = %Body
@onready var _stars: Control = %PopupStars
@onready var _buttons: HBoxContainer = %Buttons
@onready var _panel: PanelContainer = %Panel

var is_open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func show_briefing(level: LevelData) -> void:
	_open("Level %s  •  %s" % [level.level_id(), level.stage_name()], level.title,
			level.briefing + "\n\nBreng het pakketje van A naar B en dan naar C. Veilig is belangrijker dan snel!",
			Color("ffd38a"), -1, [["start", "Start!"]])


func show_police(type: int, stars_left: int) -> void:
	var info := RuleBook.info(type)
	var extra := "\n\nDe politie brengt je terug naar een veilige plek." if type in RuleBook.MOVE_TO_SAFE_SPOT else ""
	if stars_left <= 0:
		extra += "\n\nJe hebt geen sterren meer."
	_open("Politie!", info["title"], info["text"] + extra, Color("6fa8ff"), stars_left,
			[["continue", "Ik snap het" if stars_left > 0 else "Verder"]])


func show_fail(type: int, by: String = "") -> void:
	var info := RuleBook.info(type)
	var title: String = info["title"]
	if type == RuleBook.Violation.COLLISION and by != "":
		title = "Botsing met een %s!" % by
	_open("Level mislukt", title, info["text"], Color("ff7b6b"), -1,
			[["retry", "Opnieuw"], ["menu", "Menu"]])


func show_out_of_stars() -> void:
	_open("Level mislukt", "Te vaak aangehouden",
			"Je bent drie keer door de politie aangehouden. Probeer het nog een keer en let goed op de regels.",
			Color("ff7b6b"), 0, [["retry", "Opnieuw"], ["menu", "Menu"]])


func show_success(level: LevelData, stars: int, has_next: bool) -> void:
	var lesson := level.lesson if level.lesson != "" else "Goed gedaan!"
	var buttons := [["retry", "Nog een keer"], ["menu", "Menu"]]
	if has_next:
		buttons.push_front(["next", "Volgend level"])
	_open("Pakketje bezorgd!", ["Dat kan veiliger...", "Netjes!", "Goed gedaan!", "Perfect! Superveilig!"][stars],
			"Onthoud: " + lesson, Color("7be08a"), stars, buttons)


func show_pause() -> void:
	_open("Pauze", "", "", Color.WHITE, -1, [["resume", "Verder"], ["retry", "Opnieuw"], ["menu", "Menu"]])


func close() -> void:
	is_open = false
	visible = false
	get_tree().paused = false


func _open(header: String, subtitle: String, body: String, color: Color, stars: int, buttons: Array) -> void:
	is_open = true
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_header.text = header
	_header.modulate = color
	_subtitle.text = subtitle
	_subtitle.visible = subtitle != ""
	_body.text = body
	_body.visible = body != ""
	_stars.visible = stars >= 0
	if stars >= 0:
		_stars.stars = stars
	for child in _buttons.get_children():
		child.queue_free()
	var first: Button = null
	for b: Array in buttons:
		var button := Button.new()
		button.text = b[1]
		button.custom_minimum_size = Vector2(200, 56)
		button.add_theme_font_size_override("font_size", 24)
		var id: String = b[0]
		button.pressed.connect(func() -> void: action.emit(id))
		_buttons.add_child(button)
		if first == null:
			first = button
	if first:
		first.call_deferred("grab_focus")


func _unhandled_input(event: InputEvent) -> void:
	# Esc closes the pause menu.
	if is_open and event.is_action_pressed("pause") and _header.text == "Pauze":
		get_viewport().set_input_as_handled()
		action.emit("resume")
