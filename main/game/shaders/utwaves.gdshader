shader_type canvas_item;

// -------------------------
// CONFIG
// -------------------------

uniform float speed = 1.5;
uniform float height_limit = 0.5;
uniform float bar_height = 0.03;
uniform float color_speed = 1.0;
uniform float alpha = 1.0;
uniform float follow_strength = 0.7;
uniform float fade_strength = 2.0;

// alternar modo
uniform bool use_rgb = true;

// até 5 cores (RGBA)
uniform vec4 color1 : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 color2 : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform vec4 color3 : source_color = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 color4 : source_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform vec4 color5 : source_color = vec4(1.0, 0.0, 1.0, 1.0);

// -------------------------
// RANDOM
// -------------------------

float random(float x) {
    return fract(sin(x * 12345.678) * 98765.4321);
}

// -------------------------
// MAIN
// -------------------------

void fragment() {
    vec2 uv = UV;

    float row = floor(uv.y / bar_height);

    float base_offset = random(row) * 2.0;
    float neighbor_offset = random(row + 1.0) * 2.0;

    float offset = mix(base_offset, neighbor_offset, follow_strength);

    float global_wave = sin(TIME * speed);
    float local_wave = sin(TIME * speed + offset) * 0.3;

    float wave = (global_wave + local_wave) * 0.5 + 0.5;
    wave *= height_limit;

    float mask = step(uv.y, wave);

    float fade = clamp((wave - uv.y) * fade_strength, 0.0, 1.0);

    vec3 final_color;

    // -------------------------
    // MODO RGB
    // -------------------------
    if (use_rgb) {
        float r = sin(TIME * color_speed + row * 0.2) * 0.5 + 0.5;
        float g = sin(TIME * color_speed + row * 0.2 + 2.0) * 0.5 + 0.5;
        float b = sin(TIME * color_speed + row * 0.2 + 4.0) * 0.5 + 0.5;

        final_color = vec3(r, g, b);
    }
    // -------------------------
    // MODO 5 CORES
    // -------------------------
    else {
        float t = fract(TIME * color_speed + row * 0.1);

        vec3 c12 = mix(color1.rgb, color2.rgb, t);
        vec3 c23 = mix(color2.rgb, color3.rgb, t);
        vec3 c34 = mix(color3.rgb, color4.rgb, t);
        vec3 c45 = mix(color4.rgb, color5.rgb, t);

        final_color = mix(mix(c12, c23, t), mix(c34, c45, t), 0.5);
    }

    COLOR = vec4(final_color, fade * mask * alpha);
}