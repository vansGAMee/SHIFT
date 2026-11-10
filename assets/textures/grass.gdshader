shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tex : source_color, filter_nearest, repeat_disable;
varying vec4 tint;
void vertex() {
 vec3 w = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 VERTEX.x += sin(TIME*0.85 + w.x*1.7+w.z*1.1)*0.065*UV.y;
 tint = COLOR;
}
void fragment() {
 vec4 c = texture(tex,UV);
 ALBEDO = c.rgb * tint.rgb * vec3(0.76,1.0,0.88);
 ALPHA = c.a;
 ALPHA_SCISSOR_THRESHOLD = 0.5;
 ROUGHNESS = 1.0;
}
