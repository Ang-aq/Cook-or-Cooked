shader_type canvas_item;

uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform float pixel_size : hint_range(1.0, 32.0) = 8.0;

void fragment() {
    vec2 uv = FRAGCOORD.xy / pixel_size;
    uv = floor(uv) * pixel_size;

    vec4 col = vec4(0.0, 0.0, 0.0, alpha); // black fade
    COLOR = col;
}