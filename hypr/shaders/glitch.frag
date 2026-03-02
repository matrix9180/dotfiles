// http://www.shadertoy.com/view/MlVSD3
// Ported for Hyprland screen_shader

#version 300 es
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
uniform float time;
out vec4 fragColor;

#define GRID_X 12.0
#define GRID_Y 8.0
#define SCANLINE_INTENSITY 0.12
#define SCANLINE_COUNT 400.0
#define CRT_WARMTH vec3(1.04, 0.98, 0.93)

float rand(vec2 co){
  return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

float rand_signed(vec2 co){
  return rand(co) * 2.0 - 1.0;
}

void main() {
  // Divide screen into a grid of cells
  vec2 cell = floor(v_texcoord * vec2(GRID_X, GRID_Y));

  // Each cell gets its own random trigger at varying rates
  float cellSeed = rand(cell * 17.3);
  float rate = 0.4 + cellSeed * 0.8;
  float n1 = rand(vec2(floor(time * rate), cellSeed * 100.0));
  float n2 = rand(vec2(floor(time * rate * 1.7), cellSeed * 200.0));

  // Only a few cells glitch at any time
  float cellTrigger = n1 * n2;
  float glitchActive = smoothstep(0.85, 0.93, cellTrigger);

  float off = rand_signed(vec2(floor(time * 8.0), cell.y + cell.x * GRID_Y)) * 0.025 * glitchActive;

  vec4 base = texture(tex, v_texcoord);
  float r = texture(tex, v_texcoord + vec2(off, 0.0)).r;
  float b = texture(tex, v_texcoord - vec2(off * 0.5, 0.0)).b;

  vec3 color = vec3(r, base.g, b);

  // Constant CRT scanlines and warm tint
  float scanline = pow(sin(v_texcoord.y * SCANLINE_COUNT * 3.14159265), 2.0);
  color *= 1.0 - SCANLINE_INTENSITY * scanline;
  color *= CRT_WARMTH;

  fragColor = vec4(color, base.a);
}
