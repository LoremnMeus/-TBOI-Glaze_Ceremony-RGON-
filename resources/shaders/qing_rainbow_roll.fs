#ifndef GL_ES
#  define lowp
#  define mediump
#endif

// Qing Remaster：连续轮转彩虹重着色（Roll v3）
//
// Colorize.r = packed spatial
//   high 4 bit: direction index
//   low  4 bit: density index
// Colorize.g = luminanceLow
// Colorize.b = luminanceHigh（High<=Low+eps → 默认 0.03–0.92）
// Colorize.a = final phase（Lua 已混入 seed / speed / time direction）
//
// ColorOffset.r = grayHueWeight   灰度对 Hue 相位的影响（0..1）
// ColorOffset.g = spatialBend     极坐标弯曲强度（0..1）
// ColorOffset.b = shapeContrast   明暗结构对比（0..1 → gamma）
//
// ColorOffset 不再作为最终 RGB 加色；本 shader 专用。

varying lowp vec4 Color0;
varying mediump vec2 TexCoord0;
varying lowp vec4 ColorizeOut;
varying lowp vec3 ColorOffsetOut;
varying lowp vec2 TextureSizeOut;
varying lowp float PixelationAmountOut;
varying lowp vec3 ClipPlaneOut;

uniform sampler2D Texture0;

const float TAU = 6.28318530717958647692;

const float BLACK_LOW = 0.040;
const float BLACK_HIGH = 0.120;

const float MAX_GRAY_HUE_SPAN = 0.60;
const float MAX_BEND_SPAN = 0.20;
const float MIN_SHAPE_GAMMA = 0.80;
const float MAX_SHAPE_GAMMA = 1.80;

// 噪声扰动保持弱固定（不进 7 参数）
const float BEND_AMOUNT = 0.025;
const float FINE_DRIFT = 0.008;
const float HUE_REMAP_MIX = 0.30;

const float VALUE_MIN = 0.22;
const float VALUE_MAX = 1.00;
const float HIGHLIGHT_LIFT = 0.08;

float hash12(vec2 p)
{
	float h = dot(p, vec2(127.1, 311.7));
	return fract(sin(h) * 43758.5453123);
}

float noise2D(vec2 p)
{
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float getLuminance(vec3 c)
{
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float densityFromIndex(float i)
{
	if (i < 0.5) return 0.25;
	if (i < 1.5) return 0.40;
	if (i < 2.5) return 0.60;
	if (i < 3.5) return 0.80;
	if (i < 4.5) return 1.00;
	if (i < 5.5) return 1.25;
	if (i < 6.5) return 1.50;
	if (i < 7.5) return 1.75;
	if (i < 8.5) return 2.00;
	if (i < 9.5) return 2.30;
	if (i < 10.5) return 2.60;
	if (i < 11.5) return 3.00;
	if (i < 12.5) return 3.50;
	if (i < 13.5) return 4.00;
	if (i < 14.5) return 5.00;
	return 6.00;
}

vec3 rainbowPalette(float t)
{
	t = fract(t);

	vec3 c0 = vec3(1.00, 0.10, 0.16);
	vec3 c1 = vec3(1.00, 0.34, 0.10);
	vec3 c2 = vec3(1.00, 0.62, 0.08);
	vec3 c3 = vec3(1.00, 0.90, 0.14);
	vec3 c4 = vec3(0.55, 1.00, 0.22);
	vec3 c5 = vec3(0.20, 0.88, 1.00);
	vec3 c6 = vec3(0.18, 0.52, 1.00);
	vec3 c7 = vec3(0.38, 0.26, 1.00);
	vec3 c8 = vec3(0.86, 0.16, 1.00);
	vec3 c9 = vec3(1.00, 0.12, 0.52);

	if (t < 0.10) return mix(c0, c1, t / 0.10);
	if (t < 0.18) return mix(c1, c2, (t - 0.10) / 0.08);
	if (t < 0.28) return mix(c2, c3, (t - 0.18) / 0.10);
	if (t < 0.34) return mix(c3, c4, (t - 0.28) / 0.06);
	if (t < 0.42) return mix(c4, c5, (t - 0.34) / 0.08);
	if (t < 0.56) return mix(c5, c6, (t - 0.42) / 0.14);
	if (t < 0.68) return mix(c6, c7, (t - 0.56) / 0.12);
	if (t < 0.82) return mix(c7, c8, (t - 0.68) / 0.14);
	if (t < 0.92) return mix(c8, c9, (t - 0.82) / 0.10);
	return mix(c9, c0, (t - 0.92) / 0.08);
}

vec4 rainbowRollRecolor(
	vec4 source,
	vec2 uv,
	vec2 textureSize,
	float phase,
	float packedSpatial,
	float lumLow,
	float lumHigh,
	float grayHueWeight,
	float bendWeight,
	float shapeContrast
)
{
	if (source.a <= 0.001)
		return source;

	float sourceStrength = max(source.r, max(source.g, source.b));
	float recolorMask = smoothstep(BLACK_LOW, BLACK_HIGH, sourceStrength);

	float rawLum = getLuminance(source.rgb);
	float remappedLum = clamp(
		(rawLum - lumLow) / max(lumHigh - lumLow, 0.001),
		0.0,
		1.0
	);

	vec2 p = uv - vec2(0.5);
	vec2 pixelPos = uv * textureSize;

	float packed = floor(packedSpatial * 255.0 + 0.5);
	float directionIndex = floor(packed / 16.0);
	float densityIndex = mod(packed, 16.0);

	float spatialAngle = directionIndex * (TAU / 16.0);
	vec2 spatialDir = vec2(cos(spatialAngle), sin(spatialAngle));
	float spatialDensity = densityFromIndex(densityIndex);

	float spatialPhase = dot(p, spatialDir) * spatialDensity;

	float polarPhase = atan(p.y, p.x) / TAU;
	float bendSpan = clamp(bendWeight, 0.0, 1.0) * MAX_BEND_SPAN;
	spatialPhase += polarPhase * bendSpan;

	float hueLum = mix(rawLum, remappedLum, HUE_REMAP_MIX);
	float grayHueSpan = clamp(grayHueWeight, 0.0, 1.0) * MAX_GRAY_HUE_SPAN;
	float luminancePhase = (hueLum - 0.5) * grayHueSpan;

	float noiseSeed = packedSpatial;
	float bend = (noise2D(pixelPos * 0.11 + vec2(noiseSeed * 13.17, noiseSeed * 37.91)) - 0.5) * BEND_AMOUNT;

	float cycle = phase * TAU;
	float fine = (noise2D(
		pixelPos * 0.27 +
		vec2(91.7 + noiseSeed * 7.1, 11.3 + noiseSeed * 5.3) +
		vec2(cos(cycle), sin(cycle)) * 0.35
	) - 0.5) * FINE_DRIFT;

	float hueT = fract(
		phase +
		spatialPhase +
		luminancePhase +
		bend +
		fine
	);

	vec3 rainbowRGB = rainbowPalette(hueT);

	float shapeGamma = mix(
		MIN_SHAPE_GAMMA,
		MAX_SHAPE_GAMMA,
		clamp(shapeContrast, 0.0, 1.0)
	);
	float shapedLum = pow(smoothstep(0.0, 1.0, remappedLum), shapeGamma);
	float shapeValue = mix(VALUE_MIN, VALUE_MAX, shapedLum);
	rainbowRGB *= shapeValue;

	float lift = smoothstep(0.76, 1.0, remappedLum) * HIGHLIGHT_LIFT;
	rainbowRGB = clamp(rainbowRGB + vec3(lift), 0.0, 1.0);

	vec3 finalRGB = mix(source.rgb, rainbowRGB, recolorMask);
	return vec4(finalRGB, source.a);
}

void main(void)
{
	vec3 ClipPlane = ClipPlaneOut;
	if (dot(gl_FragCoord.xy, ClipPlane.xy) < ClipPlane.z)
		discard;

	vec2 TextureSize = max(TextureSizeOut, vec2(1.0, 1.0));
	vec4 source = texture2D(Texture0, TexCoord0);
	if (source.a == 0.0)
		discard;

	float phase = ColorizeOut.a;
	float packedSpatial = ColorizeOut.r;
	float lumLow = ColorizeOut.g;
	float lumHigh = ColorizeOut.b;

	float grayHueWeight = ColorOffsetOut.r;
	float bendWeight = ColorOffsetOut.g;
	float shapeContrast = ColorOffsetOut.b;

	if (lumHigh <= lumLow + 0.001)
	{
		lumLow = 0.03;
		lumHigh = 0.92;
	}

	vec4 Color = rainbowRollRecolor(
		source,
		TexCoord0,
		TextureSize,
		phase,
		packedSpatial,
		lumLow,
		lumHigh,
		grayHueWeight,
		bendWeight,
		shapeContrast
	);
	Color *= Color0;
	gl_FragColor = Color;
}
