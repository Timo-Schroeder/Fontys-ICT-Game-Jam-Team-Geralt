extends Control
## Title screen with three stages of ten levels each. Built in code from GameState.levels,
## so new levels show up automatically when a .tres file is added to data/levels.
## Language can be switched via the flag buttons in the top-right corner.

const STAGE_COLORS := [Color("ff9a3c"), Color("3cb4ff"), Color("7be08a")]


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	Locale.changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	# Remove everything built previously so we can rebuild cleanly.
	for child in get_children():
		child.queue_free()
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

	# --- Top bar: title + language flags ---
	var top_bar := HBoxContainer.new()
	top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(top_bar)

	var title := Label.new()
	title.text = Locale.t("game_title")
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("ffd38a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title)

	# Flag buttons (drawn with simple coloured rectangles + text)
	var flag_box := HBoxContainer.new()
	flag_box.add_theme_constant_override("separation", 6)
	flag_box.alignment = BoxContainer.ALIGNMENT_END
	top_bar.add_child(flag_box)

	flag_box.add_theme_constant_override("separation", 10)
	flag_box.add_child(_flag_button("English", "en", "us", Locale.language() == "en"))
	flag_box.add_child(_flag_button("Nederlands", "nl", "nl", Locale.language() == "nl"))

	# --- Subtitle ---
	var sub := Label.new()
	sub.text = Locale.t("subtitle") % [GameState.total_stars(), GameState.levels.size() * 3]
	sub.add_theme_font_size_override("font_size", 24)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)

	if GameState.levels.is_empty():
		var warn := Label.new()
		warn.text = Locale.t("no_levels") % GameState.LEVEL_DIR
		root.add_child(warn)
		return

	var stage_names := [
		Locale.t("stage_1_name"),
		Locale.t("stage_2_name"),
		Locale.t("stage_3_name"),
	]

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
		head.text = Locale.t("stage_label") % [stage + 1, stage_names[stage]]
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
	quit.text = Locale.t("quit_btn")
	quit.custom_minimum_size = Vector2(180, 48)
	quit.add_theme_font_size_override("font_size", 22)
	quit.pressed.connect(get_tree().quit)
	bottom.add_child(quit)
	if GameState.unlock_all:
		var note := Label.new()
		note.text = Locale.t("test_mode_note")
		note.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		bottom.add_child(note)


## A language button: the flag on top, the language name underneath.
## The selected language gets a bright border; the other one is dimmed until hovered.
func _flag_button(label: String, lang: String, country: String, active: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120, 100)
	btn.focus_mode = Control.FOCUS_NONE
	btn.tooltip_text = label

	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(10)
	normal.bg_color = Color(1, 1, 1, 0.12) if active else Color(1, 1, 1, 0.04)
	normal.border_color = Color("ffd38a") if active else Color(1, 1, 1, 0.15)
	normal.set_border_width_all(3 if active else 1)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1, 1, 1, 0.16)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("disabled", normal)
	btn.disabled = active
	btn.pressed.connect(func() -> void: Locale.set_language(lang))

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(box)

	var flag: Control = preload("res://scripts/ui/flag_icon.gd").new()
	flag.country = country
	flag.custom_minimum_size = Vector2(72, 44)
	flag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flag.modulate = Color.WHITE if active else Color(1, 1, 1, 0.6)
	box.add_child(flag)

	var name_label := Label.new()
	name_label.text = label
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color.WHITE if active else Color(1, 1, 1, 0.65))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	return btn
