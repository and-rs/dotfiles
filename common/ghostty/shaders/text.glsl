const float SHARPEN_STRENGTH = 0.45;
const float RADIUS_PX        = 1.0;
const float EDGE_THRESHOLD   = 0.015;

const vec3 LUMA_COEFF = vec3(0.2126, 0.7152, 0.0722);

float luma(vec3 c) { return dot(c, LUMA_COEFF); }

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 d  = (1.0 / iResolution.xy) * RADIUS_PX;

    vec4 src = texture(iChannel0, uv);
    vec3 c   = src.rgb;
    float a  = src.a;

    vec3 n0 = texture(iChannel0, uv + vec2(-d.x,  0.0)).rgb;
    vec3 n1 = texture(iChannel0, uv + vec2( d.x,  0.0)).rgb;
    vec3 n2 = texture(iChannel0, uv + vec2( 0.0, -d.y)).rgb;
    vec3 n3 = texture(iChannel0, uv + vec2( 0.0,  d.y)).rgb;
    vec3 n4 = texture(iChannel0, uv + vec2(-d.x, -d.y)).rgb;
    vec3 n5 = texture(iChannel0, uv + vec2( d.x, -d.y)).rgb;
    vec3 n6 = texture(iChannel0, uv + vec2(-d.x,  d.y)).rgb;
    vec3 n7 = texture(iChannel0, uv + vec2( d.x,  d.y)).rgb;

    vec3 neighbor_avg = (n0 + n1 + n2 + n3 + 0.5 * (n4 + n5 + n6 + n7)) / 6.0;

    float lc   = luma(c);
    float ln   = luma(n0 + n1 + n2 + n3);
    float edge = abs(4.0 * lc - ln) * 0.25;
    float mask = smoothstep(EDGE_THRESHOLD, EDGE_THRESHOLD * 4.0, edge);

    float luma_hp = lc - luma(neighbor_avg);
    float delta   = clamp(luma_hp * SHARPEN_STRENGTH * mask, -0.4, 0.4);

    fragColor = vec4(clamp(c + vec3(delta), 0.0, 1.0), a);
}
