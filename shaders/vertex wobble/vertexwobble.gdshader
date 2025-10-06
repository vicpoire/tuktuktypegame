shader_type spatial;
render_mode skip_vertex_transform;

uniform sampler2D albedo;
uniform sampler2D specular;
uniform sampler2D emission;

uniform float jitter : hint_range(0.0, 1.0) = 0.5;
uniform bool jitter_z_coordinate = true;
uniform bool jitter_depth_independent = true;
uniform bool affine_texture_mapping = true;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 1.0;

void vertex() {
    VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;

    float z_orig = VERTEX.z;
    float i = (1.0 - jitter) * min(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y) / 2.0;

    if (jitter_depth_independent) {
        float w = (PROJECTION_MATRIX * vec4(VERTEX, 1.0)).w;
        VERTEX = round(VERTEX / w * i) / i * w;
    } else {
        VERTEX = round(VERTEX * i) / i;
    }

    if (!jitter_z_coordinate) {
        VERTEX.z = z_orig;
    }

    if (affine_texture_mapping) {
        UV *= VERTEX.z;
    }
}

void fragment() {
    vec2 uv = UV;

    if (affine_texture_mapping) {
        uv /= VERTEX.z;
    }

    vec4 albedo_tex = texture(albedo, uv);
    vec4 specular_tex = texture(specular, uv);
    vec4 emission_tex = texture(emission, uv);

    ALBEDO = albedo_tex.rgb;
    SPECULAR = specular_tex.r;
    EMISSION = emission_tex.rgb;
    ALPHA = albedo_tex.a;

	if (ALPHA < alpha_scissor) {
	    discard;
	}


    ROUGHNESS = 0.5;
    METALLIC = 0.0;
}
