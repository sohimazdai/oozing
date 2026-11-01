class_name RandomFragments
extends RefCounted
## Случайные фрагменты, которые встречаются по дороге. Каждый — короткая
## грамматика: из чего состоит место и какие вещи в нём бывают. Параметры
## берутся из seed объёма, поэтому одно и то же место всегда выглядит одинаково.


static func _setup(node: Node3D, vol: Dictionary, floor_mat: Material, neutral := Color(0.86, 0.83, 0.76)) -> Array:
	var r: float = vol.radius
	var parts := Kit.volume_cut(node, r, Mats.cut(vol.base_y, 0, neutral), 12.0, 1.0)
	var content: CSGCombiner3D = parts[1]
	content.rotation.y = vol.rot
	Kit.box(content, Vector3(2.0 * r + 6.0, 0.4, 2.0 * r + 6.0), Vector3(0, -0.2, 0), floor_mat)
	var rng := RandomNumberGenerator.new()
	rng.seed = vol.seed
	# Отдельный узел для вещей без CSG, повёрнутый так же, как содержимое.
	var extra := Node3D.new()
	node.add_child(extra)
	extra.rotation.y = vol.rot
	return [content, rng, extra]


## Точка из локальных координат содержимого → лежит ли она внутри круга.
static func _in(vol: Dictionary, p: Vector3, pad := 0.3) -> bool:
	return Vector2(p.x, p.z).length() < vol.radius - pad


static func _car(c: Node, pos: Vector3, yaw: float, color: Color) -> void:
	var body := Mats.paint(color)
	var glass := Mats.world(Color(0.18, 0.26, 0.30), {"rough": 0.1, "metal": 0.4, "noise": 0.02})
	var tyre := Mats.paint(Color(0.08, 0.08, 0.08))
	var chrome := Mats.metal(Color(0.7, 0.7, 0.72))
	var car := Kit.combiner(c)
	car.position = pos
	car.rotation.y = yaw
	Kit.box(car, Vector3(4.1, 0.62, 1.62), Vector3(0, 0.62, 0), body)
	Kit.box(car, Vector3(2.0, 0.58, 1.5), Vector3(-0.25, 1.2, 0), glass)
	Kit.box(car, Vector3(1.9, 0.08, 1.46), Vector3(-0.25, 1.52, 0), body)
	Kit.box(car, Vector3(0.06, 0.18, 1.5), Vector3(2.07, 0.62, 0), chrome)
	Kit.box(car, Vector3(0.06, 0.18, 1.5), Vector3(-2.07, 0.62, 0), chrome)
	for wx in [-1.3, 1.3]:
		for wz in [-0.78, 0.78]:
			var w := Kit.cyl(car, 0.33, 0.22, Vector3(wx, 0.33, wz), tyre, 12)
			w.rotation_degrees = Vector3(90, 0, 0)


## Кусок дороги: асфальт, разметка, тротуар, фонарь, знак, отбойник, машина.
static func road(node: Node3D, vol: Dictionary) -> void:
	var s := _setup(node, vol, Mats.asphalt())
	var c: CSGCombiner3D = s[0]
	var rng: RandomNumberGenerator = s[1]
	var extra: Node3D = s[2]
	var r: float = vol.radius
	var white := Mats.paint(Color(0.92, 0.92, 0.88))
	var span := 2.0 * r + 4.0
	Kit.box(c, Vector3(span, 0.012, 0.12), Vector3(0, 0.006, 3.2), white)
	Kit.box(c, Vector3(span, 0.012, 0.12), Vector3(0, 0.006, -3.2), white)
	var x := -r - 2.0
	while x < r + 2.0:
		Kit.box(c, Vector3(3.0, 0.012, 0.12), Vector3(x, 0.006, 0), white)
		x += 6.0
	Kit.box(c, Vector3(span, 0.16, 0.2), Vector3(0, 0.08, 3.7), Mats.concrete())
	Kit.box(c, Vector3(span, 0.12, 3.0), Vector3(0, 0.06, 5.3), Mats.paving())
	# Отбойник с другой стороны.
	var steel := Mats.metal(Color(0.62, 0.64, 0.66))
	Kit.box(c, Vector3(span, 0.3, 0.06), Vector3(0, 0.62, -3.9), steel)
	var px := -r - 2.0
	while px < r + 2.0:
		Kit.box(c, Vector3(0.1, 0.75, 0.1), Vector3(px, 0.375, -3.95), steel)
		px += 2.0
	# Фонарь на тротуаре.
	var lamp_x := rng.randf_range(-r * 0.5, r * 0.5)
	var lp := Vector3(lamp_x, 0.12, 4.3)
	var post := Mats.metal(Color(0.35, 0.37, 0.38))
	Kit.cyl(c, 0.1, 6.0, lp + Vector3(0, 3.0, 0), post, 10)
	Kit.box(c, Vector3(0.08, 0.08, 1.4), lp + Vector3(0, 5.9, -0.6), post)
	Kit.box(c, Vector3(0.32, 0.12, 0.5), lp + Vector3(0, 5.82, -1.2), Mats.glow(Color(1.0, 0.85, 0.6), 2.5))
	if _in(vol, lp, 0.5):
		var l := Kit.lamp_light(extra, lp + Vector3(0, 5.5, -1.2), Color(1.0, 0.8, 0.5), 2.0, 11.0)
		l.position = lp + Vector3(0, 5.5, -1.2)
	# Знак с названием города.
	var sp := Vector3(rng.randf_range(-r * 0.6, r * 0.6), 0.12, 6.2)
	Kit.cyl(c, 0.05, 2.6, sp + Vector3(0, 1.3, 0), post, 8)
	Kit.box(c, Vector3(1.6, 0.55, 0.05), sp + Vector3(0, 2.4, 0), Mats.paint(Color(0.12, 0.30, 0.62)))
	if _in(vol, sp + Vector3(0.8, 0, 0), 0.2) and _in(vol, sp - Vector3(0.8, 0, 0), 0.2):
		var town: String = FragmentNames.pick(FragmentNames.TOWNS, vol.seed, 2)
		Kit.label(extra, "%s  %d" % [town, rng.randi_range(4, 87)], sp + Vector3(0, 2.4, 0.03), 0.0, 40, Color(0.96, 0.96, 0.96))
	# Машина, которая ехала по этой дороге.
	if rng.randf() < 0.85:
		var colors := [Color(0.80, 0.18, 0.14), Color(0.92, 0.88, 0.75), Color(0.20, 0.42, 0.30), Color(0.25, 0.45, 0.72), Color(0.82, 0.60, 0.18)]
		_car(c, Vector3(rng.randf_range(-r * 0.6, r * 0.6), 0, -1.6 if rng.randf() < 0.5 else 1.6),
			rng.randf_range(-0.12, 0.12) + (PI if rng.randf() < 0.5 else 0.0), colors[rng.randi() % colors.size()])


## Дачный участок: газон, сарай, забор, грядки, бочка.
static func shed(node: Node3D, vol: Dictionary) -> void:
	var lawn := Mats.world(Color(0.33, 0.50, 0.22), {"noise": 0.18})
	var s := _setup(node, vol, lawn)
	var c: CSGCombiner3D = s[0]
	var rng: RandomNumberGenerator = s[1]
	var extra: Node3D = s[2]
	var r: float = vol.radius
	var planks := Mats.wood(Color(0.55, 0.40, 0.27))
	var grey_planks := Mats.wood(Color(0.55, 0.53, 0.48))
	var roof := Mats.world(Color(0.38, 0.45, 0.52), {"pattern": Mats.PATTERN_PLANKS, "color2": Color(0.28, 0.33, 0.38), "scale": 2.5, "rough": 0.5, "metal": 0.3})
	var sp := Vector3(rng.randf_range(-r * 0.25, r * 0.25), 0, rng.randf_range(-r * 0.35, -r * 0.1))
	var sh := Kit.combiner(c)
	sh.position = sp
	Kit.box(sh, Vector3(3.2, 2.3, 2.6), Vector3(0, 1.15, 0), planks)
	Kit.box(sh, Vector3(2.9, 2.2, 2.3), Vector3(0, 1.2, 0), planks, 0.0, CSGShape3D.OPERATION_SUBTRACTION)
	Kit.box(sh, Vector3(0.95, 1.9, 0.5), Vector3(0.6, 0.95, 1.3), planks, 0.0, CSGShape3D.OPERATION_SUBTRACTION)
	Kit.box(sh, Vector3(0.6, 0.45, 0.5), Vector3(-0.8, 1.5, 1.3), planks, 0.0, CSGShape3D.OPERATION_SUBTRACTION)
	var roof_a := Kit.box(sh, Vector3(3.6, 0.06, 1.7), Vector3(0, 2.55, 0.68), roof)
	roof_a.rotation.x = deg_to_rad(18.0)
	var roof_b := Kit.box(sh, Vector3(3.6, 0.06, 1.7), Vector3(0, 2.55, -0.68), roof)
	roof_b.rotation.x = deg_to_rad(-18.0)
	Kit.box(sh, Vector3(3.6, 0.32, 0.06), Vector3(0, 2.38, 1.3), planks)
	Kit.box(sh, Vector3(3.6, 0.32, 0.06), Vector3(0, 2.38, -1.3), planks)
	# Полки и банки внутри.
	Kit.box(sh, Vector3(0.3, 0.04, 2.0), Vector3(-1.3, 1.1, 0), planks)
	Kit.box(sh, Vector3(0.3, 0.04, 2.0), Vector3(-1.3, 1.6, 0), planks)
	for i in 6:
		Kit.cyl(sh, 0.06, 0.18, Vector3(-1.3, 1.21, -0.8 + i * 0.3), Mats.world(Color(0.75, 0.82, 0.80), {"rough": 0.15, "noise": 0.0}), 8)
	# Забор из штакетника поперёк участка — разрезан границей.
	var fz := rng.randf_range(r * 0.35, r * 0.6)
	Kit.box(c, Vector3(2.0 * r + 2.0, 0.08, 0.04), Vector3(0, 0.35, fz), grey_planks)
	Kit.box(c, Vector3(2.0 * r + 2.0, 0.08, 0.04), Vector3(0, 0.95, fz), grey_planks)
	var fx := -r - 1.0
	while fx < r + 1.0:
		Kit.box(c, Vector3(0.09, 1.2, 0.025), Vector3(fx, 0.6, fz + 0.03), grey_planks)
		fx += 0.17
	# Грядки.
	var soil := Mats.world(Color(0.36, 0.25, 0.17), {"noise": 0.2})
	var tops := Mats.world(Color(0.38, 0.58, 0.22), {"noise": 0.2})
	for i in 3:
		var bz := sp.z + 2.3 + i * 1.1
		Kit.box(c, Vector3(4.0, 0.22, 0.7), Vector3(sp.x + 2.4, 0.11, bz), soil)
		for j in 6:
			Kit.sphere(c, 0.18, Vector3(sp.x + 0.8 + j * 0.62, 0.3, bz), tops, Vector3(1.0, 0.7, 1.0), CSGShape3D.OPERATION_UNION, 8)
	# Бочка, тачка, поленница.
	Kit.cyl(c, 0.32, 0.9, sp + Vector3(2.1, 0.45, -0.8), Mats.paint(Color(0.18, 0.40, 0.65)), 14)
	var logs := Mats.wood(Color(0.62, 0.45, 0.28))
	for i in 5:
		for j in 3 - (i % 2):
			var lg := Kit.cyl(c, 0.11, 1.0, sp + Vector3(-2.2 + j * 0.24 + (i % 2) * 0.12, 0.11 + i * 0.2, -0.2), logs, 8)
			lg.rotation_degrees = Vector3(90, 0, 0)
	Kit.label(extra, "уч. %d" % rng.randi_range(3, 120), sp + Vector3(-0.6, 2.0, 1.32), 0.0, 28, Color(0.95, 0.95, 0.9), Color(0.1, 0.1, 0.1, 0.8))


## Киоск у остановки.
static func kiosk(node: Node3D, vol: Dictionary) -> void:
	var s := _setup(node, vol, Mats.paving())
	var c: CSGCombiner3D = s[0]
	var rng: RandomNumberGenerator = s[1]
	var extra: Node3D = s[2]
	var colors := [Color(0.18, 0.40, 0.70), Color(0.75, 0.18, 0.15), Color(0.20, 0.55, 0.35), Color(0.90, 0.62, 0.15)]
	var col: Color = colors[rng.randi() % colors.size()]
	var kp := Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-1.5, 0.0))
	var k := Kit.combiner(c)
	k.position = kp
	Kit.box(k, Vector3(2.4, 2.5, 1.8), Vector3(0, 1.25, 0), Mats.paint(Color(0.93, 0.93, 0.90)))
	Kit.box(k, Vector3(2.44, 0.9, 1.84), Vector3(0, 0.45, 0), Mats.paint(col))
	Kit.box(k, Vector3(2.8, 0.15, 2.2), Vector3(0, 2.58, 0), Mats.paint(col))
	Kit.box(k, Vector3(1.8, 0.9, 0.06), Vector3(0, 1.5, 0.9), Mats.world(Color(0.95, 0.88, 0.62), {"emission": 0.4, "noise": 0.0}))
	Kit.box(k, Vector3(2.3, 0.45, 0.08), Vector3(0, 2.25, 0.92), Mats.paint(col))
	var sign: String = FragmentNames.pick(FragmentNames.KIOSK_SIGNS, vol.seed, 3)
	Kit.label(extra, sign, kp + Vector3(0, 2.25, 0.97), 0.0, 56, Color(1, 1, 1))
	# Остановка: навес, стенка, скамейка.
	var bp := Vector3(kp.x + 3.2, 0, kp.z + 0.4)
	var frame := Mats.metal(Color(0.30, 0.32, 0.34))
	var glass := Mats.world(Color(0.55, 0.70, 0.72), {"rough": 0.1, "metal": 0.2, "noise": 0.0})
	for dx in [-1.4, 1.4]:
		Kit.box(c, Vector3(0.08, 2.4, 0.08), bp + Vector3(dx, 1.2, -0.6), frame)
		Kit.box(c, Vector3(0.08, 2.4, 0.08), bp + Vector3(dx, 1.2, 0.6), frame)
	Kit.box(c, Vector3(3.0, 0.08, 1.5), bp + Vector3(0, 2.42, 0), Mats.paint(Color(0.20, 0.36, 0.55)))
	Kit.box(c, Vector3(2.8, 1.8, 0.03), bp + Vector3(0, 1.2, -0.6), glass)
	Kit.box(c, Vector3(2.4, 0.06, 0.4), bp + Vector3(0, 0.48, -0.35), Mats.wood())
	Kit.box(c, Vector3(0.06, 2.3, 0.06), bp + Vector3(1.9, 1.15, 0.7), frame)
	Kit.box(c, Vector3(0.6, 0.6, 0.04), bp + Vector3(1.9, 2.2, 0.7), Mats.paint(Color(0.95, 0.95, 0.92)))
	if _in(vol, bp + Vector3(1.9, 0, 0.7), 0.4):
		var stop: String = FragmentNames.pick(FragmentNames.STOPS, vol.seed, 4)
		Kit.label(extra, "А\n«%s»" % stop, bp + Vector3(1.9, 2.2, 0.73), 0.0, 14, Color(0.1, 0.25, 0.5))
	Kit.cyl(c, 0.22, 0.75, Vector3(kp.x - 1.7, 0.375, kp.z + 1.4), Mats.paint(Color(0.25, 0.27, 0.28)), 12)


## Край пшеничного поля с пугалом.
static func field(node: Node3D, vol: Dictionary) -> void:
	var soil := Mats.world(Color(0.42, 0.31, 0.20), {"pattern": Mats.PATTERN_PLANKS, "color2": Color(0.30, 0.21, 0.14), "scale": 0.5, "noise": 0.2})
	var s := _setup(node, vol, soil)
	var c: CSGCombiner3D = s[0]
	var rng: RandomNumberGenerator = s[1]
	var extra: Node3D = s[2]
	var r: float = vol.radius
	# Пшеница: густой MultiMesh колосьев, только внутри круга.
	var items := []
	var step := 0.42
	var gx := -r
	var path_z := rng.randf_range(-r * 0.4, r * 0.4)
	while gx < r:
		var gz := -r
		while gz < r:
			var p := Vector3(gx + rng.randf_range(-0.15, 0.15), 0, gz + rng.randf_range(-0.15, 0.15))
			if _in(vol, p, 0.25) and absf(p.z - path_z) > 0.9:
				var col := Color(0.92, 0.76, 0.36).lerp(Color(0.80, 0.62, 0.28), rng.randf())
				items.append([p, rng.randf() * TAU, rng.randf_range(0.85, 1.1), col])
			gz += step
		gx += step
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = ScatterMeshes.get_mesh("tall")
	mm.instance_count = items.size()
	for i in items.size():
		var it: Array = items[i]
		var sc: float = it[2]
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, it[1]).scaled(Vector3(sc, sc, sc)), it[0]))
		mm.set_instance_custom_data(i, it[3])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Mats.plant(0.06, true)
	extra.add_child(mmi)
	# Пугало посреди поля.
	var sp := Vector3(rng.randf_range(-r * 0.4, r * 0.4), 0, path_z + 2.0)
	var wood := Mats.wood(Color(0.50, 0.38, 0.25))
	Kit.cyl(c, 0.05, 2.2, sp + Vector3(0, 1.1, 0), wood, 8)
	Kit.box(c, Vector3(1.4, 0.06, 0.06), sp + Vector3(0, 1.6, 0), wood)
	Kit.box(c, Vector3(0.55, 0.65, 0.28), sp + Vector3(0, 1.45, 0), Mats.paint(Color(0.35, 0.40, 0.55)))
	Kit.box(c, Vector3(1.3, 0.16, 0.16), sp + Vector3(0, 1.62, 0), Mats.paint(Color(0.35, 0.40, 0.55)))
	Kit.sphere(c, 0.2, sp + Vector3(0, 2.0, 0), Mats.world(Color(0.80, 0.70, 0.50), {"noise": 0.25}), Vector3.ONE, CSGShape3D.OPERATION_UNION, 10)
	Kit.cyl(c, 0.32, 0.03, sp + Vector3(0, 2.15, 0), Mats.paint(Color(0.25, 0.20, 0.14)), 12)
	Kit.cyl(c, 0.17, 0.18, sp + Vector3(0, 2.25, 0), Mats.paint(Color(0.25, 0.20, 0.14)), 12)


## Ряд гаражей: полые коробки, внутри — то, что люди годами копили.
static func garages(node: Node3D, vol: Dictionary) -> void:
	var s := _setup(node, vol, Mats.world(Color(0.52, 0.51, 0.48), {"noise": 0.25}))
	var c: CSGCombiner3D = s[0]
	var rng: RandomNumberGenerator = s[1]
	var extra: Node3D = s[2]
	var r: float = vol.radius
	var count := int(ceil((2.0 * r) / 3.2)) + 1
	var start := -count * 3.2 * 0.5
	var z0 := rng.randf_range(-r * 0.5, -1.0)
	var brick := Mats.brick()
	var door_colors := [Color(0.25, 0.42, 0.30), Color(0.55, 0.20, 0.16), Color(0.30, 0.35, 0.50), Color(0.50, 0.45, 0.30), Color(0.40, 0.40, 0.42)]
	var num := rng.randi_range(1, 140)
	for i in count:
		var gx := start + i * 3.2 + 1.6
		var g := Kit.combiner(c)
		g.position = Vector3(gx, 0, z0)
		Kit.box(g, Vector3(3.2, 2.5, 6.0), Vector3(0, 1.25, 0), brick)
		Kit.box(g, Vector3(2.9, 2.3, 5.7), Vector3(0, 1.2, 0), brick, 0.0, CSGShape3D.OPERATION_SUBTRACTION)
		var open := rng.randf() < 0.35
		Kit.box(g, Vector3(2.5, 2.1, 0.5), Vector3(0, 1.05, 3.0), brick, 0.0, CSGShape3D.OPERATION_SUBTRACTION)
		if not open:
			Kit.box(g, Vector3(2.5, 2.1, 0.05), Vector3(0, 1.05, 2.9), Mats.paint(door_colors[rng.randi() % door_colors.size()]))
		Kit.box(g, Vector3(3.4, 0.12, 6.4), Vector3(0, 2.56, 0), Mats.world(Color(0.25, 0.25, 0.26), {"noise": 0.2}))
		# Содержимое: шины, стеллаж, канистры.
		Kit.box(g, Vector3(0.4, 1.8, 2.5), Vector3(-1.2, 0.9, -1.5), Mats.metal(Color(0.35, 0.33, 0.30)))
		for t in rng.randi_range(0, 4):
			var tyre := Kit.cyl(g, 0.32, 0.2, Vector3(0.9, 0.1 + t * 0.2, -2.0), Mats.paint(Color(0.07, 0.07, 0.07)), 12)
			tyre.rotation.y = t * 0.3
		if rng.randf() < 0.5:
			Kit.box(g, Vector3(0.3, 0.45, 0.18), Vector3(0.3, 0.225, -2.5), Mats.paint(Color(0.75, 0.15, 0.12)))
		var gp := Vector3(gx, 0, z0)
		if _in(vol, gp + Vector3(1.4, 0, 3.0), 0.3) and _in(vol, gp + Vector3(-1.4, 0, 3.0), 0.3):
			Kit.label(extra, str(num + i), gp + Vector3(0, 2.2, 3.08), 0.0, 40, Color(0.95, 0.95, 0.9))
