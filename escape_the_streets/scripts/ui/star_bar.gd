extends Control
## Three safety stars. Every police stop costs one.

@export var max_stars := 3
@export var filled := Color("ffcc33")
@export var empty := Color(1, 1, 1, 0.25)

var stars := 3:
	set(value):
		stars = value
		queue_redraw()


func _draw() -> void:
	var r := minf(size.y * 0.5, size.x / (max_stars * 2.2))
	var step := size.x / max_stars
	for i in max_stars:
		var c := Vector2(step * (i + 0.5), size.y * 0.5)
		var pts := PackedVector2Array()
		for k in 10:
			var rad := r if k % 2 == 0 else r * 0.45
			var a := -PI * 0.5 + k * PI / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * rad)
		draw_colored_polygon(pts, filled if i < stars else empty)
