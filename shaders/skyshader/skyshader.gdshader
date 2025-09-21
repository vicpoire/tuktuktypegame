shader_type sky;

uniform vec3 skyColor       : source_color;
uniform vec3 horizonColor   : source_color;
uniform vec3 cloudColor     : source_color = vec3(1.0);

uniform float horizon_height : hint_range(-1.0, 1.0) = 0.0;

uniform float cloud_threshold : hint_range(0.0, 1.0) = 0.6;
uniform float cloud_softness  : hint_range(0.0, 0.2) = 0.05;
uniform float cloud_opacity   : hint_range(0.0, 1.0) = 1.0;

uniform float cloud_scale_x   = 2.0;
uniform float cloud_scale_y   = 2.0;
uniform float cloud_speed     = 0.02;
uniform float time_offset     = 0.0;

uniform vec2 viewport_size;
uniform float dither_strength : hint_range(0.0,1.0) = 1.0;
uniform vec2 dither_offset    = vec2(0.0);


float hash(vec3 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float valueNoise(vec3 p){
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f*f*(3.0 - 2.0*f);
    float n000 = hash(i + vec3(0,0,0));
    float n100 = hash(i + vec3(1,0,0));
    float n010 = hash(i + vec3(0,1,0));
    float n110 = hash(i + vec3(1,1,0));
    float n001 = hash(i + vec3(0,0,1));
    float n101 = hash(i + vec3(1,0,1));
    float n011 = hash(i + vec3(0,1,1));
    float n111 = hash(i + vec3(1,1,1));
    float nx00 = mix(n000,n100,f.x);
    float nx10 = mix(n010,n110,f.x);
    float nx01 = mix(n001,n101,f.x);
    float nx11 = mix(n011,n111,f.x);
    float nxy0 = mix(nx00,nx10,f.y);
    float nxy1 = mix(nx01,nx11,f.y);
    return mix(nxy0,nxy1,f.z);
}

float fbm(vec3 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * valueNoise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

float bayer4(vec2 p) {
    int x = int(mod(p.x,4.0));
    int y = int(mod(p.y,4.0));
    int i = x + y*4;
    return float(int[16](
        0,8,2,10,
        12,4,14,6,
        3,11,1,9,
        15,7,13,5
    )[i]) / 16.0;
}


void sky() {
// vertical gradient from horizon to sky
    float grad = clamp((EYEDIR.y - horizon_height) / 0.5, 0.0, 1.0);
    vec3 finalCol = mix(horizonColor, skyColor, grad);
    // cloud noise
    vec3 dir = normalize(EYEDIR);
    float t = (TIME + time_offset) * cloud_speed;

    vec3 p = vec3(
        dir.x * cloud_scale_x,
        dir.y * cloud_scale_y,
        dir.z * 0.5*(cloud_scale_x + cloud_scale_y)
    );

    p.xz += vec2(t, t*0.5);

    vec3 warp = vec3(fbm(p + 10.0), fbm(p + 20.0), fbm(p + 30.0));
    p += warp * 2.0;

    float n = fbm(p);
    float clouds = smoothstep(
        cloud_threshold - cloud_softness,
        cloud_threshold + cloud_softness,
 		n
    );

    vec2 ditherCoord = SCREEN_UV * viewport_size + dither_offset;
    float dither = bayer4(ditherCoord);

    clouds = step(dither * dither_strength + (1.0 - dither_strength) * 0.5,
                  clouds);

    finalCol = mix(finalCol, cloudColor, clouds * cloud_opacity);
    COLOR = finalCol * LIGHT0_ENERGY;
}
