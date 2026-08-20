#ifndef GL_ES
#  define lowp
#  define mediump
#endif

// Qing Remaster：动态高饱和彩虹 Voronoi 色域重着色（coloroffset 同签名）
// 控制通道（与 dogma 一致，走 Colorize；勿当最终加色）：
//   Colorize.a = phase ∈ [0,1) 循环时间（仅驱动局部振荡，不整环扫 Hue）
//   Colorize.r = seed ∈ [0,1) 实例种子
//   ColorOffset 保持 0（最终可按常规叠加，通常为 0）
// Palette 定色，cell/noise/shimmer 只在附近漂移；HSV 后做软感知亮度补偿。

varying lowp vec4 Color0;
varying mediump vec2 TexCoord0;
varying lowp vec4 ColorizeOut;
varying lowp vec3 ColorOffsetOut;
varying lowp vec2 TextureSizeOut;
varying lowp float PixelationAmountOut;
varying lowp vec3 ClipPlaneOut;

uniform sampler2D Texture0;

// -----------------------------------------------------------------------------
// Tunables
// -----------------------------------------------------------------------------
const float TAU = 6.28318530717958647692;

// 更小色块（32×32 上约更密的晶片）
const float CELL_SIZE = 2.35;
const float CELL_WARP = 1.35;

const float DARK_THRESHOLD = 0.28;
const float BRIGHT_THRESHOLD = 0.64;

const float SHADOW_HUE = -0.045;
const float MID_HUE = 0.0;
const float HIGHLIGHT_HUE = 0.055;

const float SHADOW_SAT = 0.95;
const float MID_SAT = 1.00;
const float HIGHLIGHT_SAT = 0.88;

const float SHADOW_VALUE = 0.48;
const float MID_VALUE = 0.78;
const float HIGHLIGHT_VALUE = 1.00;

// 动感：只在 baseHue 附近漂移（禁止 baseHue+phase 整环旋转）
const float CELL_HUE_WAVE = 0.022;
const float NOISE_HUE_AMOUNT = 0.065;
const float FINE_SHIMMER = 0.010;

const float BLACK_LOW = 0.045;
const float BLACK_HIGH = 0.10;

// HSV→RGB 后软补偿感知亮度（压青绿、抬红蓝）
const float PERCEPTUAL_TARGET_LUM = 0.32;
const float PERCEPTUAL_MIX = 0.35;

// -----------------------------------------------------------------------------
// Hash / noise / HSV
// -----------------------------------------------------------------------------
float hash12(vec2 p)
{
	float h = dot(p, vec2(127.1, 311.7));
	return fract(sin(h) * 43758.5453123);
}

vec2 hash22(vec2 p)
{
	float x = hash12(p + vec2(17.17, 91.73));
	float y = hash12(p + vec2(73.31, 11.97));
	return vec2(x, y);
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

vec3 hsv2rgb(vec3 c)
{
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

float getLuminance(vec3 c)
{
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

/*
 * 加权色相表（16 档）：palette 是主人，动画只在附近漂移。
 * 红/玫红 6 · 橙 2 · 绿 1 · 青蓝 3 · 紫品红 4；无 teal。
 */
float weightedPaletteHue(float u)
{
	float i = floor(clamp(u, 0.0, 0.9999) * 16.0);

	if (i < 0.5) return 0.000;
	if (i < 1.5) return 0.015;
	if (i < 2.5) return 0.035;
	if (i < 3.5) return 0.060;
	if (i < 4.5) return 0.925;
	if (i < 5.5) return 0.965;
	if (i < 6.5) return 0.085;
	if (i < 7.5) return 0.115;
	if (i < 8.5) return 0.355;
	if (i < 9.5) return 0.525;
	if (i < 10.5) return 0.600;
	if (i < 11.5) return 0.665;
	if (i < 12.5) return 0.735;
	if (i < 13.5) return 0.800;
	if (i < 14.5) return 0.855;
	return 0.900;
}

// Warp ONLY color-cell lookup space (not texture UV).
vec2 warpCellSpace(vec2 pixelPos, float seed)
{
	float wx = noise2D(pixelPos * 0.095 + vec2(seed * 3.17, seed * 7.91));
	float wy = noise2D(pixelPos * 0.095 + vec2(31.7 + seed * 5.13, 79.2 + seed * 2.71));
	return pixelPos + (vec2(wx, wy) - 0.5) * CELL_WARP;
}

// xy = winning cell ID, zw = cell center in texel space
vec4 getVoronoiCell(vec2 pixelPos, float cellSize, float seed)
{
	vec2 p = pixelPos / cellSize;
	vec2 baseCell = floor(p);
	vec2 localPos = fract(p);

	float minDist = 99999.0;
	vec2 bestID = vec2(0.0);
	vec2 bestCenter = vec2(0.0);

	for (int y = -1; y <= 1; y++)
	{
		for (int x = -1; x <= 1; x++)
		{
			vec2 neighbor = vec2(float(x), float(y));
			vec2 cellID = baseCell + neighbor;
			vec2 rnd = hash22(cellID + vec2(seed * 17.31, seed * 41.73));
			vec2 randomPoint = mix(vec2(0.15), vec2(0.85), rnd);
			vec2 point = neighbor + randomPoint;
			vec2 delta = point - localPos;
			float distSq = dot(delta, delta);

			if (distSq < minDist)
			{
				minDist = distSq;
				bestID = cellID;
				bestCenter = (cellID + randomPoint) * cellSize;
			}
		}
	}

	return vec4(bestID, bestCenter);
}

vec4 rainbowCellularRecolor(vec4 source, vec2 uv, vec2 textureSize, float phase, float seed)
{
	if (source.a <= 0.001)
		return source;

	float sourceStrength = max(source.r, max(source.g, source.b));
	vec2 pixelPos = uv * textureSize;
	vec2 cellSpacePos = warpCellSpace(pixelPos, seed);

	vec4 cellData = getVoronoiCell(cellSpacePos, CELL_SIZE, seed);
	vec2 cellID = cellData.xy;

	float rawPick = hash12(cellID + vec2(seed * 13.17, seed * 37.91));
	float baseHue = weightedPaletteHue(rawPick);

	phase = fract(phase);
	float cycle = phase * TAU;

	// Palette 为基色；phase 只驱动局部振荡（禁止 +phase 整环扫色）
	float hue = baseHue;

	float cellPhase = hash12(cellID + vec2(71.13 + seed * 3.1, 19.37 + seed * 7.7));
	float cellWave = sin(cycle + cellPhase * TAU);
	hue += cellWave * CELL_HUE_WAVE;

	vec2 noiseOrbit1 = vec2(cos(cycle), sin(cycle)) * 1.20;
	float noise1 = noise2D(cellID * 0.38 + noiseOrbit1 + vec2(seed * 5.13));

	vec2 noiseOrbit2 = vec2(cos(-cycle * 2.0 + 1.7), sin(-cycle * 2.0 + 1.7)) * 0.65;
	float noise2 = noise2D(cellID * 0.71 + noiseOrbit2 + vec2(31.17 + seed * 9.71));

	float dynamicNoise = noise1 * 0.70 + noise2 * 0.30;
	hue += (dynamicNoise - 0.5) * NOISE_HUE_AMOUNT;

	float fineNoise = noise2D(
		pixelPos * 0.18 +
		vec2(cos(cycle), sin(cycle)) * 0.45 +
		vec2(seed)
	);
	hue += (fineNoise - 0.5) * FINE_SHIMMER;

	float lum = getLuminance(source.rgb);
	float saturation;
	float value;

	if (lum < DARK_THRESHOLD)
	{
		hue += SHADOW_HUE;
		saturation = SHADOW_SAT;
		value = SHADOW_VALUE;
	}
	else if (lum < BRIGHT_THRESHOLD)
	{
		hue += MID_HUE;
		saturation = MID_SAT;
		value = MID_VALUE;
	}
	else
	{
		hue += HIGHLIGHT_HUE;
		saturation = HIGHLIGHT_SAT;
		value = HIGHLIGHT_VALUE;
	}

	hue = fract(hue);
	vec3 rainbowRGB = hsv2rgb(vec3(hue, saturation, value));

	// HSV V≠感知亮度：软拉向目标 luminance，避免青绿抢眼、红蓝发闷
	float generatedLum = getLuminance(rainbowRGB);
	float correction = PERCEPTUAL_TARGET_LUM / max(generatedLum, 0.08);
	correction = mix(1.0, correction, PERCEPTUAL_MIX);
	rainbowRGB = clamp(rainbowRGB * correction, 0.0, 1.0);

	float recolorMask = smoothstep(BLACK_LOW, BLACK_HIGH, sourceStrength);
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

	// 与 dogma 相同：Colorize.a=时间，Colorize.r=附加参数（此处为 seed）
	float phase = ColorizeOut.a;
	float seed = ColorizeOut.r;

	vec4 Color = rainbowCellularRecolor(source, TexCoord0, TextureSize, phase, seed);
	Color *= Color0;
	gl_FragColor = vec4(Color.rgb + ColorOffsetOut * Color.a, Color.a);
}
