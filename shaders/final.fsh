#version 430 compatibility
#include "/lib/settings.glsl"

uniform float viewWidth, viewHeight;
#include "/lib/renderComponents/blur.glsl"
#include "/lib/util/blend.glsl"
#include "/lib/util/tonemap.glsl"

#if DEBUG_SPECIAL_VIEW >= 0
uniform sampler2D colortex15;
#endif


#ifdef TAA
uniform sampler2D colortex10;
uniform sampler2D colortex11;
#define multiplicativeLightTex colortex10
#define additiveLightTex colortex11
#else
uniform sampler2D colortex6;
uniform sampler2D colortex7;
#define multiplicativeLightTex colortex6
#define additiveLightTex colortex7
#endif

uniform sampler2D colortex0;
uniform sampler2D colortex1;

#ifdef VANILLA_FALLBACK
uniform sampler2D colortex5;
#endif




in vec2 texcoord;

/*
const int colortex3Format = RGBA8UI;
const int colortex4Format = RGBA8UI;
const int colortex6Format = RGB16F;
const int colortex7Format = RGBA16F;
const int colortex10Format = RGBA16F;
const int colortex11Format = RGBA16F;
const bool colortex10Clear = false;
const bool colortex11Clear = false;
*/

/* RENDERTARGETS: 0 */
layout(location = 0) out vec3 outputColor;

void main() {
	ivec2 texpos = ivec2(texcoord*vec2(viewWidth,viewHeight));
	vec4 albedo = texelFetch(colortex0,texpos,0);
	vec4 transColor = texelFetch(colortex1,texpos,0);
	albedo.xyz = blend(vec4(albedo.xyz,1),transColor);

#ifdef VANILLA_FALLBACK
	vec3 light = texelFetch(colortex5,texpos,0).xyz;
#else
	vec3 light = vec3(1/15.0);
#endif



	vec2 screenDim = vec2(viewWidth,viewHeight);
#if BLOOM_LEVEL > 0
	vec3 voxelLighting = doBloom(multiplicativeLightTex,texcoord,screenDim,1).rgb;
#else
	vec3 voxelLighting = texture(multiplicativeLightTex,texcoord).rgb;
//	vec3 voxelLighting = texelFetch(colortex6,scaledTexpos,0).rgb;
#endif

#if FOG_BLUR>=1
	vec4 voxelFog = doFogBlur(additiveLightTex,texcoord,screenDim,1);
#else
	vec4 voxelFog = texture(additiveLightTex,texcoord);
#endif

	if( voxelLighting.r>=0 && light!=vec3(1)){
		light=voxelLighting.xyz;
	}


	vec3 color = albedo.xyz*light;

#if VOLUMETRIC_FOG_SAMPLES > 0
	color = color*voxelFog.a + voxelFog.rgb;
#endif
	outputColor=tonemap(color);

#if DEBUG_SPECIAL_VIEW >= 0
	outputColor = texelFetch(colortex15,ivec2(floor(0.1+texcoord*LIGHTING_RENDERSCALE*vec2(viewWidth,viewHeight))),0).xyz;
#endif
}