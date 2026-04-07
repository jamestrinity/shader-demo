shader_type spatial;
// The blend_mix is absolutely crucial so the floor can see the depth buffer!
render_mode blend_mix, depth_draw_opaque, specular_disabled;

// Your standard floor texture (grass, wood, etc.)
uniform sampler2D base_texture : source_color;

// The depth buffer and our scratchy brush texture
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D erosion_texture : hint_default_white;
uniform vec2 erosion_uv_scale = vec2(5.0, 5.0);

// Occlusion Controls
uniform float occlusion_radius : hint_range(0.0, 5.0) = 1.0;
uniform float occlusion_power : hint_range(0.1, 5.0) = 2.0;
uniform vec3 occlusion_color : source_color = vec3(0.05, 0.05, 0.1);
uniform float erosion_min : hint_range(0.0, 1.0) = 0.25;
uniform float erosion_max : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    // 1. Draw the basic floor texture
    vec4 base_color = texture(base_texture, UV);
    
    // 2. Fetch the depth buffer math
    float raw_depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
    vec4 bg_upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
    float bg_depth = -(bg_upos.z / bg_upos.w);
    float surface_depth = -VERTEX.z;
    float depth_diff = bg_depth - surface_depth;
    
    // 3. Calculate the intersection mask
    float intersection = 1.0 - clamp(depth_diff / occlusion_radius, 0.0, 1.0);
    intersection = pow(intersection, occlusion_power);
    
    // 4. Sample the scratchy erosion texture
    // We scale the UVs so you can make the brush strokes smaller or larger
    float erosion = texture(erosion_texture, UV * erosion_uv_scale).r;
    
    // 5. Erode the shadow and crush it into hard strokes
    float eroded_mask = intersection * erosion;
    eroded_mask = smoothstep(erosion_min, erosion_max, eroded_mask);
    
    // 6. Output the final color
    ALBEDO = mix(base_color.rgb, occlusion_color, eroded_mask);
}