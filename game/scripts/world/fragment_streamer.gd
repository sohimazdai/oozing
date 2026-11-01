class_name FragmentStreamer
extends Node3D
## Создаёт перенесённые фрагменты рядом с героем и убирает дальние.
## Заодно сообщает шейдеру рельефа, где вырезать землю Кромы.

const BUILD_DIST := 120.0
const FREE_DIST := 200.0

var gen: WorldGen
var chunks: ChunkStreamer
var sky: SkyRig
var focus: Node3D
var built := {}            # id -> Node3D
var _timer := 0.0
var _queue: Array[Dictionary] = []


func _init(p_gen: WorldGen, p_chunks: ChunkStreamer) -> void:
	gen = p_gen
	chunks = p_chunks


func _process(delta: float) -> void:
	if focus == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.4
		_refresh()
	if not _queue.is_empty():
		_build(_queue.pop_front())


func _refresh() -> void:
	var p := focus.global_position
	var near := gen.volumes_near(p.x, p.z, BUILD_DIST)
	var queued := {}
	for v in _queue:
		queued[v.id] = true
	for v in near:
		if not built.has(v.id) and not queued.has(v.id):
			_queue.append(v)
	_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return Vector2(p.x, p.z).distance_to(a.center) < Vector2(p.x, p.z).distance_to(b.center))
	for id in built.keys():
		var node: Node3D = built[id]
		var c := Vector2(node.global_position.x, node.global_position.z)
		if c.distance_to(Vector2(p.x, p.z)) > FREE_DIST:
			node.queue_free()
			built.erase(id)
	_update_terrain_cutouts(p)


func _build(v: Dictionary) -> void:
	var node := Node3D.new()
	node.name = "Fragment_" + str(v.id)
	add_child(node)
	node.global_position = Vector3(v.center.x, v.base_y, v.center.y)
	FragmentFactory.populate(node, v, gen)
	built[v.id] = node
	if sky:
		sky.refresh_lamps()
	_update_terrain_cutouts(focus.global_position)


## Какие фрагменты уже готовы (с их CSG и коллизией).
func is_built(id: String) -> bool:
	return built.has(id)


func _update_terrain_cutouts(p: Vector3) -> void:
	var vols: Array[Dictionary] = []
	for v in gen.volumes_near(p.x, p.z, 170.0):
		if built.has(v.id):
			vols.append(v)
	vols.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return Vector2(p.x, p.z).distance_to(a.center) < Vector2(p.x, p.z).distance_to(b.center))
	var arr: Array[Vector4] = []
	for v in vols:
		if arr.size() >= 16:
			break
		arr.append(Vector4(v.center.x, v.center.y, v.radius, 0.0))
	var count := arr.size()
	while arr.size() < 16:
		arr.append(Vector4(1e9, 1e9, 0.0, 0.0))
	chunks.terrain_mat.set_shader_parameter("volumes", arr)
	chunks.terrain_mat.set_shader_parameter("volume_count", count)
