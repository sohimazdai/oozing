class_name Hud
extends CanvasLayer
## Экранные подсказки, название места, отладочная строка и пауза.

const HELP := "WASD — идти   Shift — бежать   Ctrl — красться   Пробел — забраться\nПКМ — смотреть на курсор   колесо / щипок — масштаб   T — время суток\nF2 — пиксельный режим   F3 — отладка   F1 — скрыть подсказки   Esc — пауза"

var help_label: Label
var debug_label: Label
var hint_label: Label
var place_label: Label
var toast_label: Label
var pause_panel: ColorRect
var root: Control
var _place_text := ""
var _place_t := 0.0
var _toast_t := 0.0
var show_debug := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	help_label = _label(15, HORIZONTAL_ALIGNMENT_LEFT)
	debug_label = _label(14, HORIZONTAL_ALIGNMENT_LEFT)
	debug_label.visible = false
	hint_label = _label(20, HORIZONTAL_ALIGNMENT_CENTER)
	place_label = _label(24, HORIZONTAL_ALIGNMENT_CENTER)
	toast_label = _label(18, HORIZONTAL_ALIGNMENT_CENTER)
	help_label.text = HELP
	pause_panel = ColorRect.new()
	pause_panel.color = Color(0.05, 0.05, 0.08, 0.6)
	pause_panel.visible = false
	pause_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pause_panel)
	var pl := _label(28, HORIZONTAL_ALIGNMENT_CENTER)
	pl.text = "Пауза\n\nEsc — продолжить    Q — выйти"
	pl.reparent(pause_panel)
	pl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	get_viewport().size_changed.connect(_layout)
	_layout()


func _label(size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1.0, 0.97, 0.90))
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.05, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var s := clampf(DisplayServer.screen_get_scale(), 1.0, 3.0)
	if OS.has_feature("headless") or vs.x < 1200.0:
		s = 1.0
	root.scale = Vector2(s, s)
	var size := vs / s
	root.size = size
	pause_panel.size = size
	help_label.position = Vector2(18, size.y - 86)
	debug_label.position = Vector2(18, 14)
	debug_label.size = Vector2(size.x - 36, 24)
	hint_label.position = Vector2(0, size.y - 150)
	hint_label.size = Vector2(size.x, 30)
	place_label.position = Vector2(0, 44)
	place_label.size = Vector2(size.x, 40)
	toast_label.position = Vector2(0, 88)
	toast_label.size = Vector2(size.x, 30)


func set_hint(text: String) -> void:
	hint_label.text = text


func show_place(text: String) -> void:
	if text == _place_text:
		return
	_place_text = text
	if text != "":
		place_label.text = text
		_place_t = 4.5


func toast(text: String) -> void:
	toast_label.text = text
	_toast_t = 2.0


func set_debug(text: String) -> void:
	debug_label.text = text


func toggle_help() -> void:
	help_label.visible = not help_label.visible


func toggle_debug() -> void:
	show_debug = not show_debug
	debug_label.visible = show_debug


func set_paused(p: bool) -> void:
	pause_panel.visible = p


func _process(delta: float) -> void:
	_place_t = maxf(0.0, _place_t - delta)
	place_label.modulate.a = clampf(_place_t, 0.0, 1.0)
	_toast_t = maxf(0.0, _toast_t - delta)
	toast_label.modulate.a = clampf(_toast_t * 2.0, 0.0, 1.0)
