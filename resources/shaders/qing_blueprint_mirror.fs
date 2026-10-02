#ifndef GL_ES
#  define lowp
#  define mediump
#endif

// 蓝图镜像模块：青蓝全息 + 轻扫描线 + 微色差（Colorize.a=时间，Colorize.r=seed，Colorize.g=强度）

varying lowp vec4 Color0;
varying mediump vec2 TexCoord0;
varying lowp vec4 ColorizeOut;
varying lowp vec3 ColorOffsetOut;
varying lowp vec2 TextureSizeOut;
varying lowp float PixelationAmountOut;
varying lowp vec3 ClipPlaneOut;

uniform sampler2D Texture0;

const vec3 _lum = vec3(0.212671, 0.715160, 0.072169);

void main(void)
{
	vec3 ClipPlane = ClipPlaneOut;
	if (dot(gl_FragCoord.xy, ClipPlane.xy) < ClipPlane.z)
		discard;

	float phase = ColorizeOut.a;
	float seed = ColorizeOut.r;
	float strength = clamp(ColorizeOut.g, 0.35, 1.25);

	vec2 uv = TexCoord0;
	float split = 0.0025 + seed * 0.0015;
	vec4 srcG = texture2D(Texture0, uv);
	if (srcG.a == 0.0)
		discard;

	float r = texture2D(Texture0, uv + vec2(split, 0.0)).r;
	float g = srcG.g;
	float b = texture2D(Texture0, uv - vec2(split, 0.0)).b;
	vec3 rgb = vec3(r, g, b);

	float lum = dot(rgb, _lum);
	vec3 holo = vec3(lum * 0.48, lum * 0.92, lum * 1.18);
	holo = mix(rgb, holo, 0.72 * strength);

	float scan = 0.82 + 0.18 * sin((TexCoord0.y * 96.0 + phase * 6.2831853) + seed * 17.0);
	holo *= scan;

	float edge = smoothstep(0.02, 0.22, lum);
	holo += vec3(0.08, 0.16, 0.28) * edge * strength;

	vec4 Color = vec4(clamp(holo * (1.05 + strength * 0.18), 0.0, 1.0), srcG.a);
	Color *= Color0;
	gl_FragColor = vec4(Color.rgb + ColorOffsetOut * Color.a, Color.a);
}
