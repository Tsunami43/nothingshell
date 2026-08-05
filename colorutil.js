// Pure colour maths behind the palette (see the role block in Config.qml).
//
// `.pragma library`: parsed once per engine and shared by every importer, at the cost of no
// access to QML objects. Every function here is therefore pure and takes its inputs
// explicitly -- including the light/dark flag, because derivation genuinely differs between
// the two modes. Inputs are QML `color` values, whose .r/.g/.b/.a are plain 0..1 numbers;
// outputs are "#aarrggbb" strings, which QML coerces back to `color` on assignment. That
// keeps this file dependent on nothing but Math -- Qt.rgba() included, since the Qt global
// is not reliably reachable from a library script.
.pragma library

function _cl(x) { return x < 0 ? 0 : (x > 1 ? 1 : x); }

// sRGB <-> linear light. Blending gamma-encoded channels directly muddies the midpoint of
// every mix, so all blending below round-trips through linear light.
function _lin(u) { return u <= 0.04045 ? u / 12.92 : Math.pow((u + 0.055) / 1.055, 2.4); }
function _enc(u) { return u <= 0.0031308 ? u * 12.92 : 1.055 * Math.pow(u, 1 / 2.4) - 0.055; }

function _h2(v) { var s = Math.round(_cl(v) * 255).toString(16); return s.length < 2 ? "0" + s : s; }
function _hex(o) { return "#" + _h2(o.a) + _h2(o.r) + _h2(o.g) + _h2(o.b); }
function _obj(c) { return { r: c.r, g: c.g, b: c.b, a: (c.a === undefined ? 1 : c.a) }; }

function _mix(a, b, t) {
    t = _cl(t);
    return {
        r: _enc(_lin(a.r) * (1 - t) + _lin(b.r) * t),
        g: _enc(_lin(a.g) * (1 - t) + _lin(b.g) * t),
        b: _enc(_lin(a.b) * (1 - t) + _lin(b.b) * t),
        a: a.a * (1 - t) + b.a * t
    };
}

var BLACK = { r: 0, g: 0, b: 0, a: 1 };
var WHITE = { r: 1, g: 1, b: 1, a: 1 };

// ---------------------------------------------------------------- public --

function mix(a, b, t) { return _hex(_mix(_obj(a), _obj(b), t)); }

// Replace the alpha channel outright; the RGB is passed through untouched.
function alpha(c, a) { return "#" + _h2(a) + _h2(c.r) + _h2(c.g) + _h2(c.b); }

function lum(c) { return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b); }

function contrast(a, b) {
    var x = lum(a), y = lum(b);
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
}

// Drive `c` to an absolute relative-luminance target by mixing toward black or white.
// This is the replacement for Qt.lighter()/Qt.darker(), which scale HSV *value* and so
// no-op on pure black, clip near white, and can hand back a lighter grey when asked to
// darken a near-black. The chosen pole always brackets the target, so a bisection is
// correct at both ends of the range.
function tone(c, target) {
    var o = _obj(c), L = lum(o);
    if (Math.abs(L - target) < 0.002) return _hex(o);
    var up = target > L, pole = up ? WHITE : BLACK;
    var lo = 0, hi = 1;
    for (var i = 0; i < 14; i++) {
        var m = (lo + hi) * 0.5;
        // Luminance is monotonic in the mix factor: rising toward white, falling toward black.
        if ((lum(_mix(o, pole, m)) > target) === up) hi = m; else lo = m;
    }
    return _hex(_mix(o, pole, (lo + hi) * 0.5));
}

// One elevation tier up (n > 0) or down (n < 0). The caller supplies the poles because
// "up" means toward the text colour in a dark theme -- that is Material's surface tint,
// and it keeps the theme's hue -- but toward white in a light one.
function step(c, n, hi, lo, per) {
    if (!n) return _hex(_obj(c));
    return mix(c, n > 0 ? hi : lo, Math.min(0.65, Math.abs(n) * (per === undefined ? 0.07 : per)));
}

function _toHsl(o) {
    var mx = Math.max(o.r, o.g, o.b), mn = Math.min(o.r, o.g, o.b);
    var l = (mx + mn) / 2, d = mx - mn, h = 0, s = 0;
    if (d > 1e-7) {
        s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
        if (mx === o.r)      h = ((o.g - o.b) / d + (o.g < o.b ? 6 : 0)) / 6;
        else if (mx === o.g) h = ((o.b - o.r) / d + 2) / 6;
        else                 h = ((o.r - o.g) / d + 4) / 6;
    }
    return { h: h, s: s, l: l };
}

function _chan(p, q, t) {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
}

function _fromHsl(h, s, l, a) {
    if (s <= 0) return _hex({ r: l, g: l, b: l, a: a });
    var q = l < 0.5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q;
    return _hex({ r: _chan(p, q, h + 1 / 3), g: _chan(p, q, h), b: _chan(p, q, h - 1 / 3), a: a });
}

// Rebuild a colour at a new hue, keeping the source's saturation and lightness feel. This
// is how success/warning/info are invented for a palette that omits them -- and for every
// matugen block, which has no green or amber role to map from in the first place.
//
// Saturation and lightness are both floored/clamped: carrying a pale accent's lightness
// straight over produces a washed-out pastel that reads as decoration rather than status,
// and a very dark accent produces something invisible. The band keeps a synthesised status
// colour legible against every surface tier while still leaning toward the theme.
function hueAt(c, h, minS, band) {
    var o = _obj(c), t = _toHsl(o);
    var lo = band ? band[0] : 0.42, hi = band ? band[1] : 0.68;
    var l = t.l < lo ? lo : (t.l > hi ? hi : t.l);
    return _fromHsl(h, Math.max(t.s, minS === undefined ? 0.45 : minS), l, o.a);
}

// Offset a colour's hue by `delta` turns, keeping it in the same saturation/lightness band.
// Used to lay out a categorical data ramp: rotating off the accent guarantees the slots stay
// perceptually apart in every theme, which reusing the semantic roles did not -- info is
// usually the same hue family as a blue accent, and success as a green one.
function hueRotate(c, delta, minS, band) {
    var t = _toHsl(_obj(c));
    var h = (t.h + delta) % 1;
    return hueAt(c, h < 0 ? h + 1 : h, minS, band);
}

// Pick whichever candidate reads better on `bgC`. If neither clears `ratio`, drive the
// better one to an extreme rather than hand back something unreadable.
function readable(bgC, candA, candB, ratio) {
    var a = contrast(bgC, candA), b = contrast(bgC, candB);
    var win = a >= b ? candA : candB;
    if (Math.max(a, b) >= (ratio === undefined ? 4.5 : ratio)) return _hex(_obj(win));
    return tone(win, lum(bgC) > 0.4 ? 0.02 : 0.95);
}
