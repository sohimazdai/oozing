shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;

// Общий материал вещей: цвет + процедурный узор вместо текстур.
// pattern: 0 нет, 1 кирпич, 2 плитка, 3 доски, 4 асфальт, 5 газон, 6 пятна (стеклопластик)

#include "res://shaders/common.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform vec4 albedo2 : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform int pattern = 0;
uniform float pattern_scale = 1.0;
uniform float noise_amount = 0.10;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.85;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
uniform float emission_energy = 0.0;
uniform bool use_cutaway = true;
uniform bool use_instance_color = false;

varying vec3 v_wpos;
varying vec3 v_wnorm;
varying vec4 v_inst;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_inst = use_instance_color ? INSTANCE_CUSTOM : vec4(1.0);
}

vec2 face_uv(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.y >= a.x && a.y >= a.z) return p.xz;
	if (a.x >= a.z) return vec2(p.z, p.y);
	return vec2(p.x, p.y);
}

vec3 apply_pattern(vec3 base, vec3 base2, vec2 uv, vec3 n) {
	if (pattern == 1) {
		vec2 b = uv / vec2(0.25, 0.077);
		b.x += step(1.0, mod(floor(b.y), 2.0)) * 0.5;
		vec2 f = fract(b);
		float mortar = max(step(f.x, 0.05), step(f.y, 0.15));
		float id = hash12(floor(b));
		return mix(base * (0.82 + 0.32 * id), base2, mortar);
	} else if (pattern == 2) {
		vec2 b = uv / 0.5;
		vec2 f = fract(b);
		float grout = max(step(f.x, 0.05), step(f.y, 0.05));
		float id = hash12(floor(b));
		return mix(base * (0.9 + 0.16 * id), base2, grout);
	} else if (pattern == 3) {
		bool vertical = abs(n.y) < 0.5;
		float coord = vertical ? uv.x : uv.y;
		float along = vertical ? uv.y : uv.x;
		float board = floor(coord / 0.16);
		float f = fract(coord / 0.16);
		float seam = step(f, 0.07);
		float id = hash12(vec2(board, 3.0));
		float grain = vnoise(vec2(along * 6.0, board * 13.0 + coord * 40.0));
		return mix(base * (0.82 + 0.3 * id) * (0.92 + 0.12 * grain), base2, seam);
	} else if (pattern == 4) {
		float s = hash12(floor(uv * 45.0));
		return base * (0.86 + 0.22 * s);
	} else if (pattern == 5) {
		float s = hash12(floor(uv * 55.0));
		float stripe = step(0.5, fract(uv.x * 0.4));
		return base * (0.86 + 0.2 * s) * (0.94 + 0.1 * stripe);
	} else if (pattern == 6) {
		float spots = smoothstep(0.62, 0.68, vnoise(uv * 1.6));
		float wear = smoothstep(0.55, 0.8, fbm2(uv * 3.0));
		vec3 c = mix(base, base2, spots);
		return mix(c, c * 0.72 + vec3(0.08, 0.07, 0.05), wear * 0.5);
	}
	return base;
}

void fragment() {
	if (use_cutaway && (roof_discard(v_wpos) || cutaway_discard(v_wpos, FRAGCOORD.xy))) {
		discard;
	}
	vec3 base = albedo.rgb * v_inst.rgb;
	vec3 col = apply_pattern(base, albedo2.rgb, face_uv(v_wpos, v_wnorm) * pattern_scale, v_wnorm);
	float n = fbm2(v_wpos.xz * 1.3 + vec2(v_wpos.y * 0.9, -v_wpos.y * 0.6));
	col *= 1.0 + (n - 0.5) * 2.0 * noise_amount;
	ALBEDO = col;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	if (emission_energy > 0.0) {
		EMISSION = base * emission_energy;
	}
}
