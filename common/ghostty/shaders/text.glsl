const float SHARPEN_STRENGTH = 0.80;
const float RADIUS_PX = 1.10;
const float EDGE_THRESHOLD = 0.01;
const float CLAMP_MAX = 0.20;

const vec3 LUMA_COEFF = vec3(0.2126, 0.7152, 0.0722);

float luma(vec3 c) {
  return dot(c, LUMA_COEFF);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 uv = fragCoord / iResolution.xy;
  vec2 d = (1.0 / iResolution.xy) * RADIUS_PX;
  vec3 c = texture(iChannel0, uv).rgb;

  vec3 neighbors = texture(iChannel0, uv + vec2(-d.x, 0.0)).rgb;
  neighbors += texture(iChannel0, uv + vec2(d.x, 0.0)).rgb;
  neighbors += texture(iChannel0, uv + vec2(0.0, -d.y)).rgb;
  neighbors += texture(iChannel0, uv + vec2(0.0, d.y)).rgb;

  float lc = luma(c);
  float ln = luma(neighbors);
  float e = 0.2 * abs(4.0 * lc - ln);

  float mask = smoothstep(EDGE_THRESHOLD, EDGE_THRESHOLD * 4.0, e);
  vec3 detail = 0.8 * c - 0.2 * neighbors;
  vec3 outColor = c + clamp(detail, -CLAMP_MAX, CLAMP_MAX) * (SHARPEN_STRENGTH * mask);
  fragColor = vec4(outColor, 1.0);
}
