class_name ScatterMeshes
extends RefCounted
## Процедурные меши растений и камней Кромы. Без текстур: форма + цвет вершин.
## Цвет экземпляра (оттенок) приходит через INSTANCE_CUSTOM в MultiMesh.

static var _cache := {}


static func get_mesh(kind: String) -> Mesh:
	if _cache.has(kind):
		return _cache[kind]
	var m: Mesh
	match kind:
		"grass": m = _tuft(7, 0.55, 0.05, 0.35)
		"tall": m = _tuft(11, 1.25, 0.06, 0.25)
		"reed": m = _tuft(9, 1.4, 0.035, 0.12)
		"fern": m = _fern()
		"shrub": m = _blob(1, Vector3(0.9, 0.62, 0.9), 0.22, 11, Color(1, 1, 1))
		"rock0": m = _blob(1, Vector3(1.0, 0.65, 0.85), 0.28, 21, Color(1, 1, 1))
		"rock1": m = _blob(1, Vector3(0.8, 0.9, 0.75), 0.32, 33, Color(1, 1, 1))
		"rock2": m = _blob(2, Vector3(1.2, 0.5, 1.0), 0.22, 47, Color(1, 1, 1))
		"tree": m = _tree()
	_cache[kind] = m
	return m


## Пучок травинок: сужающиеся треугольные полосы, наклонённые наружу.
static func _tuft(blades: int, height: float, width: float, lean: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = blades * 101 + int(height * 100)
	for b in blades:
		var a := rng.randf() * TAU
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x)
		var h := height * rng.randf_range(0.65, 1.1)
		var base := dir * rng.randf_range(0.0, 0.12)
		var tip := base + dir * lean * h * rng.randf_range(0.5, 1.2) + Vector3(0, h, 0)
		var mid := base.lerp(tip, 0.5) + dir * lean * h * 0.15
		var w := width * rng.randf_range(0.8, 1.2)
		var c0 := Color(0.62, 0.62, 0.62)
		var c1 := Color(1.0, 1.0, 1.0)
		var c2 := Color(1.12, 1.12, 1.05)
		var p := [base - side * w, base + side * w, mid + side * w * 0.6, mid - side * w * 0.6, tip]
		var cols := [c0, c0, c1, c1, c2]
		for tri in [[0, 1, 2], [0, 2, 3], [3, 2, 4]]:
			for i in tri:
				st.set_color(cols[i])
				st.set_normal(Vector3(0, 1, 0))
				st.add_vertex(p[i])
	return st.commit()


## Папоротник Кромы: дугообразные листья с поперечными долями.
static func _fern() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fronds := 7
	for f in fronds:
		var a := TAU * f / fronds + 0.3 * sin(f * 2.1)
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x)
		var segs := 5
		var length := 0.95
		var prev_c := Vector3(0, 0.05, 0)
		for s in segs:
			var t0 := float(s) / segs
			var t1 := float(s + 1) / segs
			var c0 := dir * length * t0 + Vector3(0, 0.05 + sin(t0 * PI * 0.8) * 0.5, 0)
			var c1 := dir * length * t1 + Vector3(0, 0.05 + sin(t1 * PI * 0.8) * 0.5, 0)
			var w0 := 0.16 * (1.0 - t0 * 0.8)
			var w1 := 0.16 * (1.0 - t1 * 0.8)
			var col0 := Color(0.7, 0.7, 0.7).lerp(Color(1.1, 1.1, 1.1), t0)
			var col1 := Color(0.7, 0.7, 0.7).lerp(Color(1.1, 1.1, 1.1), t1)
			var q := [c0 - side * w0, c0 + side * w0, c1 + side * w1, c1 - side * w1]
			var qc := [col0, col0, col1, col1]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				for i in tri:
					st.set_color(qc[i])
					st.set_normal(Vector3(0, 1, 0))
					st.add_vertex(q[i])
			prev_c = c1
	return st.commit()


## Неровный многогранник: камни и кусты. subdiv 1 = 80 граней, 2 = 320.
static func _blob(subdiv: int, scale: Vector3, rough: float, salt: int, col: Color) -> ArrayMesh:
	var verts: Array[Vector3] = []
	var t := (1.0 + sqrt(5.0)) / 2.0
	for p in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
			Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
			Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
		verts.append(p.normalized())
	var faces := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for _s in subdiv:
		var mids := {}
		var nf := []
		for f in faces:
			var m := []
			for e in 3:
				var a: int = f[e]
				var b: int = f[(e + 1) % 3]
				var key := Vector2i(mini(a, b), maxi(a, b))
				if not mids.has(key):
					verts.append(((verts[a] + verts[b]) * 0.5).normalized())
					mids[key] = verts.size() - 1
				m.append(mids[key])
			nf.append([f[0], m[0], m[2]])
			nf.append([f[1], m[1], m[0]])
			nf.append([f[2], m[2], m[1]])
			nf.append([m[0], m[1], m[2]])
		faces = nf
	var noise := FastNoiseLite.new()
	noise.seed = salt
	noise.frequency = 1.3
	var disp: Array[Vector3] = []
	for v in verts:
		var k := 1.0 + noise.get_noise_3dv(v * 2.0) * rough * 2.0
		var p := v * k * scale
		if p.y < -0.15 * scale.y:
			p.y = -0.15 * scale.y + (p.y + 0.15 * scale.y) * 0.3  # приплюснутое основание
		disp.append(p + Vector3(0, 0.12 * scale.y, 0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		var a: Vector3 = disp[f[0]]
		var b: Vector3 = disp[f[1]]
		var c: Vector3 = disp[f[2]]
		var n := (b - a).cross(c - a).normalized()
		var centroid := (a + b + c) / 3.0
		# Лицевая грань по часовой: векторное произведение должно смотреть внутрь.
		if n.dot(centroid) > 0.0:
			var tmp := b
			b = c
			c = tmp
		else:
			n = -n
		var normal := -((b - a).cross(c - a)).normalized()
		var shade := 0.85 + 0.25 * clampf(normal.y, 0.0, 1.0)
		for p in [a, b, c]:
			st.set_color(Color(col.r * shade, col.g * shade, col.b * shade))
			st.set_normal(normal)
			st.add_vertex(p)
	return st.commit()


## Дерево Кромы: тонкий изогнутый ствол и несколько плоских ярусов кроны.
static func _tree() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk_col := Color(0.42, 0.30, 0.34)
	_cylinder(st, Vector3(0, 0, 0), Vector3(0.25, 3.4, 0.1), 0.22, 0.12, 6, trunk_col)
	_cylinder(st, Vector3(0.25, 3.4, 0.1), Vector3(0.1, 4.6, 0.3), 0.12, 0.08, 6, trunk_col)
	var tiers := [[Vector3(0.2, 3.5, 0.15), 2.3, 0.45, Color(0.24, 0.48, 0.42)],
		[Vector3(0.0, 4.2, 0.3), 1.8, 0.4, Color(0.30, 0.58, 0.50)],
		[Vector3(0.15, 4.8, 0.25), 1.1, 0.35, Color(0.38, 0.66, 0.56)]]
	for t in tiers:
		_disc(st, t[0], t[1], t[2], 9, t[3], Color(0.32, 0.27, 0.38))
	return st.commit()


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	# Принимаем треугольник «против часовой снаружи» и разворачиваем для Godot.
	var n := (b - a).cross(c - a).normalized()
	for p in [a, c, b]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(p)


static func _cylinder(st: SurfaceTool, p0: Vector3, p1: Vector3, r0: float, r1: float, sides: int, col: Color) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var b0 := p0 + d0 * r0
		var b1 := p0 + d1 * r0
		var t0 := p1 + d0 * r1
		var t1 := p1 + d1 * r1
		_tri(st, b0, t1, b1, col)
		_tri(st, b0, t0, t1, col)


static func _disc(st: SurfaceTool, c: Vector3, r: float, h: float, sides: int, top_col: Color, under_col: Color) -> void:
	var top := c + Vector3(0, h * 0.5, 0)
	var bot := c - Vector3(0, h * 0.5, 0)
	for i in sides:
		var a0 := TAU * i / sides + 0.2
		var a1 := TAU * (i + 1) / sides + 0.2
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var e0 := c + d0 * r
		var e1 := c + d1 * r
		_tri(st, top, e1, e0, top_col)
		_tri(st, bot, e0, e1, under_col)
