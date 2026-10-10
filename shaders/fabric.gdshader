shader_type spatial;
uniform vec4 team_color : source_color = vec4(0.02,0.28,0.34,1.0);
uniform bool striped = true;
void fragment() {
    vec2 p = UV * 950.0;
    float weave = sin(p.x * 6.283) * sin(p.y * 6.283);
    float stripe = smoothstep(0.42,0.46,fract(UV.x * 16.0));
    float grain = fract(sin(dot(floor(p),vec2(127.1,311.7))) * 43758.5453);
    ALBEDO = team_color.rgb * (0.93 + grain * 0.07);
    if (striped) ALBEDO *= 0.85 + stripe * 0.15;
    ROUGHNESS = 0.72 + grain * 0.16;
    SPECULAR = 0.28;
    float detail = clamp(1.0-length(fwidth(p)),0.0,1.0);
    NORMAL_MAP = normalize(vec3(weave * 0.10 * detail,cos(p.y * 6.283) * 0.12 * detail,1.0))*0.5+0.5;
}
