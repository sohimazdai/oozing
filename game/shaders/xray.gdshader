shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_back, blend_mix, shadows_disabled;

// Силуэт героя, когда его заслоняет холм, трава или крона.
// Рисуем только там, где сцена заметно ближе к камере, чем сам герой.

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 color : source_color = vec4(1.0, 0.66, 0.28, 0.6);

void fragment() {
	float raw = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	vec4 vpos = INV_PROJECTION_MATRIX * ndc;
	vpos.xyz /= vpos.w;
	if (vpos.z <= VERTEX.z + 0.45) {
		discard;
	}
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
