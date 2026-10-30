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
		warning = "\n\nLet op: niet iedereen houdt zich aan de regels! Kijk altijd of auto's en fietsers echt stoppen."
	_open("Level %s  •  %s" % [level.level_id(), level.stage_name()], level.title,
			level.briefing + warning + "\n\nBreng het pakketje van A naar B en dan naar C. Je hebt 3 levens: "
			+ "elke keer dat de politie je aanhoudt, ben je er een kwijt. Elk leven dat je overhoudt, wordt een ster!",
			Color("ffd38a"), -1, [["start", "Start!"]], 3)


func show_police(type: int, lives_left: int) -> void:
	var info := RuleBook.info(type)
	var extra := "\n\nDe politie brengt je terug naar een veilige plek." if type in RuleBook.MOVE_TO_SAFE_SPOT else ""
	extra += "\n\n" + _lives_text(lives_left)
	_open("Politie!", info["title"], info["text"] + extra, Color("6fa8ff"), -1,
			[["continue", "Ik snap het" if lives_left > 0 else "Verder"]], lives_left)


## context: {"by": "auto", "bad": VehicleSpec.Misbehaviour} for collisions.
func show_fail(type: int, context: Dictionary = {}) -> void:
	var info := RuleBook.info(type)
	var title: String = info["title"]
	var text: String = info["text"]
	var by: String = context.get("by", "")
	var bad: int = context.get("bad", VehicleSpec.Misbehaviour.NONE)
	if type == RuleBook.Violation.COLLISION and by != "":
		title = "Botsing met een %s!" % by
		if bad != VehicleSpec.Misbehaviour.NONE:
			# Hit by someone who broke the rules: explain what they did wrong
			# and what the child can do to stay safe anyway.
			title = RuleBook.bad_actor_text(bad, "title", by)
			text = RuleBook.bad_actor_text(bad, "fail", by)
	_open("Level mislukt", title, text, Color("ff7b6b"), -1,
			[["retry", "Opnieuw"], ["menu", "Menu"]])


func show_out_of_lives() -> void:
	_open("Level mislukt", "Geen levens meer",
			"Je bent drie keer door de politie aangehouden. Probeer het nog een keer en let goed op de regels.",
			Color("ff7b6b"), -1, [["retry", "Opnieuw"], ["menu", "Menu"]], 0)


## stars = the lives you still had when you delivered the package.
## summary: {"dodged": rule breakers you safely waited for, "not_looked": crossings without looking}
func show_success(level: LevelData, stars: int, has_next: bool, summary: Dictionary = {}) -> void:
	var lesson := level.lesson if level.lesson != "" else "Goed gedaan!"
	var buttons := [["retry", "Nog een keer"], ["menu", "Menu"]]
	if has_next:
		buttons.push_front(["next", "Volgend level"])
	var earned := "Je had nog %s over, dus je krijgt %d %s." % [
			"1 leven" if stars == 1 else "%d levens" % stars, stars, "ster" if stars == 1 else "sterren"]
	var dodged: int = summary.get("dodged", 0)
	var not_looked: int = summary.get("not_looked", 0)
	if dodged > 0:
		earned += "\nJe hebt %s gewacht voor iemand die zich niet aan de regels hield. Slim!" % (
				"1 keer" if dodged == 1 else "%d keer" % dodged)
	if not_looked > 0:
		earned += "\nJe bent %s overgestoken zonder eerst links en rechts te kijken." % (
				"1 keer" if not_looked == 1 else "%d keer" % not_looked)
	_open("Pakketje bezorgd!", ["Dat kan veiliger...", "Netjes!", "Goed gedaan!", "Perfect! Superveilig!"][stars],
			earned + "\n\nOnthoud: " + lesson, Color("7be08a"), stars, buttons)


static func _lives_text(lives_left: int) -> String:
	if lives_left <= 0:
		return "Je hebt geen levens meer."
	return "Je hebt nog 1 leven." if lives_left == 1 else "Je hebt nog %d levens." % lives_left


func show_pause() -> void:
	_open("Pauze", "", "", Color.WHITE, -1, [["resume", "Verder"], ["retry", "Opnieuw"], ["menu", "Menu"]])


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
	# Esc closes the pause menu.
	if is_open and event.is_action_pressed("pause") and _header.text == "Pauze":
		get_viewport().set_input_as_handled()
		action.emit("resume")
