extends SceneTree
## Проверки мира без графики:
##   godot --headless --path game --script res://tests/run_tests.gd
## Код выхода 0 — всё прошло.

var failures := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		failures += 1


func _init() -> void:
	print("Проверки мира")
	var gen := WorldGen.new(731)
	var gen2 := WorldGen.new(731)
	var other := WorldGen.new(732)

	# 1. Детерминизм: один seed — один мир, другой seed — другой.
	var same := true
	var differs := false
	for i in 200:
		var x := (i * 37.3) - 3000.0
		var z := (i * 91.7) - 5000.0
		if gen.base_height(x, z) != gen2.base_height(x, z):
			same = false
		if absf(gen.base_height(x, z) - other.base_height(x, z)) > 0.01:
			differs = true
	check(same, "одинаковый seed даёт одинаковый рельеф")
	check(differs, "другой seed даёт другой рельеф")

	# 2. Швы чанков: общие края совпадают точно, в любом порядке сборки.
	var worst := 0.0
	for key in [Vector2i(0, 0), Vector2i(-3, 5), Vector2i(17, -9)]:
		var a := TerrainBuilder.build(gen, key.x, key.y)
		var right := TerrainBuilder.build(gen, key.x + 1, key.y)
		var down := TerrainBuilder.build(gen, key.x, key.y + 1)
		var n := TerrainBuilder.RES + 1
		for j in n:
			worst = maxf(worst, absf(a.verts[j * n + n - 1].y - right.verts[j * n].y))
			worst = maxf(worst, (a.normals[j * n + n - 1] - right.normals[j * n]).length())
			worst = maxf(worst, absf(a.verts[(n - 1) * n + j].y - down.verts[j].y))
	check(worst < 1e-5, "края соседних чанков совпадают (высота и нормали), расхождение %s" % str(worst))

	# 3. Объёмы: старт и дом на ровном сухом месте, не пересекаются.
	var g: Dictionary = gen.fixed_volumes[0]
	var h: Dictionary = gen.fixed_volumes[1]
	check(g.type == "minigolf" and h.type == "house", "стартовые объёмы — минигольф и дом")
	check(g.base_y > WorldGen.WATER_LEVEL + 1.0 and h.base_y > WorldGen.WATER_LEVEL + 1.0, "стартовые объёмы на сухом месте")
	check(g.center.distance_to(h.center) > g.radius + h.radius + 5.0, "минигольф и дом не пересекаются")
	var vols := gen.volumes_near(0, 0, 1500)
	var overlap := false
	for i in vols.size():
		for j in range(i + 1, vols.size()):
			if vols[i].center.distance_to(vols[j].center) < vols[i].radius + vols[j].radius:
				overlap = true
	check(not overlap, "объёмы в радиусе 1,5 км не пересекаются (%d шт.)" % vols.size())
	var bad_r := false
	for v in vols:
		if v.radius < 5.0 or v.radius > 40.0:
			bad_r = true
	check(not bad_r, "радиусы объёмов в пределах 5–40 м")
	var ids := {}
	var dup := false
	for v in gen.volumes_near(0, 0, 1500) + gen.volumes_near(200, 200, 1500):
		if ids.has(v.id) and ids[v.id] != v.center:
			dup = true
		ids[v.id] = v.center
	check(not dup, "объём с одним id всегда в одном месте")

	# 4. Вода: есть реки, есть броды, внутри объёмов воды нет.
	var water := 0
	var ford := 0
	for i in 4000:
		var x := fmod(i * 53.1, 2400.0) - 1200.0
		var z := floorf(i * 53.1 / 2400.0) * 20.0 - 900.0
		var d := gen.water_depth(x, z)
		if d > 0.0:
			water += 1
			if d < 0.5:
				ford += 1
	check(water > 20, "в окрестностях есть вода (%d точек из 4000)" % water)
	check(ford > 0, "есть мелкие места — броды (%d)" % ford)
	check(gen.water_depth(g.center.x, g.center.y) == 0.0, "внутри объёма воды нет")
	check(is_equal_approx(gen.surface_height(g.center.x + 3, g.center.y), g.base_y), "внутри объёма земля на уровне фрагмента")

	print("Итого: ", "всё прошло" if failures == 0 else "%d ошибок" % failures)
	quit(1 if failures > 0 else 0)
