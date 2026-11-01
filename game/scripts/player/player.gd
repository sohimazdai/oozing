class_name Player
extends CharacterBody3D
## Управление героем. WASD — относительно экрана, как в изометрии.
## Глубокая вода не пускает (плавания пока нет), мелкая замедляет.
## Невысокие уступы проходятся автоматически, высокие — перелезанием (Пробел).

const WALK := 3.3
const RUN := 6.2
const SNEAK := 1.6
const ACCEL := 22.0
const GRAVITY := 22.0
const STEP_HEIGHT := 0.38
const DEEP := 1.0

var gen: WorldGen
var cam: Camera3D
var rig: CleanerRig
var frozen := true
var can_climb := false

var _face := Vector3(1, 0, 1).normalized()
var _vault_t := -1.0
var _vault_from := Vector3.ZERO
var _vault_to := Vector3.ZERO
var _climb_check := 0.0
var auto_walk := Vector3.ZERO    # для автоматических проверок из командной строки
var auto_climb := false

# Экран: «вверх» — от камеры вглубь сцены (камера смотрит на -X -Z).
const SCREEN_UP := Vector3(-0.70710678, 0, -0.70710678)
const SCREEN_RIGHT := Vector3(0.70710678, 0, -0.70710678)


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	cs.shape = cap
	cs.position = Vector3(0, 0.875, 0)
	add_child(cs)
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.45
	floor_constant_speed = true
	rig = CleanerRig.new()
	add_child(rig)


func _physics_process(delta: float) -> void:
	if frozen:
		return
	if _vault_t >= 0.0:
		_vault_step(delta)
		return

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := SCREEN_RIGHT * input.x - SCREEN_UP * input.y
	if auto_walk != Vector3.ZERO:
		dir = auto_walk
	if dir.length() > 1.0:
		dir = dir.normalized()

	var sneaking := Input.is_action_pressed("sneak")
	var speed := WALK
	if Input.is_action_pressed("run") and not sneaking:
		speed = RUN
	elif sneaking:
		speed = SNEAK
	var here := global_position
	var wd := gen.water_depth(here.x, here.z) if gen else 0.0
	if wd > 0.2:
		speed *= 0.55
	dir = _filter_deep_water(dir)

	var target := dir * speed
	var hv := Vector3(velocity.x, 0, velocity.z).move_toward(target, ACCEL * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = maxf(velocity.y, -0.5)
	move_and_slide()
	if dir.length() > 0.05 and is_on_floor() and is_on_wall():
		_try_step_up(dir)

	# Подстраховка: если провалился ниже мира — вернуть на поверхность.
	if gen and global_position.y < gen.surface_height(global_position.x, global_position.z) - 3.0:
		global_position.y = gen.surface_height(global_position.x, global_position.z) + 1.0
		velocity = Vector3.ZERO

	# Перелезание.
	_climb_check -= delta
	if _climb_check <= 0.0:
		_climb_check = 0.1
		can_climb = _find_ledge(_face).size() > 0
	if Input.is_action_just_pressed("climb") or (auto_climb and can_climb):
		var ledge := _find_ledge(_face)
		if ledge.size() > 0:
			_start_vault(ledge[0])


func _process(delta: float) -> void:
	var hv := Vector3(velocity.x, 0, velocity.z)
	var want := _face
	if Input.is_action_pressed("aim") and cam:
		var p := _mouse_ground()
		if p != Vector3.INF:
			var d := p - global_position
			d.y = 0
			if d.length() > 0.2:
				want = d.normalized()
	elif hv.length() > 0.3:
		want = hv.normalized()
	_face = _face.slerp(want, 1.0 - exp(-12.0 * delta)).normalized() if _face.dot(want) > -0.99 else want
	rig.rotation.y = atan2(-_face.x, -_face.z)
	var climbing := 0.0
	if _vault_t >= 0.0:
		climbing = 1.0
	rig.animate(delta, hv.length() if _vault_t < 0.0 else 0.0, Input.is_action_pressed("sneak"), is_on_floor() or _vault_t >= 0.0, climbing)
	RenderingServer.global_shader_parameter_set("player_pos", global_position)


func _filter_deep_water(dir: Vector3) -> Vector3:
	if gen == null or dir.length() < 0.01:
		return dir
	var p := global_position
	var probe := 0.55
	if gen.water_depth(p.x, p.z) > DEEP:
		return dir   # уже в глубине (например, после загрузки) — даём выйти
	var full := p + dir.normalized() * probe
	if gen.water_depth(full.x, full.z) <= DEEP:
		return dir
	var out := Vector3.ZERO
	var px := p + Vector3(signf(dir.x), 0, 0) * probe
	if absf(dir.x) > 0.01 and gen.water_depth(px.x, px.z) <= DEEP:
		out.x = dir.x
	var pz := p + Vector3(0, 0, signf(dir.z)) * probe
	if absf(dir.z) > 0.01 and gen.water_depth(pz.x, pz.z) <= DEEP:
		out.z = dir.z
	return out


func _try_step_up(dir: Vector3) -> void:
	var t0 := global_transform
	var up := Vector3(0, STEP_HEIGHT, 0)
	if test_move(t0, up):
		return
	var t1 := t0.translated(up)
	var fwd := dir.normalized() * 0.3
	if test_move(t1, fwd):
		return
	var t2 := t1.translated(fwd)
	var col := KinematicCollision3D.new()
	if test_move(t2, Vector3(0, -STEP_HEIGHT - 0.05, 0), col):
		if col.get_normal().y > 0.7:
			global_transform = t2.translated(col.get_travel())


## Ищет уступ высотой 0,4–1,5 м прямо перед героем. Возвращает [точка] или [].
func _find_ledge(f: Vector3) -> Array:
	if not is_inside_tree() or not is_on_floor():
		return []
	var space := get_world_3d().direct_space_state
	var feet := global_position
	# Лучи на нескольких высотах: уступ может начинаться выше колена.
	var dist := -1.0
	for h in [0.3, 0.6, 0.95]:
		var from := feet + Vector3(0, h, 0)
		var q := PhysicsRayQueryParameters3D.create(from, from + f * 0.9)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			dist = (hit.position as Vector3 - from).length()
			break
	if dist < 0.0:
		return []
	var top := feet + f * (dist + 0.4) + Vector3(0, 1.9, 0)
	var q2 := PhysicsRayQueryParameters3D.create(top, top - Vector3(0, 2.2, 0))
	q2.exclude = [get_rid()]
	var hit2 := space.intersect_ray(q2)
	if hit2.is_empty():
		return []
	var p: Vector3 = hit2.position
	var dh := p.y - feet.y
	if dh < STEP_HEIGHT or dh > 1.55 or (hit2.normal as Vector3).y < 0.7:
		return []
	# Хватит ли места стоять наверху?
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28
	shape.height = 1.7
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = shape
	sq.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, 0.9, 0))
	sq.exclude = [get_rid()]
	if not space.intersect_shape(sq, 1).is_empty():
		return []
	return [p]


func _start_vault(to: Vector3) -> void:
	_vault_from = global_position
	_vault_to = to + Vector3(0, 0.02, 0)
	_vault_t = 0.0
	velocity = Vector3.ZERO


func _vault_step(delta: float) -> void:
	var dur := 0.5
	_vault_t += delta / dur
	var t := clampf(_vault_t, 0.0, 1.0)
	var up := smoothstep(0.0, 0.55, t)
	var fwd := smoothstep(0.35, 1.0, t)
	var p := _vault_from.lerp(_vault_to, fwd)
	p.y = lerpf(_vault_from.y, _vault_to.y + 0.12, up) - 0.12 * fwd
	global_position = p
	if _vault_t >= 1.0:
		_vault_t = -1.0
		global_position = _vault_to


func _mouse_ground() -> Vector3:
	var vp := cam.get_viewport()
	var mp := vp.get_mouse_position()
	var from := cam.project_ray_origin(mp)
	var d := cam.project_ray_normal(mp)
	var plane := Plane(Vector3.UP, global_position.y + 0.5)
	var hit = plane.intersects_ray(from, d)
	return hit if hit != null else Vector3.INF
