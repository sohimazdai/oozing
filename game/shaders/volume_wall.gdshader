shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled, cull_disabled;

// Боковая стенка объёма. Ниже уровня фрагмента — срез земного грунта (цоколь),
// выше — срез породы Кромы (если рельеф вокруг выше фрагмента, стенка смотрит внутрь).

#include "res://shaders/common.gdshaderinc"

uniform float base_y = 0.0;

varying vec3 v_wpos;
varying float v_top;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_top = UV.x;
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 col;
	if (v_wpos.y < base_y) {
		col = earth_layers(base_y - v_wpos.y, v_wpos);
	} else {
		float depth = v_top - v_wpos.y;
		if (depth < 0.22 + 0.06 * vnoise(v_wpos.xz * 6.0)) {
			col = vec3(0.30, 0.25, 0.18) * (0.9 + 0.2 * vnoise(v_wpos.xz * 20.0));
		} else {
			col = kroma_strata(v_wpos.y, v_wpos);
		}
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
