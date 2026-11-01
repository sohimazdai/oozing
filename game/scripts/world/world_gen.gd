class_name WorldGen
extends RefCounted
## Детерминированная природа Кромы и размещение объёмов (перенесённых фрагментов).
##
## Всё — чистые функции от seed и координат: один seed даёт один и тот же мир,
## в каком бы порядке ни загружались чанки. Поэтому методы можно вызывать
## из рабочих потоков.
##
## Это временный генератор для прогулки: бесконечный шум с реками «на уровне моря»
## (как в Minecraft). Связная гидрология живёт в prototypes/terrain и будет
## перенесена отдельно.

const WATER_LEVEL := 0.0
## Шаг сетки, в каждой клетке которой может оказаться случайный объём.
const VOLUME_CELL := 110.0
const SECTOR := 400.0

var seed_value: int

var _cont: FastNoiseLite
var _hills: FastNoiseLite
var _detail: FastNoiseLite
var _mesa: FastNoiseLite
var _river: FastNoiseLite
var _warp: FastNoiseLite
var _moist: FastNoiseLite
var _ford: FastNoiseLite
var _tall: FastNoiseLite

## Авторские объёмы около старта: минигольф и дом с магазином.
var fixed_volumes: Array[Dictionary] = []


func _init(p_seed: int) -> void:
	seed_value = p_seed
	_cont = _make_noise(1, 0.0011, 3)
	_hills = _make_noise(2, 0.0048, 4)
	_detail = _make_noise(3, 0.035, 2)
	_mesa = _make_noise(4, 0.0032, 3)
	_river = _make_noise(5, 0.0017, 2)
	_warp = _make_noise(6, 0.004, 2)
	_moist = _make_noise(7, 0.0022, 3)
	_ford = _make_noise(8, 0.012, 1)
	_tall = _make_noise(9, 0.009, 2)
	_place_fixed_volumes()


func _make_noise(salt: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = seed_value * 31 + salt * 1013
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	return n


# --- Рельеф -----------------------------------------------------------------

## Значение «реки»: 0 на оси русла, растёт при удалении.
func river_value(x: float, z: float) -> float:
	var wx := x + _warp.get_noise_2d(x, z) * 70.0
	var wz := z + _warp.get_noise_2d(x + 517.0, z - 291.0) * 70.0
	return absf(_river.get_noise_2d(wx, wz))


## Естественная высота Кромы без перенесённых фрагментов.
func base_height(x: float, z: float) -> float:
	var h := 7.0 + _cont.get_noise_2d(x, z) * 15.0
	h += _hills.get_noise_2d(x, z) * 8.0
	# Столовые горы: террасы с крутыми краями — на них видны слои породы.
	var m := _mesa.get_noise_2d(x, z)
	h += smoothstep(0.16, 0.22, m) * 9.0 + smoothstep(0.34, 0.385, m) * 6.0
	h += _detail.get_noise_2d(x, z) * 0.8
	# Долины и русла: рельеф прижимается к пойме, затем прорезается канал.
	var r := river_value(x, z)
	var floor_h := WATER_LEVEL + 1.1
	if h > floor_h:
		var valley := smoothstep(0.035, 0.17, r)
		h = floor_h + (h - floor_h) * pow(valley, 1.4)
	if r < 0.03:
		var bank := r / 0.03
		var bed := lerpf(WATER_LEVEL - 1.9, floor_h, bank * bank)
		# Броды: местами дно плавно поднимается, и реку можно перейти.
		var ford := smoothstep(0.34, 0.46, _ford.get_noise_2d(x, z))
		bed = lerpf(bed, maxf(bed, WATER_LEVEL - 0.45), ford)
		h = minf(h, bed)
	return h


## Высота поверхности, по которой ходит герой: внутри объёма — его земля.
func surface_height(x: float, z: float) -> float:
	var v := volume_at(x, z)
	if not v.is_empty():
		return v.base_y
	return base_height(x, z)


## Глубина воды Кромы в точке (внутри объёмов воды нет).
func water_depth(x: float, z: float) -> float:
	if not volume_at(x, z).is_empty():
		return 0.0
	return maxf(0.0, WATER_LEVEL - base_height(x, z))


func moisture(x: float, z: float, h: float) -> float:
	var m := 0.5 + 0.5 * _moist.get_noise_2d(x, z)
	m += (1.0 - smoothstep(0.03, 0.2, river_value(x, z))) * 0.35
	m += (1.0 - smoothstep(WATER_LEVEL + 0.5, WATER_LEVEL + 5.0, h)) * 0.2
	return clampf(m, 0.0, 1.0)


## Насколько место подходит для высокотравья (0..1).
func tall_grass(x: float, z: float) -> float:
	return smoothstep(0.25, 0.45, _tall.get_noise_2d(x, z))


## Цвет почвенного покрова для вершины рельефа (скалы рисует шейдер).
func ground_color(x: float, z: float, h: float, up: float) -> Color:
	var m := moisture(x, z, h)
	var dry := Color(0.80, 0.63, 0.33)      # охра степи
	var green := Color(0.50, 0.60, 0.31)    # трава
	var jade := Color(0.33, 0.53, 0.29)     # сочная зелень влажных низин (не путать с водой)
	var c: Color
	if m < 0.5:
		c = dry.lerp(green, smoothstep(0.25, 0.5, m))
	else:
		c = green.lerp(jade, smoothstep(0.5, 0.85, m))
	var tg := tall_grass(x, z)
	c = c.lerp(Color(0.86, 0.70, 0.36), tg * 0.35 * (1.0 - m))
	# Песок и галька у воды.
	var shore := 1.0 - smoothstep(WATER_LEVEL + 0.25, WATER_LEVEL + 1.0, h)
	c = c.lerp(Color(0.80, 0.73, 0.56), shore)
	# Высокогорье бледнеет.
	c = c.lerp(Color(0.62, 0.58, 0.50), smoothstep(22.0, 32.0, h) * 0.6)
	c.a = m
	return c


# --- Объёмы -----------------------------------------------------------------

static func ihash(a: int, b: int, c: int) -> int:
	var h := (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return h & 0x7fffffff


## Насколько ровно место для объёма радиуса r: максимальный перепад по краю.
func _site_roughness(cx: float, cz: float, r: float) -> float:
	var h0 := base_height(cx, cz)
	var worst := 0.0
	for i in 12:
		var a := TAU * i / 12.0
		var h := base_height(cx + cos(a) * r, cz + sin(a) * r)
		worst = maxf(worst, absf(h - h0))
	return worst


func _site_ok(cx: float, cz: float, r: float, max_rough: float) -> bool:
	var h0 := base_height(cx, cz)
	if h0 < WATER_LEVEL + 1.4 or h0 > 18.0:
		return false
	if river_value(cx, cz) < 0.06:
		return false
	return _site_roughness(cx, cz, r) <= max_rough


## Ищет ровное сухое место спиралью вокруг точки.
func _find_site(around: Vector2, r: float, min_d: float, max_d: float, prefer: Vector2) -> Vector2:
	var best := Vector2.INF
	var best_score := INF
	var d := min_d
	while d <= max_d:
		var steps := int(maxf(8.0, TAU * d / 6.0))
		for i in steps:
			var a := TAU * i / steps
			var p := around + Vector2(cos(a), sin(a)) * d
			if not _site_ok(p.x, p.y, r, 1.7):
				continue
			var score := d + (p - (around + prefer * d)).length() * 0.8
			if score < best_score:
				best_score = score
				best = p
		if best != Vector2.INF:
			return best
		d += 6.0
	return around + prefer * maxf(min_d, 40.0)


func _place_fixed_volumes() -> void:
	var golf_r := 14.0
	var golf_c := _find_site(Vector2.ZERO, golf_r, 0.0, 900.0, Vector2.ZERO)
	fixed_volumes.append(_make_volume("start_minigolf", "minigolf", golf_c, golf_r, 1, 0.0))
	# Дом ставим «вверх по экрану» от старта: камера смотрит на -X -Z.
	var house_r := 11.0
	var dir := Vector2(-1.0, -1.0).normalized()
	var house_c := _find_site(golf_c, house_r, 36.0, 140.0, dir)
	fixed_volumes.append(_make_volume("start_house", "house", house_c, house_r, 2, 0.0))


## Уровень земли фрагмента: ближе к средней высоте по краю круга, чуть выше неё.
## Тогда фрагмент не сидит в яме, а местами выступает срезом земного грунта.
func _volume_base(c: Vector2, r: float) -> float:
	var ring := 0.0
	for i in 16:
		var a := TAU * i / 16.0
		ring += base_height(c.x + cos(a) * r, c.y + sin(a) * r)
	ring /= 16.0
	return lerpf(base_height(c.x, c.y), ring, 0.75) + 0.3


## Насколько глубоко под землю фрагмента уходит объём: до низшей точки края и ещё 0,8 м.
## Тогда срез — сплошная стенка, и под фрагментом нет щели.
func _volume_depth(c: Vector2, r: float, base: float) -> float:
	var lowest := base
	for i in 24:
		var a := TAU * i / 24.0
		lowest = minf(lowest, base_height(c.x + cos(a) * (r + 0.35), c.y + sin(a) * (r + 0.35)))
	return base - lowest + 0.8


func _make_volume(id: String, type: String, c: Vector2, r: float, vseed: int, rot: float) -> Dictionary:
	var base := _volume_base(c, r)
	var v := {
		"id": id,
		"type": type,
		"center": c,
		"radius": r,
		"base_y": base,
		"depth": _volume_depth(c, r, base),
		"seed": vseed,
		"rot": rot,
	}
	v["name"] = FragmentNames.title_for(v)
	return v


const RANDOM_TYPES := ["road", "road", "shed", "shed", "kiosk", "field", "garages"]


## Случайный объём клетки сетки (или пустой словарь). Детерминирован.
func _cell_volume(cx: int, cz: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = ihash(cx, cz, seed_value * 7 + 3)
	if rng.randf() > 0.7:
		return {}
	var type: String = RANDOM_TYPES[rng.randi() % RANDOM_TYPES.size()]
	var r := rng.randf_range(6.0, 13.0)
	if type == "field":
		r = rng.randf_range(11.0, 18.0)
	elif type == "kiosk":
		r = rng.randf_range(5.0, 8.0)
	var margin := 24.0
	var c := Vector2(
		cx * VOLUME_CELL + rng.randf_range(margin, VOLUME_CELL - margin),
		cz * VOLUME_CELL + rng.randf_range(margin, VOLUME_CELL - margin))
	for f in fixed_volumes:
		if c.distance_to(f.center) < r + f.radius + 25.0:
			return {}
	if not _site_ok(c.x, c.y, r, 3.2):
		return {}
	return _make_volume("cell_%d_%d" % [cx, cz], type, c, r, rng.randi(), rng.randf() * TAU)


## Все объёмы, чьи круги пересекают прямоугольник (x0, z0)–(x1, z1).
func volumes_in_rect(x0: float, z0: float, x1: float, z1: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in fixed_volumes:
		if _circle_hits_rect(f.center, f.radius, x0, z0, x1, z1):
			out.append(f)
	var c0 := Vector2i(floori((x0 - 20.0) / VOLUME_CELL), floori((z0 - 20.0) / VOLUME_CELL))
	var c1 := Vector2i(floori((x1 + 20.0) / VOLUME_CELL), floori((z1 + 20.0) / VOLUME_CELL))
	for cz in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var v := _cell_volume(cx, cz)
			if not v.is_empty() and _circle_hits_rect(v.center, v.radius, x0, z0, x1, z1):
				out.append(v)
	return out


func volumes_near(x: float, z: float, dist: float) -> Array[Dictionary]:
	var all := volumes_in_rect(x - dist, z - dist, x + dist, z + dist)
	var out: Array[Dictionary] = []
	var p := Vector2(x, z)
	for v in all:
		if p.distance_to(v.center) - v.radius <= dist:
			out.append(v)
	return out


func volume_at(x: float, z: float) -> Dictionary:
	for v in volumes_in_rect(x, z, x, z):
		if Vector2(x, z).distance_to(v.center) < v.radius:
			return v
	return {}


static func _circle_hits_rect(c: Vector2, r: float, x0: float, z0: float, x1: float, z1: float) -> bool:
	var px := clampf(c.x, x0, x1)
	var pz := clampf(c.y, z0, z1)
	return Vector2(px, pz).distance_to(c) <= r


func spawn_point() -> Vector3:
	# Перед пастью динозавра, чтобы он был в кадре с первой секунды.
	var g: Dictionary = fixed_volumes[0]
	return Vector3(g.center.x - 1.0, g.base_y + 0.05, g.center.y + 2.2)
