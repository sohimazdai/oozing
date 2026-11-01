shader_type spatial;
render_mode blend_mix, cull_back, diffuse_lambert, specular_schlick_ggx, depth_draw_opaque;

// Вода Кромы: цвет зависит от глубины до дна, у берега — пена.

#include "res://shaders/common.gdshaderinc"

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 shallow : source_color = vec4(0.42, 0.82, 0.78, 1.0);
uniform vec4 deep : source_color = vec4(0.07, 0.30, 0.38, 1.0);
uniform vec4 foam : source_color = vec4(0.93, 0.98, 0.96, 1.0);

varying vec3 v_wpos;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float raw = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	vec4 vpos = INV_PROJECTION_MATRIX * ndc;
	vpos.xyz /= vpos.w;
	float dist = max(VERTEX.z - vpos.z, 0.0);
	float d = dist * 0.7071;
	float t = 1.0 - exp(-d * 1.2);
	vec3 col = mix(shallow.rgb, deep.rgb, t);
	float n = fbm2(v_wpos.xz * 0.8 + vec2(TIME * 0.12, TIME * 0.07));
	float n2 = vnoise(v_wpos.xz * 3.0 - vec2(TIME * 0.35, TIME * 0.22));
	float f = 1.0 - smoothstep(0.0, 0.16 + 0.14 * n2, d);
	col = mix(col, foam.rgb, f * 0.8);
	col += vec3(0.07) * smoothstep(0.6, 0.78, n);
	ALBEDO = col;
	ALPHA = clamp(mix(0.42, 0.93, t) + f * 0.4, 0.0, 1.0);
	ROUGHNESS = 0.15;
	SPECULAR = 0.5;
	vec3 wn = normalize(vec3((n - 0.5) * 0.35, 1.0, (n2 - 0.5) * 0.35));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}
