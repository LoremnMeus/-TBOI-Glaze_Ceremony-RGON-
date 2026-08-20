#ifndef GL_ES
#  define lowp
#  define mediump
#endif

// Qing Remaster：基于 coloroffset_dogma
// - 纯蓝键色：与原版一致，整段替换为噪点灰阶（皮肤高光/静态区）
// - 其余有色差像素：先转亮度灰阶，再按亮度与噪点混合（不保留原色）
// - Colorize.r = UV glitch（默认 0）；Colorize.a = 时间轴
// - 忽略 PixelationAmount

varying lowp vec4 Color0;
varying mediump vec2 TexCoord0;
varying lowp vec4 ColorizeOut;
varying lowp vec3 ColorOffsetOut;
varying lowp vec2 TextureSizeOut;
varying lowp float PixelationAmountOut;
varying lowp vec3 ClipPlaneOut;

uniform sampler2D Texture0;

const vec3 _lum = vec3(0.212671, 0.715160, 0.072169);

vec3 mod289(vec3 x)
{
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec2 mod289(vec2 x)
{
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec3 permute(vec3 x)
{
	return mod289(((x * 34.0) + 1.0) * x);
}

float snoise(vec2 v)
{
	const vec4 C = vec4(0.211324865405187,
	                    0.366025403784439,
	                   -0.577350269189626,
	                    0.024390243902439);
	vec2 i  = floor(v + dot(v, C.yy));
	vec2 x0 = v - i + dot(i, C.xx);
	vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
	vec4 x12 = x0.xyxy + C.xxzz;
	x12.xy -= i1;
	i = mod289(i);
	vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0))
	               + i.x + vec3(0.0, i1.x, 1.0));
	vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
	m = m * m;
	m = m * m;
	vec3 x = 2.0 * fract(p * C.www) - 1.0;
	vec3 h = abs(x) - 0.5;
	vec3 ox = floor(x + 0.5);
	vec3 a0 = x - ox;
	m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
	vec3 g;
	g.x  = a0.x * x0.x + h.x * x0.y;
	g.yz = a0.yz * x12.xz + h.yz * x12.yw;
	return 130.0 * dot(m, g);
}

void main(void)
{
	vec4 Colorize = ColorizeOut;
	vec3 ColorOffset = ColorOffsetOut;
	vec2 TextureSize = TextureSizeOut;
	vec3 ClipPlane = ClipPlaneOut;
	float PixelationAmount = 0.0;

	if (dot(gl_FragCoord.xy, ClipPlane.xy) < ClipPlane.z)
		discard;

	vec2 pa = vec2(1.0 + PixelationAmount, 1.0 + PixelationAmount) / max(TextureSize, vec2(1.0, 1.0));
	vec2 uv_aligned = TexCoord0 - mod(TexCoord0, pa) + pa * 0.5;
	vec2 uv = TexCoord0;

	float uOffset = snoise(vec2(Colorize.a * 1000.0, TextureSize.x * 0.5 * uv_aligned.y));
	uOffset = uOffset * Colorize.r * 10.0 / max(TextureSize.x, 1.0);
	uv.x += uOffset;

	vec4 Color = texture2D(Texture0, uv);
	if (Color.a == 0.0)
		discard;

	float mx = max(Color.r, max(Color.g, Color.b));
	float mn = min(Color.r, min(Color.g, Color.b));
	float chroma = mx - mn;
	float lum = dot(Color.rgb, _lum);

	vec2 NoiseUV = gl_FragCoord.xy + vec2(Colorize.a * 10000.0, Colorize.a * 10000.0);
	NoiseUV -= mod(NoiseUV, vec2(2.0, 2.0));

	// 原版蓝键：r==g 且 b>r → 整段替换为噪点（皮肤静态高光）
	if (Color.r == Color.g && Color.b > Color.r)
	{
		float a = mix((snoise(NoiseUV) + 0.5) * Color.b, Color.b, Color.r / max(Color.b, 0.001));
		Color.r = Color.g = Color.b = a;
	}
	else
	{
		// 先灰阶，再按亮度与噪点混合（暗部几乎纯灰、无噪点）
		float gray = lum;
		float brightGate = smoothstep(0.04, 0.45, lum);
		float chromaGate = smoothstep(0.01, 0.08, chroma);
		// 已是灰阶时仍允许按亮度带一点噪点，但更弱
		float strength = brightGate * max(chromaGate, 0.35 * brightGate);

		float n = (snoise(NoiseUV) + 0.5) * max(mx, gray);
		Color.rgb = mix(vec3(gray, gray, gray), vec3(n, n, n), strength);
	}

	Color *= Color0;
	gl_FragColor = vec4(Color.rgb + ColorOffset * Color.a, Color.a);
}
