shader_type spatial;

uniform sampler2D trail_map; // The ViewportTexture from your Trail Map
uniform float emboss_height = 0.05;

void fragment() {
    float trail = texture(trail_map, UV).r;
    
    // Basic wood color
    vec3 wood_base = vec3(0.4, 0.25, 0.15);
    
    // Apply "carving" by modifying the normal based on the trail map
    float h_left = texture(trail_map, UV + vec2(-0.01, 0)).r;
    float h_right = texture(trail_map, UV + vec2(0.01, 0)).r;
    vec3 custom_normal = normalize(vec3(h_left - h_right, 1.0, 0.0));
    
    ALBEDO = wood_base - (trail * 0.1); // Darken the "carved" path
    NORMAL = custom_normal;
}