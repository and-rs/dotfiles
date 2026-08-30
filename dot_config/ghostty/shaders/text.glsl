const float RADIUS_PX      = 1.4;
const float CONTRAST_GAIN  = 0.01;
const float EDGE_SOFTNESS  = 0;

const vec3 LUMA_COEFF = vec3(0.2126, 0.7152, 0.0722);

float luma(vec3 c) { return dot(c, LUMA_COEFF); }

float quantize3(float x) {
    if (x < 0.20) return 0.0;
    if (x < 0.60) return 0.5;
    return 1.0;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 d  = (1.0 / iResolution.xy) * RADIUS_PX;

    vec4 src = texture(iChannel0, uv);
    vec3 c   = src.rgb;

    vec3 n0 = texture(iChannel0, uv + vec2(-d.x,  0.0)).rgb;
    vec3 n1 = texture(iChannel0, uv + vec2( d.x,  0.0)).rgb;
    vec3 n2 = texture(iChannel0, uv + vec2( 0.0, -d.y)).rgb;
    vec3 n3 = texture(iChannel0, uv + vec2( 0.0,  d.y)).rgb;
    vec3 n4 = texture(iChannel0, uv + vec2(-d.x, -d.y)).rgb;
    vec3 n5 = texture(iChannel0, uv + vec2( d.x, -d.y)).rgb;
    vec3 n6 = texture(iChannel0, uv + vec2(-d.x,  d.y)).rgb;
    vec3 n7 = texture(iChannel0, uv + vec2( d.x,  d.y)).rgb;

    vec3 bg = (n0 + n1 + n2 + n3 + 0.5 * (n4 + n5 + n6 + n7)) / 6.0;

    float bg_luma   = luma(bg);
    float src_luma  = luma(c);
    float signal    = max(0.0, bg_luma - src_luma);
    float coverage  = clamp(signal * CONTRAST_GAIN / max(bg_luma, 0.001), 0.0, 1.0);
    float snapped   = quantize3(coverage);
    float blended   = mix(coverage, snapped, smoothstep(0.0, EDGE_SOFTNESS, abs(snapped - coverage)));
    vec3 out_rgb    = mix(bg, vec3(0.0), blended);

    fragColor = vec4(out_rgb, src.a);
}
