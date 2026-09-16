#define SAMPLES_FLOOD
#include "/lib/lighting/floodShadows/voxelHelper.glsl"

vec4 sampleFloodData(vec3 worldPos){
    vec3 distFromCenter = abs(worldPos-globalOrigin);
    if(max(max(distFromCenter.x,distFromCenter.y),distFromCenter.z)>0.5*(FLOODFILL_SIZE-1))
        return vec4(0);

    //buffer is oversized by one with last index on each axis being a duplicate of 0 for wrapping purposes.
    vec3 texPosition = ((
        fract(((worldPos)/FLOODFILL_SIZE)+0.5)
    )*float(FLOODFILL_SIZE))/FLOODFILL_MEM_SIZE;

    return vec4(texture(floodfillSampler,texPosition));
}