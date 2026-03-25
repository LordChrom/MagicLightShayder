#version 430 compatibility
#include "/lib/settings.glsl"


uniform sampler2D colortex0;
uniform sampler2D colortex5;


#if LIGHTING_RENDERSCALE >= 1
#include "/lib/renderComponents/voxelLightingComposite.glsl"
#else
uniform sampler2D colortex6;
uniform sampler2D colortex7;
#endif


uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;


/* RENDERTARGETS: 0 */
layout(location = 0) out vec3 color;

void main() {
	ivec2 texpos = ivec2(texcoord*vec2(viewWidth,viewHeight));
	vec4 albedo = texelFetch(colortex0,texpos,0);
	vec3 light = texelFetch(colortex5,texpos,0).xyz;

#ifdef DEBUG_WHITEN
	albedo.xyz=vec3(DEBUG_WHITE_LEVEL);
#endif

#if LIGHTING_RENDERSCALE >= 1
	doVoxelLighting(texcoord,texpos);
#else
	vec4 voxelLighting = texture(colortex6,texcoord* LIGHTING_RENDERSCALE );
	vec4 voxelFog = texture(colortex7,texcoord* LIGHTING_RENDERSCALE );
#endif

	if( voxelLighting.a>0.1 && light!=vec3(1)){
		light=voxelLighting.xyz;
	}


	color = albedo.xyz*light;

#if VOLUMETRIC_FOG_SAMPLES > 0
	float fogThickness = clamp(voxelFog.a,0,0.7);
	color = color*(1-fogThickness) + voxelFog.rgb;
#endif

}