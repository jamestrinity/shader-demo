shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;

uniform sampler2D albedo_texture : hint_default_black;

uniform vec4 paint_color_1 : source_color = vec4(0.8, 0.85, 0.85, 1.0);
uniform vec4 paint_color_2 : source_color = vec4(0.4, 0.5, 0.5, 1.0);
uniform float bump_depth : hint_range(0.0, 0.1) = 0.02;

void fragment() {
//bump stuff
	float initial_height = texture(albedo_texture, UV).b;
    vec3 tan_view = vec3(
		dot(VIEW, TANGENT),
		dot(VIEW, BINORMAL),
		dot(VIEW, NORMAL)
	);
	vec2 offset_uv = UV - (tan_view.xy * initial_height * bump_depth);
	
	//coloring
	vec4 final_mask= texture(albedo_texture, offset_uv);
	vec3 final_albedo = mix(paint_color_1.rgb, paint_color_2.rgb, final_mask.b);
	ALBEDO = final_albedo;
	
	vec2 raw_normal = final_mask.rg;
	vec2 unpacked_normal = (raw_normal *2.0)-1.0;
	vec3 tangent_normal = normalize(vec3(unpacked_normal, 0.95));
	NORMAL = normalize(mat3(TANGENT, BINORMAL, NORMAL)*tangent_normal);
}

void light(){
	float NdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	
	float tMask = step(-0.9, NdotL) * 0.25   
                + step(0.1, NdotL) * 0.5     
                + step(0.8, NdotL) * 0.25;
	DIFFUSE_LIGHT += tMask*LIGHT_COLOR;
	
}
