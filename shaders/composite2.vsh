#version 430 compatibility
uniform int frameCounter;
uniform vec2 scaledScreenDim;
#include "/lib/settings.glsl"

#ifdef TAA
#include "/lib/util/taaJitter.glsl"
#endif

out vec2 jitteredTexcoord;

void main() {
	gl_Position = ftransform();
	jitteredTexcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	#ifdef TAA
	jitteredTexcoord+=jitter();
	#endif
}