const vec4 CURSOR_COLOR = vec4(0.651, 0.859, 1.0, 1.0);
const float DURATION = 0.3;
const float GLOW_SIZE = 0.006;
const float GLOW_INTENSITY = 1.0;

float sdBox(in vec2 p, in vec2 xy, in vec2 b)
{
    vec2 d = abs(p - xy) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

vec2 normalize(vec2 value, float isPosition) {
    return (value * 2.0 - (iResolution.xy * isPosition)) / iResolution.y;
}

float easeInOutQuad(float t) {
    return t < 0.5 ? 2.0 * t * t : -1.0 + (4.0 - 2.0 * t) * t;
}

float easeOutQuad(float t) {
    return 1.0 - (1.0 - t) * (1.0 - t);
}

float easeInQuad(float t) {
    return t * t;
}

float easeInOutCubic(float t) {
    return t < 0.5 ? 4.0 * t * t * t : 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0;
}

float ParametricBlend(float t) {
    float sqr = t * t;
    return sqr / (2.0 * (sqr - t) + 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    #if !defined(WEB)
    fragColor = texture(iChannel0, fragCoord.xy / iResolution.xy);
    #endif

    vec2 vu = normalize(fragCoord, 1.);
    vec2 offsetFactor = vec2(-.5, 0.5);

    vec4 currentCursor = vec4(normalize(iCurrentCursor.xy, 1.), normalize(iCurrentCursor.zw, 0.));

    float t = clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0);
    float progress = easeInOutQuad(t);

    float cCursorDistance = sdBox(vu, currentCursor.xy - (currentCursor.zw * offsetFactor), currentCursor.zw * 0.5);
    float glowAlpha = (1.0 - smoothstep(cCursorDistance, -0.000, GLOW_SIZE * (1.0 - progress))) * GLOW_INTENSITY;
    fragColor = mix(fragColor, CURSOR_COLOR, glowAlpha);
}
