extends Node3D
## Runs one level: builds it from LevelData, then handles the A -> B -> C route,
## the timer, police stops and the end of the level.
## The level scene can be run on its own (F6): it then plays the first level.

enum State { BRIEFING, PLAYING, POLICE_STOP, ENDED }

## How close you must get to B or C (metres).
const REACH := {Courier.Mode.WALK: 1.8, Courier.Mode.BIKE: 2.4, Courier.Mode.CAR: 3.2}

@onready var environment_controller: EnvironmentController = $Environment
@onready var streets: StreetBuilder = $Streets
@onready var traffic: TrafficManager = $Traffic
@onready var rules: RulesEngine = $RulesEngine
@onready var monitor: RuleMonitor = $RuleMonitor
@onready var courier: Courier = $Courier
@onready var hud: Hud = $HUD
@onready var popup: GamePopup = $Popup

var data: LevelData
var layout: StreetLayout
var state := State.BRIEFING
var time_left := 0.0
var has_package := false

var _pending_fail := false
var _pending_teleport := false


func _ready() -> void:
	data = GameState.current_level
	if data == null:
		data = GameState.first_level()
		GameState.current_level = data
	if data == null:
		push_error("No levels found in %s" % GameState.LEVEL_DIR)
		return
	var problem := data.validate()
	if problem != "":
		push_error("Level %s: %s" % [data.level_id(), problem])

	layout = StreetLayout.new(data)
	environment_controller.apply(data)
	environment_controller.follow(courier)
	streets.build(layout, data)

	var mode := _mode_for_stage(data.stage)
	courier.set_mode(mode)
	courier.grip = 0.7 if data.weather == LevelData.Weather.RAIN else 1.0
	var start := layout.spot(data.start_spot)
	# The van is long: start it a bit towards the street so it does not touch the building.
	var start_pos := start.pad_center + (start.to_street * 0.8 if mode == Courier.Mode.CAR else Vector3.ZERO)
	courier.teleport(start_pos, start.to_street)

	traffic.setup(layout, data, courier)
	traffic.prewarm(30.0)
	rules.reset()
	rules.penalty.connect(_on_penalty)
	monitor.setup(layout, courier, traffic, data)
	courier.interact_pressed.connect(_on_interact)

	hud.setup(data, mode)
	hud.set_stars(rules.stars)
	time_left = data.time_limit
	_update_objective()
	hud.update_status(time_left, courier, _target().pad_center, data.speed_limit_kmh)

	popup.action.connect(_on_popup_action)
	EventBus.level_started.emit(data)
	popup.show_briefing(data)


func _physics_process(delta: float) -> void:
	if state != State.PLAYING:
		return
	time_left -= delta
	traffic.tick(delta)
	if state != State.PLAYING:
		return   # a collision during the traffic update ended the level
	var info := monitor.tick(delta)
	if state != State.PLAYING:
		return
	_check_route()
	_update_hints(info)
	hud.update_status(time_left, courier, _target().pad_center, data.speed_limit_kmh)
	if time_left <= 0.0 and state == State.PLAYING:
		_fail(RuleBook.Violation.TIME_UP, "")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and state == State.PLAYING and not popup.is_open:
		get_viewport().set_input_as_handled()
		courier.control_enabled = false
		popup.show_pause()


# --- Flow --------------------------------------------------------------------------

func _begin_play() -> void:
	state = State.PLAYING
	rules.active = true
	traffic.player_active = true
	_give_control()


func _give_control() -> void:
	courier.control_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_popup_action(id: String) -> void:
	match id:
		"start":
			popup.close()
			_begin_play()
		"continue":
			popup.close()
			_after_police_stop()
		"resume":
			popup.close()
			_give_control()
		"retry":
			GameState.restart_level()
		"menu":
			GameState.go_to_menu()
		"next":
			var next := GameState.next_level_after(data)
			if next:
				GameState.start_level(next)
			else:
				GameState.go_to_menu()


func _on_penalty(type: int, severity: int, stars_left: int, context: Dictionary) -> void:
	hud.set_stars(stars_left)
	courier.control_enabled = false
	if severity == RuleBook.Severity.FAIL:
		_fail(type, context.get("by", ""))
		return
	state = State.POLICE_STOP
	_pending_teleport = type in RuleBook.MOVE_TO_SAFE_SPOT
	_pending_fail = stars_left <= 0
	popup.show_police(type, stars_left)


func _after_police_stop() -> void:
	if _pending_fail:
		state = State.ENDED
		rules.active = false
		EventBus.level_finished.emit(false, 0)
		popup.show_out_of_stars()
		return
	if _pending_teleport:
		courier.teleport(monitor.last_safe_position, monitor.last_safe_direction)
	monitor.reset()
	rules.restart_cooldowns()
	state = State.PLAYING
	_give_control()


func _fail(type: int, by: String) -> void:
	state = State.ENDED
	rules.active = false
	courier.control_enabled = false
	EventBus.level_finished.emit(false, 0)
	popup.show_fail(type, by)


func _succeed() -> void:
	state = State.ENDED
	rules.active = false
	courier.control_enabled = false
	var stars := rules.stars
	GameState.record_result(data, stars)
	EventBus.level_finished.emit(true, stars)
	popup.show_success(data, stars, GameState.next_level_after(data) != null)


# --- Route A -> B -> C ----------------------------------------------------------------

func _target() -> StreetLayout.Spot:
	return layout.spot(data.delivery_spot if has_package else data.pickup_spot)


func _check_route() -> void:
	var target := _target()
	var d := StreetLayout.to_2d(courier.global_position).distance_to(StreetLayout.to_2d(target.pad_center))
	var slow_enough := courier.mode == Courier.Mode.WALK or courier.speed_kmh() < 8.0
	if d > REACH[courier.mode] or not slow_enough:
		return
	if not has_package:
		has_package = true
		courier.set_carrying(true)
		if courier.mode != Courier.Mode.WALK:
			monitor.set_safe_spot(target.pad_center, target.to_street)
		EventBus.package_picked_up.emit()
		hud.show_hint("Pakketje opgehaald! Breng het nu naar C.", 3.0)
		_update_objective()
	else:
		_succeed()


func _update_objective() -> void:
	if has_package:
		hud.set_objective("Breng het pakketje naar C: %s" % data.delivery_name)
	else:
		hud.set_objective("Ga naar B: haal het pakketje op bij %s" % data.pickup_name)
	for key: String in streets.markers:
		var marker: Node3D = streets.markers[key]
		if key == data.start_spot:
			marker.visible = false
		elif key == data.pickup_spot:
			marker.visible = not has_package
		else:
			marker.visible = true


# --- Hints and interaction ---------------------------------------------------------------

func _on_interact() -> void:
	if courier.mode != Courier.Mode.WALK:
		return
	var c := traffic.button_near(courier.global_position)
	if c:
		traffic.press_button(c)
		hud.show_hint("Je hebt op de knop gedrukt. Wacht op groen.", 2.5)


func _update_hints(info: StreetLayout.SurfaceInfo) -> void:
	var text := ""
	var pos := courier.global_position
	if courier.mode == Courier.Mode.WALK:
		var button := traffic.button_near(pos)
		if button and info.surface != StreetLayout.Surface.CROSSING:
			if traffic.lights.ped_state(button) == TrafficLightController.Light.GREEN:
				text = "Groen! Kijk nog even links en rechts en steek dan over."
			elif button.requested:
				text = "Wacht op het groene licht..."
			else:
				text = "Druk op E op de knop en wacht op groen."
		else:
			for c in layout.crossings:
				if c.claim_rect.has_point(StreetLayout.to_2d(pos)) and not c.road_rect.has_point(StreetLayout.to_2d(pos)) \
						and info.surface != StreetLayout.Surface.CROSSING:
					if c.type == LevelData.CrossingType.ZEBRA:
						text = "Zebrapad: wacht tot het verkeer echt stilstaat. Kijk links, rechts en weer links."
					elif c.type == LevelData.CrossingType.NONE:
						text = "Geen zebrapad: wacht tot de weg helemaal vrij is."
	elif courier.mode == Courier.Mode.BIKE and data.is_dark() and not courier.bike_light_on:
		text = "Het is donker: zet je fietslicht aan met L."
	hud.set_context_hint(text)


static func _mode_for_stage(stage: int) -> Courier.Mode:
	match stage:
		LevelData.Stage.BIKE:
			return Courier.Mode.BIKE
		LevelData.Stage.CAR:
			return Courier.Mode.CAR
	return Courier.Mode.WALK
