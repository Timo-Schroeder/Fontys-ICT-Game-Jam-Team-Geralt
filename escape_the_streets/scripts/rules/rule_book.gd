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
	NO_LOOK,               ## stepped onto a crossing without looking left and right first
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
	Violation.NO_LOOK: {
		"severity": Severity.WARNING,
		"title": "Goed kijken!",
		"text": "Kijk eerst links, dan rechts en dan weer links voordat je oversteekt. Niet iedereen stopt!",
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


## Texts about road users who broke the rules (VehicleSpec.Misbehaviour).
## %s is replaced by the kind of road user ("auto", "fietser", "fatbike", ...).
##   title  - level failed because this road user hit you
##   fail   - explanation on the failed screen
##   close  - hint when it had to brake hard for you (no life lost: it was their fault)
##   praise - hint when it passed close by while you waited safely
const BAD_ACTOR := {
	VehicleSpec.Misbehaviour.RUNS_RED: {
		"title": "Botsing met een %s die door rood reed!",
		"fail": "Deze %s reed door rood. Dat mag niet, maar het gebeurt soms wel. Ook als jij groen hebt: kijk eerst links en rechts, en ga pas als iedereen echt stopt.",
		"close": "Pas op! Die %s reed door rood. Ook bij groen: kijk of iedereen echt stopt.",
		"praise": "Goed opgelet! Die %s reed door rood. Gelukkig wachtte je even.",
	},
	VehicleSpec.Misbehaviour.IGNORES_ZEBRA: {
		"title": "Botsing met een %s die niet stopte voor het zebrapad!",
		"fail": "Deze %s stopte niet voor het zebrapad, terwijl dat wel moest. Steek pas over als iedereen echt stilstaat. Kijk de bestuurder aan: heeft hij jou gezien?",
		"close": "Pas op! Die %s stopte niet voor het zebrapad. Wacht tot iedereen echt stilstaat.",
		"praise": "Goed gewacht! Die %s stopte niet voor het zebrapad.",
	},
	VehicleSpec.Misbehaviour.IGNORES_PRIORITY: {
		"title": "Botsing met een %s die geen voorrang gaf!",
		"fail": "Deze %s gaf geen voorrang, terwijl dat wel moest. Ook als jij voorrang hebt: blijf opletten en rem als iemand de weg op komt.",
		"close": "Pas op! Die %s gaf je geen voorrang. Blijf opletten, ook als jij voorrang hebt.",
		"praise": "Goed opgelet! Die %s gaf geen voorrang.",
	},
	VehicleSpec.Misbehaviour.SPEEDING: {
		"title": "Botsing met een %s die veel te hard reed!",
		"fail": "Deze %s reed veel te hard en kon niet op tijd stoppen. Verkeer kan sneller zijn dan je denkt: wacht liever iets langer.",
		"close": "Pas op! Die %s reed veel te hard. Verkeer kan sneller zijn dan je denkt.",
		"praise": "",
	},
	VehicleSpec.Misbehaviour.DISTRACTED: {
		"title": "Botsing met een %s die op zijn telefoon keek!",
		"fail": "Deze %s keek op zijn telefoon en zag je te laat. Ga er nooit van uit dat iemand jou heeft gezien.",
		"close": "Pas op! Die %s keek op zijn telefoon en zag je bijna niet.",
		"praise": "",
	},
}


static func bad_actor_text(m: int, key: String, who: String) -> String:
	var texts: Dictionary = BAD_ACTOR.get(m, {})
	var t: String = texts.get(key, "")
	return t % who if t.contains("%s") else t


static func info(type: int) -> Dictionary:
	return INFO.get(type, {"severity": Severity.WARNING, "title": "?", "text": ""})


static func severity(type: int) -> int:
	return info(type)["severity"]


static func name_of(type: int) -> String:
	return Violation.keys()[type]
