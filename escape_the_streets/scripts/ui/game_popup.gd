class_name GamePopup
extends CanvasLayer
## Full-screen message that pauses the game: briefing, police stop, level failed,
## level complete and pause menu. Emits `action` with the chosen button's id.

signal action(id: String)

@onready var _header: Label = %Header
@onready var _subtitle: Label = %Subtitle
@onready var _body: Label = %Body
@onready var _stars: Control = %PopupStars
@onready var _lives: Control = %PopupLives
@onready var _buttons: HBoxContainer = %Buttons
@onready var _panel: PanelContainer = %Panel

var is_open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func show_briefing(level: LevelData) -> void:
	var warning := ""
	if level.bad_actor_chance > 0.0:
		warning = Locale.t("bad_actor_warning")
	_open(Locale.t("briefing_header") % [level.level_id(), level.stage_name()],
			level.title,
			level.briefing + warning + Locale.t("briefing_body"),
			Color("ffd38a"), -1, [["start", Locale.t("start_btn")]], 3)


func show_police(type: int, lives_left: int) -> void:
	var info := RuleBook.info(type)
	var extra := Locale.t("police_move_note") if type in RuleBook.MOVE_TO_SAFE_SPOT else ""
	extra += "\n\n" + _lives_text(lives_left)
	var btn_label := Locale.t("understand_btn") if lives_left > 0 else Locale.t("continue_btn")
	_open(Locale.t("police_header"), info["title"], info["text"] + extra, Color("6fa8ff"), -1,
			[["continue", btn_label]], lives_left)


## context: {"by": "auto", "bad": VehicleSpec.Misbehaviour} for collisions.
func show_fail(type: int, context: Dictionary = {}) -> void:
	var info := RuleBook.info(type)
	var title: String = info["title"]
	var text: String = info["text"]
	var by: String = context.get("by", "")
	var bad: int = context.get("bad", VehicleSpec.Misbehaviour.NONE)
	if type == RuleBook.Violation.COLLISION and by != "":
		title = Locale.t("collision_header") % by
		if bad != VehicleSpec.Misbehaviour.NONE:
			title = RuleBook.bad_actor_text(bad, "title", by)
			text = RuleBook.bad_actor_text(bad, "fail", by)
	_open(Locale.t("fail_header"), title, text, Color("ff7b6b"), -1,
			[["retry", Locale.t("retry_btn")], ["menu", Locale.t("menu_btn")]])


func show_out_of_lives() -> void:
	_open(Locale.t("out_of_lives_header"), Locale.t("out_of_lives_title"),
			Locale.t("out_of_lives_body"),
			Color("ff7b6b"), -1,
			[["retry", Locale.t("retry_btn")], ["menu", Locale.t("menu_btn")]], 0)


## stars = the lives you still had when you delivered the package.
## summary: {"dodged": rule breakers you safely waited for, "not_looked": crossings without looking}
func show_success(level: LevelData, stars: int, has_next: bool, summary: Dictionary = {}) -> void:
	var lesson := level.lesson if level.lesson != "" else Locale.t("default_lesson")
	var buttons := [["retry", Locale.t("retry_btn")], ["menu", Locale.t("menu_btn")]]
	if has_next:
		buttons.push_front(["next", Locale.t("next_level_btn")])
	var lives_str := Locale.t("lives_1") if stars == 1 else Locale.t("lives_n") % stars
	var star_str := Locale.t("star_1") if stars == 1 else Locale.t("stars_n")
	var earned := Locale.t("lives_earned") % [lives_str, stars, star_str]
	var dodged: int = summary.get("dodged", 0)
	var not_looked: int = summary.get("not_looked", 0)
	if dodged > 0:
		earned += Locale.t("dodged_1") if dodged == 1 else Locale.t("dodged_n") % dodged
	if not_looked > 0:
		earned += Locale.t("not_looked_1") if not_looked == 1 else Locale.t("not_looked_n") % not_looked
	var ratings: Array = Locale.ta("success_ratings")
	_open(Locale.t("package_delivered"), ratings[stars],
			earned + Locale.t("lesson_prefix") + lesson, Color("7be08a"), stars, buttons)


static func _lives_text(lives_left: int) -> String:
	if lives_left <= 0:
		return Locale.t("no_lives")
	return Locale.t("lives_left_1") if lives_left == 1 else Locale.t("lives_left_n") % lives_left


func show_pause() -> void:
	_open(Locale.t("pause_header"), "", "", Color.WHITE, -1,
			[["resume", Locale.t("resume_btn")], ["retry", Locale.t("restart_btn")], ["menu", Locale.t("menu_btn")]])


func close() -> void:
	is_open = false
	visible = false
	get_tree().paused = false


## stars / lives: how many to show, or -1 to hide that row.
func _open(header: String, subtitle: String, body: String, color: Color, stars: int, buttons: Array, lives: int = -1) -> void:
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
	_lives.visible = lives >= 0
	if lives >= 0:
		_lives.set("lives", lives)
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
	if is_open and event.is_action_pressed("pause") and _header.text == Locale.t("pause_header"):
		get_viewport().set_input_as_handled()
		action.emit("resume")
