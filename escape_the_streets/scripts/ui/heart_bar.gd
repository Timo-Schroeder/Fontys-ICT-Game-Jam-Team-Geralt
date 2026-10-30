extends Control
## Lives during a level, drawn as hearts. Every police stop costs one life.
## The lives you still have when you deliver the package become your stars for that level.

@export var max_lives := 3
@export var filled := Color("ff4d5e")
@export var empty := Color(1, 1, 1, 0.22)

var lives := 3:
	set(value):
		var lost := value < lives
		lives = value
		queue_redraw()
		if lost and is_inside_tree():
			_flash()


func _draw() -> void:
	var r := minf(size.y * 0.5, size.x / (max_lives * 2.3))
	var step := size.x / max_lives
	for i in max_lives:
		var c := Vector2(step * (i + 0.5), size.y * 0.5)
		var pts := PackedVector2Array()
		for k in 48:
			# Classic heart curve, scaled to radius r.
			var t := TAU * k / 48.0
			var x := 16.0 * pow(sin(t), 3)
			var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
			pts.append(c + Vector2(x, -(y + 2.5)) * (r / 16.0))
		draw_colored_polygon(pts, filled if i < lives else empty)


func _flash() -> void:
	modulate = Color(1.0, 0.35, 0.35)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.8)
