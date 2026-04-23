shader_type spatial;
render_mode cull_front, unshaded, depth_draw_opaque;

uniform sampler2D erosion_texture : hint_default_white;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Geometry Controls
uniform float inflate_amount : hint_range(0.0, 0.5) = 0.05;
uniform vec3 outline_offset = vec3(0.0, 0.0, 0.0);

// NEW: Ring Thickness Control
uniform float ring_thickness : hint_range(0.0, 1.0) = 0.2;

// Geometry Toggle
uniform bool is_sharp_geometry = false;

// Erosion Controls
uniform float rim_texture_scale = 2.0;
uniform float erosion_threshold : hint_range(0.0, 1.0) = 0.5;

// We need to pass the normal from the vertex to the fragment 
// so we can calculate the camera angle on the back-faces.
varying vec3 mesh_normal;

void vertex() {
    vec3 inflate_normal;
    
    if (is_sharp_geometry) {
        // CUBE MODE: Inflate using the fake smooth vertex colors to keep corners attached
        inflate_normal = normalize((COLOR.rgb * 2.0) - 1.0);
    } else {
        // SPHERE MODE: Inflate normally
        inflate_normal = NORMAL;
    }
    
    // Inflate and Offset
    VERTEX += inflate_normal * inflate_amount;
    VERTEX += outline_offset;
}

void fragment() {
    // --- 1. HOLLOW RING MASK (Fixed!) ---
    // Use Godot's built-in fragment NORMAL, which is safely in View Space!
    // We use abs() because cull_front means we are looking at the inside/back faces.
    float view_angle = abs(dot(VIEW, NORMAL));
    
    // Hollow out the flat back-wall to create the skinny floating ring
    if (view_angle > ring_thickness) {
        discard;
    }

    // --- 2. SCRATCHY EROSION ---
    vec2 view_uv = SCREEN_UV * rim_texture_scale;
    float tex_noise = texture(erosion_texture, view_uv).r;
    
    // Bite chunks out of the remaining ring
    if (tex_noise < erosion_threshold) {
        discard;
    }
    
    ALBEDO = outline_color.rgb;
}
