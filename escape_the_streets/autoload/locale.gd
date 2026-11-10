extends Node
## Language manager.  Default is English; call set_language("nl") to switch to Dutch.
## Access any string with   Locale.t("key")
## Signal `changed` fires after set_language() so every scene can refresh.

signal changed

var _lang := "en"

## All UI strings, keyed by language then key.
const _STRINGS := {
	"en": {
		# --- Main menu ---
		"game_title": "Escape the Streets",
		"subtitle": "Deliver your parcels safely through traffic.   Stars: %d / %d",
		"no_levels": "No levels found in %s",
		"stage_label": "Stage %d: %s",
		"stage_1_name": "On foot",
		"stage_2_name": "By bike",
		"stage_3_name": "By van",
		"quit_btn": "Quit",
		"test_mode_note": "   (test mode: all levels unlocked)",

		# --- Briefing popup ---
		"briefing_header": "Level %s  •  %s",
		"bad_actor_warning": "\n\nWatch out: not everyone follows the rules! Always check that cars and cyclists really do stop.",
		"briefing_body": "\n\nDeliver the parcel from A to B and then to C. You have 3 lives: each time the police stop you, you lose one. Every life you have left earns you a star!",
		"start_btn": "Start!",

		# --- Police popup ---
		"police_header": "Police!",
		"police_move_note": "\n\nThe police will take you back to a safe spot.",
		"understand_btn": "Got it",
		"continue_btn": "Continue",

		# --- Fail popup ---
		"fail_header": "Level failed",
		"collision_header": "Collision with a %s!",
		"retry_btn": "Try again",
		"menu_btn": "Menu",

		# --- Out of lives ---
		"out_of_lives_header": "Level failed",
		"out_of_lives_title": "No lives left",
		"out_of_lives_body": "You were stopped by the police three times. Try again and pay close attention to the rules.",

		# --- Success popup ---
		"package_delivered": "Package delivered!",
		"success_ratings": ["Be more careful...", "Good job!", "Well done!", "Perfect! Super safe!"],
		"lives_earned": "You had %s left, so you get %d %s.",
		"lives_1": "1 life",
		"lives_n": "%d lives",
		"star_1": "star",
		"stars_n": "stars",
		"dodged_1": "\nYou waited once for someone who broke the rules. Smart!",
		"dodged_n": "\nYou waited %d times for someone who broke the rules. Smart!",
		"not_looked_1": "\nYou crossed once without first looking left and right.",
		"not_looked_n": "\nYou crossed %d times without first looking left and right.",
		"lesson_prefix": "\n\nRemember: ",
		"default_lesson": "Well done!",
		"next_level_btn": "Next level",

		# --- Pause popup ---
		"pause_header": "Pause",
		"resume_btn": "Resume",
		"restart_btn": "Restart",

		# --- Lives text ---
		"no_lives": "You have no lives left.",
		"lives_left_1": "You have 1 life left.",
		"lives_left_n": "You have %d lives left.",

		# --- HUD hints (level.gd) ---
		"hint_walk": "Look around with the mouse. Before crossing: look left, right, then left again!",
		"hint_bike": "Look around with the mouse, including over your shoulder. Press C to look forward again.",
		"hint_car": "Look around with the mouse and check your mirrors: there is no rear window. C = look forward.",
		"hint_package_pickup": "Package picked up! Now take it to C.",
		"hint_button_press": "Button pressed. Wait for the green light.",
		"hint_green_light": "Green! Take one more look left and right, then cross.",
		"hint_wait_green": "Waiting for the green light...",
		"hint_press_button": "Press E on the button and wait for green.",
		"hint_zebra": "Zebra crossing: wait until the traffic really has stopped. Look left, right, then left again.",
		"hint_no_zebra": "No zebra crossing: wait until the road is completely clear.",
		"hint_no_lights": "It is dark: turn your bike light on with L.",

		# --- Objectives ---
		"obj_deliver": "Take the parcel to C: %s",
		"obj_pickup": "Go to B: pick up the parcel at %s",
	},

	"nl": {
		# --- Main menu ---
		"game_title": "Escape the Streets",
		"subtitle": "Bezorg je pakketjes veilig door het verkeer.   Sterren: %d / %d",
		"no_levels": "Geen levels gevonden in %s",
		"stage_label": "Fase %d: %s",
		"stage_1_name": "Te voet",
		"stage_2_name": "Op de fiets",
		"stage_3_name": "Met het busje",
		"quit_btn": "Stoppen",
		"test_mode_note": "   (testmodus: alle levels open)",

		# --- Briefing popup ---
		"briefing_header": "Level %s  •  %s",
		"bad_actor_warning": "\n\nLet op: niet iedereen houdt zich aan de regels! Kijk altijd of auto's en fietsers echt stoppen.",
		"briefing_body": "\n\nBreng het pakketje van A naar B en dan naar C. Je hebt 3 levens: elke keer dat de politie je aanhoudt, ben je er een kwijt. Elk leven dat je overhoudt, wordt een ster!",
		"start_btn": "Start!",

		# --- Police popup ---
		"police_header": "Politie!",
		"police_move_note": "\n\nDe politie brengt je terug naar een veilige plek.",
		"understand_btn": "Ik snap het",
		"continue_btn": "Verder",

		# --- Fail popup ---
		"fail_header": "Level mislukt",
		"collision_header": "Botsing met een %s!",
		"retry_btn": "Opnieuw",
		"menu_btn": "Menu",

		# --- Out of lives ---
		"out_of_lives_header": "Level mislukt",
		"out_of_lives_title": "Geen levens meer",
		"out_of_lives_body": "Je bent drie keer door de politie aangehouden. Probeer het nog een keer en let goed op de regels.",

		# --- Success popup ---
		"package_delivered": "Pakketje bezorgd!",
		"success_ratings": ["Dat kan veiliger...", "Netjes!", "Goed gedaan!", "Perfect! Superveilig!"],
		"lives_earned": "Je had nog %s over, dus je krijgt %d %s.",
		"lives_1": "1 leven",
		"lives_n": "%d levens",
		"star_1": "ster",
		"stars_n": "sterren",
		"dodged_1": "\nJe hebt 1 keer gewacht voor iemand die zich niet aan de regels hield. Slim!",
		"dodged_n": "\nJe hebt %d keer gewacht voor iemand die zich niet aan de regels hield. Slim!",
		"not_looked_1": "\nJe bent 1 keer overgestoken zonder eerst links en rechts te kijken.",
		"not_looked_n": "\nJe bent %d keer overgestoken zonder eerst links en rechts te kijken.",
		"lesson_prefix": "\n\nOnthoud: ",
		"default_lesson": "Goed gedaan!",
		"next_level_btn": "Volgend level",

		# --- Pause popup ---
		"pause_header": "Pauze",
		"resume_btn": "Verder",
		"restart_btn": "Opnieuw",

		# --- Lives text ---
		"no_lives": "Je hebt geen levens meer.",
		"lives_left_1": "Je hebt nog 1 leven.",
		"lives_left_n": "Je hebt nog %d levens.",

		# --- HUD hints (level.gd) ---
		"hint_walk": "Kijk om je heen met de muis. Voor je oversteekt: kijk links, rechts en weer links!",
		"hint_bike": "Kijk om je heen met de muis, ook over je schouder. Druk op C om weer vooruit te kijken.",
		"hint_car": "Kijk om je heen met de muis en kijk in je spiegels: achter je zit geen raam. C = vooruit kijken.",
		"hint_package_pickup": "Pakketje opgehaald! Breng het nu naar C.",
		"hint_button_press": "Je hebt op de knop gedrukt. Wacht op groen.",
		"hint_green_light": "Groen! Kijk nog even links en rechts en steek dan over.",
		"hint_wait_green": "Wacht op het groene licht...",
		"hint_press_button": "Druk op E op de knop en wacht op groen.",
		"hint_zebra": "Zebrapad: wacht tot het verkeer echt stilstaat. Kijk links, rechts en weer links.",
		"hint_no_zebra": "Geen zebrapad: wacht tot de weg helemaal vrij is.",
		"hint_no_lights": "Het is donker: zet je fietslicht aan met L.",

		# --- Objectives ---
		"obj_deliver": "Breng het pakketje naar C: %s",
		"obj_pickup": "Ga naar B: haal het pakketje op bij %s",
	},
}

## RuleBook INFO strings (title + text) per language.
## Keys match RuleBook.Violation enum indices.
const _RULES := {
	"en": {
		"COLLISION": {
			"title": "Collision!",
			"text": "You were hit or crashed into something. Only go when it is safe. Look left, right, then left again.",
		},
		"TIME_UP": {
			"title": "Time is up",
			"text": "The parcel was not delivered in time. Try again. Safety comes before speed, but don't dawdle too long!",
		},
		"RED_LIGHT": {
			"title": "Red light",
			"text": "At a red light you wait, even when nobody is coming. Only go on green — and still keep a good eye out.",
		},
		"WALKING_ON_ROAD": {
			"title": "On the road",
			"text": "The road is for cars. Walk on the pavement and cross only at the crossing.",
		},
		"WALKING_ON_BIKE_PATH": {
			"title": "On the bike path",
			"text": "The bike path is for cyclists. They ride fast and do not expect pedestrians there. Stay on the pavement.",
		},
		"FORCED_BRAKE": {
			"title": "Someone had to brake hard",
			"text": "You moved onto the road while something was coming. Wait until the road is clear or the traffic has really stopped.",
		},
		"BLOCKED_EMERGENCY": {
			"title": "Emergency vehicle blocked",
			"text": "Did you hear a siren or see blue flashing lights? Stay off the road and let the ambulance, fire engine or police pass first.",
		},
		"BLOCKING_TRAFFIC": {
			"title": "You were in the way",
			"text": "Do not stand still in the road. Cross all the way to the other side in one go.",
		},
		"BUMPED_PERSON": {
			"title": "Watch out!",
			"text": "Be careful of other people on the pavement.",
		},
		"CYCLING_ON_SIDEWALK": {
			"title": "Cycling on the pavement",
			"text": "The pavement is for pedestrians. Cycle on the bike path, or on the road if there is no bike path.",
		},
		"BIKE_ON_ROAD": {
			"title": "There is a bike path",
			"text": "When there is a bike path, you must use it. Cars drive fast past you on the road.",
		},
		"WRONG_WAY": {
			"title": "Wrong way",
			"text": "In the Netherlands we keep to the right. Cycle or drive on the right side of the road, in the direction of the traffic.",
		},
		"NO_LIGHTS": {
			"title": "No lights",
			"text": "In the dark your bike lights must be on: white light at the front and red at the back. Turn them on with L.",
		},
		"SPEEDING": {
			"title": "Too fast",
			"text": "Keep to the speed limit shown on the sign. In a residential area that is usually 30 kilometres per hour.",
		},
		"NO_LOOK": {
			"title": "Look carefully!",
			"text": "Look left, right, then left again before you cross. Not everyone stops!",
		},
		"CAR_OFF_ROAD": {
			"title": "Not on the pavement or bike path",
			"text": "In a car you drive on the road. You may only cross the pavement at a driveway, and even then you must give way to cyclists and pedestrians.",
		},
	},
	"nl": {
		"COLLISION": {
			"title": "Botsing!",
			"text": "Je bent geraakt of ergens tegenaan gebotst. Ga pas als het veilig is. Kijk eerst links, dan rechts en dan nog een keer links.",
		},
		"TIME_UP": {
			"title": "De tijd is op",
			"text": "Het pakketje is niet op tijd bezorgd. Probeer het nog een keer. Veilig is belangrijker dan snel, maar blijf niet te lang treuzelen!",
		},
		"RED_LIGHT": {
			"title": "Door rood licht",
			"text": "Bij rood licht wacht je, ook als er niemand aankomt. Pas bij groen mag je gaan. Kijk dan nog steeds goed uit.",
		},
		"WALKING_ON_ROAD": {
			"title": "Op de rijbaan",
			"text": "De rijbaan is voor auto's. Loop op de stoep en steek alleen over bij de oversteekplaats.",
		},
		"WALKING_ON_BIKE_PATH": {
			"title": "Op het fietspad",
			"text": "Het fietspad is voor fietsers. Zij rijden hard en verwachten daar geen voetgangers. Blijf op de stoep.",
		},
		"FORCED_BRAKE": {
			"title": "Iemand moest hard remmen",
			"text": "Je ging de weg op terwijl er iets aankwam. Wacht tot de weg vrij is, of tot het verkeer echt stilstaat.",
		},
		"BLOCKED_EMERGENCY": {
			"title": "Hulpdienst gehinderd",
			"text": "Hoor je een sirene of zie je blauwe zwaailichten? Blijf van de weg af en laat de ambulance, brandweer of politie voorgaan.",
		},
		"BLOCKING_TRAFFIC": {
			"title": "Je stond in de weg",
			"text": "Blijf niet op de weg staan. Steek in één keer over naar de overkant.",
		},
		"BUMPED_PERSON": {
			"title": "Pas op!",
			"text": "Kijk uit voor andere mensen op de stoep.",
		},
		"CYCLING_ON_SIDEWALK": {
			"title": "Fietsen op de stoep",
			"text": "De stoep is voor voetgangers. Fiets op het fietspad, of op de weg als er geen fietspad is.",
		},
		"BIKE_ON_ROAD": {
			"title": "Er is een fietspad",
			"text": "Als er een fietspad is, moet je daarop fietsen. Op de rijbaan rijden auto's hard langs je.",
		},
		"WRONG_WAY": {
			"title": "Verkeerde kant",
			"text": "In Nederland houden we rechts. Fiets of rijd aan de rechterkant van de weg, in de richting van het verkeer.",
		},
		"NO_LIGHTS": {
			"title": "Geen licht",
			"text": "Als het donker is, moet je fietslicht aan: wit licht voor en rood licht achter. Zet je licht aan met L.",
		},
		"SPEEDING": {
			"title": "Te hard",
			"text": "Houd je aan de maximumsnelheid op het bord. In een woonwijk is dat vaak 30 kilometer per uur.",
		},
		"NO_LOOK": {
			"title": "Goed kijken!",
			"text": "Kijk eerst links, dan rechts en dan weer links voordat je oversteekt. Niet iedereen stopt!",
		},
		"CAR_OFF_ROAD": {
			"title": "Niet op de stoep of het fietspad",
			"text": "Met de auto rijd je op de rijbaan. Alleen bij een inrit mag je over de stoep, en dan geef je voorrang aan fietsers en voetgangers.",
		},
	},
}

## BAD_ACTOR strings per language.  %s = kind of road user.
const _BAD_ACTORS := {
	"en": {
		"RUNS_RED": {
			"title": "Collision with a %s that ran a red light!",
			"fail": "This %s ran a red light. That is not allowed, but it does happen. Even when you have green: look left and right first and only go when everyone really stops.",
			"close": "Watch out! That %s ran a red light. Even on green: check that everyone really stops.",
			"praise": "Good spotting! That %s ran a red light. Luckily you waited.",
		},
		"IGNORES_ZEBRA": {
			"title": "Collision with a %s that did not stop at the zebra crossing!",
			"fail": "This %s did not stop at the zebra crossing, even though it had to. Only cross when everyone has really stopped. Look the driver in the eye: has he seen you?",
			"close": "Watch out! That %s did not stop at the zebra crossing. Wait until everyone has really stopped.",
			"praise": "Good waiting! That %s did not stop at the zebra crossing.",
		},
		"IGNORES_PRIORITY": {
			"title": "Collision with a %s that did not give way!",
			"fail": "This %s did not give way, even though it had to. Even when you have right of way: keep paying attention and brake if someone pulls into the road.",
			"close": "Watch out! That %s did not give way. Keep paying attention, even when you have right of way.",
			"praise": "Good spotting! That %s did not give way.",
		},
		"SPEEDING": {
			"title": "Collision with a %s going far too fast!",
			"fail": "This %s was going far too fast and could not stop in time. Traffic can be faster than you think: it is better to wait a little longer.",
			"close": "Watch out! That %s was going far too fast. Traffic can be faster than you think.",
			"praise": "",
		},
		"DISTRACTED": {
			"title": "Collision with a %s that was looking at their phone!",
			"fail": "This %s was looking at their phone and saw you too late. Never assume someone has seen you.",
			"close": "Watch out! That %s was looking at their phone and nearly did not see you.",
			"praise": "",
		},
	},
	"nl": {
		"RUNS_RED": {
			"title": "Botsing met een %s die door rood reed!",
			"fail": "Deze %s reed door rood. Dat mag niet, maar het gebeurt soms wel. Ook als jij groen hebt: kijk eerst links en rechts, en ga pas als iedereen echt stopt.",
			"close": "Pas op! Die %s reed door rood. Ook bij groen: kijk of iedereen echt stopt.",
			"praise": "Goed opgelet! Die %s reed door rood. Gelukkig wachtte je even.",
		},
		"IGNORES_ZEBRA": {
			"title": "Botsing met een %s die niet stopte voor het zebrapad!",
			"fail": "Deze %s stopte niet voor het zebrapad, terwijl dat wel moest. Steek pas over als iedereen echt stilstaat. Kijk de bestuurder aan: heeft hij jou gezien?",
			"close": "Pas op! Die %s stopte niet voor het zebrapad. Wacht tot iedereen echt stilstaat.",
			"praise": "Goed gewacht! Die %s stopte niet voor het zebrapad.",
		},
		"IGNORES_PRIORITY": {
			"title": "Botsing met een %s die geen voorrang gaf!",
			"fail": "Deze %s gaf geen voorrang, terwijl dat wel moest. Ook als jij voorrang hebt: blijf opletten en rem als iemand de weg op komt.",
			"close": "Pas op! Die %s gaf je geen voorrang. Blijf opletten, ook als jij voorrang hebt.",
			"praise": "Goed opgelet! Die %s gaf geen voorrang.",
		},
		"SPEEDING": {
			"title": "Botsing met een %s die veel te hard reed!",
			"fail": "Deze %s reed veel te hard en kon niet op tijd stoppen. Verkeer kan sneller zijn dan je denkt: wacht liever iets langer.",
			"close": "Pas op! Die %s reed veel te hard. Verkeer kan sneller zijn dan je denkt.",
			"praise": "",
		},
		"DISTRACTED": {
			"title": "Botsing met een %s die op zijn telefoon keek!",
			"fail": "Deze %s keek op zijn telefoon en zag je te laat. Ga er nooit van uit dat iemand jou heeft gezien.",
			"close": "Pas op! Die %s keek op zijn telefoon en zag je bijna niet.",
			"praise": "",
		},
	},
}


func set_language(lang: String) -> void:
	if lang == _lang:
		return
	_lang = lang
	changed.emit()


func language() -> String:
	return _lang


## Translate a key; falls back to English if the key is missing in the current language.
func t(key: String) -> String:
	var d: Dictionary = _STRINGS.get(_lang, {})
	if d.has(key):
		return d[key]
	return _STRINGS["en"].get(key, key)


## Translate an array value (e.g. success_ratings).
func ta(key: String) -> Array:
	var d: Dictionary = _STRINGS.get(_lang, {})
	if d.has(key):
		return d[key]
	return _STRINGS["en"].get(key, [])


## Rule info dict {"title", "text"} for a Violation name string.
func rule_info(violation_name: String) -> Dictionary:
	var d: Dictionary = _RULES.get(_lang, {})
	if d.has(violation_name):
		return d[violation_name]
	return _RULES["en"].get(violation_name, {"title": "?", "text": ""})


## Bad-actor text for a Misbehaviour name string and a key ("title","fail","close","praise").
func bad_actor(misbehaviour_name: String, key: String, who: String) -> String:
	var d: Dictionary = _BAD_ACTORS.get(_lang, {})
	var entry: Dictionary = d.get(misbehaviour_name, {})
	if entry.is_empty():
		entry = _BAD_ACTORS["en"].get(misbehaviour_name, {})
	var text: String = entry.get(key, "")
	return text % who if text.contains("%s") else text
