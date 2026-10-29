// A cartoon bar that always faces the camera: an ink outline, round corners, and a light band on top.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 fill_color : source_color = vec4(0.95, 0.2, 0.18, 1.0);
uniform vec4 empty_color : source_color = vec4(0.22, 0.12, 0.14, 1.0);
uniform vec4 ink_color : source_color = vec4(0.06, 0.05, 0.08, 1.0);
uniform float outline : hint_range(0.0, 0.1, 0.005) = 0.025;
uniform float corner_radius : hint_range(0.0, 0.1, 0.005) = 0.045;
uniform float highlight_strength : hint_range(0.0, 1.0) = 0.35;
instance uniform float fill : hint_range(0.0, 1.0) = 1.0;

varying vec2 local;
// Every corner of the quad has the same |VERTEX|, so this is the half size in metres.
varying flat vec2 half_size;

void vertex() {
	local = VERTEX.xy;
	half_size = abs(VERTEX.xy);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

float rounded_box(vec2 p, vec2 extent, float radius) {
	vec2 q = abs(p) - extent + radius;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	float edge = rounded_box(local, half_size, corner_radius);
	float aa = fwidth(edge);
	vec2 inner = half_size - outline;
	float bar = rounded_box(local, inner, max(corner_radius - outline, 0.0));

	float x = (local.x + inner.x) / (2.0 * inner.x);
	vec3 color = x < fill ? fill_color.rgb : empty_color.rgb;
	float band = smoothstep(0.0, aa * 2.0, local.y - inner.y * 0.15);
	color = mix(color, vec3(1.0), band * highlight_strength);
	color = mix(color, ink_color.rgb, smoothstep(-aa, aa, bar));

	ALBEDO = color;
	ALPHA = 1.0 - smoothstep(-aa, aa, edge);
}
