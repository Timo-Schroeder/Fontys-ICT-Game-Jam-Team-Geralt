class_name RuleBook
extends RefCounted
## Catalogue of Dutch traffic rules the game checks, with child-friendly explanations.
## Teachers/designers: edit the texts here. Keep them short and concrete for 6-12 year olds.
## Before release, have the texts checked against current Dutch rules and VVN lesson material.

enum Violation {
	COLLISION,             ## hit by (or crashed into) a vehicle
	TIME_UP,
	RED_LIGHT,
	WALKING_ON_ROAD,
	WALKING_ON_BIKE_PATH,
	FORCED_BRAKE,          ## a vehicle had to brake hard because of the player
	BLOCKED_EMERGENCY,     ## an emergency vehicle had to brake because of the player
	BLOCKING_TRAFFIC,      ## the player stood still in front of traffic
	BUMPED_PERSON,
	CYCLING_ON_SIDEWALK,
	BIKE_ON_ROAD,          ## cycling on the road while there is a bike path
	WRONG_WAY,
	NO_LIGHTS,
	SPEEDING,
	CAR_OFF_ROAD,
}

enum Severity {
	WARNING,  ## a tip on screen, no penalty
	POLICE,   ## police stop: lose a star, get put back somewhere safe
	FAIL,     ## the level ends
}

const INFO := {
	Violation.COLLISION: {
		"severity": Severity.FAIL,
		"title": "Botsing!",
		"text": "Je bent geraakt of ergens tegenaan gebotst. Ga pas als het veilig is. Kijk eerst links, dan rechts en dan nog een keer links.",
	},
	Violation.TIME_UP: {
		"severity": Severity.FAIL,
		"title": "De tijd is op",
		"text": "Het pakketje is niet op tijd bezorgd. Probeer het nog een keer. Veilig is belangrijker dan snel, maar blijf niet te lang treuzelen!",
	},
	Violation.RED_LIGHT: {
		"severity": Severity.POLICE,
		"title": "Door rood licht",
		"text": "Bij rood licht wacht je, ook als er niemand aankomt. Pas bij groen mag je gaan. Kijk dan nog steeds goed uit.",
	},
	Violation.WALKING_ON_ROAD: {
		"severity": Severity.POLICE,
		"title": "Op de rijbaan",
		"text": "De rijbaan is voor auto's. Loop op de stoep en steek alleen over bij de oversteekplaats.",
	},
	Violation.WALKING_ON_BIKE_PATH: {
		"severity": Severity.POLICE,
		"title": "Op het fietspad",
		"text": "Het fietspad is voor fietsers. Zij rijden hard en verwachten daar geen voetgangers. Blijf op de stoep.",
	},
	Violation.FORCED_BRAKE: {
		"severity": Severity.POLICE,
		"title": "Iemand moest hard remmen",
		"text": "Je ging de weg op terwijl er iets aankwam. Wacht tot de weg vrij is, of tot het verkeer echt stilstaat.",
	},
	Violation.BLOCKED_EMERGENCY: {
		"severity": Severity.POLICE,
		"title": "Hulpdienst gehinderd",
		"text": "Hoor je een sirene of zie je blauwe zwaailichten? Blijf van de weg af en laat de ambulance, brandweer of politie voorgaan.",
	},
	Violation.BLOCKING_TRAFFIC: {
		"severity": Severity.POLICE,
		"title": "Je stond in de weg",
		"text": "Blijf niet op de weg staan. Steek in één keer over naar de overkant.",
	},
	Violation.BUMPED_PERSON: {
		"severity": Severity.WARNING,
		"title": "Pas op!",
		"text": "Kijk uit voor andere mensen op de stoep.",
	},
	Violation.CYCLING_ON_SIDEWALK: {
		"severity": Severity.POLICE,
		"title": "Fietsen op de stoep",
		"text": "De stoep is voor voetgangers. Fiets op het fietspad, of op de weg als er geen fietspad is.",
	},
	Violation.BIKE_ON_ROAD: {
		"severity": Severity.POLICE,
		"title": "Er is een fietspad",
		"text": "Als er een fietspad is, moet je daarop fietsen. Op de rijbaan rijden auto's hard langs je.",
	},
	Violation.WRONG_WAY: {
		"severity": Severity.POLICE,
		"title": "Verkeerde kant",
		"text": "In Nederland houden we rechts. Fiets of rijd aan de rechterkant van de weg, in de richting van het verkeer.",
	},
	Violation.NO_LIGHTS: {
		"severity": Severity.POLICE,
		"title": "Geen licht",
		"text": "Als het donker is, moet je fietslicht aan: wit licht voor en rood licht achter. Zet je licht aan met L.",
	},
	Violation.SPEEDING: {
		"severity": Severity.POLICE,
		"title": "Te hard",
		"text": "Houd je aan de maximumsnelheid op het bord. In een woonwijk is dat vaak 30 kilometer per uur.",
	},
	Violation.CAR_OFF_ROAD: {
		"severity": Severity.POLICE,
		"title": "Niet op de stoep of het fietspad",
		"text": "Met de auto rijd je op de rijbaan. Alleen bij een inrit mag je over de stoep, en dan geef je voorrang aan fietsers en voetgangers.",
	},
}

## Violations where the police walk you back to the last safe place.
const MOVE_TO_SAFE_SPOT := [
	Violation.RED_LIGHT, Violation.WALKING_ON_ROAD, Violation.WALKING_ON_BIKE_PATH,
	Violation.FORCED_BRAKE, Violation.BLOCKED_EMERGENCY, Violation.BLOCKING_TRAFFIC,
	Violation.CYCLING_ON_SIDEWALK, Violation.BIKE_ON_ROAD, Violation.WRONG_WAY,
	Violation.CAR_OFF_ROAD,
]


static func info(type: int) -> Dictionary:
	return INFO.get(type, {"severity": Severity.WARNING, "title": "?", "text": ""})


static func severity(type: int) -> int:
	return info(type)["severity"]


static func name_of(type: int) -> String:
	return Violation.keys()[type]
