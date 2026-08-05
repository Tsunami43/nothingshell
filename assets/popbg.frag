#version 440

// Popout background: a bar "wall" (left half-plane) smoothly SDF-unioned (smin) with the
// popout body (rounded box). The smin fillet is what makes the popout bulge out of the bar.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;        // item size in px
    float barX;      // x of the bar's right edge within the item (px)
    float rad;       // popout body corner radius
    float k;         // smin smoothing factor
    float inset;     // body top/bottom inset (leaves room for the cove)
    vec4 fillColor;  // opaque fill colour (a = 1)
};

float sdRound(vec2 p, vec2 c, vec2 h, float r) {
    vec2 d = abs(p - c) - h + vec2(r);
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - r;
}

float smin(float a, float b, float k) {
    // Circular smooth-min: true circular-arc fillet, deviates from min only where both a,b < k.
    return max(k, min(a, b)) - length(max(vec2(k) - vec2(a, b), vec2(0.0)));
}

void main() {
    vec2 p = qt_TexCoord0 * res;

    // Bar wall: everything left of barX belongs to the bar (SDF = signed distance to that edge).
    float dBar = p.x - barX;

    // Popout body: rounded box spanning barX..res.x horizontally, inset..res.y-inset vertically.
    float bx0 = barX;
    float bx1 = res.x;
    float by0 = inset;
    float by1 = res.y - inset;
    vec2 c = vec2((bx0 + bx1) * 0.5, (by0 + by1) * 0.5);
    vec2 h = vec2((bx1 - bx0) * 0.5, (by1 - by0) * 0.5);
    float dBody = sdRound(p, c, h, rad);

    float d = smin(dBar, dBody, k);

    float aa = fwidth(d);
    float alpha = 1.0 - smoothstep(-aa, aa, d);
    fragColor = fillColor * alpha * qt_Opacity;
}
