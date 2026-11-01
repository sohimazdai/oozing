class_name ChunkStreamer
extends Node3D
## Подгружает чанки рельефа вокруг героя и выгружает дальние.
## Расчёт идёт в пуле рабочих потоков, узлы создаются в главном потоке
## небольшими порциями, чтобы не было рывков.

const CHUNK := TerrainBuilder.CHUNK
const LOAD_RADIUS := 3.2        # в чанках
const UNLOAD_RADIUS := 4.6
const MAX_TASKS := 6
const BUILDS_PER_FRAME := 2

var gen: WorldGen
var focus: Node3D

var chunks := {}            # Vector2i -> Node3D
var _tasks := {}            # Vector2i -> id задачи
var _results := {}          # Vector2i -> Dictionary
var _mutex := Mutex.new()

var terrain_mat: ShaderMaterial
var water_mat: ShaderMaterial
var _rock_mat: ShaderMaterial
var _tree_mat: ShaderMaterial


func _init(p_gen: WorldGen) -> void:
	gen = p_gen
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = preload("res://shaders/terrain.gdshader")
	terrain_mat.set_shader_parameter("water_level", WorldGen.WATER_LEVEL)
	water_mat = ShaderMaterial.new()
	water_mat.shader = preload("res://shaders/water.gdshader")
	_rock_mat = Mats.world(Color(1, 1, 1), {"instance": true, "noise": 0.12, "cutaway": false})
	_tree_mat = Mats.plant(0.004, true)


func _exit_tree() -> void:
	for key in _tasks:
		WorkerThreadPool.wait_for_task_completion(_tasks[key])
	_tasks.clear()


func focus_chunk() -> Vector2i:
	var p := focus.global_position if focus else Vector3.ZERO
	return Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))


## Готов ли рельеф вокруг точки (для безопасного старта героя).
func is_ready_at(p: Vector3) -> bool:
	return chunks.has(Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK)))


func loaded_count() -> int:
	return chunks.size()


func _process(_delta: float) -> void:
	if focus == null:
		return
	var fc := focus_chunk()
	var r := int(ceil(LOAD_RADIUS))
	var wanted: Array[Vector2i] = []
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if Vector2(dx, dz).length() <= LOAD_RADIUS:
				var key := fc + Vector2i(dx, dz)
				if not chunks.has(key) and not _tasks.has(key):
					wanted.append(key)
	wanted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - fc).length_squared() < (b - fc).length_squared())
	for key in wanted:
		if _tasks.size() >= MAX_TASKS:
			break
		_tasks[key] = WorkerThreadPool.add_task(_build_task.bind(key), false, "terrain chunk")

	# Забираем готовые результаты.
	var built := 0
	for key in _tasks.keys():
		if built >= BUILDS_PER_FRAME:
			break
		var id: int = _tasks[key]
		if WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
			_tasks.erase(key)
			_mutex.lock()
			var data: Dictionary = _results.get(key, {})
			_results.erase(key)
			_mutex.unlock()
			if not data.is_empty() and (key - fc).length() <= UNLOAD_RADIUS:
				_instantiate(data)
				built += 1

	# Выгружаем дальние.
	for key in chunks.keys():
		if Vector2(key - fc).length() > UNLOAD_RADIUS:
			chunks[key].queue_free()
			chunks.erase(key)


func _build_task(key: Vector2i) -> void:
	var data := TerrainBuilder.build(gen, key.x, key.y)
	_mutex.lock()
	_results[key] = data
	_mutex.unlock()


func _instantiate(data: Dictionary) -> void:
	var key: Vector2i = data.key
	var node := Node3D.new()
	node.name = "Chunk_%d_%d" % [key.x, key.y]
	add_child(node)
	node.position = Vector3(key.x * CHUNK, 0, key.y * CHUNK)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.verts
	arrays[Mesh.ARRAY_NORMAL] = data.normals
	arrays[Mesh.ARRAY_COLOR] = data.colors
	arrays[Mesh.ARRAY_INDEX] = TerrainBuilder.shared_indices()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = terrain_mat
	node.add_child(mi)

	# Коллизия: карта высот с шагом 1 м, центр — середина чанка.
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	hm.map_width = TerrainBuilder.COL_RES + 1
	hm.map_depth = TerrainBuilder.COL_RES + 1
	hm.map_data = data.col
	cs.shape = hm
	cs.position = Vector3(CHUNK * 0.5, 0, CHUNK * 0.5)
	body.add_child(cs)
	node.add_child(body)

	# Вода: одна плоскость на чанк, если дно где-то ниже уровня.
	if data.hmin < WorldGen.WATER_LEVEL + 0.05:
		var wm := PlaneMesh.new()
		wm.size = Vector2(CHUNK, CHUNK)
		wm.subdivide_width = 4
		wm.subdivide_depth = 4
		var wmi := MeshInstance3D.new()
		wmi.mesh = wm
		wmi.material_override = water_mat
		wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wmi.position = Vector3(CHUNK * 0.5, WorldGen.WATER_LEVEL, CHUNK * 0.5)
		node.add_child(wmi)

	_add_scatter(node, data.scatter)


func _add_scatter(node: Node3D, sc: Dictionary) -> void:
	var plant_kinds := {"grass": 0.10, "tall": 0.07, "fern": 0.06, "shrub": 0.02, "reed": 0.08}
	for kind in plant_kinds:
		var items: Array = sc[kind]
		if items.is_empty():
			continue
		var mmi := _multimesh(ScatterMeshes.get_mesh(kind), items)
		mmi.material_override = Mats.plant(plant_kinds[kind], kind == "tall")
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if kind in ["shrub", "tall"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mmi)

	# Камни: три формы, крупные получают коллизию.
	var by_shape := [[], [], []]
	for it in sc.rock:
		by_shape[it[4]].append(it)
	for s in 3:
		if by_shape[s].is_empty():
			continue
		var mmi := _multimesh(ScatterMeshes.get_mesh("rock%d" % s), by_shape[s])
		mmi.material_override = _rock_mat
		node.add_child(mmi)
	for it in sc.rock:
		var sz: float = it[2]
		if sz > 0.7:
			var b := StaticBody3D.new()
			var c := CollisionShape3D.new()
			var sph := SphereShape3D.new()
			sph.radius = 0.62 * sz
			c.shape = sph
			b.add_child(c)
			node.add_child(b)
			b.position = it[0] + Vector3(0, 0.15 * sz, 0)

	# Деревья: крона прозрачна, если заслоняет героя; ствол — препятствие.
	if not sc.tree.is_empty():
		var mmi := _multimesh(ScatterMeshes.get_mesh("tree"), sc.tree)
		mmi.material_override = _tree_mat
		node.add_child(mmi)
		for it in sc.tree:
			var b := StaticBody3D.new()
			var c := CollisionShape3D.new()
			var cap := CylinderShape3D.new()
			cap.radius = 0.25
			cap.height = 3.0
			c.shape = cap
			c.position = Vector3(0, 1.5, 0)
			b.add_child(c)
			node.add_child(b)
			b.position = it[0]


func _multimesh(mesh: Mesh, items: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		var it: Array = items[i]
		var s: float = it[2]
		var b := Basis(Vector3.UP, it[1]).scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, Transform3D(b, it[0]))
		mm.set_instance_custom_data(i, it[3])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	return mmi
