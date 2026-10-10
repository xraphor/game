shader_type sky;
uniform sampler2D panorama : filter_linear;
void sky() {
    float longitude = atan(EYEDIR.x, EYEDIR.z) / 6.2831853 + 0.5;
    if (AT_CUBEMAP_PASS) {
        vec2 uv = vec2(longitude, acos(clamp(EYEDIR.y, -1.0, 1.0)) / 3.14159265);
        // Direct sunlight has its own light; cap the HDR sun in reflections to avoid fireflies.
        COLOR = min(texture(panorama, uv).rgb * 0.40, vec3(3.0));
    } else {
        // Use the photographic sky above the horizon, excluding nearby buildings.
        float altitude = clamp(EYEDIR.y, 0.0, 1.0);
        vec3 photograph = texture(panorama, vec2(longitude, mix(0.24, 0.015, pow(altitude, 0.6)))).rgb;
        photograph = photograph / (vec3(1.0) + photograph);
        vec3 horizon = vec3(0.67, 0.41, 0.23);
        vec3 zenith = photograph * vec3(0.65, 0.85, 1.0);
        COLOR = mix(horizon, zenith, smoothstep(0.0, 0.48, altitude));
        if (EYEDIR.y < 0.0) COLOR = mix(horizon, vec3(0.045, 0.065, 0.045), smoothstep(0.0, 0.18, -EYEDIR.y));
    }
}
