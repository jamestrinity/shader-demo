shader_type spatial;

uniform vec3 ink_color : source_color = vec3(0.05, 0.05, 0.1);
uniform sampler2D flow_noise;

void fragment() {
    // Create an "ebbing" effect by oscillating the noise threshold
    float flow = texture(flow_noise, UV + (TIME * 0.05)).r;
    float dynamic_mask = smoothstep(0.4, 0.6, flow + sin(TIME) * 0.1);
    
    // Mix ink with "paper" (Albedo)
    vec3 paper_color = vec3(0.9, 0.85, 0.8);
    ALBEDO = mix(paper_color, ink_color, dynamic_mask);
    
    // Optional: Add a subtle bleed edge
    float edge = smoothstep(0.35, 0.4, flow + sin(TIME) * 0.1);
    ALBEDO = mix(ALBEDO, ink_color * 1.5, edge * 0.2);
}