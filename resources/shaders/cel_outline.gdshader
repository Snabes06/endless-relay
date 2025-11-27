shader_type spatial;
// Backface-expanded outline pass. Use as next_pass on the main toon material.
render_mode unshaded, cull_front;

uniform float outline_width : hint_range(0.0, 0.2) = 0.035; // World-space units
uniform vec4 outline_color : source_color = vec4(0.05, 0.05, 0.05, 1.0);

void vertex() {
	// Expand along vertex normal to create silhouette thickness
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
