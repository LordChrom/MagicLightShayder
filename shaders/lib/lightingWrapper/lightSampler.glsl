#include "/lib/voxel/voxelSampler.glsl"

#ifdef SHADOWMAP_SHADOWS
#include "/lib/shadowmap/shadow.glsl"
#endif

vec3 lightingSample(vec3 worldPos, vec3 normal, float subsurface, float ditherValue){
    vec3 ret = vec3(0);
    ret+= voxelSample(worldPos, normal, subsurface, ditherValue);

    #ifdef SHADOWMAP_SHADOWS
    ret+= shadowmapSample(worldPos, normal, subsurface, ditherValue);
    #endif

    return ret;
}


vec3 lightingSampleFog(vec3 worldPos, float fogNoise, float ditherValue){
    vec3 ret = vec3(0);
    ret += voxelSampleFog(worldPos, fogNoise, ditherValue);

    #ifdef SHADOWMAP_SHADOWS
    ret+= shadowmapSampleFog(worldPos, fogNoise, ditherValue);
    #endif

    return ret;
}