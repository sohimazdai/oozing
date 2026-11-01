class_name IsoCamera
extends Camera3D
## Ортографическая камера: азимут 45°, наклон 45°. Колесо мыши — масштаб.
## Ширина кадра задаётся в метрах (документ 15: 24–42 м; для прогулки шире).

const DIST := 60.0
const MIN_WIDTH := 14.0
const MAX_WIDTH := 80.0

var target: Node3D
var width := 34.0
var pixel_snap := false
var _focus := Vector3.ZERO


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	keep_aspect = KEEP_WIDTH
	size = width
	near = 0.5
	far = 220.0
	rotation_degrees = Vector3(-45.0, 45.0, 0.0)


func snap_to_target() -> void:
	if target:
		_focus = target.global_position + Vector3(0, 1.0, 0)
		_place()


func _process(delta: float) -> void:
	if target == null:
		return
	var want := target.global_position + Vector3(0, 1.0, 0)
	if target is CharacterBody3D:
		var v: Vector3 = (target as CharacterBody3D).velocity
		want += Vector3(v.x, 0, v.z) * 0.25
	_focus = _focus.lerp(want, 1.0 - exp(-5.0 * delta))
	size = lerpf(size, width, 1.0 - exp(-10.0 * delta))
	_place()


func _place() -> void:
	var b := global_transform.basis
	var pos := _focus + b.z * DIST
	if pixel_snap:
		var vp_w := float(get_viewport().get_visible_rect().size.x)
		var px := size / maxf(vp_w, 1.0)
		var lx := roundf(pos.dot(b.x) / px) * px
		var ly := roundf(pos.dot(b.y) / px) * px
		var lz := pos.dot(b.z)
		pos = b.x * lx + b.y * ly + b.z * lz
	global_position = pos
	RenderingServer.global_shader_parameter_set("cam_fwd", -b.z)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			width = clampf(width * 0.9, MIN_WIDTH, MAX_WIDTH)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			width = clampf(width * 1.1, MIN_WIDTH, MAX_WIDTH)
	elif event is InputEventMagnifyGesture:
		width = clampf(width / event.factor, MIN_WIDTH, MAX_WIDTH)
	elif event is InputEventPanGesture:
		width = clampf(width * (1.0 + event.delta.y * 0.02), MIN_WIDTH, MAX_WIDTH)
