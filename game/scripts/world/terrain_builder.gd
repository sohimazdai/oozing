class_name TerrainBuilder
extends RefCounted
## Строит данные одного чанка рельефа: вершины, нормали, цвета, коллизию и
## расстановку растений/камней. Работает в рабочем потоке, поэтому возвращает
## только «сырые» массивы; узлы сцены создаёт ChunkStreamer в главном потоке.

const CHUNK := 32.0
const RES := 64                 # квадов на сторону → шаг 0,5 м
const COL_RES := 32             # коллизия с шагом 1 м

static var _indices := PackedInt32Array()


static func shared_indices() -> PackedInt32Array:
	if _indices.is_empty():
		var n := RES + 1
		var idx := PackedInt32Array()
		idx.resize(RES * RES * 6)
		var k := 0
		for j in RES:
			for i in RES:
				var a := j * n + i
				var b := a + 1
				var c := a + n
				var d := c + 1
				# Godot считает лицевыми треугольники «по часовой стрелке».
				idx[k] = a; idx[k + 1] = b; idx[k + 2] = d
				idx[k + 3] = a; idx[k + 4] = d; idx[k + 5] = c
				k += 6
		_indices = idx
	return _indices


static func build(gen: WorldGen, cx: int, cz: int) -> Dictionary:
	var step := CHUNK / RES
	var ox := cx * CHUNK
	var oz := cz * CHUNK
	var n := RES + 1
	var ext := n + 2
	# Высоты с полем в одну клетку вокруг — для честных нормалей на швах.
	var hg := PackedFloat32Array()
	hg.resize(ext * ext)
	for j in ext:
		for i in ext:
			hg[j * ext + i] = gen.base_height(ox + (i - 1) * step, oz + (j - 1) * step)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(n * n)
	normals.resize(n * n)
	colors.resize(n * n)
	var hmin := INF
	var hmax := -INF
	for j in n:
		for i in n:
			var g := (j + 1) * ext + (i + 1)
			var h := hg[g]
			var nrm := Vector3(hg[g - 1] - hg[g + 1], 2.0 * step, hg[g - ext] - hg[g + ext]).normalized()
			var k := j * n + i
			verts[k] = Vector3(i * step, h, j * step)
			normals[k] = nrm
			colors[k] = gen.ground_color(ox + i * step, oz + j * step, h, nrm.y)
			hmin = minf(hmin, h)
			hmax = maxf(hmax, h)

	# Объёмы, задевающие чанк: под их землёй коллизия рельефа опускается.
	var vols := gen.volumes_in_rect(ox - 1.0, oz - 1.0, ox + CHUNK + 1.0, oz + CHUNK + 1.0)
	var cn := COL_RES + 1
	var col := PackedFloat32Array()
	col.resize(cn * cn)
	var ratio := RES / COL_RES
	for j in cn:
		for i in cn:
			var h := hg[(j * ratio + 1) * ext + (i * ratio + 1)]
			var p := Vector2(ox + i, oz + j)
			for v in vols:
				if p.distance_to(v.center) < v.radius - 0.3:
					h = v.base_y - 0.4
			col[j * cn + i] = h

	var scatter := _scatter(gen, cx, cz, hg, ext, step, vols)
	return {
		"key": Vector2i(cx, cz),
		"verts": verts,
		"normals": normals,
		"colors": colors,
		"col": col,
		"hmin": hmin,
		"hmax": hmax,
		"scatter": scatter,
	}


static func _sample(hg: PackedFloat32Array, ext: int, step: float, lx: float, lz: float) -> float:
	var fx := lx / step + 1.0
	var fz := lz / step + 1.0
	var ix := clampi(int(fx), 0, ext - 2)
	var iz := clampi(int(fz), 0, ext - 2)
	var tx := fx - ix
	var tz := fz - iz
	var a := lerpf(hg[iz * ext + ix], hg[iz * ext + ix + 1], tx)
	var b := lerpf(hg[(iz + 1) * ext + ix], hg[(iz + 1) * ext + ix + 1], tx)
	return lerpf(a, b, tz)


static func _in_volume(p: Vector2, vols: Array[Dictionary], pad: float) -> bool:
	for v in vols:
		if p.distance_to(v.center) < v.radius + pad:
			return true
	return false


## Расстановка: трава, папоротники, кусты, валуны, деревья, тростник.
static func _scatter(gen: WorldGen, cx: int, cz: int, hg: PackedFloat32Array, ext: int, step: float, vols: Array[Dictionary]) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = WorldGen.ihash(cx, cz, gen.seed_value * 13 + 5)
	var ox := cx * CHUNK
	var oz := cz * CHUNK
	var out := {
		"grass": [], "tall": [], "fern": [], "shrub": [], "reed": [],
		"rock": [], "tree": [],
	}
	var wl := WorldGen.WATER_LEVEL
	var attempts := 420
	for _i in attempts:
		var lx := rng.randf() * CHUNK
		var lz := rng.randf() * CHUNK
		var wx := ox + lx
		var wz := oz + lz
		if _in_volume(Vector2(wx, wz), vols, 0.6):
			continue
		var h := _sample(hg, ext, step, lx, lz)
		var dx := _sample(hg, ext, step, lx + 0.5, lz) - _sample(hg, ext, step, lx - 0.5, lz)
		var dz := _sample(hg, ext, step, lx, lz + 0.5) - _sample(hg, ext, step, lx, lz - 0.5)
		var up := 1.0 / sqrt(1.0 + dx * dx + dz * dz)
		var m := gen.moisture(wx, wz, h)
		var roll := rng.randf()
		var yaw := rng.randf() * TAU
		var pos := Vector3(lx, h, lz)
		if h < wl - 0.05:
			continue
		if h < wl + 0.5:
			if m > 0.45 and roll < 0.35:
				out.reed.append([pos, yaw, rng.randf_range(0.8, 1.3), _tint(rng, Color(0.52, 0.56, 0.30))])
			continue
		if up < 0.72:
			if roll < 0.05:
				out.rock.append([pos, yaw, rng.randf_range(0.5, 1.6), _tint(rng, Color(0.72, 0.40, 0.30)), rng.randi() % 3])
			continue
		var tg := gen.tall_grass(wx, wz)
		if tg > 0.3 and roll < 0.55 * tg:
			out.tall.append([pos, yaw, rng.randf_range(1.0, 1.5), _tint(rng, Color(0.88, 0.72, 0.38).lerp(Color(0.62, 0.66, 0.36), m))])
		elif roll < 0.42:
			var c := Color(0.86, 0.68, 0.34).lerp(Color(0.50, 0.62, 0.34), smoothstep(0.3, 0.7, m))
			out.grass.append([pos, yaw, rng.randf_range(0.7, 1.2), _tint(rng, c)])
		elif roll < 0.52 and m > 0.45:
			out.fern.append([pos, yaw, rng.randf_range(0.7, 1.3), _tint(rng, Color(0.27, 0.58, 0.55).lerp(Color(0.30, 0.50, 0.40), rng.randf()))])
		elif roll < 0.56:
			out.shrub.append([pos, yaw, rng.randf_range(0.6, 1.3), _tint(rng, Color(0.30, 0.48, 0.38).lerp(Color(0.62, 0.55, 0.30), 1.0 - m))])
		elif roll < 0.575:
			out.rock.append([pos, yaw, rng.randf_range(0.3, 1.2), _tint(rng, Color(0.70, 0.42, 0.32)), rng.randi() % 3])
		elif roll < 0.585 and m > 0.4:
			out.tree.append([pos, yaw, rng.randf_range(0.8, 1.25), _tint(rng, Color(1, 1, 1))])
	return out


static func _tint(rng: RandomNumberGenerator, c: Color) -> Color:
	var k := rng.randf_range(0.88, 1.1)
	return Color(c.r * k, c.g * k, c.b * k, 1.0)
