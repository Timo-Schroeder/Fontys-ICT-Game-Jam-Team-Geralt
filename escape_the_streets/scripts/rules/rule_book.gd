class_name RuleBook
extends RefCounted
## Catalogue of traffic rules the game checks.
## Text is now served by the Locale autoload so it updates when the language changes.
## Violation names (the enum keys) are the keys used in locale.gd's _RULES table.

enum Violation {
	COLLISION,
	TIME_UP,
	RED_LIGHT,
	WALKING_ON_ROAD,
	WALKING_ON_BIKE_PATH,
	FORCED_BRAKE,
	BLOCKED_EMERGENCY,
	BLOCKING_TRAFFIC,
	BUMPED_PERSON,
	CYCLING_ON_SIDEWALK,
	BIKE_ON_ROAD,
	WRONG_WAY,
	NO_LIGHTS,
	SPEEDING,
	CAR_OFF_ROAD,
	NO_LOOK,
}

enum Severity {
	WARNING,
	POLICE,
	FAIL,
}

## Severity is language-independent, so it stays here.
const SEVERITY := {
	Violation.COLLISION:          Severity.FAIL,
	Violation.TIME_UP:            Severity.FAIL,
	Violation.RED_LIGHT:          Severity.POLICE,
	Violation.WALKING_ON_ROAD:    Severity.POLICE,
	Violation.WALKING_ON_BIKE_PATH: Severity.POLICE,
	Violation.FORCED_BRAKE:       Severity.POLICE,
	Violation.BLOCKED_EMERGENCY:  Severity.POLICE,
	Violation.BLOCKING_TRAFFIC:   Severity.POLICE,
	Violation.BUMPED_PERSON:      Severity.WARNING,
	Violation.CYCLING_ON_SIDEWALK: Severity.POLICE,
	Violation.BIKE_ON_ROAD:       Severity.POLICE,
	Violation.WRONG_WAY:          Severity.POLICE,
	Violation.NO_LIGHTS:          Severity.POLICE,
	Violation.SPEEDING:           Severity.POLICE,
	Violation.NO_LOOK:            Severity.WARNING,
	Violation.CAR_OFF_ROAD:       Severity.POLICE,
}

## Violations where the police walk you back to the last safe place.
const MOVE_TO_SAFE_SPOT := [
	Violation.RED_LIGHT, Violation.WALKING_ON_ROAD, Violation.WALKING_ON_BIKE_PATH,
	Violation.FORCED_BRAKE, Violation.BLOCKED_EMERGENCY, Violation.BLOCKING_TRAFFIC,
	Violation.CYCLING_ON_SIDEWALK, Violation.BIKE_ON_ROAD, Violation.WRONG_WAY,
	Violation.CAR_OFF_ROAD,
]


static func bad_actor_text(m: int, key: String, who: String) -> String:
	var name: String = VehicleSpec.Misbehaviour.keys()[m]
	return Locale.bad_actor(name, key, who)


static func info(type: int) -> Dictionary:
	var vname: String = Violation.keys()[type] if type >= 0 and type < Violation.size() else ""
	var texts := Locale.rule_info(vname)
	return {
		"severity": SEVERITY.get(type, Severity.WARNING),
		"title": texts.get("title", "?"),
		"text": texts.get("text", ""),
	}


static func severity(type: int) -> int:
	return SEVERITY.get(type, Severity.WARNING)


static func name_of(type: int) -> String:
	return Violation.keys()[type]
