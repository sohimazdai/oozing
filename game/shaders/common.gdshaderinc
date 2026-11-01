// Общие функции шейдеров: шум, дизеринг, «вырез» перед героем и слои срезов.

global uniform vec3 player_pos;      // ноги героя в мировых координатах
global uniform vec3 cam_fwd;         // направление взгляда камеры
global uniform float cutaway_radius; // радиус прозрачного окна вокруг героя
global uniform float roof_cut_y;     // когда герой в здании — всё выше этой отметки скрыто
global uniform vec4 roof_cut_area;   // xy — центр здания по XZ, z — радиус действия

bool roof_discard(vec3 wpos) {
	return wpos.y > roof_cut_y && distance(wpos.xz, roof_cut_area.xy) < roof_cut_area.z;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			   mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm2(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return s;
}

float bayer4(vec2 fc) {
	int x = int(mod(fc.x, 4.0));
	int y = int(mod(fc.y, 4.0));
	int idx = x + y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
							3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[idx] + 0.5) / 16.0;
}

// true — фрагмент заслоняет героя от камеры и должен исчезнуть (с дизерингом).
bool cutaway_discard(vec3 wpos, vec2 fragcoord) {
	vec3 head = player_pos + vec3(0.0, 1.0, 0.0);
	vec3 back = -normalize(cam_fwd);
	vec3 d = wpos - head;
	float along = dot(d, back);
	if (along < 0.5) return false;
	if (wpos.y < player_pos.y + 0.35) return false;
	float dist = length(d - back * along);
	float r = cutaway_radius;
	float t = 1.0 - smoothstep(r * 0.55, r, dist);
	return t > bayer4(fragcoord);
}

// Слои земной почвы на срезе: d — глубина под поверхностью фрагмента.
vec3 earth_layers(float d, vec3 p) {
	float h = p.x + p.z;
	d += (vnoise(vec2(h * 1.7, p.y * 2.0)) - 0.5) * 0.08;
	if (d < 0.07) return vec3(0.40, 0.39, 0.38);
	if (d < 0.32) return vec3(0.80, 0.74, 0.60) * (0.9 + 0.2 * hash12(floor(vec2(h, p.y) * 40.0)));
	if (d < 1.4) {
		vec3 soil = vec3(0.38, 0.27, 0.19) * (0.85 + 0.3 * vnoise(vec2(h, p.y) * 3.0));
		float pebble = step(0.86, vnoise(vec2(h, p.y) * 10.0));
		return mix(soil, vec3(0.64, 0.60, 0.54), pebble);
	}
	vec3 clay = vec3(0.60, 0.40, 0.25);
	float band = step(0.5, fract(d * 1.2 + vnoise(vec2(h * 0.3, 0.0))));
	return clay * (0.86 + 0.14 * band);
}

// Слоистая порода Кромы — общая для склонов и стенок объёмов.
vec3 kroma_strata(float y, vec3 p) {
	float band = y * 0.42 + fbm2(p.xz * 0.04) * 1.6;
	float b = fract(band);
	vec3 c1 = vec3(0.737, 0.396, 0.294);
	vec3 c2 = vec3(0.851, 0.675, 0.349);
	vec3 c3 = vec3(0.600, 0.300, 0.250);
	vec3 c4 = vec3(0.460, 0.330, 0.400);
	vec3 col = b < 0.45 ? c1 : (b < 0.6 ? c2 : (b < 0.85 ? c3 : c4));
	return col * (0.9 + 0.2 * vnoise(p.xz * 2.0 + vec2(p.y * 3.0)));
}
