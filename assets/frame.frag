#version 440
// Unified frame + popout bulge. Bar (thick left) smin thin border → coves; plus an optional
// popout body box smin'd in so the bar surface bulges out to form the open popout, no seam.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;
    float barW;
    float t;
    float r;
    float k;
    float popK;
    vec4 pop;        // open popout body: x, y, w, h (screen px); w<=0 = none
    vec4 pop2;       // second bulge (e.g. a toast): x, y, w, h (screen px); w<=0 = none
    vec4 pop3;       // third bulge (the right-edge side panel): x, y, w, h (screen px); w<=0 = none
    vec4 fillColor;
    vec4 bevelColor; // edge tint blended into the fill along the border
    float bevelR;    // bevel width (px); <=0 = flat fill
    float bevelA;    // bevel strength at the very edge
    float bevelDir;  // +1 when bevelColor is a highlight, -1 when it is a contact shadow
};
float sdRound(vec2 p, vec2 c, vec2 h, float rr) {
    vec2 d = abs(p - c) - h + vec2(rr);
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - rr;
}
float smin(float a, float b, float kk) {
    return max(kk, min(a, b)) - length(max(vec2(kk) - vec2(a, b), vec2(0.0)));
}
void main() {
    vec2 p = qt_TexCoord0 * res;
    float dBar = p.x - barW;
    vec2 c = res * 0.5;
    vec2 h = vec2(res.x * 0.5 - t, res.y * 0.5 - t);
    float dThin = -sdRound(p, c, h, r);
    float d = smin(dBar, dThin, k);

    // Bulge the bar out into the open popout body.
    if (pop.z > 0.5) {
        vec2 pc = pop.xy + pop.zw * 0.5;
        vec2 ph = pop.zw * 0.5;
        float dPop = sdRound(p, pc, ph, r);
        d = smin(d, dPop, popK);
    }

    // Second bulge (e.g. a toast melting out of the top border).
    if (pop2.z > 0.5) {
        vec2 pc2 = pop2.xy + pop2.zw * 0.5;
        vec2 ph2 = pop2.zw * 0.5;
        float dPop2 = sdRound(p, pc2, ph2, r);
        d = smin(d, dPop2, popK);
    }

    // Third bulge (the side panel flowing out of the right border).
    if (pop3.z > 0.5) {
        vec2 pc3 = pop3.xy + pop3.zw * 0.5;
        vec2 ph3 = pop3.zw * 0.5;
        float dPop3 = sdRound(p, pc3, ph3, r);
        d = smin(d, dPop3, popK);
    }

    float aa = fwidth(d);
    float alpha = 1.0 - smoothstep(-aa, aa, d);

    // Lit edge: the fill shifts towards bevelColour along the border. The layer's drop shadow
    // (see Frame.qml) only reads against light content, so on dark themes this is what makes
    // the frame, the bar and every bulge look raised rather than flat.
    float bevel = bevelR > 0.0 ? exp(-max(-d, 0.0) / bevelR) * bevelA : 0.0;

    // ...but lighting every edge equally reads as a glow, not as depth, because real light
    // arrives from somewhere. The SDF's gradient is the outward normal, so n.y says which way
    // an edge faces, and one overhead source then falls out of the geometry: the top lip of
    // the content recess is overhung and sits in shadow, while the bottom lip catches light,
    // and the popout bulges — protrusions rather than recesses — shade the opposite way on
    // their own. No special cases, just the normal.
    //
    // The shadowed side is floored rather than cut to zero. A pure directional term drops one
    // edge to nothing, and the borders are 8px against windows that are usually dark, so that
    // edge would stop separating the frame from the window at all.
    // bevelDir flips the whole thing for a light theme, where bevelColor is a contact shadow
    // rather than a highlight: there "more bevel" means darker, so the overhung lip wants more
    // of it, not less. Without the flip the light themes shade as if lit from below.
    //
    // The + is not a typo and the sign is not free to flip: dFdy is taken in window
    // coordinates, whose y direction is the viewport's, not qt_TexCoord0's. It comes out
    // inverted from what reading the math suggests, so check a screenshot after touching this
    // rather than trusting the sign — light landing on the underside is the tell.
    vec2 g = vec2(dFdx(d), dFdy(d));
    float ny = dot(g, g) > 1e-12 ? normalize(g).y : 0.0;
    float lit = 0.4 + 0.6 * clamp(0.5 + 0.5 * ny * bevelDir, 0.0, 1.0);

    fragColor = mix(fillColor, bevelColor, bevel * lit) * alpha * qt_Opacity;
}
