shader_type spatial;

uniform sampler2D noise_tex : source_color;
uniform vec3 color_1 : source_color = vec3(0.1, 0.4, 0.8);
uniform vec3 color_2 : source_color = vec3(0.8, 0.2, 0.5);
uniform float bleed_strength : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    // Layered noise sampling for "paint" movement
    vec2 uv_move = UV + (vec2(sin(TIME * 0.2), cos(TIME * 0.3)) * 0.02);
    float noise_val = texture(noise_tex, uv_move).r;
    float noise_val2 = texture(noise_tex, UV * 1.5 - (TIME * 0.01)).r;
    
    // Multi-colored mixing
    vec3 watercolor = mix(color_1, color_2, noise_val);
    watercolor = mix(watercolor, vec3(1.0), (1.0 - noise_val2) * bleed_strength);
    
    ALBEDO = watercolor;
    ROUGHNESS = 0.8; // Keeps it looking like paper/canvas
}