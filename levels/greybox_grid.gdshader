// World-space 1 m grid for greybox geometry, so distances and speeds are easy to read.
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.35);
uniform vec3 line_color : source_color = vec3(0.2);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = abs((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = world_normal.y > 0.5 ? world_pos.xz : (world_normal.x > 0.5 ? world_pos.zy : world_pos.xy);
	vec2 dist = abs(fract(uv - 0.5) - 0.5) / fwidth(uv);
	float line = 1.0 - min(min(dist.x, dist.y), 1.0);
	ALBEDO = mix(base_color, line_color, line);
	ROUGHNESS = 0.9;
}
