shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;

uniform sampler2D albedo_texture : hint_default_black;

// Diffuse Colors
uniform vec4 paint_color_1 : source_color = vec4(0.8, 0.85, 0.85, 1.0);
uniform vec4 paint_color_2 : source_color = vec4(0.4, 0.5, 0.5, 1.0);
uniform float bump_depth : hint_range(0.0, 0.1) = 0.02;

// Reflection Colors (Defaults matched to your Unreal graph)
uniform vec3 spec_color_1 : source_color = vec3(0.64, 0.26, 0.0);
uniform vec3 spec_color_2 : source_color = vec3(1.0, 0.65, 0.23);
uniform float reflection_intensity : hint_range(0.0, 1.0) = 0.5;

varying vec3 custom_spec_normal;

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

void fragment() {
    // --- 1. BUMP OFFSET & DIFFUSE NORMAL ---
    vec3 tan_view = vec3(dot(VIEW, TANGENT), dot(VIEW, BINORMAL), dot(VIEW, NORMAL));
    float initial_height = texture(albedo_texture, UV).b;
    vec2 offset_uv = UV - (tan_view.xy * initial_height * bump_depth);
    
    vec4 tex_sample = texture(albedo_texture, offset_uv);
    ALBEDO = mix(paint_color_1.rgb, paint_color_2.rgb, tex_sample.b);
    
    vec2 unpacked_normal = (tex_sample.rg * 2.0) - 1.0;
    vec3 tangent_normal = normalize(vec3(unpacked_normal, 0.95));
    NORMAL = normalize(mat3(TANGENT, BINORMAL, NORMAL) * tangent_normal);

    // --- 2. THE PIVOTED SPECULAR NORMAL ---
    // Swizzle the UVs (YX) to break up the pattern, applying the same bump offset
    vec2 pivoted_uv = UV.yx - (tan_view.xy * initial_height * bump_depth);
    
    // Sample the normal map again with the swizzled UVs
    vec2 raw_spec_normal = texture(albedo_texture, pivoted_uv).rg;
    vec2 unpacked_spec = (raw_spec_normal * 2.0) - 1.0;
    vec3 tan_spec_normal = normalize(vec3(unpacked_spec, 0.95));
    
    // Transform to View Space
    vec3 view_spec_normal = normalize(mat3(TANGENT, BINORMAL, NORMAL) * tan_spec_normal);
    
    // Pass this second, pivoted normal to the light() function using CUSTOM0
    custom_spec_normal = view_spec_normal;
	
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
   // Retrieve our pivoted normal from the fragment function
    vec3 spec_normal = normalize(custom_spec_normal);
    
    // Calculate the Reflection Vector (View direction bouncing off the specular normal)
    vec3 ref_vector = reflect(-VIEW, spec_normal);
    
    // Compare the reflection vector to the light direction
    float RdotL = clamp(dot(ref_vector, LIGHT), 0.0, 1.0);
    
    // The precise math chain from your Unreal graph:
    // Pow(4) -> *2 -> Round -> *0.5 -> -0.5 -> *2 -> Clamp(-0.15, 1.0)
    float spec_math = pow(RdotL, 4.0);
    spec_math = spec_math * 2.0;
    spec_math = round(spec_math);
    spec_math = (spec_math * 0.5) - 0.5;
    spec_math = clamp(spec_math * 2.0, -0.15, 1.0);
    
    // The sharp cutoff mask (Bottom branch of your graph)
    float spec_cutoff = round(RdotL);
    
    // Lerp between the two input colors based on the math result
    vec3 final_spec_color = mix(spec_color_1, spec_color_2, spec_math);
    
    // Apply the reflection to Godot's built-in SPECULAR output
    SPECULAR_LIGHT += final_spec_color * reflection_intensity * spec_cutoff * LIGHT_COLOR * ATTENUATION;
}