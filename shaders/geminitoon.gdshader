shader_type spatial;

uniform vec3 albedo : source_color = vec3(1.0);
uniform sampler2D texture_albedo : source_color;
uniform float cuts : hint_range(1.0, 8.0, 1.0) = 3.0;
uniform float wrap : hint_range(-1.0, 1.0) = 0.0;
uniform float steer : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec4 tex = texture(texture_albedo, UV);
	ALBEDO = albedo * tex.rgb;
}

void light() {
	// Calculate standard diffuse lighting (Lambert)
	float dot_product = dot(NORMAL, LIGHT);
	
	// Apply "Wrap" to push light further into shadows
	float diffuse = smoothstep(0.0, 1.0, (dot_product + wrap) / (1.0 + wrap));
	
	// Quantize the light (the "Cuts" that create the toon bands)
	diffuse = floor(diffuse * cuts) / (cuts - 0.5);
	
	// Multiply by light color and attenuation (shadows)
	DIFFUSE_LIGHT += diffuse * LIGHT_COLOR * ATTENUATION;
}