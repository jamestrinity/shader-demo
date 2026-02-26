shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform sampler2D texture_light : source_color;
uniform sampler2D texture_dark : source_color;

// The center point where the textures swap
uniform float threshold : hint_range(0.0, 1.0) = 0.5;

// How wide the blended area is (0.0 is a hard cut, higher values are softer)
uniform float blend_softness : hint_range(0.0, 1.0) = 0.1; 

uniform vec2 uv_scale = vec2(1.0, 1.0);

void fragment() {
	//base color
    ALBEDO = vec3(1.0);
}

void light() {
    float NdotL = max(0.0, dot(NORMAL, LIGHT));
    float light_intensity = NdotL * ATTENUATION;
    
    vec2 scaled_uv = UV * uv_scale;
    vec3 color_light = texture(texture_light, scaled_uv).rgb;
    vec3 color_dark = texture(texture_dark, scaled_uv).rgb;
    
    // 1. Define the start and end of the blurry area
    float lower_edge = threshold - (blend_softness * 0.5);
    float upper_edge = threshold + (blend_softness * 0.5);
    
    // 2. Calculate the smooth transition (returns a value from 0.0 to 1.0)
    float blend_weight = smoothstep(lower_edge, upper_edge, light_intensity);
    
    // 3. Blend the two textures together based on that weight
    vec3 final_texture_color = mix(color_dark, color_light, blend_weight);
    
    // 4. Output the result
    DIFFUSE_LIGHT += final_texture_color * LIGHT_COLOR;
}