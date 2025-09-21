float warp = 0.3;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 dc = abs(0.5 - uv);
    dc *= dc;
    uv.x = (uv.x - 0.5) * (1.0 + dc.y * (0.3 * warp)) + 0.5;
    uv.y = (uv.y - 0.5) * (1.0 + dc.x * (0.4 * warp)) + 0.5;
    vec3 color = texture(iChannel0, uv).rgb;
    fragColor = vec4(color, 1.0);
}
