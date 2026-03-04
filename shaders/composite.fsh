#version 430 compatibility
#include "/lib/voxel/voxelSampler.glsl"


uniform sampler2D colortex0;
uniform sampler2D colortex4; //normal
uniform sampler2D colortex5; //color
uniform sampler2D depthtex0;
uniform sampler2D depthtex2;

uniform float viewWidth;
uniform float viewHeight;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
//uniform vec3 cameraPosition;

in vec2 texcoord;


/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	float depth = texture(depthtex0,texcoord).x;

	float solidDepth = texture(depthtex2,texcoord).x;

	vec3 ndcPos = vec3(vec3(texcoord,solidDepth)*2-1);

	vec4 normalAndMore = texelFetch(colortex4,ivec2(texcoord*vec2(viewWidth,viewHeight)),0);
	vec3 normal = normalize(normalAndMore.xyz*2-1);

	if(normalAndMore.a>0.5) //currently, normal.a only stores if it is or isnt the hand
		ndcPos.z/=MC_HAND_DEPTH;

	vec4 viewPos = gbufferProjectionInverse*vec4(ndcPos,1);
	viewPos/=viewPos.w;

	vec3 worldPos = (gbufferModelViewInverse*viewPos).xyz+cameraPosition;
	worldPos+=normal*0.005;



	vec4 albedo = texture(colortex0, texcoord);


	vec3 light = texture(colortex5,texcoord).xyz;

	bool voxelLit = isVoxelInBounds(worldPos) && light!=vec3(1);
//		voxelLit=false;
	if(voxelLit){
		vec3 voxelLight = voxelSample(worldPos,normal);
		light=voxelLight;
	}
	if(light==vec3(0))
		light=vec3(1);


	albedo.xyz*=light;
	color = albedo;

}