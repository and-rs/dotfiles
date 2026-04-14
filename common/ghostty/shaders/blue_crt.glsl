const float SHADOW_CRUSH = 3.0;
const float HIGHLIGHT_ROLL = 2.0;
const float MIDPOINT = 0.2;

const float BRIGHTNESS = 1.7;

const vec3 BG_COLOR = vec3(0.039, 0.082, 0.125);
const vec3 TINT_COLOR = vec3(0.627, 0.941, 1.0);

float lumaOf(vec3 c) {
  return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float tonemap(float x) {
  x = clamp(x, 0.0, 1.0);
  if (x < MIDPOINT) {
    float t = x / MIDPOINT;
    return MIDPOINT * pow(t, SHADOW_CRUSH);
  } else {
    float t = (x - MIDPOINT) / (1.0 - MIDPOINT);
    return MIDPOINT + (1.0 - MIDPOINT) * pow(t, HIGHLIGHT_ROLL);
  }
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 uv = fragCoord / iResolution.xy;
  vec4 src = texture(iChannel0, uv);
  float luma = lumaOf(src.rgb);
  luma = clamp(tonemap(luma) * BRIGHTNESS, 0.0, 1.0);
  vec3 color = mix(BG_COLOR, TINT_COLOR, luma);
  fragColor = vec4(color, src.a);
}
