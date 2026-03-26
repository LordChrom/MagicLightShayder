#version 430 compatibility
#include "/lib/settings.glsl"
//#define FOG_BLUR_SNAPPED

#include "/lib/renderComponents/blur.glsl"

#if DEBUG_SPECIAL_VIEW >= 0
uniform sampler2D colortex8;
#endif

uniform sampler2D colortex0;
uniform sampler2D colortex5;

uniform sampler2D colortex6;
uniform sampler2D colortex7;


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

	vec2 screenDim = vec2(viewWidth,viewHeight);
	vec2 scaledTexcoord = texcoord* LIGHTING_RENDERSCALE;
	ivec2 texelPos = ivec2(floor(scaledTexcoord*screenDim));
	vec2 halfPixel = 0.4/screenDim;
#if BLOOM_LEVEL > 0
	vec4 voxelLighting = doBloom(colortex6,scaledTexcoord,vec2(viewWidth,viewHeight),1);
#else
	vec4 voxelLighting = texture(colortex6,scaledTexcoord);
#endif

#if FOG_BLUR>=1
	vec4 voxelFog = doFogBlur(colortex7,scaledTexcoord,vec2(viewWidth,viewHeight),1);
#else
	vec4 voxelFog = texture(colortex7,scaledTexcoord);
#endif

	if( voxelLighting.a>0.1 && light!=vec3(1)){
		light=voxelLighting.xyz;
	}


	color = albedo.xyz*light;

#if VOLUMETRIC_FOG_SAMPLES > 0
	float fogThickness = clamp(voxelFog.a,0,0.7);
	color = color*(1-fogThickness) + voxelFog.rgb;
#endif

#if DEBUG_SPECIAL_VIEW >= 0
	color = texture(colortex8,texcoord).xyz;
#endif

}