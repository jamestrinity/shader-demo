shader_type spatial;
render_mode specular_toon, diffuse_toon;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform int toon_levels : hint_range(1, 10) = 3;
uniform float toon_smoothness : hint_range(0.0, 1.0) = 0.05;

// Fix 3: Standard bool uniforms don't use 'hint_default'
uniform bool use_rim = true;
uniform vec4 rim_color : source_color = vec4(1.0);
uniform float rim_size : hint_range(0.0, 1.0) = 0.5;
uniform float rim_smoothness : hint_range(0.0, 1.0) = 0.1;

uniform bool use_specular = true;
uniform vec4 specular_color : source_color = vec4(1.0);
uniform float specular_size : hint_range(0.0, 1.0) = 0.1;
uniform float specular_smoothness : hint_range(0.0, 1.0) = 0.05;
uniform float specular_strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec4 tex_color = texture(texture_albedo, UV);
    ALBEDO = albedo.rgb * tex_color.rgb;
}

void light() {
    float NdotL = dot(NORMAL, LIGHT);
    float diffuse_amount = max(NdotL, 0.0);

    float toon_step = 1.0 / float(toon_levels);
    float toon_diffuse = floor(diffuse_amount / toon_step) * toon_step;
    toon_diffuse = smoothstep(toon_diffuse - toon_smoothness, toon_diffuse + toon_smoothness, diffuse_amount);

    float toon_specular = 0.0;
    if (use_specular) {
        vec3 half_vector = normalize(VIEW + LIGHT);
        float NdotH = max(dot(NORMAL, half_vector), 0.0);
        float specular_amount = pow(NdotH, 32.0);
        toon_specular = smoothstep(specular_size - specular_smoothness, specular_size + specular_smoothness, specular_amount);
    }
    
    float rim_amount = 0.0;
    if (use_rim) {
        float rim_dot = 1.0 - dot(VIEW, NORMAL);
        rim_amount = smoothstep(rim_size - rim_smoothness, rim_size + rim_smoothness, rim_dot);
        rim_amount *= diffuse_amount; 
    }
    
    // Fix 4: Separate Diffuse and Specular light contributions properly
    DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * (toon_diffuse * ALBEDO + rim_color.rgb * rim_amount);
    SPECULAR_LIGHT += specular_color.rgb * toon_specular * specular_strength * ATTENUATION;
}