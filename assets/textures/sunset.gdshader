shader_type sky;
void sky() {
 vec3 d = normalize(EYEDIR);
 float h = clamp(d.y * 1.8, 0.0, 1.0);
 vec3 horizon = vec3(0.70,0.31,0.26);
 vec3 upper = vec3(0.085,0.095,0.18);
 vec3 col = mix(horizon, upper, pow(h,0.46));
 float distortion = sin(d.x*23.0+d.z*11.0)*0.45 + sin(d.x*67.0+d.y*29.0)*0.18;
 float clouds = sin(d.x*14.0 + d.z*5.0 + d.y*76.0 + TIME*0.009 + sin(d.x*10.0)*1.4 + distortion) * 0.5+0.5;
 float band = smoothstep(0.53,0.87,clouds) * smoothstep(0.02,0.09,d.y)*(1.0-smoothstep(0.24,0.54,d.y));
 col = mix(col,vec3(0.59,0.22,0.24),band*0.44*(0.7+0.3*sin(d.x*8.0+d.y*13.0)));
 vec3 sun_dir = normalize(vec3(0.32,0.10,-1.0));
 float sun = dot(d,sun_dir);
 col += vec3(0.35,0.12,0.025)*pow(max(sun,0.0),45.0);
 col = mix(col, vec3(1.0,0.63,0.24), smoothstep(0.99957,0.99963,sun));
 if(d.y<0.0) col = mix(vec3(0.12,0.13,0.17),horizon,exp(d.y*18.0));
 COLOR = col;
}
