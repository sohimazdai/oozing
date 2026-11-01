class_name Mats
extends RefCounted
## Библиотека материалов. Все вещи мира — это несколько шейдеров с параметрами,
## а не набор текстур. Одинаковые параметры → один и тот же объект Material,
## поэтому CSG и меши сливаются в меньшее число поверхностей.

const PATTERN_NONE := 0
const PATTERN_BRICK := 1
const PATTERN_TILES := 2
const PATTERN_PLANKS := 3
const PATTERN_ASPHALT := 4
const PATTERN_TURF := 5
const PATTERN_SPOTS := 6

static var _cache := {}
static var _world_shader: Shader = preload("res://shaders/world.gdshader")
static var _plant_shader: Shader = preload("res://shaders/plant.gdshader")
static var _xray: ShaderMaterial


## Материал вещи. opts: pattern, color2, scale, noise, rough, metal, emission, cutaway, instance.
static func world(color: Color, opts := {}) -> ShaderMaterial:
	var key := "w|%s|%s" % [color.to_html(), str(opts)]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = _world_shader
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("albedo2", opts.get("color2", color.darkened(0.3)))
	m.set_shader_parameter("pattern", opts.get("pattern", PATTERN_NONE))
	m.set_shader_parameter("pattern_scale", opts.get("scale", 1.0))
	m.set_shader_parameter("noise_amount", opts.get("noise", 0.1))
	m.set_shader_parameter("roughness_value", opts.get("rough", 0.85))
	m.set_shader_parameter("metallic_value", opts.get("metal", 0.0))
	m.set_shader_parameter("emission_energy", opts.get("emission", 0.0))
	m.set_shader_parameter("use_cutaway", opts.get("cutaway", true))
	m.set_shader_parameter("use_instance_color", opts.get("instance", false))
	_cache[key] = m
	return m


## Материал героя: рисуется поверх заслонивших его предметов силуэтом.
static func character(color: Color) -> ShaderMaterial:
	var key := "c|" + color.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := world(color, {"cutaway": false, "noise": 0.05, "rough": 0.8}).duplicate() as ShaderMaterial
	m.next_pass = xray()
	_cache[key] = m
	return m


static func xray() -> ShaderMaterial:
	if _xray == null:
		_xray = ShaderMaterial.new()
		_xray.shader = preload("res://shaders/xray.gdshader")
		_xray.render_priority = 10
	return _xray


static func plant(sway: float, cutaway := false) -> ShaderMaterial:
	var key := "p|%f|%s" % [sway, cutaway]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = _plant_shader
	m.set_shader_parameter("sway", sway)
	m.set_shader_parameter("use_cutaway", cutaway)
	_cache[key] = m
	return m


## Материал свежего среза для конкретного объёма.
static func cut(base_y: float, kind := 0, neutral := Color(0.86, 0.83, 0.76)) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/cut.gdshader")
	m.set_shader_parameter("base_y", base_y)
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("neutral", neutral)
	return m


# --- Частые материалы ---------------------------------------------------------

static func brick() -> ShaderMaterial:
	return world(Color(0.72, 0.36, 0.26), {"pattern": PATTERN_BRICK, "color2": Color(0.80, 0.77, 0.70), "noise": 0.06})

static func plaster(c := Color(0.90, 0.87, 0.80)) -> ShaderMaterial:
	return world(c, {"noise": 0.05})

static func concrete() -> ShaderMaterial:
	return world(Color(0.66, 0.65, 0.62), {"noise": 0.12})

static func paving() -> ShaderMaterial:
	return world(Color(0.73, 0.70, 0.64), {"pattern": PATTERN_TILES, "color2": Color(0.55, 0.52, 0.48), "noise": 0.08})

static func asphalt() -> ShaderMaterial:
	return world(Color(0.30, 0.30, 0.31), {"pattern": PATTERN_ASPHALT, "noise": 0.12})

static func turf() -> ShaderMaterial:
	return world(Color(0.30, 0.62, 0.26), {"pattern": PATTERN_TURF, "noise": 0.06, "rough": 0.95})

static func wood(c := Color(0.62, 0.45, 0.30)) -> ShaderMaterial:
	return world(c, {"pattern": PATTERN_PLANKS, "color2": c.darkened(0.45), "noise": 0.06})

static func metal(c := Color(0.16, 0.17, 0.18)) -> ShaderMaterial:
	return world(c, {"rough": 0.45, "metal": 0.6, "noise": 0.04})

static func paint(c: Color) -> ShaderMaterial:
	return world(c, {"rough": 0.6, "noise": 0.05})

static func glow(c: Color, energy := 2.5) -> ShaderMaterial:
	return world(c, {"emission": energy, "noise": 0.0, "cutaway": false})
