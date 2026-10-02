attribute vec3 Position;
attribute vec4 Color;
attribute vec2 TexCoord;
attribute vec2 TextureSize;
attribute vec2 LogicalSize;
attribute vec2 CutOrigin;
attribute vec2 CutNormal;
attribute float KeepSign;
attribute float Feather;

varying vec4 Color0;
varying vec2 TexCoord0;
varying vec2 TextureSize0;
varying vec2 LogicalSize0;
varying vec2 CutOrigin0;
varying vec2 CutNormal0;
varying float KeepSign0;
varying float Feather0;

uniform mat4 Transform;

void main(void)
{
	Color0 = Color;
	TexCoord0 = TexCoord;
	TextureSize0 = TextureSize;
	LogicalSize0 = LogicalSize;
	CutOrigin0 = CutOrigin;
	CutNormal0 = CutNormal;
	KeepSign0 = KeepSign;
	Feather0 = Feather;
	gl_Position = Transform * vec4(Position.xyz, 1.0);
}
