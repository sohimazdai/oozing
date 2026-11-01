class_name FragmentFactory
extends RefCounted
## Собирает узел перенесённого фрагмента: стенку объёма и содержимое по типу.

const WALL_SHADER := preload("res://shaders/volume_wall.gdshader")


## Узел фрагмента уже должен быть в дереве: CSG и тела считают глобальные позиции.
static func populate(node: Node3D, vol: Dictionary, gen: WorldGen) -> void:
	node.add_child(build_wall(vol, gen))
	match vol.type:
		"minigolf": MinigolfFragment.build(node, vol)
		"house": HouseFragment.build(node, vol)
		"road": RandomFragments.road(node, vol)
		"shed": RandomFragments.shed(node, vol)
		"kiosk": RandomFragments.kiosk(node, vol)
		"field": RandomFragments.field(node, vol)
		"garages": RandomFragments.garages(node, vol)


## Цилиндрическая стенка: снизу — земной цоколь, сверху — срезанная порода Кромы.
static func build_wall(vol: Dictionary, gen: WorldGen) -> MeshInstance3D:
	var r: float = vol.radius
	var base: float = vol.base_y
	var c: Vector2 = vol.center
	var segs := int(clampf(r * 9.0, 48.0, 180.0))
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in segs + 1:
		var a := TAU * i / segs
		var dir := Vector3(cos(a), 0.0, sin(a))
		var t := gen.base_height(c.x + dir.x * (r + 0.35), c.y + dir.z * (r + 0.35))
		var top := maxf(t, base) + 0.03
		var bottom := minf(t, base) - 0.8
		verts.append(dir * r + Vector3(0, bottom - base, 0))
		verts.append(dir * r + Vector3(0, top - base, 0))
		normals.append(dir)
		normals.append(dir)
		uvs.append(Vector2(t, 0))
		uvs.append(Vector2(t, 0))
	for i in segs:
		var b0 := i * 2
		var t0 := b0 + 1
		var b1 := b0 + 2
		var t1 := b0 + 3
		# по часовой, если смотреть снаружи
		idx.append_array(PackedInt32Array([t0, b0, b1, t0, b1, t1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = WALL_SHADER
	mat.set_shader_parameter("base_y", base)
	var mi := MeshInstance3D.new()
	mi.name = "VolumeWall"
	mi.mesh = mesh
	mi.material_override = mat
	return mi
