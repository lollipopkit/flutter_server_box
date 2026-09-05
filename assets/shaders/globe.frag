#version 460 core

// The sphere itself: its shading, its edge, and the haze around it.
//
// Only the body of the globe. The coastlines and the servers are drawn over
// this by `GlobePainter`, in Dart, because they are geometry that has to be
// hit-tested and animated rather than shaded.
//
// This is the first fragment shader in the project, so two things about it are
// deliberate rather than incidental:
//
//  - Uniforms are `float`, `vec2` and `vec4` only. A `vec3` is padded to four
//    components in some backends, and `FragmentShader.setFloat` indexes a flat
//    buffer, so a `vec3` in the middle silently shifts every uniform after it.
//    The light direction is therefore a `vec4` with an unused `w`.
//  - Nothing here is required. `GlobePainter` draws a plain radial gradient
//    when the program will not load, so a driver this does not compile on
//    costs the atmosphere and not the feature.
//
// Colours arrive premultiplied by nothing and are written straight out; the
// caller passes theme colours in, which is the reason this is a shader and not
// an image.

#include <flutter/runtime_effect.glsl>

precision highp float;

// Where the disc is, in the coordinates `FlutterFragCoord` reports.
uniform vec2 uCenter;
uniform float uRadius;

// Where the light comes from, in the same frame the projection uses: x right,
// y up, z toward the viewer. `w` is unused padding — see the note above.
uniform vec4 uLight;

// The sphere where it faces the light, and where it does not. Two colours
// rather than one and a multiplier, so a theme can make the dark side tend
// toward its own background instead of toward black.
uniform vec4 uLit;
uniform vec4 uShadow;

// The haze outside the outline. Its alpha is the strength at the edge.
uniform vec4 uGlow;

// Fades the whole thing in as the globe opens.
uniform float uOpacity;

out vec4 fragColor;

void main() {
  vec2 p = FlutterFragCoord().xy - uCenter;
  float dist = length(p);
  float r = dist / uRadius;

  // One pixel, in the units `r` is measured in. Every edge below is softened
  // over this rather than over a constant, so the globe is as smooth at 80
  // pixels across as at 800.
  float px = 1.0 / max(uRadius, 1.0);

  vec4 color = vec4(0.0);

  if (r < 1.0 + px) {
    // The surface normal, straight out of the orthographic projection: the
    // point on the unit sphere above this pixel.
    float z = sqrt(max(0.0, 1.0 - r * r));
    vec3 normal = vec3(p.x / uRadius, -p.y / uRadius, z);

    float lambert = dot(normal, normalize(uLight.xyz));
    // Wrapped, not clamped at zero. A hard terminator across the middle of a
    // small disc reads as the globe being cut in half; wrapping the falloff
    // keeps the whole sphere legible while still saying where the light is.
    float shade = clamp(lambert * 0.5 + 0.5, 0.0, 1.0);
    shade = smoothstep(0.0, 1.0, shade);

    vec4 surface = mix(uShadow, uLit, shade);

    // The limb darkens, which is what stops the disc reading as a flat circle.
    float limb = smoothstep(1.0, 0.86, r);
    surface.rgb *= mix(0.72, 1.0, limb);

    float inside = 1.0 - smoothstep(1.0 - px, 1.0 + px, r);
    color = surface * inside;
  }

  // The atmosphere: outside the outline, falling off over a fifth of the
  // radius. Added rather than blended, so it reads as light rather than as a
  // ring drawn around the globe.
  float halo = smoothstep(1.22, 1.0, r) * smoothstep(0.94, 1.0, r);
  color += vec4(uGlow.rgb, 1.0) * uGlow.a * halo;

  fragColor = color * uOpacity;
}
