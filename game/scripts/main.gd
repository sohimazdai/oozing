extends Node
## Точка входа: мир Кромы, герой, камера, интерфейс.
##
## Сцена собирается кодом — так её проще читать и менять без редактора.
## Параметры командной строки (после «--») нужны для автоматических проверок:
##   --tour=папка   обойти контрольные точки и сохранить скриншоты
##   --frames=N     выйти через N кадров

const WORLD_SEED := 731

var gen: WorldGen
var view_container: SubViewportContainer
var view: SubViewport
var world_root: Node3D
var sky: SkyRig
var chunks: ChunkStreamer
var fragments: FragmentStreamer
var player: Player
var cam: IsoCamera
var hud: Hud

var pixel_level := 0
const PIXEL_LEVELS := [1, 3, 4, 6]

var _booted := false
var _boot_frames := 0
var _frame := 0
var _args := {}
var _tour: Array = []
var _tour_dir := ""
var _tour_wait := 0
var _place_id := ""


func _ready() -> void:
	_parse_args()
	_setup_input()
	gen = WorldGen.new(WORLD_SEED)
	# Главный узел и интерфейс работают и на паузе, мир — нет.
	process_mode = Node.PROCESS_MODE_ALWAYS

	view_container = SubViewportContainer.new()
	view_container.process_mode = Node.PROCESS_MODE_PAUSABLE
	view_container.stretch = true
	view_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(view_container)
	view = SubViewport.new()
	view.msaa_3d = Viewport.MSAA_4X
	view.positional_shadow_atlas_size = 2048
	view_container.add_child(view)
	world_root = Node3D.new()
	world_root.name = "World"
	view.add_child(world_root)

	sky = SkyRig.new()
	world_root.add_child(sky)
	chunks = ChunkStreamer.new(gen)
	chunks.name = "Terrain"
	world_root.add_child(chunks)
	fragments = FragmentStreamer.new(gen, chunks)
	fragments.name = "Fragments"
	fragments.sky = sky
	world_root.add_child(fragments)

	player = Player.new()
	player.name = "Cleaner"
	player.gen = gen
	world_root.add_child(player)
	player.global_position = gen.spawn_point() + Vector3(0, 0.5, 0)

	cam = IsoCamera.new()
	cam.target = player
	world_root.add_child(cam)
	cam.current = true
	cam.snap_to_target()
	player.cam = cam

	chunks.focus = player
	fragments.focus = player

	hud = Hud.new()
	add_child(hud)
	hud.set_hint("Загрузка мира…")
	RenderingServer.global_shader_parameter_set("roof_cut_y", 1.0e6)

	if _args.has("time"):
		sky.set_preset(int(_args.time), true)
	if _args.has("pixel"):
		_set_pixel(int(_args.pixel))
	if _args.has("width"):
		cam.width = float(_args.width)
		cam.size = cam.width
	if _args.has("tour"):
		_tour_dir = _args.tour
		_build_tour()
	if _args.has("autowalk"):
		var d: PackedStringArray = str(_args.autowalk).split(",")
		player.auto_walk = Vector3(float(d[0]), 0, float(d[1])).normalized()


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var s: String = a
		if s.begins_with("--"):
			var kv := s.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"


func _setup_input() -> void:
	_key("move_forward", [KEY_W, KEY_UP])
	_key("move_back", [KEY_S, KEY_DOWN])
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("run", [KEY_SHIFT])
	_key("sneak", [KEY_CTRL, KEY_C])
	_key("climb", [KEY_SPACE])
	_key("time_of_day", [KEY_T])
	_key("pixel_mode", [KEY_F2])
	_key("debug", [KEY_F3])
	_key("help", [KEY_F1])
	_key("pause", [KEY_ESCAPE])
	_key("quit", [KEY_Q])
	if not InputMap.has_action("aim"):
		InputMap.add_action("aim")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("aim", mb)


## Физические клавиши: работают при любой раскладке (в том числе русской).
func _key(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _process(_delta: float) -> void:
	_frame += 1
	if _args.has("verbose") and _frame % int(_args.get("every", "20")) == 0:
		print("frame %d  fps %d  booted %s  chunks %d  fragments %d  player %s" % [
			_frame, Engine.get_frames_per_second(), _booted, chunks.loaded_count(),
			fragments.built.size(), player.global_position])
	if not _booted:
		_boot()
	else:
		_update_world_state()
	if _args.has("frames") and _frame >= int(_args.frames) and _tour.is_empty():
		get_tree().quit()
	if _booted and not _tour.is_empty():
		_run_tour()


func _boot() -> void:
	var spawn := gen.spawn_point()
	if not chunks.is_ready_at(spawn) or not fragments.is_built("start_minigolf"):
		return
	_boot_frames += 1
	if _boot_frames < 8:
		return
	# Ставим героя на реальную поверхность фрагмента.
	var space := world_root.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(spawn + Vector3(0, 12, 0), spawn - Vector3(0, 12, 0))
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		player.global_position = hit.position + Vector3(0, 0.05, 0)
	player.frozen = false
	cam.snap_to_target()
	_booted = true
	hud.set_hint("")


func _update_world_state() -> void:
	var p := player.global_position
	var vol := gen.volume_at(p.x, p.z)
	# Внутри дома скрываем всё выше текущего этажа.
	if not vol.is_empty() and vol.type == "house":
		var rel: float = p.y - vol.base_y
		var k := floori((rel - 0.3 + 0.6) / 3.0)
		k = clampi(k, 0, 2)
		var cut_y: float = vol.base_y + 0.3 + (k + 1) * 3.0 - 0.32
		RenderingServer.global_shader_parameter_set("roof_cut_y", cut_y)
		RenderingServer.global_shader_parameter_set("roof_cut_area", Vector4(vol.center.x, vol.center.y, vol.radius + 0.5, 0))
		_set_labels_cut(cut_y, vol.center, vol.radius + 0.5)
	else:
		RenderingServer.global_shader_parameter_set("roof_cut_y", 1.0e6)
		_set_labels_cut(1.0e6, Vector2.ZERO, 0.0)
	var vid: String = vol.get("id", "")
	if vid != _place_id:
		_place_id = vid
		hud.show_place(vol.get("name", ""))
	hud.set_hint("Пробел — забраться" if player.can_climb else "")
	if hud.show_debug:
		var sector := Vector2i(floori(p.x / WorldGen.SECTOR), floori(p.z / WorldGen.SECTOR))
		hud.set_debug("x %.0f  z %.0f  высота %.1f м  ·  сектор %d:%d  ·  чанков %d  ·  фрагментов %d  ·  %s  ·  %d к/с" % [
			p.x, p.z, p.y, sector.x, sector.y, chunks.loaded_count(), fragments.built.size(),
			sky.current_name(), Engine.get_frames_per_second()])


var _labels_cut := INF


func _set_labels_cut(cut_y: float, c: Vector2, r: float) -> void:
	if cut_y == _labels_cut:
		return
	_labels_cut = cut_y
	for l in get_tree().get_nodes_in_group("labels"):
		var p: Vector3 = l.global_position
		l.visible = not (p.y > cut_y and Vector2(p.x, p.z).distance_to(c) < r)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().paused = not get_tree().paused
		hud.set_paused(get_tree().paused)
	elif event.is_action_pressed("quit") and get_tree().paused:
		get_tree().quit()
	elif event.is_action_pressed("time_of_day"):
		hud.toast(sky.next_preset())
	elif event.is_action_pressed("pixel_mode"):
		_set_pixel((pixel_level + 1) % PIXEL_LEVELS.size())
		hud.toast("Пиксельный режим: выкл." if pixel_level == 0 else "Пиксельный режим: ×%d" % PIXEL_LEVELS[pixel_level])
	elif event.is_action_pressed("help"):
		hud.toggle_help()
	elif event.is_action_pressed("debug"):
		hud.toggle_debug()


func _set_pixel(level: int) -> void:
	pixel_level = clampi(level, 0, PIXEL_LEVELS.size() - 1)
	var scale := maxf(1.0, DisplayServer.screen_get_scale()) if not OS.has_feature("headless") else 1.0
	var shrink := 1 if pixel_level == 0 else int(round(PIXEL_LEVELS[pixel_level] * scale))
	view_container.stretch_shrink = shrink
	view.msaa_3d = Viewport.MSAA_4X if pixel_level == 0 else Viewport.MSAA_DISABLED
	cam.pixel_snap = pixel_level > 0


# --- Автоматический обход для проверки (скриншоты) -----------------------------

func _build_tour() -> void:
	var g: Dictionary = gen.fixed_volumes[0]
	var h: Dictionary = gen.fixed_volumes[1]
	var gc: Vector2 = g.center
	var hc: Vector2 = h.center
	_tour = [
		{"name": "01_start", "pos": gen.spawn_point(), "width": 34.0},
		{"name": "02_start_wide", "pos": gen.spawn_point(), "width": 70.0},
		{"name": "03_dino", "pos": Vector3(gc.x - 2.0, g.base_y, gc.y - 2.0), "width": 22.0},
		{"name": "04_house", "pos": Vector3(hc.x + 9.0, h.base_y, hc.y + 12.0), "width": 40.0},
		{"name": "05_house_floor2", "pos": Vector3(hc.x + 3.0, h.base_y + 3.35, hc.y + 1.0), "width": 26.0},
		{"name": "06_house_shop", "pos": Vector3(hc.x + 2.0, h.base_y + 0.35, hc.y + 1.5), "width": 26.0},
		{"name": "07_night", "pos": gen.spawn_point(), "width": 34.0, "time": 3},
		{"name": "08_pixel", "pos": gen.spawn_point(), "width": 34.0, "time": 0, "pixel": 2},
	]
	var extra := 0
	for v in gen.volumes_near(gc.x, gc.y, 700.0):
		if v.id.begins_with("cell_") and extra < 5:
			_tour.append({"name": "1%d_%s" % [extra, v.type], "pos": Vector3(v.center.x + 1.0, v.base_y, v.center.y + 1.0), "width": 40.0, "pixel": 0})
			extra += 1
	_tour.append({"name": "20_river", "pos": _find_water_near(gc), "width": 50.0})
	if _args.has("only"):
		var keep: PackedStringArray = str(_args.only).split(",")
		_tour = _tour.filter(func(s: Dictionary) -> bool:
			for k in keep:
				if s.name.begins_with(k):
					return true
			return false)
	DirAccess.make_dir_recursive_absolute(_tour_dir)


func _find_water_near(c: Vector2) -> Vector3:
	for d in range(20, 600, 10):
		for i in 24:
			var a := TAU * i / 24.0
			var p := c + Vector2(cos(a), sin(a)) * d
			if gen.water_depth(p.x, p.y) > 0.5:
				var q := p + Vector2(cos(a), sin(a)) * -6.0
				return Vector3(q.x, gen.surface_height(q.x, q.y), q.y)
	return gen.spawn_point()


func _run_tour() -> void:
	var stop: Dictionary = _tour[0]
	if _tour_wait == 0:
		player.global_position = stop.pos + Vector3(0, 0.3, 0)
		player.velocity = Vector3.ZERO
		cam.width = stop.width
		cam.size = stop.width
		cam.snap_to_target()
		if stop.has("time"):
			sky.set_preset(stop.time, true)
		if stop.has("pixel"):
			_set_pixel(stop.pixel)
	_tour_wait += 1
	var wait := int(_args.get("wait", "90"))
	if _tour_wait == wait / 2:
		cam.snap_to_target()
	if _tour_wait >= wait:
		var img := get_viewport().get_texture().get_image()
		var path := _tour_dir.path_join(stop.name + ".png")
		img.save_png(path)
		print("tour shot: ", path, "  player at ", player.global_position)
		_tour.pop_front()
		_tour_wait = 0
		if _tour.is_empty():
			get_tree().quit()
