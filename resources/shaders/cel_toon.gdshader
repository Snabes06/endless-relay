shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_toon, ambient_light_disabled;

// Cartoony cel/toon shader with quantized lighting and optional rim light.
// Works best with a Next Pass outline material.

uniform vec4 albedo_color : source_color = vec4(0.95, 0.95, 0.95, 1.0);
uniform sampler2D albedo_texture : source_color;
uniform bool use_albedo_texture = false;

uniform int toon_steps : hint_range(1, 8) = 4;        // Number of diffuse steps
uniform float min_light : hint_range(0.0, 1.0) = 0.12; // Base light floor so shadows don't go pure black

uniform float specular_intensity : hint_range(0.0, 2.0) = 0.25;
uniform float specular_size : hint_range(0.0, 1.0) = 0.35; // Smaller = tighter highlight
uniform bool specular_quantize = true;

uniform float rim_intensity : hint_range(0.0, 2.0) = 0.2;
uniform float rim_power : hint_range(0.1, 8.0) = 2.0;

varying vec3 view_dir;

void vertex() {
	view_dir = normalize(-VERTEX);
}

void fragment() {
	vec3 base_color = albedo_color.rgb;
	if (use_albedo_texture) {
		vec4 tex = texture(albedo_texture, UV);
		base_color *= tex.rgb;
	}
	ALBEDO = base_color;
	ALPHA = albedo_color.a;
	// Rim (view-dependent) as emission so it isn't affected by light attenuation
	vec3 Nf = normalize(NORMAL);
	vec3 Vf = normalize(-VIEW);
	float rim = pow(1.0 - max(dot(Nf, Vf), 0.0), rim_power) * rim_intensity;
	EMISSION = ALBEDO * rim;
}

// Custom per-light function implementing quantized (toon) shading
void light() {
	vec3 N = normalize(NORMAL);
	vec3 L = normalize(LIGHT);
	float ndl = max(dot(N, L), 0.0);
	// Quantize diffuse into N steps with a floor (min_light)
	float q = floor(ndl * float(max(toon_steps, 1))) / float(max(toon_steps, 1));
	q = max(q, min_light);
	DIFFUSE_LIGHT += ALBEDO * q * LIGHT_COLOR * ATTENUATION;

	// Specular (simple Phong-like) with optional quantization
	vec3 V = normalize(-VIEW);
	vec3 H = normalize(L + V);
	float ndh = max(dot(N, H), 0.0);
	float shininess = mix(16.0, 96.0, 1.0 - specular_size);
	float spec = pow(ndh, shininess) * specular_intensity;
	if (specular_quantize) {
		spec = step(0.5, spec) * specular_intensity; // hard threshold
	}
	SPECULAR_LIGHT += LIGHT_COLOR * spec * ATTENUATION;

	// Rim handled in fragment() to avoid per-light accumulation
}
