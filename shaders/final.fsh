#version 430 compatibility
#include "/lib/voxel/voxelSampler.glsl"


uniform sampler2D colortex0;
uniform sampler2D colortex5;
uniform sampler2D colortex6;

in vec2 texcoord;


uniform float viewWidth;
uniform float viewHeight;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec3 color;

void main() {
	ivec2 texpos = ivec2(texcoord*vec2(viewWidth,viewHeight));
//	vec4 albedo = texture(colortex0, texcoord);
//	vec3 light = texture(colortex5,texcoord).xyz;
	vec4 albedo = texelFetch(colortex0,texpos,0);
	vec3 light = texelFetch(colortex5,texpos,0).xyz;
	vec4 voxelLighting = texture(colortex6,texcoord*LIGHTING_RENDERSCALE);

	if( voxelLighting.a>0.1 && light!=vec3(1)){
		light=voxelLighting.xyz;
	}


	color = albedo.xyz*light;

}