#version 430 compatibility

layout (rgba16f) uniform readonly restrict image3D lightVox;

#include "/lib/voxel/voxelBoundsCheck.glsl"
#include "/lib/voxel/voxelDebugSampler.glsl"


uniform sampler2D lightmap;
uniform sampler2D gtexture;

uniform float alphaTestRef = 0.1;

const vec2 maxLm = vec2(15.0/16.0,15.0/16.0);

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 worldPos;
in vec3 normal;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	color = texture(gtexture, texcoord) * glcolor;
	vec4 vanillaLightingColor = texture(lightmap, min(lmcoord,maxLm));

	bool voxelLit = isVoxelInBounds(worldPos);
	if(voxelLit){
		vec4 voxelLight = voxelSample(worldPos,normal);
		color.rgb*=voxelLight.a*0.9+0.1;
	}else{
		color *= vanillaLightingColor;
	}
	if (color.a < alphaTestRef) {
		discard;
	}
}