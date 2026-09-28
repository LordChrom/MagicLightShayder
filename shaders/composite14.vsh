#version 430 compatibility


out vec2 texcoord;
out vec3 worldPosDirection;

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}