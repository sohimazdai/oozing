class_name CleanerRig
extends Node3D
## Ночной уборщик из примитивов. Анимация — код: шаг привязан к пройденному
## расстоянию, поэтому ноги не скользят при любой скорости.
## Модель смотрит в -Z (вперёд по соглашению Godot).

const HIP_H := 0.88

var hips: Node3D
var torso: Node3D
var head: Node3D
var l_thigh: Node3D
var l_shin: Node3D
var r_thigh: Node3D
var r_shin: Node3D
var l_upper: Node3D
var l_fore: Node3D
var r_upper: Node3D
var r_fore: Node3D

var _phase := 0.0
var _move := 0.0      # 0 стоит, 1 идёт, 2 бежит (сглажено)
var _crouch := 0.0
var _air := 0.0
var _climb := 0.0
var _t := 0.0


func _ready() -> void:
	_build()


func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scale := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 4
	return c


static func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func _build() -> void:
	var jacket := Mats.character(Color(0.93, 0.47, 0.17))
	var stripe := Mats.character(Color(0.86, 0.90, 0.88))
	var pants := Mats.character(Color(0.17, 0.21, 0.27))
	var skin := Mats.character(Color(0.86, 0.63, 0.50))
	var boots := Mats.character(Color(0.12, 0.11, 0.10))
	var cap := Mats.character(Color(0.17, 0.30, 0.45))
	var stick := Mats.character(Color(0.85, 0.80, 0.30))
	var mop_head := Mats.character(Color(0.78, 0.78, 0.74))

	hips = _pivot(self, Vector3(0, HIP_H, 0))
	_mesh(hips, _box(Vector3(0.34, 0.18, 0.21)), pants, Vector3(0, 0.0, 0))

	torso = _pivot(hips, Vector3(0, 0.07, 0))
	_mesh(torso, _capsule(0.19, 0.62), jacket, Vector3(0, 0.28, 0), Vector3(1.15, 1.0, 0.72))
	_mesh(torso, _box(Vector3(0.45, 0.05, 0.3)), stripe, Vector3(0, 0.2, 0))
	_mesh(torso, _box(Vector3(0.45, 0.05, 0.3)), stripe, Vector3(0, 0.36, 0))
	head = _pivot(torso, Vector3(0, 0.6, 0))
	_mesh(head, _capsule(0.05, 0.12), skin, Vector3(0, 0.0, 0))
	_mesh(head, SphereMesh.new(), skin, Vector3(0, 0.15, 0), Vector3(0.24, 0.27, 0.25))
	_mesh(head, _box(Vector3(0.04, 0.05, 0.05)), skin, Vector3(0, 0.14, -0.13))
	var cap_top := CylinderMesh.new()
	cap_top.top_radius = 0.115
	cap_top.bottom_radius = 0.13
	cap_top.height = 0.09
	_mesh(head, cap_top, cap, Vector3(0, 0.27, 0.0))
	_mesh(head, _box(Vector3(0.2, 0.025, 0.12)), cap, Vector3(0, 0.235, -0.15))

	# Руки: плечо → локоть → кисть. Сегменты висят вниз от шарниров.
	l_upper = _pivot(torso, Vector3(-0.25, 0.5, 0))
	r_upper = _pivot(torso, Vector3(0.25, 0.5, 0))
	for side in [[l_upper, -1.0], [r_upper, 1.0]]:
		var up: Node3D = side[0]
		_mesh(up, _capsule(0.065, 0.34), jacket, Vector3(0, -0.15, 0))
		var fore := _pivot(up, Vector3(0, -0.3, 0))
		_mesh(fore, _capsule(0.058, 0.3), jacket, Vector3(0, -0.13, 0))
		_mesh(fore, SphereMesh.new(), skin, Vector3(0, -0.3, 0), Vector3(0.1, 0.12, 0.1))
		if side[1] < 0:
			l_fore = fore
		else:
			r_fore = fore
	# Швабра в правой руке.
	var mop := _pivot(r_fore, Vector3(0, -0.3, 0))
	mop.rotation = Vector3(deg_to_rad(-70.0), 0, deg_to_rad(8.0))
	var stick_mesh := CylinderMesh.new()
	stick_mesh.top_radius = 0.016
	stick_mesh.bottom_radius = 0.016
	stick_mesh.height = 1.45
	_mesh(mop, stick_mesh, stick, Vector3(0, -0.45, 0))
	_mesh(mop, _box(Vector3(0.34, 0.08, 0.12)), mop_head, Vector3(0, -1.18, 0))

	# Ноги: бедро → колено → ступня.
	l_thigh = _pivot(hips, Vector3(-0.1, -0.04, 0))
	r_thigh = _pivot(hips, Vector3(0.1, -0.04, 0))
	for side in [[l_thigh, -1.0], [r_thigh, 1.0]]:
		var th: Node3D = side[0]
		_mesh(th, _capsule(0.085, 0.46), pants, Vector3(0, -0.2, 0))
		var shin := _pivot(th, Vector3(0, -0.42, 0))
		_mesh(shin, _capsule(0.075, 0.42), pants, Vector3(0, -0.19, 0))
		_mesh(shin, _box(Vector3(0.12, 0.09, 0.27)), boots, Vector3(0, -0.38, -0.05))
		if side[1] < 0:
			l_shin = shin
		else:
			r_shin = shin


## state: speed (м/с по горизонтали), crouch, grounded, climbing (0..1 — фаза перелезания).
func animate(delta: float, speed: float, crouch: bool, grounded: bool, climbing: float) -> void:
	_t += delta
	var target_move := clampf(speed / 3.3, 0.0, 1.0) + clampf((speed - 3.3) / 2.9, 0.0, 1.0)
	var k := 1.0 - exp(-10.0 * delta)
	_move = lerpf(_move, target_move, k)
	_crouch = lerpf(_crouch, 1.0 if crouch else 0.0, k)
	_air = lerpf(_air, 0.0 if grounded else 1.0, 1.0 - exp(-6.0 * delta))
	_climb = lerpf(_climb, climbing, 1.0 - exp(-14.0 * delta))

	var walk := clampf(_move, 0.0, 1.0)
	var run := clampf(_move - 1.0, 0.0, 1.0)
	var stride := lerpf(1.45, 2.4, run)
	_phase = fmod(_phase + speed * delta / stride * TAU, TAU * 1000.0)
	var s := sin(_phase)
	var c := cos(_phase)

	var leg_amp := 0.5 * walk + 0.3 * run
	var knee_amp := 0.75 * walk + 0.55 * run
	l_thigh.rotation.x = s * leg_amp + _crouch * 0.7 + _air * 0.35
	r_thigh.rotation.x = -s * leg_amp + _crouch * 0.7 + _air * 0.1
	l_shin.rotation.x = -(maxf(0.0, c) * knee_amp + 0.08 * walk) - _crouch * 1.1 - _air * 0.6
	r_shin.rotation.x = -(maxf(0.0, -c) * knee_amp + 0.08 * walk) - _crouch * 1.1 - _air * 0.3

	var arm_amp := 0.45 * walk + 0.4 * run
	l_upper.rotation.x = -s * arm_amp + _air * 0.6
	r_upper.rotation.x = s * arm_amp * 0.6 + 0.15
	l_upper.rotation.z = -0.08 - _air * 0.4
	r_upper.rotation.z = 0.08 + _air * 0.4
	l_fore.rotation.x = 0.2 + 0.9 * run + 0.15 * walk
	r_fore.rotation.x = 0.35 + 0.6 * run

	var bob := -absf(s) * (0.035 * walk + 0.06 * run)
	var breathe := sin(_t * 1.7) * 0.006 * (1.0 - walk)
	hips.position.y = HIP_H + bob + breathe - _crouch * 0.26 - _climb * 0.2
	torso.rotation.x = -0.06 * walk - 0.2 * run - _crouch * 0.35 - _climb * 0.5
	torso.rotation.y = s * 0.1 * walk
	head.rotation.y = sin(_t * 0.37) * 0.35 * (1.0 - walk) * (1.0 - _crouch)
	head.rotation.x = -torso.rotation.x * 0.6

	if _climb > 0.01:
		l_upper.rotation.x = lerpf(l_upper.rotation.x, 2.6, _climb)
		r_upper.rotation.x = lerpf(r_upper.rotation.x, 2.4, _climb)
		l_thigh.rotation.x = lerpf(l_thigh.rotation.x, 1.3, _climb)
		l_shin.rotation.x = lerpf(l_shin.rotation.x, -1.6, _climb)
