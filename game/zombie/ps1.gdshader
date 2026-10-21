shader_type spatial;
render_mode vertex_lighting;

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec2 virtual_resolution = vec2(320.0, 240.0);
instance uniform float flash = 0.0;

const vec3 FLASH_COLOR = vec3(1.0, 0.25, 0.2);
const float FLASH_ENERGY = 1.5;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = virtual_resolution * 0.5;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = texture(albedo_texture, UV).rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = FLASH_COLOR * FLASH_ENERGY * flash;
}
