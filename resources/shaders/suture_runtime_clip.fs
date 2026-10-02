#ifndef GL_ES
#  define lowp
#  define mediump
#endif

varying lowp vec4 Color0;
varying mediump vec2 TexCoord0;
varying mediump vec2 TextureSize0;
varying mediump vec2 LogicalSize0;
varying mediump vec2 CutOrigin0;
varying mediump vec2 CutNormal0;
varying lowp float KeepSign0;
varying lowp float Feather0;

uniform sampler2D Texture0;

void main(void)
{
	// TexCoord is padded-UV space. Convert to 0~1 over the logical image.
	vec2 logical = max(LogicalSize0, vec2(1.0));
	vec2 localUV = (TexCoord0 * TextureSize0) / logical;

	vec2 n = CutNormal0;
	float nLen = length(n);
	if (nLen > 0.0001) {
		n = n / nLen;
	} else {
		n = vec2(1.0, 0.0);
	}

	float side = dot(localUV - CutOrigin0, n);
	float keep = KeepSign0;
	if (abs(keep) < 0.001) {
		keep = -1.0;
	}
	float signedSide = side * keep;
	float feather = max(Feather0, 0.0);
	if (feather <= 0.0001) {
		if (signedSide > 0.0) {
			discard;
		}
		gl_FragColor = Color0 * texture2D(Texture0, TexCoord0);
	} else {
		float alphaMul = 1.0 - smoothstep(0.0, feather, signedSide);
		if (alphaMul <= 0.001) {
			discard;
		}
		vec4 c = Color0 * texture2D(Texture0, TexCoord0);
		gl_FragColor = vec4(c.rgb, c.a * alphaMul);
	}
}
