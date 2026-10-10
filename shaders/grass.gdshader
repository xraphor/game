shader_type spatial;
render_mode cull_back;

// Original procedural turf: no downloaded textures or licensed art.
uniform vec3 grass_dark : source_color = vec3(0.10, 0.20, 0.038);
uniform vec3 grass_light : source_color = vec3(0.16, 0.29, 0.065);
uniform float stripe_width = 4.0;
varying vec3 world_position;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
               mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 p = world_position.xz;
    float stripe = smoothstep(-0.075, 0.075, sin((p.y + 28.0) * 3.14159265 / stripe_width));
    float organic = value_noise(p * 1.8) * 0.55 + value_noise(p * 8.0) * 0.30;
    float blade = value_noise(p * vec2(65.0, 11.0)) * 0.5 + 0.5;
    float patches = value_noise(p * 0.19);
    vec3 turf = mix(grass_dark, grass_light, stripe * 0.34 + organic * 0.38);
    turf *= 0.86 + patches * 0.22 + blade * 0.08;
    // Taper the groomed turf into a slightly rougher apron.
    float edge = smoothstep(17.9, 18.5, abs(p.x)) + smoothstep(27.9, 28.5, abs(p.y));
    ALBEDO = mix(turf, turf * vec3(0.87, 0.93, 0.78), clamp(edge, 0.0, 1.0) * 0.4);
    ROUGHNESS = 0.78 + blade * 0.16;
    SPECULAR = 0.25;
    NORMAL_MAP = normalize(vec3((value_noise(p * 53.0) - 0.5) * 0.17,
                            (value_noise(p * vec2(15.0, 67.0)) - 0.5) * 0.12, 1.0)) * 0.5 + 0.5;
}
