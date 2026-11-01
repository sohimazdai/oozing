shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled, cull_disabled;

// Растения: цвет вершин × оттенок экземпляра, покачивание на ветру.

#include "res://shaders/common.gdshaderinc"

uniform float sway = 0.10;
uniform bool use_cutaway = false;

varying vec3 v_col;
varying vec3 v_wpos;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = max(VERTEX.y, 0.0);
	float w = sin(TIME * 1.5 + origin.x * 0.31 + origin.z * 0.23) + 0.5 * sin(TIME * 2.7 + origin.x * 0.9);
	VERTEX.x += w * sway * h * h;
	VERTEX.z += w * sway * 0.6 * h * h;
	v_col = COLOR.rgb * INSTANCE_CUSTOM.rgb;
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	if (use_cutaway && cutaway_discard(v_wpos, FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = v_col;
	ROUGHNESS = 0.9;
	BACKLIGHT = v_col * 0.35;
}
