#include "/lib/voxel/voxelSampler.glsl"

#ifdef SHADOWMAP_SHADOWS
#include "/lib/shadowmap/shadowSampler.glsl"
#endif

#define UNIVERSAL_SUBSURFACENESS 0.0
vec3 lightingSample(vec3 worldPos, vec3 normal, float subsurface, float ditherValue){
    vec3 ret = vec3(0);
    subsurface+=UNIVERSAL_SUBSURFACENESS;
    ret+= voxelSample(worldPos, normal, subsurface, ditherValue);

    #ifdef SHADOWMAP_SHADOWS
    ret+= shadowmapSample(worldPos, normal, subsurface, ditherValue);
    #endif
    return ret + MIN_LIGHT_AMOUNT*clamp(1-(ret.x+ret.y+ret.z),0,1);
}


vec3 lightingSampleFog(vec3 worldPos, float ditherValue){
    vec3 ret = vec3(0);
    ret += voxelSampleFog(worldPos, ditherValue);

    #ifdef SHADOWMAP_SHADOWS
    ret+= shadowmapSampleFog(worldPos, ditherValue);
    #endif

    return ret;
}