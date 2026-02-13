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

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	color = texture(gtexture, texcoord) * glcolor;
	vec4 vanillaLightingColor = texture(lightmap, lmcoord);

	bool voxelLit = isVoxelInBounds(worldPos);
	if(voxelLit){
		vec3 voxelLight = voxelSample(worldPos,normal);
		color.rgb*=voxelLight;
	}else{
		color *= vanillaLightingColor;
	}
	if (color.a < alphaTestRef) {
		discard;
	}
}