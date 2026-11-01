class_name MinigolfFragment
extends RefCounted
## Стартовый фрагмент: минигольф «Пасть динозавра», радиус 14 м.
## Всё, что пересекает границу, — дорожка, кирпичная стенка, забор, фонарь,
## мусорный пакет — разрезано объёмом.


static func build(node: Node3D, vol: Dictionary) -> void:
	var r: float = vol.radius
	var parts := Kit.volume_cut(node, r, Mats.cut(vol.base_y, 0, Color(0.85, 0.82, 0.74)), 12.0, vol.depth)
	var content: CSGCombiner3D = parts[1]
	Kit.box(content, Vector3(2.0 * r + 4.0, 0.5, 2.0 * r + 4.0), Vector3(0, -0.25, 0), Mats.paving())
	_lanes(content)
	_low_wall(content)
	_half_lamp(content, r)
	_garbage_bag(content)
	_fence(node, r)
	_dino(node, Vector3(-5.6, 0, -5.4), deg_to_rad(45.0))
	_lamps(node)
	_props(node)
	_sign(node)


static func _lanes(content: CSGCombiner3D) -> void:
	var lanes := [
		[PackedVector2Array([Vector2(-3.4, -3.2), Vector2(-1.4, -0.6), Vector2(1.6, 0.3), Vector2(3.9, 3.1)]), 1.0],
		[PackedVector2Array([Vector2(5.0, -7.6), Vector2(7.6, -4.6), Vector2(6.4, -1.0), Vector2(8.6, 1.6)]), 0.9],
		[PackedVector2Array([Vector2(4.4, 7.6), Vector2(8.0, 9.2), Vector2(11.6, 10.6), Vector2(15.0, 12.6)]), 0.9],
		[PackedVector2Array([Vector2(-11.0, 1.8), Vector2(-7.4, 4.6), Vector2(-4.2, 5.4)]), 0.85],
	]
	var turf := Mats.turf()
	var brick := Mats.world(Color(0.66, 0.30, 0.24), {"pattern": Mats.PATTERN_BRICK, "color2": Color(0.78, 0.74, 0.66), "noise": 0.05})
	var dark := Mats.paint(Color(0.08, 0.09, 0.08))
	for lane in lanes:
		var pts: PackedVector2Array = lane[0]
		var hw: float = lane[1]
		var border := Kit.combiner(content)
		Kit.flat(border, Kit.strip(pts, hw + 0.17), 0.0, 0.2, brick)
		Kit.flat(border, Kit.strip(pts, hw), -0.1, 0.5, brick, CSGShape3D.OPERATION_SUBTRACTION)
		Kit.flat(content, Kit.strip(pts, hw), 0.0, 0.06, turf)
		var end := pts[pts.size() - 1]
		Kit.cyl(content, 0.08, 0.066, Vector3(end.x, 0.033, end.y), dark, 12)


static func _low_wall(content: CSGCombiner3D) -> void:
	var a := Vector2(-14.5, 4.4)
	var b := Vector2(-6.4, 12.6)
	var d := b - a
	Kit.box(content, Vector3(d.length(), 0.7, 0.36), Vector3((a.x + b.x) * 0.5, 0.35, (a.y + b.y) * 0.5),
		Mats.brick(), -atan2(d.y, d.x))
	Kit.box(content, Vector3(d.length(), 0.08, 0.46), Vector3((a.x + b.x) * 0.5, 0.74, (a.y + b.y) * 0.5),
		Mats.concrete(), -atan2(d.y, d.x))


## Фонарь, стоявший ровно на границе: от него осталась половина столба.
static func _half_lamp(content: CSGCombiner3D, r: float) -> void:
	var a := deg_to_rad(200.0)
	var p := Vector3(cos(a) * r, 0, sin(a) * r)
	var m := Mats.metal(Color(0.20, 0.22, 0.20))
	Kit.cyl(content, 0.11, 3.4, p + Vector3(0, 1.7, 0), m, 12)
	var out := Vector3(cos(a), 0, sin(a))
	Kit.box(content, Vector3(0.9, 0.08, 0.08), p + out * 0.4 + Vector3(0, 3.3, 0), m, -a)


static func _garbage_bag(content: CSGCombiner3D) -> void:
	var bag := Mats.world(Color(0.13, 0.13, 0.15), {"rough": 0.3, "noise": 0.05})
	Kit.sphere(content, 0.5, Vector3(-11.62, 0.72, 8.08), bag, Vector3(0.66, 0.9, 0.66))
	Kit.cone(content, 0.12, 0.25, Vector3(-11.62, 1.22, 8.08), bag)


## Чугунный забор: прямые участки, обрезанные кругом. Один меш на весь забор.
static func _fence(node: Node3D, r: float) -> void:
	var lines := [
		[Vector2(-16, -10.6), Vector2(16, -10.6)],
		[Vector2(-11.6, -16), Vector2(-11.6, 16)],
		[Vector2(12.3, -16), Vector2(12.3, -1.2)],
		[Vector2(12.3, 1.2), Vector2(12.3, 16)],
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := StaticBody3D.new()
	node.add_child(body)
	for ln in lines:
		var seg := Kit.clip_segment(ln[0], ln[1], r - 0.03)
		if seg.is_empty():
			continue
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var d := b - a
		var length := d.length()
		var basis := Basis(Vector3.UP, -atan2(d.y, d.x))
		var mid := Vector3((a.x + b.x) * 0.5, 0, (a.y + b.y) * 0.5)
		Kit.st_box(st, mid + Vector3(0, 0.15, 0), Vector3(length, 0.04, 0.05), basis)
		Kit.st_box(st, mid + Vector3(0, 1.0, 0), Vector3(length, 0.05, 0.05), basis)
		var bars := int(length / 0.16)
		for i in bars + 1:
			var t := float(i) / maxf(1.0, float(bars))
			var p := a.lerp(b, t)
			var is_post := i % 12 == 0
			var w := 0.08 if is_post else 0.022
			var hgt := 1.2 if is_post else 1.06
			Kit.st_box(st, Vector3(p.x, hgt * 0.5, p.y), Vector3(w, hgt, w), basis)
			if not is_post:
				Kit.st_box(st, Vector3(p.x, 1.1, p.y), Vector3(0.05, 0.07, 0.05), basis * Basis(Vector3.FORWARD, PI * 0.25))
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(length, 1.2, 0.12)
		cs.shape = shape
		cs.transform = Transform3D(basis, mid + Vector3(0, 0.6, 0))
		body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Mats.metal(Color(0.10, 0.11, 0.11))
	node.add_child(mi)


## Голова динозавра из примитивов. Лицом к камере, внутри — проход дорожки.
static func _dino(node: Node3D, pos: Vector3, yaw: float) -> void:
	var skin := Mats.world(Color(0.36, 0.60, 0.30), {"pattern": Mats.PATTERN_SPOTS, "color2": Color(0.24, 0.43, 0.22), "rough": 0.45, "noise": 0.06})
	var belly := Mats.world(Color(0.78, 0.80, 0.50), {"rough": 0.5, "noise": 0.05})
	var mouth := Mats.world(Color(0.78, 0.30, 0.36), {"rough": 0.5, "noise": 0.04})
	var tooth := Mats.world(Color(0.96, 0.93, 0.83), {"rough": 0.35, "noise": 0.02})
	var white := Mats.world(Color(0.97, 0.97, 0.95), {"rough": 0.3, "noise": 0.0})
	var black := Mats.world(Color(0.06, 0.06, 0.08), {"rough": 0.2, "noise": 0.0})
	var tunnel := Mats.world(Color(0.22, 0.17, 0.19), {"noise": 0.05})

	var root := CSGCombiner3D.new()
	root.name = "Dino"
	root.use_collision = true
	node.add_child(root)
	root.position = pos
	root.rotation.y = yaw

	Kit.box(root, Vector3(3.8, 0.6, 3.4), Vector3(0, 0.3, -1.2), Mats.brick())
	Kit.sphere(root, 1.0, Vector3(0, 2.6, -1.1), skin, Vector3(2.0, 1.75, 2.0), CSGShape3D.OPERATION_UNION, 24)
	Kit.sphere(root, 1.0, Vector3(0, 1.7, -0.5), skin, Vector3(1.9, 1.5, 1.6), CSGShape3D.OPERATION_UNION, 20)
	Kit.sphere(root, 1.0, Vector3(0, 2.8, 1.0), skin, Vector3(1.7, 1.05, 2.5), CSGShape3D.OPERATION_UNION, 24)
	Kit.sphere(root, 1.0, Vector3(0, 0.8, 0.9), belly, Vector3(1.5, 0.55, 2.35), CSGShape3D.OPERATION_UNION, 20)
	# Пасть: полость и открытый перед.
	Kit.sphere(root, 1.0, Vector3(0, 1.8, 1.6), mouth, Vector3(1.32, 0.92, 2.4), CSGShape3D.OPERATION_SUBTRACTION, 20)
	Kit.box(root, Vector3(2.5, 1.5, 2.0), Vector3(0, 1.8, 3.3), mouth, 0.0, CSGShape3D.OPERATION_SUBTRACTION)
	# Проход для мяча и для человека.
	var t := Kit.cyl(root, 1.15, 7.0, Vector3(0, 0.9, -0.8), tunnel, 20, CSGShape3D.OPERATION_SUBTRACTION)
	t.rotation_degrees = Vector3(90, 0, 0)
	# Ноздри.
	for sx in [-1.0, 1.0]:
		Kit.sphere(root, 0.13, Vector3(sx * 0.38, 3.36, 3.0), black, Vector3.ONE, CSGShape3D.OPERATION_SUBTRACTION, 10)
	# Глаза навыкате.
	for sx in [-1.0, 1.0]:
		Kit.sphere(root, 0.46, Vector3(sx * 1.25, 3.45, 0.25), white, Vector3.ONE, CSGShape3D.OPERATION_UNION, 16)
		Kit.sphere(root, 0.21, Vector3(sx * 1.48, 3.52, 0.56), black, Vector3.ONE, CSGShape3D.OPERATION_UNION, 12)
	# Зубы: сверху вниз и снизу вверх по дуге пасти.
	for i in 7:
		var f := lerpf(-1.0, 1.0, i / 6.0)
		var x := f * 1.12
		var z := 1.9 + (1.0 - f * f) * 1.35
		Kit.cone(root, 0.15, 0.48, Vector3(x, 2.48, z), tooth, Vector3(PI, 0, 0))
	for i in 6:
		var f := lerpf(-1.0, 1.0, (i + 0.5) / 6.0)
		var x := f * 1.0
		var z := 1.8 + (1.0 - f * f) * 1.3
		Kit.cone(root, 0.12, 0.36, Vector3(x, 1.18, z), tooth)


static func _lamps(node: Node3D) -> void:
	var post := Mats.metal(Color(0.12, 0.13, 0.13))
	var glass := Mats.glow(Color(1.0, 0.80, 0.50), 3.0)
	for p in [Vector3(-8.5, 0, 2.6), Vector3(2.4, 0, -8.6), Vector3(9.6, 0, 4.2)]:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.06
		cm.bottom_radius = 0.09
		cm.height = 3.1
		mi.mesh = cm
		mi.material_override = post
		mi.position = p + Vector3(0, 1.55, 0)
		node.add_child(mi)
		Kit.mesh_box(node, Vector3(0.34, 0.42, 0.34), p + Vector3(0, 3.25, 0), glass)
		Kit.mesh_box(node, Vector3(0.44, 0.06, 0.44), p + Vector3(0, 3.5, 0), post)
		Kit.lamp_light(node, p + Vector3(0, 3.0, 0))
		_pole_collision(node, p, 0.12, 3.2)


static func _pole_collision(node: Node3D, p: Vector3, r: float, h: float) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	cs.position = Vector3(0, h * 0.5, 0)
	b.add_child(cs)
	node.add_child(b)
	b.position = p


static func _box_collision(node: Node3D, size: Vector3, pos: Vector3, yaw := 0.0) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	node.add_child(b)
	b.position = pos
	b.rotation.y = yaw


static func _props(node: Node3D) -> void:
	var wood := Mats.wood(Color(0.66, 0.46, 0.28))
	var iron := Mats.metal()
	# Скамейка.
	var bench := Node3D.new()
	node.add_child(bench)
	bench.position = Vector3(-9.3, 0, -1.4)
	bench.rotation.y = deg_to_rad(60.0)
	Kit.mesh_box(bench, Vector3(1.8, 0.07, 0.5), Vector3(0, 0.45, 0), wood)
	Kit.mesh_box(bench, Vector3(1.8, 0.4, 0.06), Vector3(0, 0.75, -0.24), wood)
	for sx in [-0.8, 0.8]:
		Kit.mesh_box(bench, Vector3(0.06, 0.45, 0.5), Vector3(sx, 0.22, 0), iron)
	_box_collision(node, Vector3(1.8, 0.9, 0.6), bench.position + Vector3(0, 0.45, 0), bench.rotation.y)
	# Урна.
	var bin := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.26
	bm.bottom_radius = 0.22
	bm.height = 0.8
	bin.mesh = bm
	bin.material_override = Mats.paint(Color(0.18, 0.42, 0.30))
	bin.position = Vector3(-8.0, 0.4, 0.7)
	node.add_child(bin)
	_pole_collision(node, Vector3(-8.0, 0, 0.7), 0.27, 0.8)
	# Уборочная тележка героя.
	var cart := Node3D.new()
	node.add_child(cart)
	cart.position = Vector3(3.5, 0, 6.3)
	cart.rotation.y = deg_to_rad(-25.0)
	var blue := Mats.paint(Color(0.18, 0.36, 0.62))
	var yellow := Mats.paint(Color(0.98, 0.78, 0.12))
	Kit.mesh_box(cart, Vector3(1.0, 0.08, 0.56), Vector3(0, 0.2, 0), blue)
	Kit.mesh_box(cart, Vector3(0.06, 0.9, 0.5), Vector3(-0.48, 0.6, 0), blue)
	Kit.mesh_box(cart, Vector3(0.04, 0.04, 0.56), Vector3(-0.48, 1.05, 0), iron)
	var bucket := MeshInstance3D.new()
	var cmb := CylinderMesh.new()
	cmb.top_radius = 0.22
	cmb.bottom_radius = 0.18
	cmb.height = 0.32
	bucket.mesh = cmb
	bucket.material_override = yellow
	bucket.position = Vector3(0.22, 0.4, 0)
	cart.add_child(bucket)
	Kit.mesh_box(cart, Vector3(0.36, 0.5, 0.42), Vector3(-0.2, 0.49, 0), Mats.paint(Color(0.25, 0.25, 0.27)))
	for wx in [-0.4, 0.4]:
		for wz in [-0.24, 0.24]:
			Kit.mesh_box(cart, Vector3(0.12, 0.12, 0.04), Vector3(wx, 0.07, wz), Mats.paint(Color(0.1, 0.1, 0.1)))
	_box_collision(node, Vector3(1.05, 1.1, 0.6), cart.position + Vector3(0, 0.55, 0), cart.rotation.y)
	# Будка кассы.
	var booth := Node3D.new()
	node.add_child(booth)
	booth.position = Vector3(10.0, 0, -4.8)
	booth.rotation.y = deg_to_rad(45.0)
	Kit.mesh_box(booth, Vector3(1.7, 2.3, 1.5), Vector3(0, 1.15, 0), Mats.paint(Color(0.93, 0.92, 0.88)))
	Kit.mesh_box(booth, Vector3(1.9, 0.18, 1.7), Vector3(0, 2.38, 0), Mats.paint(Color(0.80, 0.20, 0.18)))
	Kit.mesh_box(booth, Vector3(0.9, 0.6, 0.04), Vector3(0, 1.35, 0.76), Mats.glow(Color(0.98, 0.86, 0.6), 0.6))
	Kit.label(booth, "КАССА", Vector3(0, 2.0, 0.77), 0.0, 48, Color(0.75, 0.12, 0.1))
	_box_collision(node, Vector3(1.7, 2.3, 1.5), booth.position + Vector3(0, 1.15, 0), booth.rotation.y)
	# Флажок у последней лунки.
	var flag := Node3D.new()
	node.add_child(flag)
	flag.position = Vector3(8.6, 0, 1.6)
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.015
	pm.bottom_radius = 0.015
	pm.height = 1.3
	pole.mesh = pm
	pole.material_override = Mats.paint(Color(0.95, 0.95, 0.95))
	pole.position = Vector3(0, 0.65, 0)
	flag.add_child(pole)
	Kit.mesh_box(flag, Vector3(0.36, 0.24, 0.01), Vector3(0.18, 1.18, 0), Mats.paint(Color(0.88, 0.12, 0.10)))


static func _sign(node: Node3D) -> void:
	var s := Node3D.new()
	node.add_child(s)
	s.position = Vector3(7.2, 0, -8.6)
	s.rotation.y = deg_to_rad(45.0)
	var post := Mats.metal(Color(0.2, 0.2, 0.22))
	for sx in [-1.5, 1.5]:
		Kit.mesh_box(s, Vector3(0.1, 2.9, 0.1), Vector3(sx, 1.45, -0.05), post)
	Kit.mesh_box(s, Vector3(3.6, 1.15, 0.1), Vector3(0, 2.35, 0), Mats.paint(Color(0.12, 0.42, 0.24)))
	Kit.mesh_box(s, Vector3(3.75, 0.08, 0.14), Vector3(0, 2.97, 0), Mats.paint(Color(0.96, 0.78, 0.15)))
	Kit.label(s, "ПАСТЬ ДИНОЗАВРА", Vector3(0, 2.52, 0.06), 0.0, 72, Color(1.0, 0.92, 0.55))
	Kit.label(s, "мини-гольф · 9 лунок · дети до 7 лет бесплатно", Vector3(0, 2.1, 0.06), 0.0, 28, Color(0.95, 0.95, 0.9))
	_box_collision(node, Vector3(3.6, 3.0, 0.3), s.position + Vector3(0, 1.5, 0), s.rotation.y)
