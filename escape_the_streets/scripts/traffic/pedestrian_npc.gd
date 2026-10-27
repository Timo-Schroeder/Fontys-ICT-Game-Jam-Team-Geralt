class_name PedestrianNPC
extends AnimatableBody3D
## A walker or runner going back and forth along a stretch of sidewalk.
## Waits when the player is right in front of them.

var traffic: TrafficManager
var is_runner := false
var _a: Vector3
var _b: Vector3
var _t := 0.0
var _dir := 1.0
var _speed := 1.3
var _anim_time := 0.0
var _visual: Node3D


func setup(p_traffic: TrafficManager, a: Vector3, b: Vector3, runner: bool, rng: RandomNumberGenerator) -> void:
	traffic = p_traffic
	_a = a
	_b = b
	is_runner = runner
	_speed = rng.randf_range(2.8, 3.4) if runner else rng.randf_range(1.0, 1.5)
	_t = rng.randf()
	_dir = 1.0 if rng.randf() < 0.5 else -1.0
	collision_layer = 8   # people
	collision_mask = 0
	sync_to_physics = false
	var shirt := Color.from_hsv(rng.randf(), 0.75, 0.95) if runner else Color.from_hsv(rng.randf(), 0.35, 0.7)
	_visual = Greybox.person(self, shirt, rng.randf_range(1.55, 1.85))
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)
	var hitbox := Area3D.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2
	hitbox.monitorable = false
	var hshape := CollisionShape3D.new()
	var hcap := CapsuleShape3D.new()
	hcap.radius = 0.4
	hcap.height = 1.7
	hshape.shape = hcap
	hshape.position.y = 0.85
	hitbox.add_child(hshape)
	add_child(hitbox)
	hitbox.body_entered.connect(_on_body_entered)
	_place()


func tick(delta: float) -> void:
	var heading := (_b - _a).normalized() * _dir
	var p := traffic.player
	if p and traffic.player_active:
		var rel := p.global_position - global_position
		rel.y = 0.0
		if rel.length() < 1.5 and rel.dot(heading) > 0.0:
			return   # politely wait
	_t += _dir * _speed * delta / maxf(_a.distance_to(_b), 0.1)
	if _t > 1.0:
		_t = 1.0
		_dir = -1.0
	elif _t < 0.0:
		_t = 0.0
		_dir = 1.0
	_anim_time += delta * _speed * 3.0
	_visual.position.y = absf(sin(_anim_time)) * (0.08 if is_runner else 0.03)
	_place()


func _place() -> void:
	var heading := (_b - _a).normalized() * _dir
	global_transform = Transform3D(Basis.looking_at(heading, Vector3.UP), _a.lerp(_b, _t))


func _on_body_entered(body: Node3D) -> void:
	if not (body is Courier) or not traffic.player_active:
		return
	var courier := body as Courier
	var gap := courier.global_position - global_position
	if Vector2(gap.x, gap.z).length() > courier.half_size().x + 1.0:
		return   # stale overlap from before a teleport
	var v := courier.get_real_velocity().length()
	if courier.mode == Courier.Mode.CAR or (courier.mode == Courier.Mode.BIKE and v > 2.0):
		EventBus.violation.emit(RuleBook.Violation.COLLISION, {"by": "voetganger"})
	elif v > 2.5:
		EventBus.violation.emit(RuleBook.Violation.BUMPED_PERSON, {})
