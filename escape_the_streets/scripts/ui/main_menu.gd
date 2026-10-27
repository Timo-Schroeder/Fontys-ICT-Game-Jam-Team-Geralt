extends Control
## Title screen with three stages of ten levels each. Built in code from GameState.levels,
## so new levels show up automatically when a .tres file is added to data/levels.

const STAGE_COLORS := [Color("ff9a3c"), Color("3cb4ff"), Color("7be08a")]
const STAGE_ICONS := ["Te voet", "Op de fiets", "Met het busje"]


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("1d2731")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 18)
	root.offset_left = 60
	root.offset_right = -60
	root.offset_top = 40
	root.offset_bottom = -30
	add_child(root)

	var title := Label.new()
	title.text = "Escape the Streets"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("ffd38a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var sub := Label.new()
	sub.text = "Bezorg je pakketjes veilig door het verkeer.   Sterren: %d / %d" % [GameState.total_stars(), GameState.levels.size() * 3]
	sub.add_theme_font_size_override("font_size", 24)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)

	if GameState.levels.is_empty():
		var warn := Label.new()
		warn.text = "Geen levels gevonden in %s" % GameState.LEVEL_DIR
		root.add_child(warn)
		return

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(columns)

	for stage in 3:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(440, 0)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(STAGE_COLORS[stage], 0.12)
		style.border_color = STAGE_COLORS[stage]
		style.set_border_width_all(2)
		style.set_corner_radius_all(14)
		style.set_content_margin_all(16)
		panel.add_theme_stylebox_override("panel", style)
		columns.add_child(panel)

		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		panel.add_child(col)

		var head := Label.new()
		head.text = "Fase %d: %s" % [stage + 1, STAGE_ICONS[stage]]
		head.add_theme_font_size_override("font_size", 30)
		head.add_theme_color_override("font_color", STAGE_COLORS[stage])
		col.add_child(head)

		for level in GameState.levels_for_stage(stage):
			var row := HBoxContainer.new()
			col.add_child(row)
			var b := Button.new()
			b.text = "%d. %s" % [level.number, level.title]
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", 20)
			b.custom_minimum_size = Vector2(0, 40)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.disabled = not GameState.is_unlocked(level)
			b.tooltip_text = level.briefing
			b.pressed.connect(GameState.start_level.bind(level))
			row.add_child(b)
			var star_bar: Control = preload("res://scripts/ui/star_bar.gd").new()
			star_bar.custom_minimum_size = Vector2(84, 30)
			star_bar.stars = GameState.stars_for(level)
			row.add_child(star_bar)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(bottom)
	var quit := Button.new()
	quit.text = "Stoppen"
	quit.custom_minimum_size = Vector2(180, 48)
	quit.add_theme_font_size_override("font_size", 22)
	quit.pressed.connect(get_tree().quit)
	bottom.add_child(quit)
	if GameState.unlock_all:
		var note := Label.new()
		note.text = "   (testmodus: alle levels open)"
		note.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		bottom.add_child(note)
