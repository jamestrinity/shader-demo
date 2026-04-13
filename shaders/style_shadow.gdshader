shader_type spatial;
render_mode depth_draw_opaque, cull_disabled; 

uniform sampler2D erosion_texture : hint_default_white, filter_linear_mipmap;

// Shadow Controls
uniform float shadow_size : hint_range(-1.0, 1.0) = 0.0;
uniform float noise_strength : hint_range(0.0, 2.0) = 0.8;
uniform vec2 texture_scale = vec2(2.0, 2.0);

void fragment() {
    // 1. The Light Angle
    // Because this only runs during the shadow pass, VIEW points perfectly at the Sun.
    // abs() ensures it works on both the front and back faces of the sphere.
    // 1.0 = Facing the Sun (Center), 0.0 = Edge of the silhouette.
    float light_angle = abs(dot(VIEW, NORMAL));
    
    // 2. Fetch and center the noise (-0.5 to 0.5)
    float tex_noise = texture(erosion_texture, UV * texture_scale).r - 0.5;
    
    // 3. The Mask
    // Core = 1.0 + noise (Always > 0.5, stays solid)
    // Edges = 0.0 + noise (Drops below 0.5, gets eroded)
    float mask = light_angle + (tex_noise * noise_strength) + shadow_size;
    
    // 4. Cut the shadow!
    ALPHA = mask;
    ALPHA_SCISSOR_THRESHOLD = 0.5;
}