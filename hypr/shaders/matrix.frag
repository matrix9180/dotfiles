// Matrix code rain overlay shader for Hyprland screen_shader

#version 300 es
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
uniform float time;
out vec4 fragColor;

// --- Tunables ---
#define OPACITY 0.05
#define COLUMNS 120.0
#define CHAR_ROWS 80.0
#define TAIL 0.30
#define SPEED 0.04
#define ACTIVE_FRAC 0.4         // Fraction of columns active at once (0.0–1.0)

const int NUM_DROPS = 3;
const vec3 GREEN = vec3(0.0, 1.0, 0.35);
const vec3 WHITE = vec3(0.7, 1.0, 0.85);

// Simple float hash — just needs to look random per-column
float H(float n) { return fract(sin(n * 91.3458) * 47453.5453); }

void main() {
    vec4 scr = texture(tex, v_texcoord);
    float y = v_texcoord.y;
    float col = floor(v_texcoord.x * COLUMNS);

    // Only a fraction of columns are active — slowly rotates over time
    float colPhase = H(col * 53.7) + time * 0.01;
    float colOn = step(1.0 - ACTIVE_FRAC, fract(colPhase));
    if (colOn < 0.5) {
        fragColor = scr;
        return;
    }

    // Soft glow per character cell (rounded rect feel)
    vec2 cell = fract(vec2(v_texcoord.x * COLUMNS, v_texcoord.y * CHAR_ROWS));
    cell = cell * 2.0 - 1.0; // -1..1
    float glow = 1.0 - smoothstep(0.3, 0.9, length(cell));

    // Cell-level random brightness variation (makes it look like different chars)
    float cellId = floor(v_texcoord.y * CHAR_ROWS);
    float charVar = 0.5 + 0.5 * H(col * 31.7 + cellId * 17.3);

    // Accumulate brightness from drops
    float bright = 0.0;
    float head = 0.0;

    for (int i = 0; i < NUM_DROPS; i++) {
        float fi = float(i);
        // Each drop gets unique speed + offset from column + drop index
        float s = SPEED * (0.4 + H(col * 3.17 + fi * 71.1) * 1.2);
        float o = H(col * 7.31 + fi * 43.7);
        float tl = TAIL * (0.5 + H(col * 11.3 + fi * 97.1) * 1.0);

        float headY = fract(time * s + o);

        // Wrap-aware distance behind the head
        float d = headY - y;
        d = d - floor(d); // always positive, wraps at 1

        if (d < tl) {
            float t = 1.0 - d / tl;
            bright += t * t;
            if (d < tl * 0.06) head = max(head, t);
        }
    }

    if (bright < 0.002) {
        fragColor = scr;
        return;
    }

    bright = min(bright, 1.5);
    vec3 rc = mix(GREEN, WHITE, head * 0.8);
    vec3 rain = rc * glow * charVar * bright;

    fragColor = vec4(scr.rgb + rain * OPACITY, scr.a);
}
