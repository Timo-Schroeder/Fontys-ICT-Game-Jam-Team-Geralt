class_name StreetLayout
extends RefCounted
## Pure geometry of a Dutch four-arm crossroads, without any nodes.
## Used by the StreetBuilder (visuals), the TrafficManager (lanes) and the
## RuleMonitor ("what is the player standing on?"). Keeping it pure math
## makes it easy to unit-test and to replace later with a bigger road network.
##
## Coordinates: the crossroads is at the origin. North = -Z, south = +Z,
## east = +X, west = -X. Traffic keeps right. 2D points use Vector2(x, z).
##
## Cross-section from the road centre outwards (metres):
##   0 .. 3.5   road (one 3.5 m lane per direction)
##   3.5 .. 4.0 curb strip
##   4.0 .. 6.0 one-way bike path (only when has_bike_paths)
##   .. +2.5    sidewalk (stoep)
##   beyond     front gardens, pads (delivery spots), buildings

enum Surface { GRASS, SIDEWALK, BIKE_PATH, ROAD, CURB, CROSSING, DRIVEWAY, PAD }
enum Axis { NS, EW }

const LANE_WIDTH := 3.5
const ROAD_HALF := 3.5
const CURB := 0.5
const BIKE_WIDTH := 2.0
const WALK_WIDTH := 2.5
const ARM_LENGTH := 70.0
const PAD_DEPTH := 5.0
const PAD_WIDTH := 6.0
const DRIVEWAY_WIDTH := 3.0
## Waiting area next to a crossing. A pedestrian standing here "claims" a zebra crossing.
const CLAIM_MARGIN := 1.5

const ARM_DIR := {"N": Vector2(0, -1), "S": Vector2(0, 1), "E": Vector2(1, 0), "W": Vector2(-1, 0)}
const ARMS := ["N", "E", "S", "W"]


## A named place on the map where the route starts, the package is picked up or delivered.
class Spot:
	var name: String
	var arm: String
	var side: int              ## -1 = west/north side, +1 = east/south side
	var distance: float
	var sidewalk_point: Vector3
	var pad_rect: Rect2        ## the paved delivery area in front of the building
	var pad_center: Vector3
	var driveway_rect: Rect2   ## from the road edge to the pad (bike and car stages)
	var to_street: Vector3     ## unit vector from the pad towards the street


## A place to cross one arm of the crossroads (zebra, signalled or unmarked).
class Crossing:
	var arm: String
	var road_axis: int           ## the Axis of the road being crossed
	var type: int                ## LevelData.CrossingType
	var rect: Rect2              ## the whole crossing, including bike paths
	var road_rect: Rect2         ## only the part over the car lanes
	var claim_rect: Rect2        ## crossing plus the waiting area on both ends
	var walk_dir: Vector2        ## direction of walking across
	var center: Vector3
	var buttons: Array[Vector3] = []   ## push-button (drukknop) positions for signalled crossings
	# Runtime state, written by the traffic system:
	var requested := false       ## someone pressed the push button
	var claimed := false         ## a pedestrian is on it or waiting next to it


## What is at a point on the map.
class SurfaceInfo:
	var surface: int = 0              ## Surface
	var axis: int = -1                ## Axis of the road/bike path, -1 if not on one or in the middle
	var crossing: Crossing = null
	var on_crossing_road := false     ## on the car-lane part of a crossing
	var in_junction := false          ## inside the square where the two roads meet
	var spot: Spot = null


## A straight lane that vehicles drive along, from one end of the map to the other.
class LaneDef:
	var name: String
	var kind: String                  ## "road" or "bike"
	var axis: int
	var start: Vector2
	var dir: Vector2
	var length: float
	var stop_offset: float            ## where vehicles stop for lights / give way
	var junction_enter: float
	var junction_exit: float
	var crossings: Array = []         ## [{crossing, enter, exit}] sorted by enter


var has_bike_paths: bool
var has_driveways: bool
var crossing_type: int
var junction_control: int
var bike_inner: float
var bike_outer: float
var walk_inner: float
var walk_outer: float
var crossings: Array[Crossing] = []
var spots: Dictionary = {}            ## spot string -> Spot
var lanes: Array[LaneDef] = []


func _init(level: LevelData) -> void:
	has_bike_paths = level.has_bike_paths
	has_driveways = level.stage != LevelData.Stage.WALK
	crossing_type = level.crossing_type
	junction_control = level.junction_control
	bike_inner = ROAD_HALF + CURB
	bike_outer = bike_inner + (BIKE_WIDTH if has_bike_paths else 0.0)
	walk_inner = bike_outer
	walk_outer = walk_inner + WALK_WIDTH
	_build_crossings()
	for spot_text: String in [level.start_spot, level.pickup_spot, level.delivery_spot]:
		var spot := _make_spot(spot_text)
		if spot:
			spots[spot_text] = spot
	_build_lanes()


# --- Spots -------------------------------------------------------------------

## "S-W-30" -> {arm: "S", side: -1, distance: 30}. Empty dictionary if invalid.
static func parse_spot(text: String) -> Dictionary:
	var parts := text.strip_edges().to_upper().split("-")
	if parts.size() != 3:
		return {}
	var arm := parts[0]
	var side := parts[1]
	if not ARM_DIR.has(arm):
		return {}
	var valid_sides := ["W", "E"] if arm in ["N", "S"] else ["N", "S"]
	if side not in valid_sides:
		return {}
	if not parts[2].is_valid_float():
		return {}
	var distance := parts[2].to_float()
	if distance < 16.0 or distance > ARM_LENGTH - 10.0:
		return {}
	return {"arm": arm, "side": -1 if side in ["W", "N"] else 1, "distance": distance}


func spot(text: String) -> Spot:
	return spots.get(text)


func _make_spot(text: String) -> Spot:
	var parsed := parse_spot(text)
	if parsed.is_empty():
		push_error("Invalid spot '%s' (format ARM-SIDE-DISTANCE, e.g. S-W-30)" % text)
		return null
	var s := Spot.new()
	s.name = text
	s.arm = parsed["arm"]
	s.side = parsed["side"]
	s.distance = parsed["distance"]
	var a: Vector2 = ARM_DIR[s.arm]
	var lat := lateral_axis(s.arm)
	var d := s.distance
	s.sidewalk_point = to_3d(a * d + lat * (s.side * (walk_inner + walk_outer) * 0.5))
	s.pad_rect = _arm_rect(s.arm, d - PAD_WIDTH * 0.5, d + PAD_WIDTH * 0.5,
			s.side * walk_outer, s.side * (walk_outer + PAD_DEPTH))
	s.pad_center = to_3d(s.pad_rect.get_center())
	s.driveway_rect = _arm_rect(s.arm, d - DRIVEWAY_WIDTH * 0.5, d + DRIVEWAY_WIDTH * 0.5,
			s.side * ROAD_HALF, s.side * walk_outer)
	s.to_street = to_3d(lat * -s.side).normalized()
	return s


# --- Crossings ---------------------------------------------------------------

func _build_crossings() -> void:
	for arm: String in ARMS:
		var c := Crossing.new()
		c.arm = arm
		c.road_axis = Axis.NS if arm in ["N", "S"] else Axis.EW
		c.type = crossing_type
		c.rect = _arm_rect(arm, walk_inner, walk_outer, -walk_inner, walk_inner)
		c.road_rect = _arm_rect(arm, walk_inner, walk_outer, -ROAD_HALF, ROAD_HALF)
		c.claim_rect = _arm_rect(arm, walk_inner, walk_outer,
				-(walk_inner + CLAIM_MARGIN), walk_inner + CLAIM_MARGIN)
		c.walk_dir = lateral_axis(arm)
		c.center = to_3d(c.rect.get_center())
		var a: Vector2 = ARM_DIR[arm]
		var lat := lateral_axis(arm)
		for side: int in [-1, 1]:
			c.buttons.append(to_3d(a * (walk_outer + 0.3) + lat * (side * (walk_inner + 0.5))))
		crossings.append(c)


# --- Lanes -------------------------------------------------------------------

func _build_lanes() -> void:
	var road_lat := LANE_WIDTH * 0.5
	# Keep right: southbound traffic drives on the west half, northbound on the east half, etc.
	_add_lane("road_southbound", "road", Axis.NS, Vector2(-road_lat, -ARM_LENGTH), Vector2(0, 1))
	_add_lane("road_northbound", "road", Axis.NS, Vector2(road_lat, ARM_LENGTH), Vector2(0, -1))
	_add_lane("road_eastbound", "road", Axis.EW, Vector2(-ARM_LENGTH, road_lat), Vector2(1, 0))
	_add_lane("road_westbound", "road", Axis.EW, Vector2(ARM_LENGTH, -road_lat), Vector2(-1, 0))
	if has_bike_paths:
		var b := (bike_inner + bike_outer) * 0.5
		_add_lane("bike_southbound", "bike", Axis.NS, Vector2(-b, -ARM_LENGTH), Vector2(0, 1))
		_add_lane("bike_northbound", "bike", Axis.NS, Vector2(b, ARM_LENGTH), Vector2(0, -1))
		_add_lane("bike_eastbound", "bike", Axis.EW, Vector2(-ARM_LENGTH, b), Vector2(1, 0))
		_add_lane("bike_westbound", "bike", Axis.EW, Vector2(ARM_LENGTH, -b), Vector2(-1, 0))


func _add_lane(lane_name: String, kind: String, axis: int, start: Vector2, dir: Vector2) -> void:
	var ld := LaneDef.new()
	ld.name = lane_name
	ld.kind = kind
	ld.axis = axis
	ld.start = start
	ld.dir = dir
	ld.length = ARM_LENGTH * 2.0
	var junction := conflict_rect()
	var j := _interval_on_lane(ld, junction)
	ld.junction_enter = j.x
	ld.junction_exit = j.y
	for c in crossings:
		var iv := _interval_on_lane(ld, c.rect)
		if iv.x >= 0.0:
			ld.crossings.append({"crossing": c, "enter": iv.x, "exit": iv.y})
	ld.crossings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["enter"] < b["enter"])
	# Stop before the first crossing on the way in, or at the junction edge if there is none.
	var first_stop := ld.junction_enter
	for entry in ld.crossings:
		if entry["enter"] < ld.junction_enter:
			first_stop = minf(first_stop, entry["enter"])
	ld.stop_offset = first_stop - 1.0
	lanes.append(ld)


## Offsets along the lane where it overlaps the rect, as Vector2(enter, exit); (-1, -1) if never.
func _interval_on_lane(ld: LaneDef, rect: Rect2) -> Vector2:
	var t1: float
	var t2: float
	if ld.axis == Axis.NS:
		if ld.start.x <= rect.position.x or ld.start.x >= rect.end.x:
			return Vector2(-1, -1)
		t1 = (rect.position.y - ld.start.y) * ld.dir.y
		t2 = (rect.end.y - ld.start.y) * ld.dir.y
	else:
		if ld.start.y <= rect.position.y or ld.start.y >= rect.end.y:
			return Vector2(-1, -1)
		t1 = (rect.position.x - ld.start.x) * ld.dir.x
		t2 = (rect.end.x - ld.start.x) * ld.dir.x
	return Vector2(minf(t1, t2), maxf(t1, t2))


# --- Queries -----------------------------------------------------------------

## The square where the two roads (and their bike paths) meet.
func conflict_rect() -> Rect2:
	return Rect2(-walk_inner, -walk_inner, walk_inner * 2.0, walk_inner * 2.0)


func in_conflict_zone(p: Vector2) -> bool:
	return absf(p.x) < walk_inner and absf(p.y) < walk_inner


## What kind of surface is at point p (x, z)?
func classify(p: Vector2) -> SurfaceInfo:
	var info := SurfaceInfo.new()
	var ax := absf(p.x)
	var az := absf(p.y)
	info.in_junction = ax < walk_inner and az < walk_inner
	for s: Spot in spots.values():
		if s.pad_rect.has_point(p):
			info.surface = Surface.PAD
			info.spot = s
			return info
		if has_driveways and s.driveway_rect.has_point(p):
			info.surface = Surface.DRIVEWAY
			info.spot = s
			return info
	for c in crossings:
		if c.rect.has_point(p):
			info.surface = Surface.CROSSING
			info.crossing = c
			info.axis = c.road_axis
			info.on_crossing_road = c.road_rect.has_point(p)
			return info
	if ax < ROAD_HALF or az < ROAD_HALF:
		info.surface = Surface.ROAD
		if ax < ROAD_HALF and az >= ROAD_HALF:
			info.axis = Axis.NS
		elif az < ROAD_HALF and ax >= ROAD_HALF:
			info.axis = Axis.EW
		return info
	if ax < bike_inner or az < bike_inner:
		info.surface = Surface.CURB
		return info
	var ns_bike := has_bike_paths and ax < bike_outer
	var ew_bike := has_bike_paths and az < bike_outer
	if ns_bike or ew_bike:
		info.surface = Surface.BIKE_PATH
		if ns_bike and not ew_bike:
			info.axis = Axis.NS
		elif ew_bike and not ns_bike:
			info.axis = Axis.EW
		return info
	if ax < walk_outer or az < walk_outer:
		info.surface = Surface.SIDEWALK
		return info
	info.surface = Surface.GRASS
	return info


## Direction traffic is supposed to move at point p on a road or bike path of `axis` (keep right).
func expected_direction(p: Vector2, axis: int) -> Vector2:
	if axis == Axis.NS:
		return Vector2(0, -1) if p.x > 0.0 else Vector2(0, 1)
	if axis == Axis.EW:
		return Vector2(1, 0) if p.y > 0.0 else Vector2(-1, 0)
	return Vector2.ZERO


# --- Helpers -----------------------------------------------------------------

static func lateral_axis(arm: String) -> Vector2:
	return Vector2(1, 0) if arm in ["N", "S"] else Vector2(0, 1)


static func to_3d(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)


static func to_2d(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


## Rect along an arm: d = distance from the centre along the arm, l = lateral offset (signed).
func _arm_rect(arm: String, d0: float, d1: float, l0: float, l1: float) -> Rect2:
	var a: Vector2 = ARM_DIR[arm]
	var lat := lateral_axis(arm)
	var p1 := a * d0 + lat * l0
	var p2 := a * d1 + lat * l1
	return Rect2(p1, Vector2.ZERO).expand(p2)
