shader_type spatial;
render_mode cull_back, diffuse_toon, specular_toon;

uniform vec3 albedo_color : source_color = vec3(1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, repeat_enable;

uniform float rim_threshold : hint_range(0.0, 1.0) = 0.02;
uniform float rim_softness : hint_range(0.0, 1.0) = 0.015;
uniform float specular_shininess : hint_range(1.0, 100.0) = 60.0;
uniform float specular_threshold : hint_range(0.0, 1.0) = 0.06;
uniform float specular_softness : hint_range(0.0, 1.0) = 0.15;

void fragment() {
    ALBEDO = albedo_color * texture(albedo_texture, UV).rgb;
}

void light() {
    // Toon (cel) shading: Calculate N·L and band it with smoothstep for soft edges
    float NdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
    NdotL = smoothstep(0.01, 0.03, NdotL);  // Adjust these values for harder/softer shadows

    // Specular highlights: Blinn-Phong style, powered for sharpness
    vec3 half_vector = normalize(VIEW + LIGHT);
    float NdotH = clamp(dot(NORMAL, half_vector), 0.0, 1.0);
    float specular = pow(NdotH, specular_shininess);
    specular = smoothstep(specular_threshold, specular_threshold + specular_softness, specular);

    // Rim lighting: Highlights edges based on view angle, masked by light
    float rim_dot = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
    float rim = pow(1.0 - rim_dot, 12.0) * NdotL;  // Power controls rim width
    rim = smoothstep(rim_threshold, rim_threshold + rim_softness, rim);

    // Combine: Apply toon diffuse, add rim to diffuse, specular separately
    DIFFUSE_LIGHT += (NdotL + rim) * ATTENUATION * LIGHT_COLOR * ALBEDO;
    SPECULAR_LIGHT += specular * ATTENUATION * LIGHT_COLOR;
}