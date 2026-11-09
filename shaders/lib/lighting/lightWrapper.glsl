#include "/lib/settings.glsl"

#include "/lib/util/shadowLightInfo.glsl"

#ifdef BASIC_FLOODFILL
#define SAMPLES_FLOOD
#endif

#ifdef FLOOD_SHADOWS
#include "/lib/lighting/floodShadows/fsSampler.glsl"
#endif

#ifdef BASIC_FLOODFILL
#include "/lib/lighting/basicFloodfill/bfSampler.glsl"
#endif

#ifdef SHADOWMAP_SHADOWS
#include "/lib/lighting/shadowmap/shadowSampler.glsl"
#endif

#ifdef SCREENSPACE_SHADOW_FALLBACK
#include "/lib/lighting/screenspaceShadow/screenspaceShadowSampler.glsl"
#endif

#ifdef SWRT
#include "/lib/lighting/swrt/swrtSampler.glsl"
#endif

float mixInSunlight(float blockSun, float shadowSun){
    if(shadowSun<0)
        return blockSun;
    else if(blockSun<0)
        return shadowSun;
    else
        return mix(blockSun,shadowSun,SHADOWMAP_FLOODFILL_MIX);
}

#define UNIVERSAL_SUBSURFACENESS 0.0
#ifndef FOG_SHADER
//a is a hash for rejecting accumulation
vec4 lightingSample(vec3 worldPos, vec3 normal, float subsurface, float ditherValue){
    vec4 ret = vec4(0f);
    float sunAmount=-1f;
    subsurface+=UNIVERSAL_SUBSURFACENESS;

    #ifdef BASIC_FLOODFILL
    ret = sampleFloodData(worldPos);
    #endif

    #ifdef FLOOD_SHADOWS
    ret.rgb+= voxelSample(worldPos, normal, subsurface, ditherValue);
    #endif

    #ifdef SWRT
    vec2 tc = ((vec2(texpos)+0.5)*0.5)/textureSize(swrtRayHitSampler,0).xy;
    ret+=shadePrehitRays(worldPos, normal, subsurface, tc);

    #endif

    #ifdef SWRT_SKY_SHADOW
        vec4 swrtSkyShadow = texelFetch(colortex6,texpos,0);
        sunAmount=mixInSunlight(sunAmount,swrtSkyShadow.a);
    #endif

    #ifdef SHADOWMAP_SHADOWS
        #ifdef SWRT_SKY_SHADOW
        if(swrtSkyShadow.a<0)
        #endif
    {
        float shadowLightStrength = shadowmapSample(worldPos, normal, subsurface, ditherValue);

        #ifdef DEBUG_SHOW_SHADOWMAP_RANGE
        if(shadowLightStrength.a==-1) ret.r++;
        #endif

        sunAmount=mixInSunlight(sunAmount,shadowLightStrength);
    }
    #endif

    if(sunAmount==-1){
        #ifdef SCREENSPACE_SHADOW_FALLBACK
        sunAmount = sampleScreenspaceShadow(worldPos, normal);
        #elif defined SHADOWMAP_SHADOWS
        sunAmount = max(0,dot(normalize(mat3(gbufferModelViewInverse)*shadowLightPosition),normal));
        #else
        sunAmount=1;
        #endif
    }

    sunAmount=0.1+0.9*clamp(sunAmount,0,1);
    ret.rgb+=sunAmount*getSunColor();
    ret.rgb+=MIN_LIGHT_AMOUNT*clamp(1-(ret.r+ret.g+ret.b),0,1);
    return ret;
}
#endif


vec3 lightingSampleFog(vec3 worldPos, float ditherValue){
    vec4 ret = vec4(0f);
    float sunAmount=-1f;
    #ifdef BASIC_FLOODFILL
    ret = sampleFloodData(worldPos);
    #endif

    #if defined FLOOD_SHADOWS && (ADVANCED_BLOCKLIGHT_FOG>=0)
        #if ADVANCED_BLOCKLIGHT_FOG ==0
        if(hasCeiling)
        #endif
        {
            ret.rgb += voxelSampleFog(worldPos, ditherValue);
        }
    #endif

    #ifdef SHADOWMAP_SHADOWS
    float shadowLightStrength = shadowmapSampleFog(worldPos);
    sunAmount=mixInSunlight(sunAmount,shadowLightStrength);
    #endif

    #ifdef SWRT
    ret.rgb+= swrtSampleFog(worldPos).rgb;
    #endif

    if(sunAmount==-1){
        sunAmount=1;
    }

    sunAmount=0.2+0.8*clamp(sunAmount,0,1);
    ret.rgb=(FOG_BRIGHTNESS_BLOCK*ret.rgb) + (FOG_BRIGHTNESS_SUN*sunAmount)*getSunColorForFog();
    return ret.rgb;
}