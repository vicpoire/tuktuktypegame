shader_type sky;

uniform vec3 skyColor       : source_color;
uniform vec3 horizonColor   : source_color;
uniform vec3 cloudColor     : source_color = vec3(1.0, 1.0, 1.0);
uniform float cloud_threshold : hint_range(0.0, 1.0) = 0.6;   // cloud coverage threshold
uniform float cloud_softness  : hint_range(0.0, 0.2) = 0.05;  // fade width
uniform float cloud_opacity : hint_range(0.0,1.0) = 1.0;

// separate cloud scales
uniform float cloud_scale_x = 2.0;
uniform float cloud_scale_y = 2.0;

uniform float cloud_speed = 0.02;
uniform float time_offset = 0.0;

// pass this in from script: get_viewport().size
uniform vec2 viewport_size;   

// Strength of dithering: 0 = off, 1 = full
uniform float dither_strength : hint_range(0.0,1.0) = 1.0;

float noise3d(vec3 p) {
    return 0.5 + 0.3 * sin(p.x) * cos(p.y) * sin(p.z)
         + 0.2 * sin(p.x * 2.1) * cos(p.y * 1.7) * sin(p.z * 1.9)
         + 0.1 * sin(p.x * 4.3) * cos(p.y * 3.8) * sin(p.z * 4.1);
}

float bayer4(vec2 p) {
    int x = int(mod(p.x,4.0));
    int y = int(mod(p.y,4.0));
    int i = x + y*4;
    return float(int[16](
        0,  8,  2, 10,
       12,  4, 14,  6,
        3, 11,  1,  9,
       15,  7, 13,  5
    )[i]) / 16.0;
}

void sky() {
    // Base sky gradient
    float col = clamp(EYEDIR.y / 0.5, 0.0, 1.0);
    vec3 finalCol = mix(horizonColor, skyColor, col);
    vec3 dir = normalize(EYEDIR);

    // Cloud noise field
    float time_factor = (TIME + time_offset) * cloud_speed;
    vec3 noise_pos = vec3(
        dir.x * cos(time_factor) - dir.z * sin(time_factor),
        dir.y,
        dir.x * sin(time_factor) + dir.z * cos(time_factor)
    );
    
    // Apply separate scales
    noise_pos.x *= cloud_scale_x;
    noise_pos.y *= cloud_scale_y;
    noise_pos.z *= (cloud_scale_x + cloud_scale_y) * 0.5; // optional for Z scaling

    float n = noise3d(noise_pos);

    // Only use noise for clouds
    float cloud_mask = smoothstep(cloud_threshold - cloud_softness, cloud_threshold + cloud_softness, n);
    n *= cloud_mask;

    // Smoothstep for final cloud shape
    float clouds = smoothstep(cloud_threshold, cloud_threshold + cloud_softness, n);

    // Apply dithering
    float dither = bayer4(SCREEN_UV * viewport_size);
    clouds = step(dither * dither_strength + (1.0 - dither_strength) * 0.5, clouds);

    finalCol = mix(finalCol, cloudColor, clouds * cloud_opacity);

    COLOR = finalCol * LIGHT0_ENERGY;
}
