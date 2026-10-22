// the cursor itself glides between cells instead of jumping.
// Ghostty's own cursor must be hidden:
//
//     cursor-opacity = 0
//     custom-shader  = "./shaders/cursor_wire.glsl"

// --- CONFIGURATION ---
const float DURATION = 0.1; // seconds for one glide
const float BORDER_RATIO = 0.08; // border thickness as a fraction of cell height
const float MIN_BORDER = 2.0; // px; bar/underline cursors up to 2x this thick draw solid
const float CURSOR_SCALE_X = 1.3; // cursor width multiplier, centered on the cell
const float CURSOR_SCALE_Y = 1; // cursor height multiplier, centered on the cell

// sRGB -> linear: uniforms arrive as sRGB, iChannel0 and the output are linear.
vec3 sRGBToLinear(vec3 c) {
  return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

// EaseOutCubic — swap for any of the curves in cursor_sweep.glsl.
float ease(float x) {
  return 1.0 - pow(1.0 - x, 3.0);
}

// iCurrentCursor/iPreviousCursor are (left, top-edge, width, height) in
// pixels with shadertoy's y-up convention: the rect spans [y - h, y].
vec2 rectCenter(vec4 r) {
  return vec2(r.x + r.z * 0.5, r.y - r.w * 0.5);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec4 tex = texture(iChannel0, fragCoord / iResolution.xy);
  fragColor = tex;

  vec4 cur = iCurrentCursor;
  vec4 prev = iPreviousCursor;
  // An all-zero previous cursor is the first frame after launch; don't
  // glide in from the window corner.
  if (dot(prev.zw, prev.zw) == 0.0) prev = cur;

  float t = clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0);
  float e = ease(t);

  vec2 center = mix(rectCenter(prev), rectCenter(cur), e);
  vec2 halfSize = mix(prev.zw, cur.zw, e) * 0.5 * vec2(CURSOR_SCALE_X, CURSOR_SCALE_Y);
  vec3 rgb = sRGBToLinear(mix(iPreviousCursorColor.rgb, iCurrentCursorColor.rgb, e));

  // Snap edges to whole pixels so every side gets the same thickness.
  vec2 lo = round(center - halfSize);
  vec2 hi = round(center + halfSize);

  // Based on cell height (bar/block rects) rather than the cursor's own
  // height, which for an underline is just its thickness.
  float border = max(MIN_BORDER, round(BORDER_RATIO * max(prev.w, cur.w)));

  // Wire = inside the rect but outside the rect shrunk by `border`.
  // A bar/underline is thinner than 2 * border, so the shrunk rect is empty
  // and it comes out solid with no special case.
  bool inside = all(greaterThan(fragCoord, lo)) && all(lessThan(fragCoord, hi));
  bool hole = all(greaterThan(fragCoord, lo + border)) && all(lessThan(fragCoord, hi - border));
  fragColor = mix(tex, vec4(rgb, 1.0), float(inside && !hole));
}
