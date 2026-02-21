#version 430 compatibility


//#include "/lib/voxel/voxelHelper.glsl"
#include "/lib/voxel/voxelSampler.glsl"


uniform sampler2D lightmap;
uniform sampler2D gtexture;

uniform float alphaTestRef = 0.1;

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 worldPos;
in vec3 normal;

/* RENDERTARGETS: 0,4,5 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 normalOut;
layout(location = 2) out vec4 vanillaLighting;

void main() {
	color = texture(gtexture, texcoord) * glcolor;
	vanillaLighting = texture(lightmap, lmcoord);

	normalOut = vec4((normal+1)*0.5,0);

	if (color.a < alphaTestRef) {
		discard;
	}
}