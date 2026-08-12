#include "/lib/settings.glsl"
uniform bool hasCeiling;


#ifdef BASIC_FLOODFILL
#define SAMPLES_FLOOD
#endif

#ifdef ADVANCED_VOXEL_TRACE
#include "/lib/voxel/voxelSampler.glsl"
#endif

#ifdef BASIC_FLOODFILL
#include "/lib/voxel/basicFloodfillSampler.glsl"
#endif

#ifdef SHADOWMAP_SHADOWS
#include "/lib/shadowmap/shadowSampler.glsl"
#endif

#define UNIVERSAL_SUBSURFACENESS 0.0
vec3 lightingSample(vec3 worldPos, vec3 normal, float subsurface, float ditherValue){
    vec3 ret = vec3(0);
    subsurface+=UNIVERSAL_SUBSURFACENESS;

    #ifdef BASIC_FLOODFILL
    ret+= sampleFloodfillLight(worldPos,normal);
    #endif

    #ifdef ADVANCED_VOXEL_TRACE
    ret+= voxelSample(worldPos, normal, subsurface, ditherValue);
    #endif

    #ifdef SHADOWMAP_SHADOWS
    ret+= shadowmapSample(worldPos, normal, subsurface, ditherValue);
    #endif
    return ret + MIN_LIGHT_AMOUNT*clamp(1-(ret.x+ret.y+ret.z),0,1);
}


vec3 lightingSampleFog(vec3 worldPos, float ditherValue){
    vec3 ret = vec3(0);
    #ifdef BASIC_FLOODFILL
    ret+= sampleFloodfillFog(worldPos);
    #endif

    #if defined ADVANCED_VOXEL_TRACE && (ADVANCED_BLOCKLIGHT_FOG>=0)
        #if ADVANCED_BLOCKLIGHT_FOG ==0
        if(hasCeiling)
        #endif
        {
            ret += voxelSampleFog(worldPos, ditherValue);
        }
    #endif

    #ifdef SHADOWMAP_SHADOWS
    ret+= shadowmapSampleFog(worldPos, ditherValue);
    #endif

    return ret;
}