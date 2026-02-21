#version 430 compatibility
#include "/lib/voxel/voxelSampler.glsl"


uniform sampler2D colortex0;
uniform sampler2D colortex4; //normal
uniform sampler2D colortex5; //color
uniform sampler2D depthtex0;

uniform float viewWidth;
uniform float viewHeight;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

in vec2 texcoord;


/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	float depth = texture(depthtex0,texcoord).x;
	vec3 screenPos = vec3(texcoord,depth);
	vec4 viewPos = gbufferProjectionInverse*vec4(screenPos*2-1,1);
	viewPos/=viewPos.w;
	vec3 worldPos = (gbufferModelViewInverse*viewPos).xyz+cameraPosition;

//	vec3 normal = normalize(texture(colortex4,texcoord).xyz*2-1);
	vec3 normal = normalize(texelFetch(colortex4,ivec2(texcoord*vec2(viewWidth,viewHeight)),0).xyz*2-1);

	vec4 albedo = texture(colortex0, texcoord);

	worldPos+=normal*0.005;

	vec3 light;

	bool voxelLit = isVoxelInBounds(worldPos);
//	voxelLit = true;
	if(voxelLit){
		vec3 voxelLight = voxelSample(worldPos,normal);
		light=voxelLight;
	}else{
		light=texture(colortex5,texcoord).xyz;
	}


	albedo.xyz*=light;
	color = albedo;

}