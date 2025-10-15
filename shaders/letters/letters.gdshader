shader_type spatial;

uniform vec4 color_a : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 color_b : source_color = vec4(0.0, 0.0, 1.0, 1.0);

void fragment() {
    float factor = UV.y;
    ALBEDO = mix(color_a.rgb, color_b.rgb, factor);
}