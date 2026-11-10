extends Control
## Draws a small flag: "us" (United States) or "nl" (the Netherlands).
## Drawn in code, so no image files are needed.

@export var country := "nl"


func _draw() -> void:
	var w := size.x
	var h := size.y
	if country == "us":
		_draw_us(w, h)
	else:
		_draw_nl(w, h)
	# Thin outline so the white parts stand out on any background.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35), false, 1.0)


func _draw_nl(w: float, h: float) -> void:
	var band := h / 3.0
	draw_rect(Rect2(0, 0, w, band), Color("ae1c28"))
	draw_rect(Rect2(0, band, w, band), Color.WHITE)
	draw_rect(Rect2(0, band * 2.0, w, h - band * 2.0), Color("21468b"))


func _draw_us(w: float, h: float) -> void:
	var red := Color("b22234")
	var blue := Color("3c3b6e")
	# 13 stripes, starting and ending with red.
	var stripe := h / 13.0
	for i in 13:
		draw_rect(Rect2(0, i * stripe, w, stripe + 0.5), red if i % 2 == 0 else Color.WHITE)
	# Blue canton over the top seven stripes, 40% of the width.
	var cw := w * 0.4
	var ch := stripe * 7.0
	draw_rect(Rect2(0, 0, cw, ch), blue)
	# Stars as small white dots: alternating rows of 6 and 5, like the real flag.
	var rows := 9
	var r: float = max(0.8, ch / 40.0)
	for row in rows:
		var count := 6 if row % 2 == 0 else 5
		var y := ch * (row + 1) / float(rows + 1)
		for col in count:
			var x := cw * ((col * 2 + (1 if row % 2 == 0 else 2)) / 12.0)
			draw_circle(Vector2(x, y), r, Color.WHITE)
