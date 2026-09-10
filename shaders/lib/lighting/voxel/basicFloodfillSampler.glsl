#define SAMPLES_FLOOD
#include "/lib/lighting/voxel/voxelHelper.glsl"

vec4 sampleFloodData(vec3 worldPos){
    vec3 distFromCenter = worldPos-globalOrigin;
    distFromCenter=abs(distFromCenter);
    if(max(max(distFromCenter.x,distFromCenter.y),distFromCenter.z)>0.5*(FLOODFILL_SIZE-1))
        return vec4(0);

    //buffer is oversized by one with last index on each axis being a duplicate of 0 for wrapping purposes.
    vec3 texPosition = (
        fract(((worldPos-0.5)/FLOODFILL_SIZE)+0.5)
    )*float(FLOODFILL_SIZE)/FLOODFILL_MEM_SIZE
    + 0.5/FLOODFILL_MEM_SIZE;

    return texture(floodfillSampler,texPosition);
}