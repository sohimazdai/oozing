extends SceneTree
## Проверка дома: проёмы дверей свободны для коллизии, лестница ведёт наверх.
##   godot --headless --path game --script res://tests/test_house.gd

var node: Node3D
var n := 0
var failures := 0


func _init() -> void:
	var gen := WorldGen.new(731)
	var vol: Dictionary = gen.fixed_volumes[1]
	node = Node3D.new()
	root.add_child(node)
	node.position = Vector3(vol.center.x, vol.base_y, vol.center.y)
	FragmentFactory.populate(node, vol, gen)


func check(cond: bool, what: String) -> void:
	print("  ok   " if cond else "  FAIL ", what)
	if not cond:
		failures += 1


func _ray(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(node.to_global(a), node.to_global(b)))


func _physics_process(_d: float) -> bool:
	n += 1
	if n < 5:
		return false
	print("Проверки дома")
	var space := node.get_world_3d().direct_space_state
	# Дверь подъезда (x −6,8, ширина 1,2) и дверь магазина (x 0,7, ширина 1,4).
	for door in [[-6.8, 1.2, "подъезд"], [0.7, 1.4, "магазин"]]:
		var blocked := 0
		for dx in [-0.4, 0.0, 0.4]:
			for y in [0.6, 1.2, 1.8, 2.3]:
				var x: float = door[0] + dx * door[1] / 1.2
				if not _ray(space, Vector3(x, y, 7.6), Vector3(x, y, 5.6)).is_empty():
					blocked += 1
		check(blocked == 0, "дверь «%s» свободна (заблокировано лучей: %d из 12)" % [door[2], blocked])
	# Внутренняя дверь подъезда к лестнице.
	var inner := 0
	for y in [0.6, 1.2, 1.8]:
		if not _ray(space, Vector3(-5.8, y, 2.4), Vector3(-5.8, y, 0.6)).is_empty():
			inner += 1
	check(inner == 0, "дверь к лестнице свободна")
	# Площадка лестницы на высоте 1,8 м над землёй фрагмента.
	var land := _ray(space, Vector3(-7.7, 4.0, -3.5), Vector3(-7.7, -1.0, -3.5))
	check(not land.is_empty() and absf(node.to_local(land.position).y - 1.8) < 0.05, "площадка первого марша на высоте 1,8 м")
	# Пол второго этажа есть, над лестницей — проём.
	var f2 := _ray(space, Vector3(2.0, 3.29 + 0.5, 0.0), Vector3(2.0, 2.0, 0.0))
	check(not f2.is_empty() and absf(node.to_local(f2.position).y - 3.3) < 0.05, "пол второго этажа на 3,3 м")
	var hole := _ray(space, Vector3(-7.7, 3.29 + 0.5, -1.0), Vector3(-7.7, 2.2, -1.0))
	check(hole.is_empty() or node.to_local(hole.position).y < 3.0, "над маршем в перекрытии есть проём")
	print("Итого: ", "всё прошло" if failures == 0 else "%d ошибок" % failures)
	quit(1 if failures > 0 else 0)
	return true
