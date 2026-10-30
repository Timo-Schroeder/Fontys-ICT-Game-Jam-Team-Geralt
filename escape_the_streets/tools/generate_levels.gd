extends SceneTree
## Generates the 30 starting levels as .tres files in res://data/levels/.
## Run from the project folder:
##   godot --headless --path . --script res://tools/generate_levels.gd
## WARNING: this overwrites the .tres files. After the first run, edit levels in the
## Godot inspector instead (double-click a .tres in the FileSystem dock).

const OUT_DIR := "res://data/levels"

# Shorthands
const WALK := LevelData.Stage.WALK
const BIKE := LevelData.Stage.BIKE
const CAR := LevelData.Stage.CAR
const DAY := LevelData.TimeOfDay.DAY
const EVENING := LevelData.TimeOfDay.EVENING
const CLEAR := LevelData.Weather.CLEAR
const RAIN := LevelData.Weather.RAIN
const FOG := LevelData.Weather.FOG
const LIGHTS := {"junction_control": LevelData.JunctionControl.TRAFFIC_LIGHTS, "crossing_type": LevelData.CrossingType.SIGNAL}
const ZEBRA := {"junction_control": LevelData.JunctionControl.PRIORITY_ROAD, "crossing_type": LevelData.CrossingType.ZEBRA}
const UNMARKED := {"junction_control": LevelData.JunctionControl.PRIORITY_ROAD, "crossing_type": LevelData.CrossingType.NONE}

## Chance that a road user breaks the rules, per stage and level (index 0 = level 1).
## None in the very first lessons; then rare, slowly rising within each stage.
const BAD_ACTOR_CHANCE := [
	[0.0, 0.0, 0.03, 0.03, 0.03, 0.04, 0.04, 0.05, 0.05, 0.06],   # te voet
	[0.02, 0.04, 0.04, 0.05, 0.04, 0.04, 0.05, 0.04, 0.05, 0.06], # op de fiets
	[0.02, 0.04, 0.04, 0.04, 0.04, 0.05, 0.05, 0.05, 0.05, 0.06], # met het busje
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var count := 0
	for spec: Dictionary in _levels():
		var level := LevelData.new()
		for key: String in spec:
			if key == "layout":
				for k: String in spec[key]:
					level.set(k, spec[key][k])
			else:
				level.set(key, spec[key])
		if not spec.has("bad_actor_chance"):
			level.bad_actor_chance = BAD_ACTOR_CHANCE[level.stage][level.number - 1]
		var problem := level.validate()
		if problem != "":
			push_error("Level %s: %s" % [level.level_id(), problem])
			continue
		var path := OUT_DIR.path_join("stage%d_level%02d.tres" % [level.stage + 1, level.number])
		var err := ResourceSaver.save(level, path)
		if err != OK:
			push_error("Could not save %s: %s" % [path, error_string(err)])
		else:
			count += 1
	print("Saved %d levels to %s" % [count, OUT_DIR])
	quit()


func _levels() -> Array[Dictionary]:
	return [
		# ---------------------------------------------------------------- Stage 1: te voet
		{"stage": WALK, "number": 1, "title": "Het eerste pakketje",
		 "briefing": "Je eerste dag als bezorger! Je loopt naar de bakker en brengt daarna een pakketje rond. Bij het kruispunt staan verkeerslichten voor voetgangers. Druk op de knop (E) en wacht op groen.",
		 "lesson": "Bij een voetgangerslicht druk je op de knop en wacht je op groen.",
		 "layout": LIGHTS, "has_bike_paths": false, "building_setback": 6.0,
		 "car_density": 0.2, "bike_density": 0.0, "walkers": 2,
		 "start_spot": "S-W-30", "pickup_spot": "N-W-26", "delivery_spot": "N-E-30",
		 "pickup_name": "Bakkerij", "delivery_name": "Familie Jansen", "time_limit": 300.0},
		{"stage": WALK, "number": 2, "title": "Het fietspad",
		 "briefing": "Naast de stoep ligt een rood fietspad. Dat is voor fietsers! Blijf op de stoep en steek alleen over bij het voetgangerslicht.",
		 "lesson": "De stoep is voor voetgangers, het rode fietspad is voor fietsers.",
		 "layout": LIGHTS, "car_density": 0.25, "bike_density": 0.35, "walkers": 2,
		 "start_spot": "S-E-28", "pickup_spot": "N-E-30", "delivery_spot": "N-W-34",
		 "pickup_name": "Apotheek", "delivery_name": "Opa Henk", "time_limit": 300.0},
		{"stage": WALK, "number": 3, "title": "Het zebrapad",
		 "briefing": "Hier is geen verkeerslicht, maar een zebrapad. Auto's en fietsers moeten voor je stoppen. Maar let op: wacht tot ze echt stilstaan voordat je oversteekt!",
		 "lesson": "Bij een zebrapad wacht je tot het verkeer echt stilstaat. Kijk links, rechts en weer links.",
		 "layout": ZEBRA, "car_density": 0.25, "bike_density": 0.25, "walkers": 3,
		 "start_spot": "W-S-30", "pickup_spot": "E-S-30", "delivery_spot": "E-N-28",
		 "pickup_name": "Speelgoedwinkel", "delivery_name": "Juf Fatima", "time_limit": 300.0},
		{"stage": WALK, "number": 4, "title": "Fietsers en fatbikes",
		 "briefing": "Er fietsen veel mensen langs, en fatbikes gaan extra hard. Fietsers hebben hun eigen stoplicht. Ook als jij groen hebt: kijk goed of iedereen stopt.",
		 "lesson": "Fietsers en fatbikes kunnen hard rijden. Kijk ook naar het fietspad voordat je oversteekt.",
		 "layout": LIGHTS, "car_density": 0.3, "bike_density": 0.6, "fatbike_share": 0.35, "race_group_share": 0.1, "walkers": 2,
		 "start_spot": "N-W-30", "pickup_spot": "S-W-26", "delivery_spot": "S-E-32",
		 "pickup_name": "Fietsenmaker", "delivery_name": "Kinderboerderij", "time_limit": 300.0},
		{"stage": WALK, "number": 5, "title": "Oversteken zonder zebrapad",
		 "briefing": "Hier is geen zebrapad en geen verkeerslicht. Het verkeer stopt niet voor jou! Wacht op de stoep tot de weg helemaal vrij is: kijk links, rechts en weer links.",
		 "lesson": "Zonder zebrapad heeft het verkeer voorrang. Steek pas over als de weg helemaal vrij is.",
		 "layout": UNMARKED, "building_setback": 6.0, "car_density": 0.18, "bike_density": 0.2, "walkers": 2,
		 "start_spot": "E-N-30", "pickup_spot": "W-N-28", "delivery_spot": "W-S-34",
		 "pickup_name": "Bibliotheek", "delivery_name": "Mevrouw De Vries", "time_limit": 300.0},
		{"stage": WALK, "number": 6, "title": "Bussen en vrachtwagens",
		 "briefing": "Grote voertuigen zoals bussen en vrachtwagens kunnen niet snel stoppen en zien kleine mensen niet altijd. De huizen staan hier dicht bij de weg: kijk extra goed om de hoek.",
		 "lesson": "Grote voertuigen zien je soms niet. Ga nooit vlak naast of voor een bus of vrachtwagen staan.",
		 "layout": LIGHTS, "building_setback": 2.5, "car_density": 0.4, "bike_density": 0.3,
		 "bus_share": 0.2, "truck_share": 0.15, "walkers": 3,
		 "start_spot": "S-W-40", "pickup_spot": "N-W-30", "delivery_spot": "N-E-24",
		 "pickup_name": "Supermarkt", "delivery_name": "Basisschool", "time_limit": 300.0},
		{"stage": WALK, "number": 7, "title": "Sirene!",
		 "briefing": "Vandaag rijden er ambulances en brandweerauto's. Hoor je een sirene? Blijf op de stoep staan, ook als jouw licht groen is.",
		 "lesson": "Hoor je een sirene of zie je blauwe lichten? Blijf van de weg en laat de hulpdienst voorgaan.",
		 "layout": LIGHTS, "car_density": 0.3, "bike_density": 0.3, "emergency_times": PackedFloat32Array([20.0, 75.0]), "walkers": 2,
		 "start_spot": "W-S-30", "pickup_spot": "E-S-30", "delivery_spot": "E-N-34",
		 "pickup_name": "Huisarts", "delivery_name": "Buurvrouw Ans", "time_limit": 300.0},
		{"stage": WALK, "number": 8, "title": "Regen",
		 "briefing": "Het regent! Auto's en fietsers remmen nu minder goed. Wacht extra lang tot alles echt stilstaat.",
		 "lesson": "Bij regen is de remweg langer. Wacht langer met oversteken.",
		 "weather": RAIN, "layout": ZEBRA, "car_density": 0.25, "bike_density": 0.22, "bus_share": 0.1, "walkers": 2,
		 "start_spot": "N-E-30", "pickup_spot": "S-E-30", "delivery_spot": "S-W-26",
		 "pickup_name": "Viswinkel", "delivery_name": "Tante Lies", "time_limit": 320.0},
		{"stage": WALK, "number": 9, "title": "Het wordt donker",
		 "briefing": "Het wordt al donker. Bestuurders zien je dan minder goed. Steek alleen over bij groen en kijk goed om je heen.",
		 "lesson": "In het donker zien anderen je slecht. Draag lichte kleren of reflectie en steek over op een veilige plek.",
		 "time_of_day": EVENING, "layout": LIGHTS, "car_density": 0.35, "bike_density": 0.35, "walkers": 4, "runners": 3,
		 "start_spot": "E-S-30", "pickup_spot": "W-S-32", "delivery_spot": "W-N-28",
		 "pickup_name": "Snackbar", "delivery_name": "Meneer Bakker", "time_limit": 300.0},
		{"stage": WALK, "number": 10, "title": "Spitsuur",
		 "briefing": "Spitsuur! Het is heel druk. Laat zien wat je hebt geleerd: knop, groen licht, en goed kijken.",
		 "lesson": "Ook als het druk is: rustig blijven, wachten op groen en goed kijken.",
		 "layout": LIGHTS, "building_setback": 2.5, "car_density": 0.6, "bike_density": 0.5,
		 "bus_share": 0.12, "truck_share": 0.08, "motorbike_share": 0.08, "fatbike_share": 0.25, "race_group_share": 0.1,
		 "emergency_times": PackedFloat32Array([45.0]), "walkers": 5, "runners": 3,
		 "start_spot": "S-W-30", "pickup_spot": "N-E-30", "delivery_spot": "S-E-30",
		 "pickup_name": "Postkantoor", "delivery_name": "Burgemeester", "time_limit": 360.0},

		# ---------------------------------------------------------------- Stage 2: op de fiets
		{"stage": BIKE, "number": 1, "title": "Op het fietspad",
		 "briefing": "Nu ga je op de fiets! Fiets op het rode fietspad aan de rechterkant. Bij het kruispunt heb je een eigen fietslicht: rood is stoppen. Wil je naar de overkant? Kijk links, rechts en weer links en steek recht over.",
		 "lesson": "Fiets op het fietspad, rechts, in de richting van het verkeer. Bij rood stop je.",
		 "layout": LIGHTS, "car_density": 0.25, "bike_density": 0.2, "walkers": 2,
		 "start_spot": "S-E-40", "pickup_spot": "N-E-30", "delivery_spot": "N-W-24",
		 "pickup_name": "Pizzeria", "delivery_name": "Familie Yilmaz", "time_limit": 240.0},
		{"stage": BIKE, "number": 2, "title": "Rood is stoppen",
		 "briefing": "Twee keer over het kruispunt. Stop bij rood, ook als er niemand aankomt.",
		 "lesson": "Bij rood stop je altijd, ook als de weg leeg lijkt.",
		 "layout": LIGHTS, "car_density": 0.35, "bike_density": 0.3, "walkers": 2,
		 "start_spot": "S-E-40", "pickup_spot": "N-E-30", "delivery_spot": "S-W-35",
		 "pickup_name": "Bloemist", "delivery_name": "Opa Kees", "time_limit": 240.0},
		{"stage": BIKE, "number": 3, "title": "Haaientanden",
		 "briefing": "Zie je de witte driehoeken op de weg? Dat zijn haaientanden. Je moet voorrang geven aan al het verkeer op de andere weg, ook aan fietsers.",
		 "lesson": "Haaientanden betekenen: voorrang geven aan het verkeer op de kruisende weg.",
		 "layout": ZEBRA, "car_density": 0.22, "bike_density": 0.22, "walkers": 3,
		 "start_spot": "S-E-40", "pickup_spot": "N-E-30", "delivery_spot": "S-W-30",
		 "pickup_name": "Kapper", "delivery_name": "Mevrouw Bos", "time_limit": 240.0},
		{"stage": BIKE, "number": 4, "title": "De voorrangsweg",
		 "briefing": "Nu fiets je op de voorrangsweg (het gele ruitbord). Verkeer van de zijwegen moet jou voorrang geven. Maar kijk toch goed: niet iedereen doet het!",
		 "lesson": "Op een voorrangsweg heb je voorrang, maar blijf altijd opletten.",
		 "layout": ZEBRA, "car_density": 0.25, "bike_density": 0.25, "walkers": 2,
		 "start_spot": "W-S-40", "pickup_spot": "E-S-30", "delivery_spot": "W-N-32",
		 "pickup_name": "Sportschool", "delivery_name": "Meneer Visser", "time_limit": 240.0},
		{"stage": BIKE, "number": 5, "title": "Fatbikes en wielrenners",
		 "briefing": "Op het fietspad is het druk. Fatbikes en groepjes wielrenners gaan hard. Houd rechts en kijk achterom voordat je het fietspad op gaat.",
		 "lesson": "Kijk achterom voordat je het fietspad op rijdt. Snelle fietsers zijn er sneller dan je denkt.",
		 "layout": LIGHTS, "car_density": 0.3, "bike_density": 0.6, "fatbike_share": 0.35, "race_group_share": 0.15, "walkers": 2,
		 "start_spot": "W-S-40", "pickup_spot": "E-S-30", "delivery_spot": "W-N-32",
		 "pickup_name": "Fietsenwinkel", "delivery_name": "Familie De Jong", "time_limit": 240.0},
		{"stage": BIKE, "number": 6, "title": "Lampjes aan",
		 "briefing": "Het wordt donker. Zet je fietslicht aan met L: wit licht voor, rood licht achter. Zo kunnen anderen je zien.",
		 "lesson": "In het donker zet je altijd je fietslicht aan.",
		 "time_of_day": EVENING, "layout": LIGHTS, "car_density": 0.3, "bike_density": 0.3, "walkers": 2, "runners": 2,
		 "start_spot": "S-E-40", "pickup_spot": "N-E-30", "delivery_spot": "S-W-34",
		 "pickup_name": "Chinees restaurant", "delivery_name": "Buurman Piet", "time_limit": 240.0},
		{"stage": BIKE, "number": 7, "title": "Regen op de fiets",
		 "briefing": "Het regent en de weg is glad. Je remt minder goed en anderen ook. Rijd rustig en rem op tijd.",
		 "lesson": "Bij regen rem je eerder en rijd je rustiger.",
		 "weather": RAIN, "layout": ZEBRA, "car_density": 0.22, "bike_density": 0.22, "walkers": 2,
		 "start_spot": "W-S-40", "pickup_spot": "E-S-30", "delivery_spot": "W-N-30",
		 "pickup_name": "Drogist", "delivery_name": "Familie Smit", "time_limit": 260.0},
		{"stage": BIKE, "number": 8, "title": "Geen fietspad",
		 "briefing": "In deze straat is geen fietspad. Dan fiets je op de rijbaan, helemaal rechts. Auto's moeten achter je blijven of je voorzichtig inhalen.",
		 "lesson": "Is er geen fietspad? Fiets dan rechts op de weg.",
		 "layout": LIGHTS, "has_bike_paths": false, "car_density": 0.3, "bike_density": 0.0, "walkers": 2,
		 "start_spot": "S-E-40", "pickup_spot": "N-E-30", "delivery_spot": "S-W-30",
		 "pickup_name": "IJssalon", "delivery_name": "Juf Emma", "time_limit": 240.0},
		{"stage": BIKE, "number": 9, "title": "Sirene op de fiets",
		 "briefing": "Er komen hulpdiensten langs. Hoor je een sirene? Stop op het fietspad en laat de ambulance of brandweer eerst gaan.",
		 "lesson": "Bij een sirene stop je en laat je de hulpdienst voorgaan.",
		 "layout": LIGHTS, "car_density": 0.35, "bike_density": 0.3, "emergency_times": PackedFloat32Array([25.0, 70.0]), "walkers": 2,
		 "start_spot": "S-E-40", "pickup_spot": "N-E-30", "delivery_spot": "S-W-35",
		 "pickup_name": "Dierenwinkel", "delivery_name": "Familie Mulder", "time_limit": 240.0},
		{"stage": BIKE, "number": 10, "title": "Avondspits op de fiets",
		 "briefing": "Donker, regen en heel druk. Licht aan, rustig fietsen en goed kijken!",
		 "lesson": "Licht aan, rustig aan en goed kijken: zo kom je overal veilig.",
		 "time_of_day": EVENING, "weather": RAIN, "layout": LIGHTS, "building_setback": 3.0,
		 "car_density": 0.5, "bike_density": 0.5, "bus_share": 0.1, "fatbike_share": 0.25, "race_group_share": 0.1,
		 "emergency_times": PackedFloat32Array([50.0]), "walkers": 3, "runners": 2,
		 "start_spot": "W-S-40", "pickup_spot": "E-S-34", "delivery_spot": "W-N-30",
		 "pickup_name": "Pakketpunt", "delivery_name": "Wethouder", "time_limit": 280.0},

		# ---------------------------------------------------------------- Stage 3: met het busje
		{"stage": CAR, "number": 1, "title": "Rustig rijden",
		 "briefing": "Je hebt nu een bezorgbusje! Rijd rechts op de weg en houd je aan 30 km per uur. Bij een inrit geef je voorrang aan voetgangers en fietsers.",
		 "lesson": "Uit een inrit komen: iedereen gaat voor. Op de weg houd je je aan de maximumsnelheid.",
		 "layout": LIGHTS, "car_density": 0.15, "bike_density": 0.2, "walkers": 3,
		 "start_spot": "S-E-45", "pickup_spot": "N-E-30", "delivery_spot": "S-W-35",
		 "pickup_name": "Groothandel", "delivery_name": "Restaurant", "time_limit": 240.0},
		{"stage": CAR, "number": 2, "title": "Verkeerslichten",
		 "briefing": "Bij oranje stop je als dat nog veilig kan. Bij rood stop je altijd voor de streep.",
		 "lesson": "Oranje betekent: stoppen als dat veilig kan. Rood betekent: altijd stoppen.",
		 "layout": LIGHTS, "car_density": 0.35, "bike_density": 0.3, "walkers": 2,
		 "start_spot": "W-S-45", "pickup_spot": "E-S-30", "delivery_spot": "W-N-35",
		 "pickup_name": "Bouwmarkt", "delivery_name": "Familie Peters", "time_limit": 240.0},
		{"stage": CAR, "number": 3, "title": "Haaientanden met de auto",
		 "briefing": "Haaientanden: jij moet voorrang geven aan al het verkeer op de andere weg, ook aan fietsers.",
		 "lesson": "Haaientanden: stoppen, kijken en pas gaan als het helemaal vrij is.",
		 "layout": ZEBRA, "car_density": 0.25, "bike_density": 0.25, "walkers": 2,
		 "start_spot": "S-E-45", "pickup_spot": "N-E-30", "delivery_spot": "S-W-35",
		 "pickup_name": "Meubelwinkel", "delivery_name": "Familie Hendriks", "time_limit": 240.0},
		{"stage": CAR, "number": 4, "title": "Fietsers naast je",
		 "briefing": "Sla je rechtsaf? Fietsers die rechtdoor gaan, gaan voor! Kijk in je spiegel en over je schouder.",
		 "lesson": "Rechtsaf slaan: eerst fietsers en voetgangers die rechtdoor gaan voor laten gaan.",
		 "layout": LIGHTS, "car_density": 0.3, "bike_density": 0.6, "fatbike_share": 0.3, "walkers": 2,
		 "start_spot": "S-E-45", "pickup_spot": "E-S-30", "delivery_spot": "W-N-35",
		 "pickup_name": "Bloemenveiling", "delivery_name": "Hotel", "time_limit": 260.0},
		{"stage": CAR, "number": 5, "title": "Bus en vrachtwagen",
		 "briefing": "Hier mag je 50 km per uur. Er rijden bussen en vrachtwagens: houd genoeg afstand.",
		 "lesson": "Houd afstand tot het voertuig voor je, zodat je op tijd kunt stoppen.",
		 "layout": LIGHTS, "speed_limit_kmh": 50, "car_density": 0.35, "bike_density": 0.25,
		 "bus_share": 0.2, "truck_share": 0.2, "walkers": 2,
		 "start_spot": "S-E-45", "pickup_spot": "N-E-30", "delivery_spot": "S-W-35",
		 "pickup_name": "Distributiecentrum", "delivery_name": "Supermarkt", "time_limit": 240.0},
		{"stage": CAR, "number": 6, "title": "Op de voorrangsweg",
		 "briefing": "Je rijdt op de voorrangsweg. Verkeer uit de zijstraten moet jou voorrang geven, maar rijd niet te hard: 50 is het maximum.",
		 "lesson": "Voorrang hebben betekent niet dat je niet hoeft op te letten.",
		 "layout": ZEBRA, "speed_limit_kmh": 50, "car_density": 0.28, "bike_density": 0.25, "motorbike_share": 0.1, "walkers": 2,
		 "start_spot": "W-S-45", "pickup_spot": "E-S-35", "delivery_spot": "W-N-30",
		 "pickup_name": "Garage", "delivery_name": "Bakkerij", "time_limit": 240.0},
		{"stage": CAR, "number": 7, "title": "Ruim baan",
		 "briefing": "Een ambulance met zwaailicht en sirene gaat altijd voor. Stop bij het kruispunt, ook bij groen, en laat hem eerst gaan.",
		 "lesson": "Hulpdiensten met zwaailicht en sirene gaan altijd voor.",
		 "layout": LIGHTS, "car_density": 0.3, "bike_density": 0.3, "emergency_times": PackedFloat32Array([20.0, 60.0]), "walkers": 2,
		 "start_spot": "S-E-45", "pickup_spot": "N-E-30", "delivery_spot": "S-W-35",
		 "pickup_name": "Ziekenhuis", "delivery_name": "Huisartsenpost", "time_limit": 240.0},
		{"stage": CAR, "number": 8, "title": "Avondrit",
		 "briefing": "Het is donker. Fietsers en voetgangers zie je pas laat. Rijd rustig en kijk goed bij het oversteken.",
		 "lesson": "In het donker rijd je rustiger, omdat je anderen later ziet.",
		 "time_of_day": EVENING, "layout": LIGHTS, "car_density": 0.3, "bike_density": 0.35, "walkers": 3, "runners": 2,
		 "start_spot": "W-S-45", "pickup_spot": "E-S-30", "delivery_spot": "W-N-35",
		 "pickup_name": "Pakketcentrum", "delivery_name": "Familie Kok", "time_limit": 240.0},
		{"stage": CAR, "number": 9, "title": "Mist",
		 "briefing": "Het is mistig. Je ziet anderen pas laat, en zij jou ook. Rijd langzaam en houd veel afstand.",
		 "lesson": "Bij mist rijd je langzaam en houd je veel afstand.",
		 "weather": FOG, "layout": ZEBRA, "car_density": 0.22, "bike_density": 0.22, "walkers": 2,
		 "start_spot": "S-E-45", "pickup_spot": "N-E-30", "delivery_spot": "S-W-35",
		 "pickup_name": "Boerderij", "delivery_name": "Markthal", "time_limit": 260.0},
		{"stage": CAR, "number": 10, "title": "Logistiek-kampioen",
		 "briefing": "De laatste rit: avond, regen, spitsuur en een ambulance. Laat zien dat je de veiligste bezorger van de stad bent!",
		 "lesson": "Een goede bezorger is niet de snelste, maar de veiligste.",
		 "time_of_day": EVENING, "weather": RAIN, "layout": LIGHTS, "speed_limit_kmh": 50, "building_setback": 3.0,
		 "car_density": 0.5, "bike_density": 0.45, "bus_share": 0.12, "truck_share": 0.1, "motorbike_share": 0.08,
		 "fatbike_share": 0.25, "race_group_share": 0.1, "emergency_times": PackedFloat32Array([40.0]), "walkers": 4, "runners": 2,
		 "start_spot": "S-E-45", "pickup_spot": "N-E-30", "delivery_spot": "S-W-35",
		 "pickup_name": "Hoofdkantoor", "delivery_name": "Stadhuis", "time_limit": 280.0},
	]
