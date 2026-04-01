shader_type spatial;
// diffuse_toon makes the base lighting step naturally, specular_disabled lets us write our own
render_mode depth_draw_opaque, cull_back, diffuse_toon, specular_disabled;

uniform sampler2D packed_texture : source_color, filter_linear_mipmap;
uniform vec3 color_a : source_color = vec3(0.8, 0.3, 0.1);
uniform vec3 color_b : source_color = vec3(0.9, 0.7, 0.1);

uniform float bump_depth = 0.02;
uniform float erosion_threshold = 0.5;

//SDF
// Fetch the engine's internal depth buffer
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
// Occlusion Controls
uniform float occlusion_radius : hint_range(0.0, 5.0) = 1.0;
uniform float occlusion_power : hint_range(0.1, 5.0) = 2.0;
uniform vec3 occlusion_color : source_color = vec3(0.05, 0.05, 0.1);
// Godot's simple equivalent to a Static Switch Parameter
uniform bool enable_occlusion = true;

uniform float erosion_min : hint_range(0.0, 1.0) = 0.25;
uniform float erosion_max : hint_range(0.0, 1.0) = 0.5;

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
// --- 3. THE GODOT OCCLUSION (Eroded Depth Fade) ---
    if (enable_occlusion) {
        float raw_depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
        vec4 bg_upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
        float bg_depth = -(bg_upos.z / bg_upos.w);
        float surface_depth = -VERTEX.z;
        float depth_diff = bg_depth - surface_depth;
        
        // 1. Calculate the base depth shadow (0.0 = deep shadow, 1.0 = no shadow)
        float base_occlusion = clamp(depth_diff / occlusion_radius, 0.0, 1.0);
        base_occlusion = pow(base_occlusion, occlusion_power);
        
        // 2. Add the Alpha channel to "erode" the shadow
        // Because tex_sample already uses offset_uv, this automatically has Parallax depth!
        float eroded_mask = base_occlusion + tex_sample.a;
        
        // 3. The "Dry Brush" Threshold (Matches Unreal's SmoothStep)
        // This crushes the soft gradient into hard, painterly chunks
        eroded_mask = smoothstep(erosion_min, erosion_max, eroded_mask);
        
        // 4. Blend the final colors
        ALBEDO = mix(occlusion_color, ALBEDO, eroded_mask);
    }
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