shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;

#include "res://shaders/common.gdshaderinc"

// Круги объёмов: xy — центр по XZ, z — радиус. Внутри рельеф Кромы вырезан.
uniform vec4 volumes[16];
uniform int volume_count = 0;
uniform float water_level = 0.0;

varying vec3 v_wpos;
varying vec3 v_wnorm;
varying vec4 v_col;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_col = COLOR;
}

void fragment() {
	for (int i = 0; i < 16; i++) {
		if (i >= volume_count) break;
		vec4 v = volumes[i];
		if (distance(v_wpos.xz, v.xy) < v.z) discard;
	}
	float slope = 1.0 - clamp(v_wnorm.y, 0.0, 1.0);
	float rock = smoothstep(0.24, 0.40, slope + (fbm2(v_wpos.xz * 0.15) - 0.5) * 0.18);
	vec3 strata = kroma_strata(v_wpos.y, v_wpos);
	float g = fbm2(v_wpos.xz * 0.55);
	vec3 ground = v_col.rgb * (0.86 + 0.28 * g);
	// мелкие пятна: сухие и сочные травинки
	float speck = hash12(floor(v_wpos.xz * 6.0));
	ground *= 0.94 + 0.12 * speck;
	vec3 col = mix(ground, strata, rock);
	float shore = 1.0 - smoothstep(water_level + 0.02, water_level + 0.5, v_wpos.y);
	col *= 1.0 - 0.28 * shore;
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
