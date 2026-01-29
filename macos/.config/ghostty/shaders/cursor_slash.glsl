// Dark mode
const vec4 COLOR = vec4(0.651, 0.859, 1.0, 1.0);
const vec4 COLOR_ACCENT = vec4(0.878, 0.886, 0.918, 1.0);

// Light mode
// const vec4 COLOR = vec4(0.0, 0.0, 0.0, 1.0);
// const vec4 COLOR_ACCENT = vec4(0.0, 0.0, 0.0, 1.0);

// Configuration
const float DURATION = 0.2;
const float INTENSITY = 1.0;
const float DISTANCE_THRESHOLD = 3.4;
const float SMOOTHNESS = 0.001;

// Pre-calculate saturation constants
const vec4 LUMA = vec4(0.299, 0.587, 0.114, 0.0);
#define SAT(c) mix(vec4(dot(c, LUMA)), c, 1.5)
const vec4 SAT_COLOR = SAT(COLOR);
const vec4 SAT_ACCENT = SAT(COLOR_ACCENT);

float sdBox(in vec2 p, in vec2 b) {
  vec2 d = abs(p) - b;
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float edge(vec2 p, vec2 a, vec2 b, inout float d, inout float s) {
  vec2 e = b - a;
  vec2 w = p - a;
  vec2 proj = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
  d = min(d, dot(proj, proj));

  bvec3 c = bvec3(p.y >= a.y, p.y < b.y, e.x * w.y > e.y * w.x);
  if (all(c) || all(not(c))) s *= -1.0;
  return d;
}

float sdQuad(in vec2 p, in vec2 v0, in vec2 v1, in vec2 v2, in vec2 v3) {
  float d = dot(p - v0, p - v0);
  float s = 1.0;

  edge(p, v0, v1, d, s);
  edge(p, v1, v2, d, s);
  edge(p, v2, v3, d, s);
  edge(p, v3, v0, d, s);

  return s * sqrt(d);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 uv = fragCoord / iResolution.xy;
  vec4 texColor = texture(iChannel0, uv);

  if (INTENSITY <= 0.0) {
    fragColor = texColor;
    return;
  }

  vec2 r = iResolution.xy;
  vec2 p = (2.0 * fragCoord - r) / r.y;

  vec4 cur = iCurrentCursor;
  vec4 prev = iPreviousCursor;

  vec2 scalePos = vec2(2.0, 2.0) / r.y;
  vec2 scaleSize = vec2(2.0) / r.y;

  cur.xy = (cur.xy * 2.0 - r) / r.y;
  cur.zw *= scaleSize;
  prev.xy = (prev.xy * 2.0 - r) / r.y;
  prev.zw *= scaleSize;

  vec2 cCur = vec2(cur.x + cur.z * 0.5, cur.y - cur.w * 0.5);
  vec2 cPrev = vec2(prev.x + prev.z * 0.5, prev.y - prev.w * 0.5);

  float dist = distance(cCur, cPrev);

  vec2 offset = cur.zw * vec2(-0.5, 0.5);
  float sdfCur = sdBox(p - (cur.xy - offset), cur.zw * 0.5);

  bool trailEnabled = dist <= DISTANCE_THRESHOLD;
  float sdfTrail = 1e5;

  if (trailEnabled) {
    vec2 delta = cCur - cPrev;
    float dir = step(0.0, delta.x * delta.y);
    float invDir = 1.0 - dir;

    vec2 v0 = vec2(cur.x + cur.z * dir, cur.y - cur.w);
    vec2 v1 = vec2(cur.x + cur.z * invDir, cur.y);
    vec2 v2 = vec2(prev.x + prev.z * invDir, prev.y);
    vec2 v3 = vec2(prev.x + prev.z * dir, prev.y - prev.w);

    sdfTrail = sdQuad(p, v0, v1, v2, v3);
  }

  float progress = clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0);
  float invP = 1.0 - progress;
  float easedProgress = invP * invP * invP;

  vec4 trail = texColor;

  if (trailEnabled) {
    float aaTrail = smoothstep(-SMOOTHNESS, SMOOTHNESS, sdfTrail);
    float aaTrailBorder = smoothstep(-SMOOTHNESS * 0.5, SMOOTHNESS * 0.5, sdfTrail);
    trail = mix(SAT_ACCENT, trail, aaTrail);
    trail = mix(SAT_COLOR, trail, aaTrailBorder);
  }

  float aaCur = smoothstep(-SMOOTHNESS, SMOOTHNESS, sdfCur);
  float aaCurBorder = smoothstep(-SMOOTHNESS * 0.5, SMOOTHNESS * 0.5, sdfCur);

  trail = mix(SAT_ACCENT, trail, aaCur);
  trail = mix(SAT_COLOR, trail, aaCurBorder);

  float wipe = 1.0 - smoothstep(0.0, max(0.0, sdfCur + 0.05), easedProgress * dist);
  fragColor = mix(texColor, mix(trail, texColor, wipe), INTENSITY);
}
