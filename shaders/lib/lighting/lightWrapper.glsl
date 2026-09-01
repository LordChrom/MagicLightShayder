#include "/lib/settings.glsl"
uniform bool hasCeiling;


#ifdef BASIC_FLOODFILL
#define SAMPLES_FLOOD
#endif

#ifdef ADVANCED_VOXEL_TRACE
#include "/lib/lighting/voxel/voxelSampler.glsl"
#endif

#ifdef BASIC_FLOODFILL
#include "/lib/lighting/voxel/basicFloodfillSampler.glsl"
#endif

#ifdef SHADOWMAP_SHADOWS
#include "/lib/lighting/shadowmap/shadowSampler.glsl"
#endif

#ifdef SCREENSPACE_SHADOW_FALLBACK
#include "/lib/lighting/screenspaceShadow/screenspaceShadowSampler.glsl"
#endif

const vec3 sunColor = vec3(240.0/255.0);
const vec3 moonColor = vec3(0.22,0.22,0.48);

vec3 getSunColor(){
    if(hasCeiling) return vec3(0);
    return (sunAngle>0.5?moonColor:sunColor);
}


uniform sampler2D lightmapTex;

vec3 getFloodfillSunlight(float sunlightness){
    return texture(lightmapTex,clamp(vec2(0,sunlightness),1.0/32.0,31.0/32.0)).rgb;
}




#define UNIVERSAL_SUBSURFACENESS 0.0
vec3 lightingSample(vec3 worldPos, vec3 normal, float subsurface, float ditherValue){
    vec4 ret = vec4(0,0,0,-1);
    subsurface+=UNIVERSAL_SUBSURFACENESS;

    #ifdef BASIC_FLOODFILL
    ret = sampleFloodData(worldPos);
    #endif

    #ifdef ADVANCED_VOXEL_TRACE
    ret.rgb+= voxelSample(worldPos, normal, subsurface, ditherValue);
    #endif

    #ifdef SHADOWMAP_SHADOWS
    ret.a= shadowmapSample(worldPos, normal, subsurface);

        #ifdef DEBUG_SHOW_SHADOWMAP_RANGE
        if(ret.a==-1) ret.r++;
        #endif
    #endif

    if(ret.a==-1){
        #ifdef SCREENSPACE_SHADOW_FALLBACK
        ret.a = sampleScreenspaceShadow(worldPos, normal);
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
    ret+= sampleFloodData(worldPos);
    #endif

    #if defined ADVANCED_VOXEL_TRACE && (ADVANCED_BLOCKLIGHT_FOG>=0)
        #if ADVANCED_BLOCKLIGHT_FOG ==0
        if(hasCeiling)
        #endif
        {
            ret.rgb += voxelSampleFog(worldPos, ditherValue);
        }
    #endif

    #ifdef SHADOWMAP_SHADOWS
    ret.a= shadowmapSampleFog(worldPos);
    #endif

    if(ret.a==-1){
        ret.a=1;
    }

    ret.a=0.2+0.8*clamp(ret.a,0,1);
    ret.rgb=(FOG_BRIGHTNESS_BLOCK*ret.rgb) + (FOG_BRIGHTNESS_SUN*ret.a)*getSunColor();
    return ret.rgb;
}