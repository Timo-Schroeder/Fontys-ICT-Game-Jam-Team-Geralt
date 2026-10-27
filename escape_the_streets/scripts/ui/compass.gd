extends Control
## Arrow at the top of the screen pointing to the current target (B or C).
## angle = 0 means straight ahead, positive = to the right.

@export var color := Color("ffd38a")

var angle := 0.0:
	set(value):
		angle = value
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.45
	draw_circle(c, r, Color(0, 0, 0, 0.45))
	draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.6), 2.0, true)
	var pts := PackedVector2Array([
		Vector2(0, -r * 0.8), Vector2(r * 0.45, r * 0.5), Vector2(0, r * 0.22), Vector2(-r * 0.45, r * 0.5),
	])
	for i in pts.size():
		pts[i] = c + pts[i].rotated(angle)
	draw_colored_polygon(pts, color)
