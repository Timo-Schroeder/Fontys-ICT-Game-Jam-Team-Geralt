class_name RulesEngine
extends Node
## Turns rule violations (from EventBus) into consequences:
## a tip on screen, a police stop that costs a star, or the end of the level.
## The level decides how to show them; this node only keeps score.

## Emitted for POLICE and FAIL violations. The level shows the popup.
signal penalty(type: int, severity: int, stars_left: int, context: Dictionary)

const START_STARS := 3
## The same rule cannot be punished twice within this many seconds.
const COOLDOWN := 4.0

var stars: int = START_STARS
var violations_log: Array[Dictionary] = []   ## for the end screen and later analytics
var active := false
var _last_time: Dictionary = {}   ## type -> time (seconds) of the last penalty
var _clock := 0.0


func _ready() -> void:
	EventBus.violation.connect(_on_violation)


func _physics_process(delta: float) -> void:
	_clock += delta


func reset() -> void:
	stars = START_STARS
	violations_log.clear()
	_last_time.clear()


func _on_violation(type: int, context: Dictionary) -> void:
	if not active:
		return
	if _clock - float(_last_time.get(type, -INF)) < COOLDOWN:
		return
	_last_time[type] = _clock
	var sev := RuleBook.severity(type)
	violations_log.append({"type": type, "time": _clock})
	match sev:
		RuleBook.Severity.WARNING:
			var i := RuleBook.info(type)
			EventBus.hint.emit("%s %s" % [i["title"], i["text"]], 3.0)
		RuleBook.Severity.POLICE:
			stars = maxi(stars - 1, 0)
			penalty.emit(type, sev, stars, context)
		RuleBook.Severity.FAIL:
			active = false
			penalty.emit(type, sev, stars, context)


## Called after a police stop so the same situation is not punished again right away.
func restart_cooldowns() -> void:
	for key in _last_time.keys():
		_last_time[key] = _clock
