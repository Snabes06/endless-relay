shader_type spatial;

render_mode diffuse_toon;

uniform sampler2D color_gradient;
uniform sampler2D fresnel_gradient;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
