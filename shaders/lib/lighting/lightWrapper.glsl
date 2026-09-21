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
#include "/lib/util/wideFilteredSample.glsl"
uniform sampler2D colortex6;
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
vec3 lightingSample(vec3 worldPos, vec3 normal, float subsurface, float ditherValue){
    vec4 ret = vec4(0,0,0,-1);
    subsurface+=UNIVERSAL_SUBSURFACENESS;

    #ifdef BASIC_FLOODFILL
    ret = sampleFloodData(worldPos);
    #endif

    #ifdef FLOOD_SHADOWS
    ret.rgb+= voxelSample(worldPos, normal, subsurface, ditherValue);
    #endif

    #ifdef SWRT
    #ifndef GBUFFER_SHADER
        #if SWRT_DENOISE==2
        ret.rgb+=wideSample(colortex6,jitteredTexcoord).rgb;
        #elif SWRT_DENOISE==1
        ret.rgb+=fourNeighborsSample(colortex6,jitteredTexcoord).rgb;
        #else
        ret.rgb+=texelFetch(colortex6,ivec2(gl_FragCoord.xy),0).rgb;
        #endif
    #endif
//    ret.rgb+= swrtSample(worldPos, normal, subsurface, ditherValue,15u);
    #endif

    #ifdef SHADOWMAP_SHADOWS
        float shadowLightStrength = shadowmapSample(worldPos, normal, subsurface, ditherValue);

        #ifdef DEBUG_SHOW_SHADOWMAP_RANGE
        if(shadowLightStrength.a==-1) ret.r++;
        #endif

        ret.a=mixInSunlight(ret.a,shadowLightStrength);
    #endif

    if(ret.a==-1){
        #ifdef SCREENSPACE_SHADOW_FALLBACK
        ret.a = sampleScreenspaceShadow(worldPos, normal);
        #elif defined SHADOWMAP_SHADOWS
        ret.a = max(0,dot(normalize(mat3(gbufferModelViewInverse)*shadowLightPosition),normal));
        #else
        ret.a=1;
        #endif
    }

    ret.a=0.2+0.8*clamp(ret.a,0,1);
    ret.rgb+=ret.a*getSunColor();
    return ret.rgb + MIN_LIGHT_AMOUNT*clamp(1-(ret.r+ret.g+ret.b),0,1);
}


vec3 lightingSampleFog(vec3 worldPos, float ditherValue){
    vec4 ret = vec4(0,0,0,-1);
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
    ret.a=mixInSunlight(ret.a,shadowLightStrength);
    #endif

    #ifdef SWRT
    ret.rgb+= swrtSampleFog(worldPos, vec3(0), 0, ditherValue,8u).rgb;
    #endif

    if(ret.a==-1){
        ret.a=1;
    }

    ret.a=0.2+0.8*clamp(ret.a,0,1);
    ret.rgb=(FOG_BRIGHTNESS_BLOCK*ret.rgb) + (FOG_BRIGHTNESS_SUN*ret.a)*getSunColor();
    return ret.rgb;
}