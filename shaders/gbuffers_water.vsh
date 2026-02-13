#version 330 compatibility

const vec2 maxLm = vec2(15.0/16.0);

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmcoord = min(lmcoord,maxLm);
	glcolor = gl_Color;
}