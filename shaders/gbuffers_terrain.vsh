#version 330 compatibility

uniform mat4 shadowModelViewInverse;
uniform vec3 cameraPosition;

//in vec4 at_midBlock;
//in vec3 gl_Normal;

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 worldPos;
out vec3 normal;

void main() {
	worldPos = gl_Vertex.xyz-gl_ProjectionMatrix[3].xyz+cameraPosition;
	worldPos+= gl_Normal*0.001;


	gl_Position = ftransform();

	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
	normal = gl_Normal;
}