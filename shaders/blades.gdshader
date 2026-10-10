shader_type spatial;
render_mode cull_disabled;
uniform vec4 grass_color : source_color = vec4(0.14, 0.24, 0.045, 1.0);
varying float blade_height;
void vertex() {
    blade_height = UV.y;
    vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float range_fade = 1.0 - smoothstep(10.0, 24.0, distance(world, CAMERA_POSITION_WORLD));
    VERTEX.y *= range_fade;
    VERTEX.x += sin(TIME * 1.4 + world.x * 0.3 + world.z * 0.6) * UV.y * 0.009 * range_fade;
}
void fragment() {
    ALBEDO = grass_color.rgb * COLOR.rgb * mix(0.7, 1.15, blade_height);
    NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
    ROUGHNESS = 0.91;
    SPECULAR = 0.15;
    BACKLIGHT = ALBEDO * 0.22;
}
