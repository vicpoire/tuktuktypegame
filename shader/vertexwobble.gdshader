shader_type spatial;
render_mode depth_draw_opaque, cull_back;

uniform float wobble_strength : hint_range(0.0, 0.1) = 0.02;
uniform float wobble_speed : hint_range(0.1, 10.0) = 3.0;
uniform float noise_scale : hint_range(0.1, 5.0) = 1.5;
uniform sampler2D albedo_texture : source_color;
uniform vec4 albedo_color : source_color = vec4(1.0);

varying vec2 vert_uv;

// Hash function for pseudo-noise
float hash(vec3 p) {
    return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

// Smoother noise function
float smooth_noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    return mix(
        mix(
            mix(hash(i + vec3(0,0,0)), hash(i + vec3(1,0,0)), f.x),
            mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x),
            f.y
        ),
        mix(
            mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
            mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x),
            f.y
        ),
        f.z
    );
}

void vertex() {
    float t = TIME * wobble_speed;
    vec3 world_pos = VERTEX;

    // Create smoother displacement
    vec3 noise_pos = world_pos * noise_scale + vec3(t);
    float noise_x = smooth_noise(noise_pos);
    float noise_y = smooth_noise(noise_pos + vec3(100.0));
    float noise_z = smooth_noise(noise_pos + vec3(200.0));

    vec3 displacement = vec3(
        (noise_x - 0.5),
        (noise_y - 0.5),
        (noise_z - 0.5)
    ) * wobble_strength;

    VERTEX += displacement;

    // Simple normal adjustment - displace normal in same direction as vertex
    NORMAL = normalize(NORMAL + displacement * 2.0);

    vert_uv = UV;
}

void fragment() {
    vec4 tex = texture(albedo_texture, vert_uv);
    ALBEDO = tex.rgb * albedo_color.rgb;
    ALPHA = tex.a * albedo_color.a;
}