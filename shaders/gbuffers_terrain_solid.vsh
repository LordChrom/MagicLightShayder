#version 330 compatibility

const vec2 maxLm = vec2(15.0/16.0);

uniform mat4 shadowModelViewInverse;
uniform vec3 cameraPosition;


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
	lmcoord = min(lmcoord,maxLm);
	glcolor = gl_Color;
	normal = gl_Normal;
}