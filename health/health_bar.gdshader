// A slanted bar that always faces the camera. `fill` is per instance, so all bars share one material.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 fill_color : source_color = vec4(1.0, 0.25, 0.15, 1.0);
uniform vec4 empty_color : source_color = vec4(0.12, 0.12, 0.13, 0.75);
// How far the top edge moves right of the bottom edge, as a part of the width.
uniform float slant : hint_range(0.0, 0.5) = 0.08;
instance uniform float fill : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float x = (UV.x - slant * (1.0 - UV.y)) / (1.0 - slant);
	if (x < 0.0 || x > 1.0) {
		discard;
	}
	vec4 color = x < fill ? fill_color : empty_color;
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
