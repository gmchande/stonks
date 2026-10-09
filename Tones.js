// How the theme's colours are put to work: which colour is up, how much
// quieter secondary text is, and how strongly a chart's wash lies over the
// ground. Every colour comes in from the theme; none is chosen here.
// Colours are { r, g, b } in 0..1, as a QML color is; a colour made here is
// a "#rrggbb" string, which a QML color property takes.

// A theme's colour by its first key present, read the way the shell reads
// colors.toml (`Color.loadColors`): `green`, else the terminal's `color2`.
function themeColor(toml, keys) {
  for (var k = 0; k < keys.length; k++) {
    var pattern = new RegExp("^\\s*" + keys[k] + "\\s*=\\s*[\"']?(#[0-9A-Fa-f]{6})", "m")
    var match = pattern.exec(String(toml || ""))
    if (match) return match[1]
  }
  return ""
}

function hexColor(text) {
  var m = /^#([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})$/.exec(String(text || ""))
  return m ? { r: parseInt(m[1], 16) / 255, g: parseInt(m[2], 16) / 255, b: parseInt(m[3], 16) / 255 } : null
}

function hexOf(c) {
  var two = function(v) {
    var n = Math.round(Math.max(0, Math.min(1, v)) * 255)
    return (n < 16 ? "0" : "") + n.toString(16)
  }
  return "#" + two(c.r) + two(c.g) + two(c.b)
}

function linear(v) {
  return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
}

function oklab(c) {
  var r = linear(c.r), g = linear(c.g), b = linear(c.b)
  var l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
  var m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
  var s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
  return {
    L: 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    a: 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    b: 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
  }
}

function oklabLightness(c) {
  return oklab(c).L
}

// How far apart two colours look: the straight line between them in OKLab,
// where black to white is 1.
function oklabDistance(x, y) {
  var p = oklab(x), q = oklab(y)
  return Math.sqrt(Math.pow(p.L - q.L, 2) + Math.pow(p.a - q.a, 2) + Math.pow(p.b - q.b, 2))
}

// Closer than this, up and down read as one colour. The four themes whose
// green and red are both blues, greys, or greens sit at 0.049 to 0.063;
// every other installed theme's pair is at least 0.114 apart.
var UP_DOWN_APART = 0.10

// Up is the theme's green, as Omarchy colours success in every app it
// themes; never the accent, which means selected. Where the green (a
// "#rrggbb" from colors.toml, or "") is too close to down (the shell's
// urgent, the theme's red) or missing, up is the plain foreground, as the
// shell shows a good state beside a bad one.
function upColor(green, down, foreground) {
  var g = hexColor(green)
  return g && oklabDistance(g, down) >= UP_DOWN_APART ? green : foreground
}

// WCAG 2's contrast between two opaque colours.
function contrast(x, y) {
  var lum = function(c) { return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b) }
  var a = lum(x), b = lum(y)
  return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05)
}

function mixed(from, to, share) {
  return {
    r: from.r + (to.r - from.r) * share,
    g: from.g + (to.g - from.g) * share,
    b: from.b + (to.b - from.b) * share
  }
}

// Secondary text: the foreground mixed `share` of the way toward the ground
// it sits on, so it is quieter on a light theme as on a dark one, but never
// under `floor` contrast against that ground. Dim takes a third and keeps
// body text's 4.5:1; dimmer takes half and keeps 3:1.
var DIM = { share: 0.32, floor: 4.5 }
var DIMMER = { share: 0.5, floor: 3 }

function secondary(foreground, ground, level) {
  if (contrast(foreground, ground) <= level.floor) return hexOf(foreground)
  if (contrast(mixed(foreground, ground, level.share), ground) >= level.floor)
    return hexOf(mixed(foreground, ground, level.share))
  var lo = 0, hi = level.share
  for (var i = 0; i < 30; i++) {
    var mid = (lo + hi) / 2
    if (contrast(mixed(foreground, ground, mid), ground) >= level.floor) lo = mid
    else hi = mid
  }
  return hexOf(mixed(foreground, ground, lo))
}

function dim(foreground, ground) {
  return secondary(foreground, ground, DIM)
}

function dimmer(foreground, ground) {
  return secondary(foreground, ground, DIMMER)
}

// A wash is a colour at some alpha over the surface's ground. At one alpha a
// dark red adds far less light than a light blue, so a down day's wash would
// look half as present as an up day's. Each side's alpha is worked out from
// the theme instead: the alpha at which its colour adds the same lightness,
// OKLab's L, over the ground as the up colour does at the alpha the chart
// sets.

// The lightness `color` at `alpha` adds over `ground`, either way, mixed
// channel by channel in sRGB, as a canvas composites it.
function addedLightness(color, ground, alpha) {
  return Math.abs(oklabLightness(mixed(ground, color, alpha)) - oklabLightness(ground))
}

// The alpha at which `color` over `ground` adds the lightness `reference`
// adds at `alpha`: `alpha` itself for the reference. Never more than half
// `ink`, the alpha of the line or cap it sits under, so the line and the
// caps stay the most important thing: a pale up colour over a dark red
// (Kanagawa) would otherwise take the red's stems to solid ink.
function washAlpha(color, reference, ground, alpha, ink) {
  var cap = ink / 2
  var target = addedLightness(reference, ground, alpha)
  if (addedLightness(color, ground, cap) <= target) return cap
  var lo = 0
  var hi = cap
  for (var i = 0; i < 30; i++) {
    var mid = (lo + hi) / 2
    if (addedLightness(color, ground, mid) < target) lo = mid
    else hi = mid
  }
  return (lo + hi) / 2
}
