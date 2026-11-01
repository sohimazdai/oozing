class_name SkyRig
extends Node3D
## Солнце, окружение и время суток. T — следующее время суток с плавным переходом.

const PRESETS := [
	{
		"name": "Рассвет",
		"sun": Color(1.0, 0.76, 0.52), "energy": 1.25, "elev": 24.0, "azim": 200.0,
		"ambient": Color(0.50, 0.55, 0.72), "amb_energy": 0.75,
		"fog": Color(0.95, 0.72, 0.58), "fog_density": 0.0004, "bg": Color(0.36, 0.33, 0.45),
		"lamps": 1.0, "exposure": 1.0,
	},
	{
		"name": "День",
		"sun": Color(1.0, 0.95, 0.86), "energy": 1.55, "elev": 58.0, "azim": 215.0,
		"ambient": Color(0.62, 0.68, 0.78), "amb_energy": 0.8,
		"fog": Color(0.78, 0.84, 0.92), "fog_density": 0.0002, "bg": Color(0.55, 0.65, 0.78),
		"lamps": 0.0, "exposure": 0.95,
	},
	{
		"name": "Закат",
		"sun": Color(1.0, 0.56, 0.38), "energy": 1.2, "elev": 16.0, "azim": 120.0,
		"ambient": Color(0.52, 0.42, 0.62), "amb_energy": 0.7,
		"fog": Color(0.85, 0.50, 0.50), "fog_density": 0.0005, "bg": Color(0.35, 0.25, 0.38),
		"lamps": 0.8, "exposure": 1.0,
	},
	{
		"name": "Ночь",
		"sun": Color(0.55, 0.66, 0.95), "energy": 0.32, "elev": 42.0, "azim": 230.0,
		"ambient": Color(0.20, 0.25, 0.42), "amb_energy": 0.55,
		"fog": Color(0.16, 0.20, 0.32), "fog_density": 0.0006, "bg": Color(0.06, 0.07, 0.12),
		"lamps": 2.2, "exposure": 1.15,
	},
]

var sun: DirectionalLight3D
var env: Environment
var index := 0
var _cur := {}
var _from := {}
var _to := {}
var _t := 1.0


func _ready() -> void:
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 140.0
	sun.shadow_blur = 1.2
	sun.shadow_normal_bias = 1.2
	add_child(sun)
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	# Ортокамера: все точки кадра почти на одном расстоянии, поэтому туман
	# по дальности даёт лишь лёгкую общую дымку. Высотный туман выключен:
	# он заливал реки и низины сплошной пеленой.
	env.fog_height_density = 0.0
	env.fog_aerial_perspective = 0.0
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_cur = PRESETS[0].duplicate()
	_to = _cur
	_apply(_cur)


func next_preset() -> String:
	index = (index + 1) % PRESETS.size()
	set_preset(index, false)
	return PRESETS[index].name


func set_preset(i: int, instant: bool) -> void:
	index = i
	_from = _cur.duplicate()
	_to = PRESETS[i]
	_t = 1.0 if instant else 0.0
	if instant:
		_cur = _to.duplicate()
		_apply(_cur)


func current_name() -> String:
	return PRESETS[index].name


func _process(delta: float) -> void:
	if _t < 1.0:
		_t = minf(1.0, _t + delta / 1.6)
		var k := smoothstep(0.0, 1.0, _t)
		for key in _to:
			var a = _from.get(key, _to[key])
			var b = _to[key]
			if a is Color or a is float:
				_cur[key] = lerp(a, b, k)
			else:
				_cur[key] = b
		_apply(_cur)


func _apply(p: Dictionary) -> void:
	sun.light_color = p.sun
	sun.light_energy = p.energy
	var elev := deg_to_rad(p.elev)
	var azim := deg_to_rad(p.azim)
	var dir := Vector3(cos(elev) * sin(azim), -sin(elev), cos(elev) * cos(azim))
	sun.basis = Basis.looking_at(dir.normalized(), Vector3.UP)
	env.background_color = p.bg
	env.ambient_light_color = p.ambient
	env.ambient_light_energy = p.amb_energy
	env.fog_light_color = p.fog
	env.fog_density = p.fog_density
	env.tonemap_exposure = p.exposure
	for l in get_tree().get_nodes_in_group("lamps"):
		var base: float = l.get_meta("base_energy", 1.6)
		l.light_energy = base * p.lamps


func refresh_lamps() -> void:
	_apply(_cur)
