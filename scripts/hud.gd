class_name FootballHUD
extends CanvasLayer
## Presentation only. The field scene owns input, physics, bots and exercise state.

signal start_requested
signal resume_requested
signal restart_requested
signal menu_requested
signal difficulty_changed(index: int)
signal exercise_changed(index: int)
signal quality_changed(index: int)
signal defender_changed(enabled: bool)

const INK := Color("111a20")
const LIME := Color("c6f35c")
const WHITE := Color("f4f6f1")
const MUTED := Color("a3b1af")
const ORANGE := Color("ff9b64")

var _root: Control
var _menu: Control
var _game: Control
var _pause: Control
var _hero: VBoxContainer
var _headline: Label
var _menu_bottom: Label
var _start_button: Button
var _resume_button: Button
var _pause_title: Label
var _pause_description: Label
var _goals: Label
var _attempts: Label
var _time: Label
var _objective: Label
var _charge_label: Label
var _charge_bar: ProgressBar
var _toast_card: PanelContainer
var _toast_text: Label
var _toast_remaining := 0.0
var _radar: FieldRadar
var _menu_controls: Label
var _game_controls: Label
var _pause_hint: Label
var _charge_hint: Label
var _controller_status: Label
var _pause_controls: Label
var _options: Array[Control] = []
var _display_font: FontVariation


class MenuShade extends Control:
	func _ready() -> void:
		var horizontal_gradient := Gradient.new()
		horizontal_gradient.offsets = PackedFloat32Array([0.0, 0.35, 0.72, 1.0])
		horizontal_gradient.colors = PackedColorArray([
			Color(0.035, 0.07, 0.09, 0.98), Color(0.035, 0.07, 0.09, 0.57),
			Color(0.035, 0.07, 0.09, 0.0), Color(0.035, 0.07, 0.09, 0.0)
		])
		var horizontal_texture := GradientTexture2D.new()
		horizontal_texture.gradient = horizontal_gradient
		horizontal_texture.width = 512
		horizontal_texture.height = 8
		horizontal_texture.fill_from = Vector2.ZERO
		horizontal_texture.fill_to = Vector2(1.0, 0.0)
		var horizontal := TextureRect.new()
		horizontal.texture = horizontal_texture
		horizontal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		horizontal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(horizontal)
		var bottom_gradient := Gradient.new()
		bottom_gradient.colors = PackedColorArray([Color(0.025, 0.055, 0.075, 0.0), Color(0.025, 0.055, 0.075, 0.75)])
		var bottom_texture := GradientTexture2D.new()
		bottom_texture.gradient = bottom_gradient
		bottom_texture.width = 8
		bottom_texture.height = 256
		bottom_texture.fill_from = Vector2.ZERO
		bottom_texture.fill_to = Vector2(0.0, 1.0)
		var bottom := TextureRect.new()
		bottom.texture = bottom_texture
		bottom.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		bottom.offset_top = -180.0
		bottom.offset_bottom = 0.0
		bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bottom)


class FieldRadar extends Control:
	var player := Vector3.ZERO
	var ball := Vector3.ZERO
	var keeper := Vector3.ZERO
	var defender := Vector3.ZERO
	var partner := Vector3.ZERO
	var has_defender := true
	var field_half := Vector2(18.0, 28.0)

	func _map(position_3d: Vector3) -> Vector2:
		var padding := Vector2(44.0, 12.0)
		var pitch_size := size - padding * 2.0
		return padding + Vector2(
			clampf((position_3d.x + field_half.x) / (field_half.x * 2.0), 0.0, 1.0),
			clampf((position_3d.z + field_half.y) / (field_half.y * 2.0), 0.0, 1.0)
		) * pitch_size

	func _draw() -> void:
		var pitch := Rect2(Vector2(44.0, 12.0), size - Vector2(88.0, 24.0))
		var line := Color(0.70, 0.79, 0.77, 0.28)
		draw_rect(pitch, Color(0.16, 0.25, 0.22, 0.55))
		draw_rect(pitch, line, false, 1.0)
		draw_line(Vector2(pitch.position.x, size.y * 0.5), Vector2(pitch.end.x, size.y * 0.5), line)
		draw_arc(size * 0.5, 15.0, 0.0, TAU, 40, line, 1.0, true)
		for z in [pitch.position.y, pitch.end.y - 24.0]:
			draw_rect(Rect2(size.x * 0.5 - 33.0, z, 66.0, 24.0), line, false, 1.0)
		draw_circle(_map(partner), 3.5, Color("80a9ff"))
		draw_circle(_map(keeper), 3.5, Color("ff9b64"))
		if has_defender:
			draw_circle(_map(defender), 3.5, Color("ff9b64"))
		draw_circle(_map(player), 7.0, Color(0.78, 0.95, 0.36, 0.18))
		draw_circle(_map(player), 4.0, Color("c6f35c"))
		draw_circle(_map(ball), 2.8, Color.WHITE)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_display_font = FontVariation.new()
	_display_font.base_font = ThemeDB.fallback_font
	_display_font.variation_embolden = 1.2
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 17
	ui_theme.set_color("font_color", "Label", WHITE)
	ui_theme.set_color("font_color", "Button", WHITE)
	ui_theme.set_color("font_color", "OptionButton", WHITE)
	_root.theme = ui_theme
	_build_menu()
	_build_game()
	_build_pause()
	_build_toast()
	_root.resized.connect(_layout)
	_layout()
	show_menu()


func _process(delta: float) -> void:
	if _toast_remaining > 0.0:
		_toast_remaining -= delta
		_toast_card.modulate.a = minf(1.0, _toast_remaining * 4.0)
		if _toast_remaining <= 0.0:
			_toast_card.hide()


func _full(parent: Node) -> Control:
	var control := Control.new()
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(control)
	return control


func _label(text: String, font_size: int, color: Color = WHITE, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", _display_font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _box(background: Color, border: Color = Color.TRANSPARENT, radius: int = 8, padding: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style


func _card(parent: Node, background: Color = Color(0.055, 0.095, 0.115, 0.91)) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(background, Color(0.65, 0.76, 0.73, 0.15), 10, 16))
	parent.add_child(panel)
	return panel


func _button(text: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 54.0
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_font_override("font", _display_font)
	var base := LIME if primary else Color("1c2c32")
	button.add_theme_stylebox_override("normal", _box(base, Color.TRANSPARENT, 7, 14))
	button.add_theme_stylebox_override("hover", _box(base.lightened(0.10), LIME if not primary else Color.WHITE, 7, 14))
	button.add_theme_stylebox_override("pressed", _box(base.darkened(0.10), LIME, 7, 14))
	button.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, LIME, 7, 14))
	if primary:
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state, INK)
	return button


func _option(title: String, choices: Array[String], selected: int, callback: Callable) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 5)
	column.add_child(_label(title, 12, MUTED, true))
	var option := OptionButton.new()
	_options.append(option)
	option.custom_minimum_size = Vector2(180.0, 42.0)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	option.add_theme_font_size_override("font_size", 16)
	option.add_theme_stylebox_override("normal", _box(Color("17252b"), Color(0.65, 0.76, 0.73, 0.21), 6, 10))
	option.add_theme_stylebox_override("hover", _box(Color("203138"), Color(0.78, 0.95, 0.36, 0.5), 6, 10))
	option.add_theme_stylebox_override("pressed", _box(Color("203138"), LIME, 6, 10))
	option.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, LIME, 6, 10))
	for choice in choices:
		option.add_item(choice)
	option.select(selected)
	option.item_selected.connect(callback)
	var popup := option.get_popup()
	popup.add_theme_font_size_override("font_size", 16)
	popup.add_theme_stylebox_override("panel", _box(Color("14232b"), Color(0.65, 0.76, 0.73, 0.35), 7, 8))
	popup.add_theme_stylebox_override("hover", _box(Color("354c35"), Color.TRANSPARENT, 4, 7))
	column.add_child(option)
	return column


func _build_menu() -> void:
	_menu = _full(_root)
	var shade := MenuShade.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.resized.connect(shade.queue_redraw)
	_menu.add_child(shade)
	var brand := HBoxContainer.new()
	brand.position = Vector2(64.0, 37.0)
	brand.add_theme_constant_override("separation", 12)
	_menu.add_child(brand)
	brand.add_child(_label("N", 38, LIME, true))
	var brand_words := VBoxContainer.new()
	brand_words.add_theme_constant_override("separation", -3)
	brand.add_child(brand_words)
	brand_words.add_child(_label("N U K E", 21, WHITE, true))
	brand_words.add_child(_label("F O O T B A L L", 10, MUTED))
	var status := _label("TECLADO E MOUSE", 12, WHITE)
	_controller_status = status
	status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	status.position = Vector2(-330.0, 51.0)
	_menu.add_child(status)
	_hero = VBoxContainer.new()
	_hero.add_theme_constant_override("separation", 16)
	_hero.size = Vector2(430.0, 580.0)
	_menu.add_child(_hero)
	_hero.add_child(_label("●   TREINO LIVRE. JOGO REAL.", 12, LIME, true))
	_headline = _label("O CAMPO\nÉ SEU.", 79, WHITE, true)
	_headline.add_theme_constant_override("line_spacing", -9)
	_hero.add_child(_headline)
	var description := _label("Domine a bola. Encontre o espaço.\nTransforme cada tentativa em um gol.", 17, MUTED)
	_hero.add_child(description)
	var options := GridContainer.new()
	options.columns = 2
	options.add_theme_constant_override("h_separation", 14)
	options.add_theme_constant_override("v_separation", 13)
	_hero.add_child(options)
	options.add_child(_option("EXERCÍCIO", ["Finalização", "Chutes livres", "Passes", "Cones", "1 contra 1"], 0, func(index: int): exercise_changed.emit(index)))
	options.add_child(_option("DIFICULDADE", ["Fácil", "Médio", "Difícil"], 1, func(index: int): difficulty_changed.emit(index)))
	options.add_child(_option("QUALIDADE VISUAL", ["Baixa", "Média", "Alta"], 2, func(index: int): quality_changed.emit(index)))
	var defender_column := VBoxContainer.new()
	defender_column.add_theme_constant_override("separation", 5)
	defender_column.add_child(_label("MARCAÇÃO", 12, MUTED, true))
	var defender_toggle := CheckButton.new()
	_options.append(defender_toggle)
	defender_toggle.text = "Defensor em campo"
	defender_toggle.button_pressed = true
	defender_toggle.custom_minimum_size.y = 42
	defender_toggle.add_theme_font_size_override("font_size", 15)
	defender_toggle.add_theme_color_override("font_color", WHITE)
	defender_toggle.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, LIME, 6, 8))
	defender_toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	defender_toggle.toggled.connect(func(enabled: bool): defender_changed.emit(enabled))
	defender_column.add_child(defender_toggle)
	options.add_child(defender_column)
	_start_button = _button("ENTRAR EM CAMPO    →", true)
	_start_button.custom_minimum_size.y = 58.0
	_start_button.pressed.connect(func(): start_requested.emit())
	_hero.add_child(_start_button)
	_menu_controls = _label("", 10, MUTED)
	_hero.add_child(_menu_controls)
	_options.append(_start_button)
	for index in _options.size():
		var current := _options[index]
		current.focus_neighbor_top = current.get_path_to(_options[posmod(index - 1, _options.size())])
		current.focus_neighbor_bottom = current.get_path_to(_options[(index + 1) % _options.size()])
		current.focus_next = current.focus_neighbor_bottom
		current.focus_previous = current.focus_neighbor_top
	_menu_bottom = _label("01  /  NUKE TRAINING GROUND\nFUTEBOL EM PRIMEIRO LUGAR.", 12, WHITE)
	_menu_bottom.add_theme_constant_override("line_spacing", 5)
	_menu.add_child(_menu_bottom)
	var footer := _label("VERSÃO JOGÁVEL   •   TREINO LOCAL", 10, MUTED)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.position = Vector2(64.0, -36.0)
	_menu.add_child(footer)


func _build_game() -> void:
	_game = _full(_root)
	var brand := _label("N U K E", 22, WHITE, true)
	brand.position = Vector2(35.0, 26.0)
	_game.add_child(brand)
	var live := _label("●  TREINO", 11, LIME, true)
	live.position = Vector2(36.0, 60.0)
	_game.add_child(live)
	var score_card := _card(_game)
	score_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	score_card.offset_left = -255.0
	score_card.offset_right = 255.0
	score_card.offset_top = 22.0
	score_card.offset_bottom = 106.0
	score_card.custom_minimum_size = Vector2(510.0, 78.0)
	var scores := HBoxContainer.new()
	scores.add_theme_constant_override("separation", 30)
	score_card.add_child(scores)
	_goals = _stat(scores, "GOLS", "00", LIME)
	_add_separator(scores)
	_attempts = _stat(scores, "TENTATIVAS", "00", WHITE)
	_add_separator(scores)
	_time = _stat(scores, "TEMPO", "00:00", WHITE)
	var pause_hint := _label("ESC  /  PAUSA", 12, WHITE)
	_pause_hint = pause_hint
	pause_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause_hint.position = Vector2(-144.0, 35.0)
	_game.add_child(pause_hint)
	var objective_card := _card(_game, Color(0.055, 0.095, 0.115, 0.80))
	objective_card.position = Vector2(34.0, 104.0)
	objective_card.custom_minimum_size = Vector2(300.0, 68.0)
	var objective_column := VBoxContainer.new()
	objective_column.add_theme_constant_override("separation", 4)
	objective_card.add_child(objective_column)
	objective_column.add_child(_label("OBJETIVO DO TREINO", 10, LIME, true))
	_objective = _label("Faça gols contra o goleiro", 15, WHITE)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.custom_minimum_size.x = 280.0
	objective_column.add_child(_objective)
	var charge_card := _card(_game)
	charge_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	charge_card.offset_left = 34.0
	charge_card.offset_right = 286.0
	charge_card.offset_top = -133.0
	charge_card.offset_bottom = -37.0
	charge_card.custom_minimum_size = Vector2(252.0, 96.0)
	var charge_column := VBoxContainer.new()
	charge_column.add_theme_constant_override("separation", 7)
	charge_card.add_child(charge_column)
	var charge_title := HBoxContainer.new()
	charge_column.add_child(charge_title)
	var title := _label("FORÇA DO CHUTE", 11, MUTED, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	charge_title.add_child(title)
	_charge_label = _label("0%", 13, LIME, true)
	charge_title.add_child(_charge_label)
	_charge_bar = ProgressBar.new()
	_charge_bar.custom_minimum_size.y = 6.0
	_charge_bar.max_value = 1.0
	_charge_bar.show_percentage = false
	_charge_bar.add_theme_stylebox_override("background", _box(Color("30413e"), Color.TRANSPARENT, 3, 0))
	_charge_bar.add_theme_stylebox_override("fill", _box(LIME, Color.TRANSPARENT, 3, 0))
	charge_column.add_child(_charge_bar)
	_charge_hint = _label("", 11, WHITE)
	charge_column.add_child(_charge_hint)
	var radar_card := _card(_game)
	radar_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	radar_card.offset_left = -238.0
	radar_card.offset_right = -34.0
	radar_card.offset_top = -215.0
	radar_card.offset_bottom = -37.0
	radar_card.custom_minimum_size = Vector2(204.0, 178.0)
	var radar_column := VBoxContainer.new()
	radar_column.add_theme_constant_override("separation", 0)
	radar_card.add_child(radar_column)
	var radar_title := _label("VISÃO DO CAMPO", 10, MUTED, true)
	radar_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radar_column.add_child(radar_title)
	_radar = FieldRadar.new()
	_radar.custom_minimum_size = Vector2(170.0, 122.0)
	_radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radar_column.add_child(_radar)
	var instructions := _label("", 11, WHITE)
	_game_controls = instructions
	instructions.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.position = Vector2(-390.0, -27.0)
	instructions.size.x = 780.0
	_game.add_child(instructions)
	_ignore_pointer(_game)


func _ignore_pointer(node: Node) -> void:
	# Aiming and charging a shot must work even over passive HUD cards.
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_pointer(child)


func _stat(parent: HBoxContainer, caption: String, initial: String, color: Color) -> Label:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", -1)
	parent.add_child(column)
	var value := _label(initial, 29, color, true)
	column.add_child(value)
	column.add_child(_label(caption, 9, MUTED, true))
	return value


func _add_separator(parent: HBoxContainer) -> void:
	var separator := VSeparator.new()
	separator.add_theme_stylebox_override("separator", _box(Color(0.65, 0.76, 0.73, 0.20), Color.TRANSPARENT, 0, 0))
	separator.custom_minimum_size.x = 1.0
	parent.add_child(separator)


func _build_pause() -> void:
	_pause = _full(_root)
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.045, 0.055, 0.82)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(center)
	var card := _card(center, Color("101e25"))
	card.custom_minimum_size = Vector2(425.0, 0.0)
	card.add_theme_stylebox_override("panel", _box(Color("101e25"), Color(0.65, 0.76, 0.73, 0.25), 12, 32))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	card.add_child(column)
	column.add_child(_label("●   INTERVALO", 12, LIME, true))
	_pause_title = _label("RESPIRA.\nVOLTA PRO JOGO.", 32, WHITE, true)
	column.add_child(_pause_title)
	_pause_description = _label("O treino espera por você.", 16, MUTED)
	_pause_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pause_description.custom_minimum_size.x = 350.0
	column.add_child(_pause_description)
	_resume_button = _button("RETOMAR    →", true)
	_resume_button.pressed.connect(func(): resume_requested.emit())
	column.add_child(_resume_button)
	var restart := _button("REINICIAR EXERCÍCIO")
	restart.pressed.connect(func(): restart_requested.emit())
	column.add_child(restart)
	var menu_button := _button("VOLTAR AO MENU")
	menu_button.pressed.connect(func(): menu_requested.emit())
	column.add_child(menu_button)
	_pause_controls = _label("", 13, MUTED)
	_pause_controls.add_theme_constant_override("line_spacing", 3)
	column.add_child(_pause_controls)
	var navigation: Array[Button] = [_resume_button, restart, menu_button]
	for index in navigation.size():
		var button := navigation[index]
		button.focus_neighbor_top = button.get_path_to(navigation[posmod(index - 1, navigation.size())])
		button.focus_neighbor_bottom = button.get_path_to(navigation[(index + 1) % navigation.size()])


func _build_toast() -> void:
	_toast_card = _card(_root, Color(0.05, 0.12, 0.11, 0.96))
	_toast_card.add_theme_stylebox_override("panel", _box(Color(0.05, 0.12, 0.11, 0.96), Color(0.78, 0.95, 0.36, 0.6), 8, 18))
	_toast_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast_card.offset_left = -240.0
	_toast_card.offset_right = 240.0
	_toast_card.offset_top = 125.0
	_toast_card.offset_bottom = 191.0
	_toast_card.custom_minimum_size = Vector2(480.0, 64.0)
	_toast_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_text = _label("", 21, WHITE, true)
	_toast_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_text.custom_minimum_size.x = 440.0
	_toast_card.add_child(_toast_text)
	_toast_card.hide()


func _layout() -> void:
	if not is_instance_valid(_hero):
		return
	var compact := _root.size.y < 810.0
	_headline.add_theme_font_size_override("font_size", 65 if compact else 79)
	_hero.add_theme_constant_override("separation", 11 if compact else 16)
	_hero.position = Vector2(64.0, 104.0 if compact else 154.0)
	_hero.size.x = 430.0
	_menu_bottom.position = Vector2(maxf(620.0, _root.size.x - 400.0), _root.size.y - 105.0)


func show_menu() -> void:
	_menu.show()
	_game.hide()
	_pause.hide()
	_toast_card.hide()
	_start_button.grab_focus()


func show_game() -> void:
	_menu.hide()
	_game.show()
	_pause.hide()
	if _root.get_viewport().gui_get_focus_owner():
		_root.get_viewport().gui_release_focus()


func show_pause() -> void:
	_menu.hide()
	_game.show()
	_pause.show()
	_pause_title.text = "RESPIRA.\nVOLTA PRO JOGO."
	_pause_description.text = "O treino espera por você."
	_resume_button.text = "RETOMAR    →"
	_resume_button.grab_focus()


func show_result(title: String, detail: String) -> void:
	show_pause()
	_pause_title.text = title
	_pause_description.text = detail
	_resume_button.text = "CONTINUAR    →"


func update_stats(goals: int, attempts: int, elapsed: float, charge: float, objective: String) -> void:
	_goals.text = "%02d" % goals
	_attempts.text = "%02d" % attempts
	var seconds := int(elapsed)
	_time.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	_objective.text = objective
	_charge_bar.value = clampf(charge, 0.0, 1.0)
	_charge_label.text = "%d%%" % int(clampf(charge, 0.0, 1.0) * 100.0)


func toast(message: String, duration: float = 2.5) -> void:
	_toast_text.text = message
	_toast_remaining = maxf(duration, 0.1)
	_toast_card.modulate.a = 1.0
	_toast_card.show()


func update_minimap(player: Vector3, ball: Vector3, keeper: Vector3, defender: Vector3, partner: Vector3, defender_enabled: bool) -> void:
	_radar.player = player
	_radar.ball = ball
	_radar.keeper = keeper
	_radar.defender = defender
	_radar.partner = partner
	_radar.has_defender = defender_enabled
	_radar.queue_redraw()


func set_controller(using_controller: bool, connected: bool) -> void:
	_controller_status.text = "XBOX / CONTROLE CONECTADO" if connected else "TECLADO E MOUSE"
	if using_controller:
		_menu_controls.text = "D-PAD  NAVEGAR     /     A  CONFIRMAR     /     B  VOLTAR"
		_game_controls.text = "LS  Mover   RS  Mirar   RT/RB  Correr   LT  Precisão   X  Passe   LB/B  Câmera   Y  Repetir"
		_charge_hint.text = "A • segure para carregar e solte"
		_pause_hint.text = "MENU / PAUSA"
		_pause_controls.text = "CONTROLE XBOX
LS mover • RS mirar • RT/RB correr
A segurar e soltar: chute • X passe
LT precisão/chute rasteiro • Y repor bola
LB/B câmera • ↑/↓ zoom • View ajuda
D-pad navegar • A confirmar • B voltar"
	else:
		_menu_controls.text = "WASD  MOVER     /     MOUSE  MIRAR     /     ESPAÇO  CHUTAR"
		_game_controls.text = "WASD  Mover   SHIFT  Correr   MOUSE  Mirar   E  Passe   C  Câmera   R  Repetir   F1  Ajuda"
		_charge_hint.text = "ESPAÇO ou clique • segure e solte"
		_pause_hint.text = "ESC / PAUSA"
		_pause_controls.text = "WASD/setas mover • Shift correr • mouse mirar
Espaço/clique: segurar e soltar para chutar
E passe • C câmera • R repor bola
Roda do mouse: zoom • Esc pausa
Xbox: LS mover, RS mirar, A chute, X passe
RT/RB correr • LT precisão • Menu pausa"
