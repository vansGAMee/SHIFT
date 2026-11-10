shader_type canvas_item;
render_mode unshaded;

uniform float unease = 0.0;
uniform bool calm = false;

vec3 highlight(vec3 color) {
	float peak = max(color.r, max(color.g, color.b));
	return color * smoothstep(0.63, 1.0, peak);
}

void fragment() {
	vec2 uv = UV;
	if (!calm) {
		uv.x += sin(UV.y * 28.0 + TIME * 0.45) * 0.0012 * unease;
		uv.y += sin(TIME * 0.25) * 0.0005 * unease;
	}
	uv = clamp(uv, TEXTURE_PIXEL_SIZE, vec2(1.0) - TEXTURE_PIXEL_SIZE);
	vec3 color = texture(TEXTURE, uv).rgb;
	// Small, stable halation around practical lights; also works in OpenGL.
	vec3 halo = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.785398;
		vec2 direction = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE;
		halo += highlight(texture(TEXTURE, clamp(uv + direction * 2.0, vec2(0.0), vec2(1.0))).rgb) * 0.08;
		halo += highlight(texture(TEXTURE, clamp(uv + direction * 5.0, vec2(0.0), vec2(1.0))).rgb) * 0.045;
	}
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	color = mix(vec3(luma), color, 0.93);
	float shadows = 1.0 - smoothstep(0.04, 0.42, luma);
	color += vec3(0.0, 0.001, 0.003) * shadows;
	color += halo * 0.23;
	vec2 edge = UV * 2.0 - 1.0;
	color *= 1.0 - 0.20 * pow(dot(edge, edge) * 0.5, 1.3);
	// Static fine dithering avoids both flashing grain and crushed dark gradients.
	float grain = fract(sin(dot(floor(UV / TEXTURE_PIXEL_SIZE), vec2(12.9898, 78.233))) * 43758.5453);
	color += (grain - 0.5) * 0.003;
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
