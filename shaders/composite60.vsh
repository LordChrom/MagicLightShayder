#version 430 compatibility
uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;

out vec2 texcoord;
out vec3 worldDirNormalizeMe;

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	worldDirNormalizeMe = gbufferModelViewInverse[3].xyz+mat3(gbufferModelViewInverse)*(
		gbufferProjectionInverse[3].xyz+(mat2x3(gbufferProjectionInverse)*(texcoord*2-1))
	);
}