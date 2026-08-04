#define SAMPLES_FLOOD
#include "/lib/voxel/voxelHelper.glsl"

vec4 sampleFloodfillLightRaw(vec3 worldPos){
    ivec3 areaShift = getAreaShift(1.0);
    ivec3 areaPos = worldPosToArea(worldPos,1.0);
    uint areaMemOffset = 0;
    return getFloodData(areaPos, areaShift, areaMemOffset);
}

vec3 sampleFloodfillLight(vec3 worldPos, vec3 normal){
    vec4 sampleLight = sampleFloodfillLightRaw(worldPos+0.01*normal);
    return sampleLight.rgb+sampleLight.a;
}

vec3 sampleFloodfillFog(vec3 worldPos){
    vec4 sampleLight = sampleFloodfillLightRaw(worldPos);
    return sampleLight.rgb*FOG_BRIGHTNESS_BLOCK+sampleLight.a*FOG_BRIGHTNESS_SUN;
}
