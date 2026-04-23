shader_type spatial;
render_mode specular_disabled, ambient_light_disabled, blend_mix, depth_draw_opaque, depth_prepass_alpha;

uniform sampler2D albedo_texture : hint_default_black;

// Glass Controls
uniform float glass_opacity : hint_range(0.0, 1.0) = 0.8;

// Geometry Toggle
uniform bool is_sharp_geometry = false; // Check this box for Cubes/Cylinders!

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

uniform float erosion_min : hint_range(0.0, 1.0) = 0.25;
uniform float erosion_max : hint_range(0.0, 1.0) = 0.5;
uniform float occlusion_offset = 0.0;

uniform sampler2D erosion_texture : hint_default_black;

// Rim Erosion Controls
uniform float rim_texture_scale = 2.0;
uniform float rim_power = 5.0;
uniform float rim_threshold = 0.05;
uniform float curvature_epsilon = 0.00001;

void fragment() {
    // --- THE FIX 1: Capture the smooth geometry normal BEFORE we apply the bumpy normal map ---
    vec3 smooth_mesh_normal = NORMAL;

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
    vec2 pivoted_uv = UV.yx - (tan_view.xy * initial_height * bump_depth);
    vec2 raw_spec_normal = texture(albedo_texture, pivoted_uv).rg;
    vec2 unpacked_spec = (raw_spec_normal * 2.0) - 1.0;
    vec3 tan_spec_normal = normalize(vec3(unpacked_spec, 0.95));
    custom_spec_normal = normalize(mat3(TANGENT, BINORMAL, NORMAL) * tan_spec_normal);
    
    // --- 3. RIM EROSION (Masked Silhouette) ---
    vec3 working_normal;
    
    if (is_sharp_geometry) {
        // CUBE MODE: Unpack the fake "smooth" normal from the vertex colors
        working_normal = normalize((COLOR.rgb * 2.0) - 1.0);
    } else {
        // SPHERE MODE: Use the actual smooth mesh normal
        working_normal = smooth_mesh_normal; 
    }

    // [The rest of your Rim Erosion code stays exactly the same!]
    vec2 view_uv = SCREEN_UV * rim_texture_scale;
    float rim_tex = texture(erosion_texture, view_uv).r; 
    
    // Calculate Fresnel (0.0 at center, 1.0 at edges)
    float view_dot = dot(VIEW, working_normal);
    float fresnel = clamp(1.0 - view_dot, 0.0, 1.0);
    
    // Curvature Filter (Checks if geometry is actually curved)
    vec3 ddx_n = dFdx(working_normal);
    vec3 ddy_n = dFdy(working_normal);
    vec3 curv_vec = abs(ddx_n) + abs(ddy_n);
    float curvature = curv_vec.x + curv_vec.y + curv_vec.z;
    float is_curved = ceil(curvature - curvature_epsilon); 
    
	
	// 4. Calculate the Erosion Mask
    float rim_math = pow(fresnel * rim_tex, rim_power);
    float rim_mask = step(rim_threshold, rim_math);
    
    // Multiply by curvature to protect flat faces
    float final_rim_mask = rim_mask * is_curved;
    
    // 5. THE FIX: Pure Alpha Blending!
    // (Ensure you DELETED the ALPHA_SCISSOR_THRESHOLD line!)
    
    // First, we cut out the chunks for the rim erosion (1.0 is solid, 0.0 is deleted)
    float eroded_geometry = 1.0 - final_rim_mask;
    
    // Then, we multiply the remaining paint by your opacity slider
    ALPHA = eroded_geometry * glass_opacity;
    //// Calculate final mask
    //float rim_math = pow(fresnel * rim_tex, rim_power);
    //float rim_mask = step(rim_threshold, rim_math);
    //
    //// Multiply by curvature to protect flat faces
    //float final_rim_mask = rim_mask * is_curved;
    //
    //// Cut the geometry! 
    //ALPHA = 1.0 - final_rim_mask;
	
	
}

void light() {
	// --- 3. TOON DIFFUSE (This got deleted!) ---
    float NdotL = dot(NORMAL, LIGHT);
    float toon_intensity;
    if (NdotL > 0.1) {
        toon_intensity = 1.0;
    } else if (NdotL > -0.2) {
        toon_intensity = 0.25;
    } else {
        toon_intensity = 0.0;
    }
    DIFFUSE_LIGHT += toon_intensity * ATTENUATION * LIGHT_COLOR;
	
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