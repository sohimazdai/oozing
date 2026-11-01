class_name HouseFragment
extends RefCounted
## Трёхэтажный кирпичный дом с магазином «Продукты». Радиус объёма 11 м.
##
## Дом больше круга: объём срезал его восточную часть, и разрез смотрит
## прямо в камеру — видны перекрытия, кладка, комнаты, полки магазина.
## Объём захватывает здание на всю высоту, по лестнице можно подняться
## на второй и третий этажи.
##
## Координаты локальные: (0, 0, 0) — центр круга на уровне асфальта.

const X0 := -9.0
const X1 := 17.0
const Z0 := -5.0
const Z1 := 7.0
const BRICK := 0.36
const PLASTER := 0.06
const IX0 := X0 + BRICK + PLASTER     # внутренние грани наружных стен
const IX1 := X1 - BRICK - PLASTER
const IZ0 := Z0 + BRICK + PLASTER
const IZ1 := Z1 - BRICK - PLASTER
const LEVELS := [0.3, 3.3, 6.3]       # отметки чистого пола этажей
const ROOF := 9.3
const SLAB := 0.25
const CLEAR := 2.75                    # от пола до потолка
const EPS := 0.02                      # перекрытие деталей в CSG

# Лестничная клетка у северо-западного угла: два марша и площадка.
const SW_X0 := IX0
const SW_X1 := -5.0
const SW_Z0 := IZ0
const SW_Z1 := 1.45
const LANE_A := -7.72                  # ось первого марша (вверх к площадке)
const LANE_B := -5.88                  # ось второго марша (с площадки на этаж)
const FLIGHT_Z0 := 0.0                 # низ первого марша
const FLIGHT_Z1 := -2.5                # верх первого марша / площадка

static var _r := 11.0


static func build(node: Node3D, vol: Dictionary) -> void:
	_r = vol.radius
	var base: float = vol.base_y

	var bcut := Mats.cut(base, 1)
	var a := Kit.volume_cut(node, _r, bcut, 14.0, vol.depth)
	var structure: CSGCombiner3D = a[1]
	_structure(structure)

	var b := Kit.volume_cut(node, _r, Mats.cut(base, 0), 14.0, vol.depth, false)
	var content: CSGCombiner3D = b[1]
	_ground(content)
	_shop(content)
	_apartment(content, 1)
	_apartment(content, 2)
	_birch(content)

	_stairs(node)
	_windows(node)
	_facade_details(node)
	_products(node)
	_lights(node)


static func _inside(p: Vector2, pad := 0.0) -> bool:
	return p.length() < _r - pad


# --- Коробка здания -------------------------------------------------------------

static func _structure(s: CSGCombiner3D) -> void:
	var brick := Mats.brick()
	var w := X1 - X0
	var d := Z1 - Z0
	var cx := (X0 + X1) * 0.5
	var cz := (Z0 + Z1) * 0.5
	# Наружные стены на всю высоту + парапет.
	Kit.box(s, Vector3(w, ROOF + 0.5, BRICK), Vector3(cx, (ROOF + 0.5) * 0.5, Z1 - BRICK * 0.5), brick)
	Kit.box(s, Vector3(w, ROOF + 0.5, BRICK), Vector3(cx, (ROOF + 0.5) * 0.5, Z0 + BRICK * 0.5), brick)
	Kit.box(s, Vector3(BRICK, ROOF + 0.5, d), Vector3(X0 + BRICK * 0.5, (ROOF + 0.5) * 0.5, cz), brick)
	Kit.box(s, Vector3(BRICK, ROOF + 0.5, d), Vector3(X1 - BRICK * 0.5, (ROOF + 0.5) * 0.5, cz), brick)
	# Штукатурка изнутри — свой цвет на каждом этаже.
	var colors := [Color(0.88, 0.86, 0.80), Color(0.80, 0.86, 0.75), Color(0.77, 0.83, 0.90)]
	for k in 3:
		var L: float = LEVELS[k]
		var pm := Mats.plaster(colors[k])
		# Детали перекрывают друг друга на EPS: совпадающие грани дают в CSG
		# невидимые обрезки, о которые спотыкается коллизия.
		var yc := L + CLEAR * 0.5
		var hh := CLEAR + 2.0 * EPS
		var t := PLASTER + 2.0 * EPS
		var iw := IX1 - IX0 + 2.0 * PLASTER
		var idp := IZ1 - IZ0 + 2.0 * PLASTER
		Kit.box(s, Vector3(iw, hh, t), Vector3(cx, yc, IZ1 + PLASTER * 0.5 + EPS), pm)
		Kit.box(s, Vector3(iw, hh, t), Vector3(cx, yc, IZ0 - PLASTER * 0.5 - EPS), pm)
		Kit.box(s, Vector3(t, hh, idp), Vector3(IX0 - PLASTER * 0.5 - EPS, yc, cz), pm)
		Kit.box(s, Vector3(t, hh, idp), Vector3(IX1 + PLASTER * 0.5 + EPS, yc, cz), pm)
	# Перекрытия: пол магазина — плитка, выше — паркет, сверху — кровля.
	var tiles := Mats.world(Color(0.84, 0.80, 0.70), {"pattern": Mats.PATTERN_TILES, "color2": Color(0.62, 0.58, 0.52), "scale": 1.2})
	var parquet := Mats.wood(Color(0.66, 0.44, 0.26))
	Kit.box(s, Vector3(w, 0.3, d), Vector3(cx, 0.15, cz), tiles)
	for k in [1, 2]:
		var L: float = LEVELS[k]
		Kit.box(s, Vector3(IX1 - IX0 + 0.1, SLAB, IZ1 - IZ0 + 0.1), Vector3(cx, L - SLAB * 0.5, cz), parquet)
	Kit.box(s, Vector3(IX1 - IX0 + 0.1, SLAB, IZ1 - IZ0 + 0.1), Vector3(cx, ROOF - SLAB * 0.5, cz), Mats.world(Color(0.33, 0.32, 0.31), {"noise": 0.15}))

	# Перегородки первого этажа: подъезд с лестницей отделён от магазина.
	var p0 := Mats.plaster(colors[0])
	_wall_z(s, -4.82, IZ0, IZ1, LEVELS[0], p0)
	_wall_x(s, 1.51, SW_X0, -4.84, LEVELS[0], p0)
	# Верхние этажи: клетка, три поперечные стены с проёмами.
	for k in [1, 2]:
		var L: float = LEVELS[k]
		var pm := Mats.plaster(colors[k])
		_wall_z(s, -4.94, IZ0, 1.57, L, pm)
		_wall_x(s, 1.51, SW_X0, -4.90, L, pm)
		for x in [-0.5, 5.5, 11.0]:
			_wall_z(s, x, IZ0, IZ1, L, pm)

	# Проёмы: всё вычитается одним набором после стен.
	var reveal := Mats.plaster(Color(0.92, 0.91, 0.87))
	for o in openings():
		Kit.box(s, o.size, o.pos, reveal, 0.0, CSGShape3D.OPERATION_SUBTRACTION)
	# Двери во внутренних стенах.
	for k in 3:
		var L: float = LEVELS[k]
		Kit.box(s, Vector3(1.2, 2.2, 0.5), Vector3(-5.8, L + 1.075, 1.51), reveal, 0.0, CSGShape3D.OPERATION_SUBTRACTION)
		if k > 0:
			for x in [-0.5, 5.5, 11.0]:
				Kit.box(s, Vector3(0.5, 2.2, 1.0), Vector3(x, L + 1.075, 3.9), reveal, 0.0, CSGShape3D.OPERATION_SUBTRACTION)
			# Проём в перекрытии над маршами.
			Kit.box(s, Vector3(SW_X1 - SW_X0 - 0.02, 0.5, FLIGHT_Z0 - SW_Z0 - 0.02),
				Vector3((SW_X0 + SW_X1) * 0.5, L - SLAB * 0.5, (SW_Z0 + FLIGHT_Z0) * 0.5), reveal, 0.0, CSGShape3D.OPERATION_SUBTRACTION)
	# Площадки, стенка между маршами и перила на верхнем этаже.
	var conc := Mats.concrete()
	for k in [0, 1]:
		var L: float = LEVELS[k]
		Kit.box(s, Vector3(SW_X1 - SW_X0 + 0.08, 0.2, FLIGHT_Z1 - SW_Z0 + 0.08), Vector3((SW_X0 + SW_X1) * 0.5, L + 1.4, (SW_Z0 + FLIGHT_Z1) * 0.5 - 0.04), conc)
	Kit.box(s, Vector3(0.1, LEVELS[2] + 1.0 - LEVELS[0], FLIGHT_Z0 - FLIGHT_Z1 + 0.06),
		Vector3(-6.8, (LEVELS[0] + LEVELS[2] + 1.0) * 0.5, (FLIGHT_Z0 + FLIGHT_Z1) * 0.5 - 0.03), conc)
	Kit.box(s, Vector3(-6.85 - SW_X0, 1.0, 0.08), Vector3((SW_X0 - 6.85) * 0.5, LEVELS[2] + 0.5, 0.0), Mats.metal(Color(0.3, 0.22, 0.16)))


## Стена вдоль оси Z (поперечная), толщина 0,12, на один этаж.
static func _wall_z(s: Node, x: float, z0: float, z1: float, L: float, m: Material) -> void:
	Kit.box(s, Vector3(0.12, CLEAR + 2.0 * EPS, z1 - z0 + 2.0 * EPS), Vector3(x, L + CLEAR * 0.5, (z0 + z1) * 0.5), m)


static func _wall_x(s: Node, z: float, x0: float, x1: float, L: float, m: Material) -> void:
	Kit.box(s, Vector3(x1 - x0 + 2.0 * EPS, CLEAR + 2.0 * EPS, 0.12), Vector3((x0 + x1) * 0.5, L + CLEAR * 0.5, z), m)


## Окна и двери фасадов: [{size, pos, kind, facade, w, h}]
static func openings() -> Array:
	var out := []
	var add := func(facade: String, along: float, y0: float, y1: float, width: float, kind: String) -> void:
		if kind == "door" or kind == "shopdoor":
			y0 -= EPS
		var h := y1 - y0
		var o := {"kind": kind, "facade": facade, "w": width, "h": h, "along": along, "y0": y0}
		match facade:
			"S":
				o.size = Vector3(width, h, 1.0); o.pos = Vector3(along, y0 + h * 0.5, Z1 - 0.2)
			"N":
				o.size = Vector3(width, h, 1.0); o.pos = Vector3(along, y0 + h * 0.5, Z0 + 0.2)
			"W":
				o.size = Vector3(1.0, h, width); o.pos = Vector3(X0 + 0.2, y0 + h * 0.5, along)
		out.append(o)
	var L0: float = LEVELS[0]
	add.call("S", -6.8, L0, L0 + 2.2, 1.2, "door")
	add.call("S", 0.7, L0, L0 + 2.2, 1.4, "shopdoor")
	for x in [-2.4, 3.8, 7.8, 11.8]:
		add.call("S", x, 1.0, 2.7, 2.8, "shop")
	for x in [2.5, 6.5, 10.5, 14.5]:
		add.call("N", x, 1.9, 2.7, 1.6, "window")
	add.call("W", 4.0, 1.0, 2.4, 1.2, "window")
	for k in [1, 2]:
		var L: float = LEVELS[k]
		for x in [-7.2, -2.8, 1.0, 3.8, 7.0, 9.8, 12.8, 15.4]:
			add.call("S", x, L + 0.85, L + 2.35, 1.3, "window")
		for x in [1.0, 3.8, 7.0, 9.8, 12.8, 15.4]:
			add.call("N", x, L + 0.85, L + 2.35, 1.3, "window")
		add.call("W", 4.0, L + 0.85, L + 2.35, 1.3, "window")
		add.call("W", -2.0, L + 0.85, L + 2.35, 1.3, "window")
	for k in [0, 1]:
		var y: float = LEVELS[k] + 1.5
		add.call("N", -6.8, y + 0.9, y + 2.0, 1.2, "window")
	return out


# --- Земля, улица, береза -------------------------------------------------------

static func _ground(c: CSGCombiner3D) -> void:
	Kit.box(c, Vector3(2.0 * _r + 4.0, 0.4, 2.0 * _r + 4.0), Vector3(0, -0.2, 0), Mats.asphalt())
	Kit.box(c, Vector3(40.0, 0.12, 2.0), Vector3(4.0, 0.06, 8.0), Mats.paving())
	Kit.box(c, Vector3(40.0, 0.16, 0.22), Vector3(4.0, 0.08, 9.1), Mats.concrete())
	var white := Mats.paint(Color(0.93, 0.93, 0.90))
	for i in 6:
		Kit.box(c, Vector3(0.45, 0.014, 1.9), Vector3(-4.2 + i * 0.9, 0.007, 10.3), white)


static func _birch(c: CSGCombiner3D) -> void:
	var bark := Mats.world(Color(0.92, 0.90, 0.85), {"noise": 0.25})
	var leaves := Mats.world(Color(0.48, 0.64, 0.27), {"noise": 0.2, "rough": 0.9})
	var p := Vector3(-4.8, 0, 8.25)
	Kit.cyl(c, 0.15, 6.6, p + Vector3(0, 3.3, 0), bark, 10)
	Kit.sphere(c, 1.0, p + Vector3(0, 6.1, 0), leaves, Vector3(1.8, 2.2, 1.8), CSGShape3D.OPERATION_UNION, 14)
	Kit.sphere(c, 1.0, p + Vector3(0.7, 4.9, 0.6), leaves, Vector3(1.3, 1.4, 1.3), CSGShape3D.OPERATION_UNION, 12)
	Kit.sphere(c, 1.0, p + Vector3(-0.6, 5.2, -0.6), leaves, Vector3(1.2, 1.3, 1.2), CSGShape3D.OPERATION_UNION, 12)


# --- Магазин --------------------------------------------------------------------

const SHELF_ROWS := [-2.4, 0.2, 2.8]
const SHELF_SPANS := [[-3.8, 0.8], [2.6, 11.8]]
const SHELF_BOARDS := [0.45, 0.95, 1.45]


static func _shop(c: CSGCombiner3D) -> void:
	var L: float = LEVELS[0]
	var shelf := Mats.paint(Color(0.82, 0.84, 0.86))
	var dark := Mats.paint(Color(0.30, 0.32, 0.36))
	for z in SHELF_ROWS:
		for span in SHELF_SPANS:
			var x0: float = span[0]
			var x1: float = span[1]
			var len := x1 - x0
			var xc := (x0 + x1) * 0.5
			Kit.box(c, Vector3(len, 1.8, 0.04), Vector3(xc, L + 0.9, z), dark)
			Kit.box(c, Vector3(len, 0.12, 0.5), Vector3(xc, L + 0.06, z), dark)
			for h in SHELF_BOARDS:
				Kit.box(c, Vector3(len, 0.035, 0.5), Vector3(xc, L + h, z), shelf)
			Kit.box(c, Vector3(len, 0.035, 0.5), Vector3(xc, L + 1.85, z), shelf)
			for x in [x0, x1]:
				Kit.box(c, Vector3(0.04, 1.86, 0.5), Vector3(x, L + 0.93, z), dark)
	# Холодильники вдоль северной стены.
	Kit.box(c, Vector3(9.8, 1.9, 0.7), Vector3(1.1, L + 0.95, -4.2), Mats.paint(Color(0.92, 0.93, 0.94)))
	Kit.box(c, Vector3(9.6, 1.4, 0.03), Vector3(1.1, L + 1.05, -3.84), Mats.world(Color(0.55, 0.75, 0.85), {"emission": 0.35, "rough": 0.1, "noise": 0.0}))
	# Касса.
	Kit.box(c, Vector3(2.3, 1.0, 0.8), Vector3(-2.65, L + 0.5, 5.0), Mats.wood(Color(0.55, 0.36, 0.22)))
	Kit.box(c, Vector3(0.45, 0.25, 0.38), Vector3(-2.0, L + 1.13, 5.0), Mats.paint(Color(0.25, 0.25, 0.28)))
	Kit.box(c, Vector3(0.38, 0.12, 0.3), Vector3(-3.2, L + 1.06, 5.0), Mats.paint(Color(0.85, 0.85, 0.82)))
	# Почтовые ящики в подъезде.
	Kit.box(c, Vector3(0.25, 0.8, 1.6), Vector3(IX0 + 0.13, L + 1.5, 3.8), Mats.paint(Color(0.22, 0.40, 0.62)))


# --- Квартиры -------------------------------------------------------------------

static func _apartment(c: CSGCombiner3D, k: int) -> void:
	var L: float = LEVELS[k]
	var wood := Mats.wood(Color(0.56, 0.38, 0.24))
	var light_wood := Mats.wood(Color(0.78, 0.62, 0.42))
	var white := Mats.paint(Color(0.93, 0.93, 0.91))
	# Кухня в общей комнате у лестницы.
	Kit.box(c, Vector3(0.6, 0.9, 2.6), Vector3(-0.86, L + 0.45, -2.6), light_wood if k == 1 else white)
	Kit.box(c, Vector3(0.62, 0.04, 2.62), Vector3(-0.86, L + 0.92, -2.6), Mats.paint(Color(0.3, 0.3, 0.32)))
	Kit.box(c, Vector3(0.35, 0.7, 2.6), Vector3(-0.73, L + 1.95, -2.6), light_wood if k == 1 else white)
	Kit.box(c, Vector3(0.6, 0.88, 0.6), Vector3(-0.86, L + 0.44, -0.9), white)
	Kit.box(c, Vector3(0.62, 1.8, 0.62), Vector3(-4.3, L + 0.9, -4.15), white)
	Kit.box(c, Vector3(1.2, 0.05, 0.8), Vector3(-2.6, L + 0.75, 4.2), wood)
	for leg in [Vector2(-3.1, 3.9), Vector2(-2.1, 3.9), Vector2(-3.1, 4.5), Vector2(-2.1, 4.5)]:
		Kit.box(c, Vector3(0.05, 0.72, 0.05), Vector3(leg.x, L + 0.36, leg.y), wood)
	for st in [Vector2(-2.6, 3.4), Vector2(-2.6, 5.0)]:
		Kit.box(c, Vector3(0.4, 0.45, 0.4), Vector3(st.x, L + 0.225, st.y), Mats.paint(Color(0.75, 0.25, 0.22)))
	# Комната: x от -0,5 до 5,5.
	if k == 1:
		Kit.box(c, Vector3(2.0, 0.45, 1.6), Vector3(2.4, L + 0.225, -3.7), wood)
		Kit.box(c, Vector3(1.9, 0.12, 1.5), Vector3(2.4, L + 0.51, -3.7), Mats.paint(Color(0.30, 0.42, 0.70)))
		Kit.box(c, Vector3(0.8, 0.1, 0.4), Vector3(2.4, L + 0.62, -4.25), white)
		Kit.box(c, Vector3(2.0, 0.9, 0.08), Vector3(2.4, L + 0.6, -4.54), wood)
		Kit.box(c, Vector3(0.6, 2.0, 1.2), Vector3(5.1, L + 1.0, 5.6), wood)
		Kit.box(c, Vector3(2.4, 0.02, 1.7), Vector3(2.4, L + 0.01, 0.8), Mats.world(Color(0.66, 0.20, 0.22), {"pattern": Mats.PATTERN_TILES, "color2": Color(0.88, 0.72, 0.30), "scale": 4.0}))
		Kit.box(c, Vector3(0.45, 0.5, 0.4), Vector3(0.9, L + 0.25, -4.2), wood)
	else:
		Kit.box(c, Vector3(1.6, 0.4, 0.85), Vector3(1.4, L + 0.2, -4.0), light_wood)
		Kit.box(c, Vector3(1.5, 0.1, 0.8), Vector3(1.4, L + 0.45, -4.0), Mats.paint(Color(0.90, 0.55, 0.25)))
		Kit.box(c, Vector3(1.1, 0.05, 0.6), Vector3(4.6, L + 0.75, -4.1), light_wood)
		Kit.box(c, Vector3(1.05, 0.7, 0.55), Vector3(4.6, L + 0.36, -4.1), light_wood)
		Kit.box(c, Vector3(0.5, 0.4, 0.4), Vector3(3.0, L + 0.2, 4.8), Mats.paint(Color(0.2, 0.55, 0.85)))
		Kit.box(c, Vector3(0.3, 1.6, 1.2), Vector3(-0.29, L + 0.8, 1.6), light_wood)
		Kit.cyl(c, 1.0, 0.02, Vector3(2.6, L + 0.01, 0.9), Mats.world(Color(0.95, 0.80, 0.30), {"pattern": Mats.PATTERN_TILES, "color2": Color(0.30, 0.65, 0.55), "scale": 3.0}), 24)
	# Комната: x от 5,5 до 11 — разрезана объёмом.
	if k == 1:
		Kit.box(c, Vector3(2.2, 0.45, 0.9), Vector3(8.2, L + 0.225, -3.9), Mats.paint(Color(0.45, 0.30, 0.22)))
		Kit.box(c, Vector3(2.2, 0.5, 0.2), Vector3(8.2, L + 0.7, -4.35), Mats.paint(Color(0.45, 0.30, 0.22)))
		Kit.box(c, Vector3(1.2, 0.05, 1.2), Vector3(8.0, L + 0.75, 0.6), wood)
		Kit.box(c, Vector3(0.12, 0.72, 0.12), Vector3(8.0, L + 0.36, 0.6), wood)
		Kit.box(c, Vector3(1.4, 0.5, 0.45), Vector3(8.2, L + 0.25, 6.2), wood)
		Kit.box(c, Vector3(0.9, 0.6, 0.12), Vector3(8.2, L + 0.8, 6.3), Mats.paint(Color(0.1, 0.1, 0.12)))
		# Пианино стояло на границе — от него осталась половина.
		Kit.box(c, Vector3(1.5, 1.3, 0.6), Vector3(10.4, L + 0.65, 3.0), Mats.world(Color(0.08, 0.07, 0.07), {"rough": 0.2, "noise": 0.02}))
		Kit.box(c, Vector3(1.4, 0.06, 0.25), Vector3(10.4, L + 0.75, 3.38), white)
	else:
		Kit.box(c, Vector3(2.0, 2.2, 0.35), Vector3(8.0, L + 1.1, -4.38), wood)
		Kit.box(c, Vector3(2.0, 0.45, 0.85), Vector3(7.6, L + 0.225, 0.2), Mats.paint(Color(0.30, 0.45, 0.40)))
		Kit.box(c, Vector3(0.85, 0.5, 0.85), Vector3(6.2, L + 0.25, 2.2), Mats.paint(Color(0.30, 0.45, 0.40)))
		# Обеденный стол, разрезанный по дуге.
		Kit.box(c, Vector3(1.8, 0.05, 0.9), Vector3(10.3, L + 0.75, 1.6), light_wood)
		for leg in [Vector2(9.5, 1.25), Vector2(9.5, 1.95), Vector2(11.1, 1.25), Vector2(11.1, 1.95)]:
			Kit.box(c, Vector3(0.06, 0.72, 0.06), Vector3(leg.x, L + 0.36, leg.y), light_wood)


# --- Лестница -------------------------------------------------------------------

static func _stairs(node: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 10
	var rise := 1.5 / steps
	var run := (FLIGHT_Z0 - FLIGHT_Z1) / steps
	for k in [0, 1]:
		var L: float = LEVELS[k]
		for j in steps:
			var top_a := L + (j + 1) * rise
			Kit.st_box(st, Vector3(LANE_A, top_a - 0.15, FLIGHT_Z0 - (j + 0.5) * run), Vector3(1.6, 0.3, run + 0.01))
			var top_b := L + 1.5 + (j + 1) * rise
			Kit.st_box(st, Vector3(LANE_B, top_b - 0.15, FLIGHT_Z1 + (j + 0.5) * run), Vector3(1.6, 0.3, run + 0.01))
		Kit.ramp(node, Vector3(LANE_A, L, FLIGHT_Z0 + 0.05), Vector3(LANE_A, L + 1.5, FLIGHT_Z1), 1.6)
		Kit.ramp(node, Vector3(LANE_B, L + 1.5, FLIGHT_Z1), Vector3(LANE_B, L + 3.0, FLIGHT_Z0 + 0.05), 1.6)
	var mi := MeshInstance3D.new()
	mi.name = "Stairs"
	mi.mesh = st.commit()
	mi.material_override = Mats.world(Color(0.62, 0.60, 0.57), {"noise": 0.1})
	node.add_child(mi)


# --- Стёкла, рамы, двери --------------------------------------------------------

static func _windows(node: Node3D) -> void:
	var frames := SurfaceTool.new()
	frames.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glass := SurfaceTool.new()
	glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any_glass := false
	for o in openings():
		if o.kind == "door" or o.kind == "shopdoor":
			continue
		var w: float = o.w
		var h: float = o.h
		var y0: float = o.y0
		var along: float = o.along
		var basis := Basis.IDENTITY
		var center: Vector3
		var ends: Array
		match o.facade:
			"S":
				center = Vector3(along, y0 + h * 0.5, Z1 - 0.12)
				ends = [Vector2(along - w * 0.5, Z1), Vector2(along + w * 0.5, Z1)]
			"N":
				center = Vector3(along, y0 + h * 0.5, Z0 + 0.12)
				ends = [Vector2(along - w * 0.5, Z0), Vector2(along + w * 0.5, Z0)]
			"W":
				center = Vector3(X0 + 0.12, y0 + h * 0.5, along)
				basis = Basis(Vector3.UP, PI * 0.5)
				ends = [Vector2(X0, along - w * 0.5), Vector2(X0, along + w * 0.5)]
		if not (_inside(ends[0], 0.05) and _inside(ends[1], 0.05)):
			continue
		any_glass = true
		Kit.st_box(glass, center, Vector3(w - 0.04, h - 0.04, 0.03), basis)
		Kit.st_box(frames, center, Vector3(0.06, h, 0.08), basis)
		Kit.st_box(frames, center + Vector3(0, h * 0.18, 0), Vector3(w, 0.06, 0.08), basis)
		var out := Vector3(0, 0, 0.16) if o.facade == "S" else (Vector3(0, 0, -0.16) if o.facade == "N" else Vector3(-0.16, 0, 0))
		Kit.st_box(frames, Vector3(center.x, y0 - 0.02, center.z) + out, Vector3(w + 0.1, 0.05, 0.3), basis)
	if any_glass:
		var gm := MeshInstance3D.new()
		gm.mesh = glass.commit()
		gm.material_override = Mats.world(Color(0.22, 0.36, 0.42), {"rough": 0.08, "metal": 0.4, "noise": 0.03})
		node.add_child(gm)
		var fm := MeshInstance3D.new()
		fm.mesh = frames.commit()
		fm.material_override = Mats.paint(Color(0.94, 0.94, 0.92))
		node.add_child(fm)
	# Открытые двери: подъезд и магазин.
	var door := Kit.mesh_box(node, Vector3(1.15, 2.15, 0.06), Vector3(0, 0, 0), Mats.paint(Color(0.45, 0.28, 0.18)))
	door.position = Vector3(-7.4 + 0.05, LEVELS[0] + 1.08, Z1 + 0.55)
	door.rotation.y = deg_to_rad(80.0)
	door.position.x += 0.0
	var sdoor := Kit.mesh_box(node, Vector3(1.35, 2.15, 0.05), Vector3(0, 0, 0), Mats.world(Color(0.30, 0.44, 0.50), {"rough": 0.1, "metal": 0.4}))
	sdoor.position = Vector3(0.0 + 0.05, LEVELS[0] + 1.08, Z1 + 0.66)
	sdoor.rotation.y = deg_to_rad(-80.0)


# --- Вывески, козырёк, фонарь, скамейка ----------------------------------------

static func _facade_details(node: Node3D) -> void:
	var white := Mats.paint(Color(0.95, 0.95, 0.93))
	Kit.mesh_box(node, Vector3(5.6, 0.8, 0.1), Vector3(1.8, 3.0, Z1 + 0.06), white)
	Kit.label(node, "ПРОДУКТЫ", Vector3(1.8, 3.0, Z1 + 0.115), 0.0, 120, Color(0.80, 0.10, 0.10))
	Kit.mesh_box(node, Vector3(2.3, 0.42, 0.01), Vector3(3.8, 2.25, Z1 - 0.1), white)
	Kit.label(node, "Довольный клиент —\nнаша гарантия!", Vector3(3.8, 2.25, Z1 - 0.09), 0.0, 22, Color(0.70, 0.12, 0.10))
	# Козырёк и табличка подъезда.
	Kit.mesh_box(node, Vector3(2.0, 0.12, 1.1), Vector3(-6.8, 2.75, Z1 + 0.55), Mats.concrete())
	Kit.mesh_box(node, Vector3(1.1, 0.26, 0.03), Vector3(-6.8, 2.5, Z1 + 0.02), Mats.paint(Color(0.20, 0.36, 0.60)))
	Kit.label(node, "Подъезд 1 · кв. 1–12", Vector3(-6.8, 2.5, Z1 + 0.04), 0.0, 20, Color(0.95, 0.95, 0.95))
	Kit.mesh_box(node, Vector3(1.0, 0.3, 0.03), Vector3(-8.0, 3.9, Z1 + 0.02), Mats.paint(Color(0.18, 0.32, 0.58)))
	Kit.label(node, "ул. Садовая, 14", Vector3(-8.0, 3.9, Z1 + 0.04), 0.0, 22, Color(0.96, 0.96, 0.96))
	# Уличный фонарь.
	var post := Mats.metal(Color(0.35, 0.37, 0.38))
	var lp := Vector3(4.0, 0.12, 8.7)
	var pm := CylinderMesh.new()
	pm.top_radius = 0.07
	pm.bottom_radius = 0.11
	pm.height = 5.4
	var pmi := MeshInstance3D.new()
	pmi.mesh = pm
	pmi.material_override = post
	pmi.position = lp + Vector3(0, 2.7, 0)
	node.add_child(pmi)
	Kit.mesh_box(node, Vector3(0.08, 0.08, 1.2), lp + Vector3(0, 5.3, 0.5), post)
	Kit.mesh_box(node, Vector3(0.3, 0.12, 0.5), lp + Vector3(0, 5.22, 1.0), Mats.glow(Color(1.0, 0.86, 0.6), 3.0))
	Kit.lamp_light(node, lp + Vector3(0, 5.0, 0.9), Color(1.0, 0.82, 0.55), 2.2, 11.0)
	MinigolfFragment._pole_collision(node, lp, 0.13, 5.0)
	# Скамейка и урна у магазина.
	var bench := Node3D.new()
	node.add_child(bench)
	bench.position = Vector3(-2.6, 0.12, 8.4)
	bench.rotation.y = PI
	var wood := Mats.wood(Color(0.55, 0.36, 0.22))
	Kit.mesh_box(bench, Vector3(1.8, 0.07, 0.5), Vector3(0, 0.45, 0), wood)
	Kit.mesh_box(bench, Vector3(1.8, 0.4, 0.06), Vector3(0, 0.75, -0.24), wood)
	for sx in [-0.8, 0.8]:
		Kit.mesh_box(bench, Vector3(0.06, 0.45, 0.5), Vector3(sx, 0.22, 0), Mats.metal())
	MinigolfFragment._box_collision(node, Vector3(1.8, 0.9, 0.6), bench.position + Vector3(0, 0.45, 0), PI)
	var bin := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.24
	bm.bottom_radius = 0.2
	bm.height = 0.75
	bin.mesh = bm
	bin.material_override = Mats.paint(Color(0.30, 0.32, 0.34))
	bin.position = Vector3(2.0, 0.12 + 0.375, 7.5)
	node.add_child(bin)
	MinigolfFragment._pole_collision(node, Vector3(2.0, 0.12, 7.5), 0.25, 0.75)
	# Крыша: вентиляция и антенна.
	Kit.mesh_box(node, Vector3(1.2, 0.9, 0.8), Vector3(-3.0, ROOF + 0.45, -2.0), Mats.brick())
	var ant := Node3D.new()
	node.add_child(ant)
	ant.position = Vector3(2.0, ROOF, -1.0)
	Kit.mesh_box(ant, Vector3(0.05, 2.2, 0.05), Vector3(0, 1.1, 0), post)
	for i in 4:
		Kit.mesh_box(ant, Vector3(1.2 - i * 0.2, 0.03, 0.03), Vector3(0, 1.4 + i * 0.22, 0), post)


# --- Товары на полках (один MultiMesh) -----------------------------------------

static func _products(node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1414
	var palette := [Color(0.85, 0.15, 0.12), Color(0.98, 0.78, 0.15), Color(0.15, 0.42, 0.78),
		Color(0.20, 0.62, 0.30), Color(0.95, 0.95, 0.92), Color(0.95, 0.50, 0.12),
		Color(0.55, 0.25, 0.55), Color(0.40, 0.28, 0.18)]
	var items := []
	var L: float = LEVELS[0]
	for z in SHELF_ROWS:
		for span in SHELF_SPANS:
			for h in SHELF_BOARDS + [1.85]:
				for side in [-1.0, 1.0]:
					var x: float = span[0] + 0.06
					var group_color: Color = palette[rng.randi() % palette.size()]
					var group_left := rng.randi_range(3, 8)
					var w := rng.randf_range(0.08, 0.2)
					var hh := rng.randf_range(0.12, 0.3)
					while x < span[1] - 0.15:
						if group_left <= 0:
							group_color = palette[rng.randi() % palette.size()]
							group_left = rng.randi_range(3, 8)
							w = rng.randf_range(0.08, 0.2)
							hh = rng.randf_range(0.12, 0.3)
						var p := Vector3(x + w * 0.5, L + h + 0.02 + hh * 0.5, z + side * 0.13)
						if _inside(Vector2(p.x, p.z), 0.15) and rng.randf() > 0.06:
							items.append([p, Vector3(w, hh, 0.18), group_color])
						x += w + 0.015
						group_left -= 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	mm.mesh = bm
	mm.instance_count = items.size()
	for i in items.size():
		var it: Array = items[i]
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(it[1]), it[0]))
		mm.set_instance_custom_data(i, it[2])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Mats.world(Color(1, 1, 1), {"instance": true, "noise": 0.05, "rough": 0.5})
	node.add_child(mmi)


static func _lights(node: Node3D) -> void:
	Kit.lamp_light(node, Vector3(3.0, LEVELS[0] + 2.5, 0.4), Color(0.86, 0.94, 1.0), 1.3, 10.0)
	Kit.lamp_light(node, Vector3(-6.8, LEVELS[0] + 2.4, 4.0), Color(1.0, 0.85, 0.6), 0.8, 6.0)
	for k in [1, 2]:
		var L: float = LEVELS[k]
		Kit.lamp_light(node, Vector3(2.5, L + 2.4, 0.4), Color(1.0, 0.80, 0.52), 1.0, 7.0)
		Kit.lamp_light(node, Vector3(8.0, L + 2.4, 0.4), Color(1.0, 0.80, 0.52), 1.0, 7.0)
		Kit.lamp_light(node, Vector3(-2.8, L + 2.4, 2.0), Color(1.0, 0.86, 0.62), 0.8, 6.0)
