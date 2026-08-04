#define SAMPLES_FLOOD
#include "/lib/voxel/voxelHelper.glsl"

vec3 sampleFloodfillLight(vec3 worldPos, vec3 normal){
    worldPos+=0.01*normal;
    ivec3 areaShift = getAreaShift(1.0);
    ivec3 areaPos = worldPosToArea(worldPos,1.0);
    uint areaMemOffset = 0;
    vec4 sampleLight = getFloodData(areaPos, areaShift, areaMemOffset);
    return sampleLight.rgb+sampleLight.a;
}
