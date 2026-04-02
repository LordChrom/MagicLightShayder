#version 430 compatibility
#include "/lib/settings.glsl"
//#define FOG_BLUR_SNAPPED

#include "/lib/renderComponents/blur.glsl"
#include "/lib/util/blend.glsl"
#include "/lib/util/tonemap.glsl"

#if DEBUG_SPECIAL_VIEW >= 0
uniform sampler2D colortex15;
#endif

uniform sampler2D colortex0;
uniform sampler2D colortex6;
uniform sampler2D colortex7;

#ifdef VANILLA_FALLBACK
uniform sampler2D colortex5;
#endif

#ifdef TRANSLUCENT_SEPARATE_BUFFER
uniform sampler2D colortex1;
#endif

uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

/*
const int colortex3Format = RGBA8UI;
const int colortex6Format = RGB16F;
const int colortex7Format = RGBA16F;
*/

/* RENDERTARGETS: 0 */
layout(location = 0) out vec3 outputColor;

void main() {
	ivec2 texpos = ivec2(texcoord*vec2(viewWidth,viewHeight));
	vec4 albedo = texelFetch(colortex0,texpos,0);
	#ifdef TRANSLUCENT_SEPARATE_BUFFER
	vec4 transColor = texelFetch(colortex1,texpos,0);
//	albedo.xyz = albedo.xyz*(1-transColor.a)*transColor.xyz;
	albedo.xyz = blend(vec4(albedo.xyz,1),transColor);
	#endif
#ifdef VANILLA_FALLBACK
	vec3 light = texelFetch(colortex5,texpos,0).xyz;
#else
	vec3 light = vec3(1/15.0);
#endif

#ifdef DEBUG_WHITEN
	albedo.xyz=vec3(DEBUG_WHITE_LEVEL);
#endif

	vec2 screenDim = vec2(viewWidth,viewHeight);
#if BLOOM_LEVEL > 0
	vec3 voxelLighting = doBloom(colortex6,texcoord,screenDim,1).rgb;
#else
	vec3 voxelLighting = texture(colortex6,texcoord).rgb;
#endif

#if FOG_BLUR>=1
	vec4 voxelFog = doFogBlur(colortex7,texcoord,screenDim,1);
#else
	vec4 voxelFog = texture(colortex7,texcoord);
#endif

	if( voxelLighting.r>=0 && light!=vec3(1)){
		light=voxelLighting.xyz;
	}


	vec3 color = albedo.xyz*light;

#if VOLUMETRIC_FOG_SAMPLES > 0
	float fogThickness = clamp(voxelFog.a,0,0.7);
	color = color*(1-fogThickness) + voxelFog.rgb;
#endif
	outputColor=tonemap(color);

#if DEBUG_SPECIAL_VIEW >= 0
	outputColor = texelFetch(colortex15,ivec2(floor(0.1+texcoord*LIGHTING_RENDERSCALE*vec2(viewWidth,viewHeight))),0).xyz;
#endif
}