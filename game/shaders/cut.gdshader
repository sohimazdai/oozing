shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;

// Свежий срез по границе объёма. Узор восстанавливается по высоте:
// ниже земли фрагмента — слои грунта; в здании — перекрытия и кирпичная кладка;
// у прочих вещей — светлый чистый материал.

#include "res://shaders/common.gdshaderinc"

uniform float base_y = 0.0;
uniform int kind = 0;               // 0 — прочее, 1 — здание
uniform float first_floor = 0.3;    // отметка чистого пола первого этажа
uniform float floor_h = 3.0;
uniform float slab = 0.25;
uniform int floors = 3;
uniform vec4 neutral : source_color = vec4(0.86, 0.83, 0.76, 1.0);

varying vec3 v_wpos;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (cutaway_discard(v_wpos, FRAGCOORD.xy)) {
		discard;
	}
	float y = v_wpos.y - base_y;
	vec3 col;
	if (y < 0.0) {
		col = earth_layers(-y, v_wpos);
	} else if (kind == 1) {
		float k = clamp(round((y - first_floor) / floor_h), 0.0, float(floors));
		float level = first_floor + k * floor_h;
		float h = v_wpos.x * 0.7071 + v_wpos.z * 0.7071;
		if (y > level - slab && y <= level + 0.02) {
			// бетон перекрытия с заполнителем и прутками арматуры
			col = vec3(0.70, 0.70, 0.68) * (0.9 + 0.2 * hash12(floor(vec2(h, y) * 35.0)));
			vec2 g = fract(vec2(h / 0.2, (y - level + slab * 0.5) / 0.12)) - 0.5;
			col = mix(col, vec3(0.30, 0.22, 0.18), step(length(g * vec2(0.2, 0.12)), 0.012));
		} else if (y < first_floor - slab) {
			col = vec3(0.62, 0.62, 0.60);
		} else {
			vec2 b = vec2(h, y) / vec2(0.25, 0.077);
			b.x += step(1.0, mod(floor(b.y), 2.0)) * 0.5;
			vec2 f = fract(b);
			float mortar = max(step(f.x, 0.05), step(f.y, 0.15));
			float id = hash12(floor(b));
			vec3 brick = vec3(0.80, 0.42, 0.30) * (0.85 + 0.3 * id);
			col = mix(brick, vec3(0.86, 0.84, 0.78), mortar);
		}
	} else {
		col = neutral.rgb * (0.92 + 0.12 * vnoise(v_wpos.xz * 4.0 + vec2(v_wpos.y * 5.0)));
	}
	ALBEDO = col;
	ROUGHNESS = 0.9;
}
