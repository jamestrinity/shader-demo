shader_type spatial;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform int light_steps = 3;
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.6;

void fragment() {
    ALBEDO = albedo_color.rgb;
}

void light() {
    float ndotl = max(dot(NORMAL, LIGHT), 0.0);
    float stepped = floor(ndotl * float(light_steps)) / float(light_steps);
    
    // Smooth the transition slightly to avoid flickering artifacts
    vec3 toon_light = mix(vec3(1.0 - shadow_strength), vec3(1.0), stepped);
    
    // Fix 5: Always use += for LIGHT functions to support multiple lamps
    DIFFUSE_LIGHT += ALBEDO * toon_light * LIGHT_COLOR * ATTENUATION;
}