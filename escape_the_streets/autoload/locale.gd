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
		"collision_header": "Collision with %s!",
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

		# --- HUD ---
		"hud_level": "Level %s  •  %s",
		"controls_walk": "WASD walk  •  mouse look and turn  •  C look forward  •  Shift run  •  E push button  •  Esc pause",
		"controls_bike": "W pedal  •  S brake  •  A/D steer  •  mouse look around  •  C look forward  •  L light  •  B bell  •  Esc pause",
		"controls_car": "W accelerate  •  S brake/reverse  •  A/D steer  •  mouse look around  •  C look forward  •  H horn  •  Esc pause",
		"hud_time": "Time %d:%02d",
		"hud_speed": "%d km/h  (max %d)",
		"hud_light_on": "Light: ON",
		"hud_light_off": "Light: off (L)",
		"hud_siren": "Siren! Stay off the road and let the emergency vehicle go first.",
		"good_look": "Good looking!",
		"sign_depot": "Depot",
		"push_button_sign": "PUSH",
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
		"collision_header": "Botsing met %s!",
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

		# --- HUD ---
		"hud_level": "Level %s  •  %s",
		"controls_walk": "WASD lopen  •  muis rondkijken en draaien  •  C vooruit kijken  •  Shift rennen  •  E drukknop  •  Esc pauze",
		"controls_bike": "W trappen  •  S remmen  •  A/D sturen  •  muis rondkijken  •  C vooruit kijken  •  L licht  •  B bel  •  Esc pauze",
		"controls_car": "W gas  •  S rem/achteruit  •  A/D sturen  •  muis rondkijken  •  C vooruit kijken  •  H toeter  •  Esc pauze",
		"hud_time": "Tijd %d:%02d",
		"hud_speed": "%d km/u  (max %d)",
		"hud_light_on": "Licht: AAN",
		"hud_light_off": "Licht: uit (L)",
		"hud_siren": "Sirene! Blijf van de weg en laat de hulpdienst voorgaan.",
		"good_look": "Goed gekeken!",
		"sign_depot": "Depot",
		"push_button_sign": "DRUK",
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
	return text % vehicle(who) if text.contains("%s") else text


## English texts for the levels. The Dutch texts stay in the level files (data/levels/*.tres).
## Key = level id ("stage-number"). Fields: title, briefing, lesson, pickup_name, delivery_name.
const _LEVELS_EN := {
	"1-1": {"title": "Your first parcel", "briefing": "Your first day as a courier! You walk to the bakery and then deliver a parcel. There are pedestrian lights at the crossroads. Press the button (E) and wait for green.", "lesson": "At a pedestrian light you press the button and wait for green.", "pickup_name": "Bakery", "delivery_name": "The Jansen family"},
	"1-2": {"title": "The bike path", "briefing": "Next to the pavement is a red bike path. That is for cyclists! Stay on the pavement and only cross at the pedestrian light.", "lesson": "The pavement is for pedestrians, the red bike path is for cyclists.", "pickup_name": "Pharmacy", "delivery_name": "Grandpa Henk"},
	"1-3": {"title": "The zebra crossing", "briefing": "There is no traffic light here, but a zebra crossing. Cars and cyclists must stop for you. But watch out: wait until they have really stopped before you cross!", "lesson": "At a zebra crossing you wait until the traffic has really stopped. Look left, right and left again.", "pickup_name": "Toy shop", "delivery_name": "Miss Fatima"},
	"1-4": {"title": "Cyclists and fatbikes", "briefing": "Lots of people cycle past, and fatbikes go extra fast. Cyclists have their own traffic light. Even when you have green: check that everyone stops.", "lesson": "Cyclists and fatbikes can go fast. Look at the bike path too before you cross.", "pickup_name": "Bike repair shop", "delivery_name": "Petting farm"},
	"1-5": {"title": "Crossing without a zebra", "briefing": "There is no zebra crossing and no traffic light here. The traffic does not stop for you! Wait on the pavement until the road is completely clear: look left, right and left again.", "lesson": "Without a zebra crossing, traffic has right of way. Only cross when the road is completely clear.", "pickup_name": "Library", "delivery_name": "Mrs De Vries"},
	"1-6": {"title": "Buses and lorries", "briefing": "Big vehicles like buses and lorries cannot stop quickly and do not always see small people. The houses here are close to the road: look extra carefully around the corner.", "lesson": "Big vehicles sometimes cannot see you. Never stand right next to or in front of a bus or lorry.", "pickup_name": "Supermarket", "delivery_name": "Primary school"},
	"1-7": {"title": "Siren!", "briefing": "Ambulances and fire engines are out today. Do you hear a siren? Stay on the pavement, even if your light is green.", "lesson": "Do you hear a siren or see blue lights? Stay off the road and let the emergency vehicle go first.", "pickup_name": "Doctor's surgery", "delivery_name": "Neighbour Ans"},
	"1-8": {"title": "Rain", "briefing": "It is raining! Cars and cyclists cannot brake as well now. Wait extra long until everything has really stopped.", "lesson": "In the rain it takes longer to stop. Wait longer before you cross.", "pickup_name": "Fish shop", "delivery_name": "Aunt Lies"},
	"1-9": {"title": "It's getting dark", "briefing": "It is getting dark. Drivers cannot see you as well. Only cross on green and look carefully around you.", "lesson": "In the dark others can hardly see you. Wear light clothes or reflectors and cross at a safe place.", "pickup_name": "Snack bar", "delivery_name": "Mr Bakker"},
	"1-10": {"title": "Rush hour", "briefing": "Rush hour! It is very busy. Show what you have learned: button, green light, and look carefully.", "lesson": "Even when it is busy: stay calm, wait for green and look carefully.", "pickup_name": "Post office", "delivery_name": "The mayor"},
	"2-1": {"title": "On the bike path", "briefing": "Now you go by bike! Ride on the red bike path on the right. At the crossroads you have your own bike light: red means stop. Want to go to the other side? Look left, right and left again and cross straight over.", "lesson": "Ride on the bike path, on the right, in the direction of the traffic. At red you stop.", "pickup_name": "Pizzeria", "delivery_name": "The Yilmaz family"},
	"2-2": {"title": "Red means stop", "briefing": "Across the crossroads twice. Stop at red, even when nobody is coming.", "lesson": "At red you always stop, even when the road looks empty.", "pickup_name": "Florist", "delivery_name": "Grandpa Kees"},
	"2-3": {"title": "Shark teeth", "briefing": "Do you see the white triangles on the road? Those are shark teeth. You must give way to all traffic on the other road, cyclists too.", "lesson": "Shark teeth mean: give way to the traffic on the crossing road.", "pickup_name": "Hairdresser", "delivery_name": "Mrs Bos"},
	"2-4": {"title": "The priority road", "briefing": "Now you are cycling on the priority road (the yellow diamond sign). Traffic from the side roads must give way to you. But keep looking: not everyone does!", "lesson": "On a priority road you have right of way, but always stay alert.", "pickup_name": "Gym", "delivery_name": "Mr Visser"},
	"2-5": {"title": "Fatbikes and racing cyclists", "briefing": "The bike path is busy. Fatbikes and groups of racing cyclists go fast. Keep right and look behind you before you ride onto the bike path.", "lesson": "Look behind you before you ride onto the bike path. Fast cyclists are there sooner than you think.", "pickup_name": "Bike shop", "delivery_name": "The De Jong family"},
	"2-6": {"title": "Lights on", "briefing": "It is getting dark. Turn your bike light on with L: white light at the front, red light at the back. That way others can see you.", "lesson": "In the dark you always turn your bike light on.", "pickup_name": "Chinese restaurant", "delivery_name": "Neighbour Piet"},
	"2-7": {"title": "Cycling in the rain", "briefing": "It is raining and the road is slippery. You brake less well, and so do others. Ride calmly and brake in time.", "lesson": "In the rain you brake earlier and ride more calmly.", "pickup_name": "Chemist", "delivery_name": "The Smit family"},
	"2-8": {"title": "No bike path", "briefing": "There is no bike path in this street. Then you ride on the road, all the way to the right. Cars must stay behind you or overtake you carefully.", "lesson": "No bike path? Then ride on the right of the road.", "pickup_name": "Ice cream shop", "delivery_name": "Miss Emma"},
	"2-9": {"title": "Siren on the bike", "briefing": "Emergency vehicles are coming through. Do you hear a siren? Stop on the bike path and let the ambulance or fire engine go first.", "lesson": "When you hear a siren, you stop and let the emergency vehicle go first.", "pickup_name": "Pet shop", "delivery_name": "The Mulder family"},
	"2-10": {"title": "Evening rush on the bike", "briefing": "Dark, rain and very busy. Lights on, ride calmly and look carefully!", "lesson": "Lights on, take it easy and look carefully: that way you get everywhere safely.", "pickup_name": "Parcel point", "delivery_name": "The alderman"},
	"3-1": {"title": "Easy driving", "briefing": "You now have a delivery van! Drive on the right of the road and keep to 30 km per hour. At a driveway you give way to pedestrians and cyclists.", "lesson": "Coming out of a driveway: everyone goes first. On the road you keep to the speed limit.", "pickup_name": "Wholesaler", "delivery_name": "Restaurant"},
	"3-2": {"title": "Traffic lights", "briefing": "At orange you stop if you still can safely. At red you always stop before the line.", "lesson": "Orange means: stop if you safely can. Red means: always stop.", "pickup_name": "DIY store", "delivery_name": "The Peters family"},
	"3-3": {"title": "Shark teeth in the van", "briefing": "Shark teeth: you must give way to all traffic on the other road, cyclists too.", "lesson": "Shark teeth: stop, look and only go when it is completely clear.", "pickup_name": "Furniture shop", "delivery_name": "The Hendriks family"},
	"3-4": {"title": "Cyclists next to you", "briefing": "Turning right? Cyclists going straight on go first! Check your mirror and look over your shoulder.", "lesson": "Turning right: first let cyclists and pedestrians going straight on go.", "pickup_name": "Flower auction", "delivery_name": "Hotel"},
	"3-5": {"title": "Bus and lorry", "briefing": "You may drive 50 km per hour here. There are buses and lorries: keep enough distance.", "lesson": "Keep your distance from the vehicle in front, so you can stop in time.", "pickup_name": "Distribution centre", "delivery_name": "Supermarket"},
	"3-6": {"title": "On the priority road", "briefing": "You are driving on the priority road. Traffic from the side streets must give way to you, but do not drive too fast: 50 is the maximum.", "lesson": "Having right of way does not mean you can stop paying attention.", "pickup_name": "Garage", "delivery_name": "Bakery"},
	"3-7": {"title": "Make way", "briefing": "An ambulance with flashing lights and a siren always goes first. Stop at the crossroads, even on green, and let it go first.", "lesson": "Emergency vehicles with flashing lights and a siren always go first.", "pickup_name": "Hospital", "delivery_name": "Out-of-hours doctor"},
	"3-8": {"title": "Evening drive", "briefing": "It is dark. You only see cyclists and pedestrians late. Drive calmly and look carefully at the crossings.", "lesson": "In the dark you drive more calmly, because you see others later.", "pickup_name": "Parcel centre", "delivery_name": "The Kok family"},
	"3-9": {"title": "Fog", "briefing": "It is foggy. You see others late, and they see you late too. Drive slowly and keep plenty of distance.", "lesson": "In fog you drive slowly and keep plenty of distance.", "pickup_name": "Farm", "delivery_name": "Market hall"},
	"3-10": {"title": "Delivery champion", "briefing": "The last ride: evening, rain, rush hour and an ambulance. Show that you are the safest courier in town!", "lesson": "A good courier is not the fastest, but the safest.", "pickup_name": "Head office", "delivery_name": "Town hall"},
}

## Road user names. The game stores the Dutch name; English is looked up here.
const _VEHICLES_EN := {
	"auto": "car", "bestelbus": "van", "bus": "bus", "vrachtwagen": "lorry", "motor": "motorbike",
	"ambulance": "ambulance", "brandweerauto": "fire engine", "politieauto": "police car",
	"fietser": "cyclist", "fatbike": "fatbike", "wielrenner": "racing cyclist",
}


## A level's text in the current language. `fallback` is the Dutch text from the level file.
func level_text(level_id: String, field: String, fallback: String) -> String:
	if _lang == "en":
		var entry: Dictionary = _LEVELS_EN.get(level_id, {})
		var text: String = entry.get(field, "")
		if text != "":
			return text
	return fallback


## Name of a road user ("auto", "fietser", ...) in the current language.
func vehicle(dutch_name: String) -> String:
	if _lang == "en":
		return _VEHICLES_EN.get(dutch_name, dutch_name)
	return dutch_name


## The same with "a"/"an" in front in English ("an ambulance"), or "een" in Dutch.
func vehicle_with_article(dutch_name: String) -> String:
	var n := vehicle(dutch_name)
	if _lang == "en":
		return ("an " if n.substr(0, 1).to_lower() in ["a", "e", "i", "o", "u"] else "a ") + n
	return "een " + n
