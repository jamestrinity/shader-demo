shader_type spatial;
// diffuse_toon makes the base lighting step naturally, specular_disabled lets us write our own
render_mode depth_draw_opaque, cull_back, diffuse_toon, specular_disabled;

uniform sampler2D packed_texture : source_color, filter_linear_mipmap;
uniform vec3 color_a : source_color = vec3(0.8, 0.3, 0.1);
uniform vec3 color_b : source_color = vec3(0.9, 0.7, 0.1);

uniform float bump_depth = 0.02;
uniform float erosion_threshold = 0.5;

void vertex() {
    // We assume you baked Smooth Normals into the Vertex Colors in Blender.
    // Vertex colors import from 0.0 to 1.0, so we remap them to -1.0 to 1.0 for math
    COLOR.rgb = COLOR.rgb * 2.0 - 1.0;
}

void fragment() {
    // 1. CHEAP BUMP OFFSET (PARALLAX)
    // Sample just the blue channel (height) first using raw UVs
    float height = texture(packed_texture, UV).b;
    vec3 view_dir = normalize(VIEW);
    // Offset the UV based on camera angle and height
    vec2 uv_offset = (view_dir.xy / (view_dir.z + 0.0001)) * (height * bump_depth);
    vec2 final_uv = UV - uv_offset;
    
    // Sample the full packed texture with the new offset UVs
    vec4 tex_sample = texture(packed_texture, final_uv);
    
    // 2. DIFFUSE COLOR MIXING
    // Interpolate between the two colors using the blue channel gradient
    ALBEDO = mix(color_a, color_b, tex_sample.b);
    
    // 3. NORMAL MAP RECONSTRUCTION
    // Extract R and G, reconstruct the missing B (Z-axis) channel mathematically
    vec2 xy_normal = tex_sample.rg * 2.0 - 1.0;
    float z_normal = sqrt(max(0.0, 1.0 - dot(xy_normal, xy_normal)));
    NORMAL_MAP = vec3(xy_normal, z_normal);
    
    // 4. EDGE DETECTION & CURVATURE
    vec3 smooth_normal = normalize(COLOR.rgb);
    float fresnel = 1.0 - max(0.0, dot(smooth_normal, view_dir));
    
    // Calculate curvature using GLSL derivatives (Godot's equivalent to DDX/DDY)
    vec3 ddx = dFdx(smooth_normal);
    vec3 ddy = dFdy(smooth_normal);
    float curvature = length(ddx) + length(ddy);
    
    // 5. RIM EROSION
    // Swizzle view vector for static panning, multiply by Alpha channel detail mask
    vec2 screen_uv = VIEW.xy * 0.5 + 0.5; 
    float detail_noise = texture(packed_texture, final_uv * 2.0).a; 
    
    float edge_mask = smoothstep(0.4, 0.6, fresnel * detail_noise);
    // Only mask if curvature is high enough (prevents flat faces from vanishing)
    float final_mask = edge_mask * step(0.05, curvature);
    
    // Use Alpha Scissor for hard clipping, exactly like Unreal's Masked Blend Mode
    ALPHA = 1.0 - final_mask;
    ALPHA_SCISSOR_THRESHOLD = erosion_threshold;
}

void light() {
    // 6. STEPPED TOON LIGHTING
    float NdotL = max(0.0, dot(NORMAL, LIGHT));
    
    float step_light;
    if (NdotL > 0.5) {
        step_light = 1.0;
    } else if (NdotL > 0.1) {
        step_light = 0.25;
    } else {
        step_light = 0.0;
    }
    
    // 7. STYLIZED REFLECTIONS
    // Compare reflection vector with light vector for "dancing" specular paint
    vec3 ref_vec = reflect(-LIGHT, NORMAL);
    float RdotL = max(0.0, dot(LIGHT, ref_vec));
    float specular_step = step(0.85, RdotL) * 0.5;
    
    DIFFUSE_LIGHT += (step_light + specular_step) * LIGHT_COLOR * ATTENUATION;
}