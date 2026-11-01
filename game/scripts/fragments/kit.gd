class_name Kit
extends RefCounted
## Строительные помощники для фрагментов.
##
## Главная идея: фрагмент собирается как обычное земное место, а потом
## пересекается с цилиндром объёма средствами CSG. Новые грани получают
## материал среза — рисовать внутренности каждой вещи не нужно.


## Корень фрагмента: CSG-объединение содержимого ∩ цилиндр объёма.
## Возвращает [корень, контейнер для содержимого]. Всё в локальных координатах:
## (0, 0, 0) — центр круга на уровне земли фрагмента.
static func volume_cut(parent: Node3D, radius: float, cut_mat: Material, height := 40.0, depth := 1.0, with_soil := true) -> Array:
	var root := CSGCombiner3D.new()
	root.name = "VolumeCut"
	root.use_collision = true
	parent.add_child(root)
	var content := CSGCombiner3D.new()
	content.name = "Content"
	root.add_child(content)
	# Грунт под землёй фрагмента: сплошной до низа объёма, срез без щелей.
	if with_soil:
		var soil := CSGBox3D.new()
		soil.name = "Soil"
		soil.size = Vector3(2.0 * radius + 2.0, depth, 2.0 * radius + 2.0)
		soil.position = Vector3(0, -depth * 0.5 - 0.15, 0)
		soil.material = cut_mat
		content.add_child(soil)
	var cyl := CSGCylinder3D.new()
	cyl.name = "Volume"
	cyl.operation = CSGShape3D.OPERATION_INTERSECTION
	cyl.radius = radius - 0.02
	cyl.height = height + depth
	cyl.sides = int(clampf(radius * 6.0, 32.0, 128.0))
	cyl.position = Vector3(0, (height - depth) * 0.5, 0)
	cyl.material = cut_mat
	root.add_child(cyl)
	return [root, content]


static func box(parent: Node, size: Vector3, pos: Vector3, mat: Material, rot_y := 0.0, op := CSGShape3D.OPERATION_UNION) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.size = size
	b.position = pos
	b.rotation.y = rot_y
	b.material = mat
	b.operation = op
	parent.add_child(b)
	return b


static func cyl(parent: Node, r: float, h: float, pos: Vector3, mat: Material, sides := 12, op := CSGShape3D.OPERATION_UNION) -> CSGCylinder3D:
	var c := CSGCylinder3D.new()
	c.radius = r
	c.height = h
	c.sides = sides
	c.position = pos
	c.material = mat
	c.operation = op
	parent.add_child(c)
	return c


static func cone(parent: Node, r: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> CSGCylinder3D:
	var c := cyl(parent, r, h, pos, mat, 8)
	c.cone = true
	c.rotation = rot
	return c


static func sphere(parent: Node, r: float, pos: Vector3, mat: Material, scale := Vector3.ONE, op := CSGShape3D.OPERATION_UNION, seg := 16) -> CSGSphere3D:
	var s := CSGSphere3D.new()
	s.radius = r
	s.radial_segments = seg
	s.rings = maxi(6, seg / 2)
	s.position = pos
	s.scale = scale
	s.material = mat
	s.operation = op
	parent.add_child(s)
	return s


## Плоская фигура (например, дорожка минигольфа), лежащая на земле.
static func flat(parent: Node, poly: PackedVector2Array, y: float, thickness: float, mat: Material, op := CSGShape3D.OPERATION_UNION) -> CSGPolygon3D:
	var p := CSGPolygon3D.new()
	p.polygon = poly
	p.mode = CSGPolygon3D.MODE_DEPTH
	p.depth = thickness
	p.rotation_degrees = Vector3(90, 0, 0)
	p.position = Vector3(0, y, 0)
	p.material = mat
	p.operation = op
	parent.add_child(p)
	return p


static func combiner(parent: Node, op := CSGShape3D.OPERATION_UNION) -> CSGCombiner3D:
	var c := CSGCombiner3D.new()
	c.operation = op
	parent.add_child(c)
	return c


## Простой меш без CSG (для мелочей внутри круга).
static func mesh_box(parent: Node, size: Vector3, pos: Vector3, mat: Material, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi


static func label(parent: Node, text: String, pos: Vector3, rot_y: float, size := 64, color := Color.WHITE, outline := Color(0, 0, 0, 0)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.006
	l.modulate = color
	l.outline_size = 0 if outline.a == 0.0 else 8
	l.outline_modulate = outline
	l.position = pos
	l.rotation.y = rot_y
	l.double_sided = false
	l.shaded = false
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(l)
	# Надписи не умеют исчезать шейдером — когда герой в здании, их прячет main.gd.
	l.add_to_group("labels")
	return l


static func lamp_light(parent: Node, pos: Vector3, color := Color(1.0, 0.72, 0.38), energy := 1.6, rng := 7.5) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.2
	l.position = pos
	l.shadow_enabled = false
	l.add_to_group("lamps")
	l.set_meta("base_energy", energy)
	parent.add_child(l)
	return l


## Невидимый пандус для лестницы: CharacterBody не умеет шагать по ступеням.
static func ramp(parent: Node, from: Vector3, to: Vector3, width: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var d := to - from
	var length := d.length()
	shape.size = Vector3(width, 0.12, length)
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	var mid := (from + to) * 0.5 - Vector3(0, 0.06, 0)
	body.transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), mid)
	return body


## Отрезок прямой, оставшийся внутри круга радиуса r (центр в начале координат).
static func clip_segment(a: Vector2, b: Vector2, r: float) -> Array:
	var d := b - a
	var A := d.dot(d)
	var B := 2.0 * a.dot(d)
	var C := a.dot(a) - r * r
	var disc := B * B - 4.0 * A * C
	if disc <= 0.0:
		return []
	var s := sqrt(disc)
	var t0 := maxf((-B - s) / (2.0 * A), 0.0)
	var t1 := minf((-B + s) / (2.0 * A), 1.0)
	if t1 <= t0:
		return []
	return [a + d * t0, a + d * t1]


## Полигон полосы вокруг ломаной (для дорожек).
static func strip(points: PackedVector2Array, half_width: float) -> PackedVector2Array:
	var polys := Geometry2D.offset_polyline(points, half_width, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)
	return polys[0] if polys.size() > 0 else PackedVector2Array()


## Добавляет ящик в SurfaceTool (для сборки множества мелочей в один меш).
static func st_box(st: SurfaceTool, center: Vector3, size: Vector3, basis := Basis.IDENTITY) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
		[Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)],
		[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
		[Vector3(0, -1, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var c := n * h
		var su := u * h
		var sv := v * h
		var p := [c - su - sv, c + su - sv, c + su + sv, c - su + sv]
		var wn := (basis * n).normalized()
		# (u × v) = n → обход p0,p1,p2 против часовой снаружи; для Godot разворачиваем
		for i in [0, 2, 1, 0, 3, 2]:
			st.set_normal(wn)
			st.add_vertex(center + basis * p[i])


static func grow(poly: PackedVector2Array, delta: float) -> PackedVector2Array:
	var polys := Geometry2D.offset_polygon(poly, delta, Geometry2D.JOIN_ROUND)
	return polys[0] if polys.size() > 0 else poly
