class_name Hud
extends CanvasLayer
## On-screen info: level, objective, arrow to the target, stars, time, speed, hints, siren warning.

const CONTROLS := {
	Courier.Mode.WALK: "WASD lopen  •  muis kijken en draaien  •  Shift rennen  •  E drukknop  •  Esc pauze",
	Courier.Mode.BIKE: "W trappen  •  S remmen  •  A/D sturen  •  muis rondkijken  •  C vooruit kijken  •  L licht  •  B bel  •  Esc pauze",
	Courier.Mode.CAR: "W gas  •  S rem/achteruit  •  A/D sturen  •  muis rondkijken  •  C vooruit kijken  •  H toeter  •  Esc pauze",
}

@onready var _level_label: Label = %LevelLabel
@onready var _objective_label: Label = %ObjectiveLabel
@onready var _compass: Control = %Compass
@onready var _distance_label: Label = %DistanceLabel
@onready var _stars: Control = %Stars
@onready var _time_label: Label = %TimeLabel
@onready var _speed_label: Label = %SpeedLabel
@onready var _light_label: Label = %LightLabel
@onready var _siren_banner: Control = %SirenBanner
@onready var _hint_panel: Control = %HintPanel
@onready var _hint_label: Label = %HintLabel
@onready var _controls_label: Label = %ControlsLabel

var _hint_time := 0.0
var _context_hint := ""


func _ready() -> void:
	EventBus.hint.connect(show_hint)
	EventBus.emergency_state_changed.connect(set_siren)
	_siren_banner.visible = false
	_hint_panel.visible = false


func setup(level: LevelData, mode: Courier.Mode) -> void:
	_level_label.text = "Level %s  •  %s" % [level.level_id(), level.title]
	_controls_label.text = CONTROLS[mode]
	_speed_label.visible = mode != Courier.Mode.WALK
	_light_label.visible = mode == Courier.Mode.BIKE


func set_objective(text: String) -> void:
	_objective_label.text = text


func set_stars(stars: int) -> void:
	_stars.stars = stars


func update_status(time_left: float, player: Courier, target: Vector3, speed_limit: int) -> void:
	var secs := maxi(int(ceil(time_left)), 0)
	_time_label.text = "Tijd %d:%02d" % [floori(secs / 60.0), secs % 60]
	_time_label.modulate = Color("ff6b5e") if time_left < 30.0 else Color.WHITE
	if player.mode != Courier.Mode.WALK:
		var kmh := player.speed_kmh()
		_speed_label.text = "%d km/u  (max %d)" % [roundi(kmh), speed_limit]
		_speed_label.modulate = Color("ff6b5e") if kmh > speed_limit + 2 else Color.WHITE
	if player.mode == Courier.Mode.BIKE:
		_light_label.text = "Licht: AAN" if player.bike_light_on else "Licht: uit (L)"
	# Arrow: angle between where the camera looks and where the target is.
	var fwd := player.view_direction()
	var to_target := target - player.global_position
	var a := Vector2(fwd.x, fwd.z).angle_to(Vector2(to_target.x, to_target.z))
	_compass.angle = a
	_distance_label.text = "%d m" % roundi(Vector2(to_target.x, to_target.z).length())


func show_hint(text: String, seconds: float = 3.0) -> void:
	_hint_label.text = text
	_hint_panel.visible = true
	_hint_time = seconds


## A hint that stays while the situation lasts (e.g. standing next to a push button).
func set_context_hint(text: String) -> void:
	_context_hint = text


func set_siren(active: bool) -> void:
	_siren_banner.visible = active


func _process(delta: float) -> void:
	if _hint_time > 0.0:
		_hint_time -= delta
		if _hint_time <= 0.0:
			_hint_panel.visible = false
	if _hint_time <= 0.0:
		_hint_panel.visible = _context_hint != ""
		_hint_label.text = _context_hint
	if _siren_banner.visible:
		_siren_banner.modulate.a = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.012)
