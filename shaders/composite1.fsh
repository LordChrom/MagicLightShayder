#version 430 compatibility
#include "/lib/voxel/voxelSampler.glsl"


uniform sampler2D colortex4;
//uniform sampler2D depthtex0;
uniform sampler2D depthtex2;

uniform float viewWidth;
uniform float viewHeight;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

in vec2 texcoord;


/* RENDERTARGETS: 6 */
layout(location = 0) out vec4 lighting;

void main() {
	vec2 newTexCoord = texcoord/LIGHTING_RENDERSCALE;
	if(newTexCoord.x>1 || newTexCoord.y>1) return;
	ivec2 texpos = ivec2(newTexCoord*vec2(viewWidth,viewHeight));

//	float depth = texelFetch(depthtex0,texpos,0).x;
	float solidDepth = texelFetch(depthtex2,texpos,0).x;
	vec4 normalAndMore = texelFetch(colortex4,texpos,0);

	vec3 ndcPos = vec3(vec3(newTexCoord,solidDepth)*2-1);

	vec3 normal = normalize(normalAndMore.xyz*2-1);

	if(normalAndMore.a>0.5) //currently, normal.a only stores if it is or isnt the hand
		ndcPos.z/=MC_HAND_DEPTH;

	vec4 viewPos = gbufferProjectionInverse*vec4(ndcPos,1);
	viewPos/=viewPos.w;

	vec3 worldPos = (gbufferModelViewInverse*viewPos).xyz+cameraPosition;



	bool voxelLit = isVoxelInBounds(worldPos+normal);
	if(voxelLit){
		vec3 voxelLight = voxelSample(worldPos,normal);
		lighting=vec4(voxelLight,1);
	}else{
		lighting=vec4(0);
	}
}