shader_type canvas_item;

// Fix 1: Explicitly define the screen texture uniform
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float edge_threshold : hint_range(0.0, 0.1) = 0.01;
uniform vec4 edge_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform int color_reduction : hint_range(2, 16) = 4;

void fragment() {
    vec3 color = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
    
    // Color quantization
    color = floor(color * float(color_reduction)) / float(color_reduction);
    
    // Fix 2: SCREEN_PIXEL_SIZE is already (1/width, 1/height)
    vec2 pixel_size = SCREEN_PIXEL_SIZE; 
    float edge = 0.0;
    
    for(int i = -1; i <= 1; i++) {
        for(int j = -1; j <= 1; j++) {
            vec2 offset = vec2(float(i), float(j)) * pixel_size;
            vec3 sample_color = textureLod(screen_tex, SCREEN_UV + offset, 0.0).rgb;
            edge += length(color - sample_color);
        }
    }
    
    edge /= 9.0;
    if(edge > edge_threshold) {
        color = mix(color, edge_color.rgb, edge_color.a);
    }
    
    COLOR = vec4(color, 1.0);
}