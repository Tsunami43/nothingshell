#version 440

// Popout background (TOP-oriented): a top "wall" (top half-plane, the screen frame edge)
// smoothly SDF-unioned (smin) with the popout body (rounded box hanging below). The smin
// fillet is the concave "cove" where the panel melts into the top edge — same idea as the
// bar popouts (popbg.frag) but the wall is on top instead of the left.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;        // item size in px
    float barY;      // y of the top edge (wall) within the item
    float rad;       // popout body corner radius
    float k;         // smin smoothing factor (cove size)
    float inset;     // body left/right inset (leaves room for the coves)
    vec4 fillColor;  // opaque fill colour (a = 1)
};

float sdRound(vec2 p, vec2 c, vec2 h, float r) {
    vec2 d = abs(p - c) - h + vec2(r);
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - r;
}

float smin(float a, float b, float k) {
    return max(k, min(a, b)) - length(max(vec2(k) - vec2(a, b), vec2(0.0)));
}

void main() {
    vec2 p = qt_TexCoord0 * res;

    // Top wall: everything above barY belongs to the frame edge.
    float dBar = p.y - barY;

    // Popout body: rounded box, inset..res.x-inset horizontally, barY..res.y vertically.
    float bx0 = inset;
    float bx1 = res.x - inset;
    float by0 = barY;
    float by1 = res.y;
    vec2 c = vec2((bx0 + bx1) * 0.5, (by0 + by1) * 0.5);
    vec2 h = vec2((bx1 - bx0) * 0.5, (by1 - by0) * 0.5);
    float dBody = sdRound(p, c, h, rad);

    float d = smin(dBar, dBody, k);

    float aa = fwidth(d);
    float alpha = 1.0 - smoothstep(-aa, aa, d);
    fragColor = fillColor * alpha * qt_Opacity;
}
