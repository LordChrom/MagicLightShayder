#define WRITES_VOX
#include "/lib/lighting/floodShadows/voxelHelper.glsl"
#include "/lib/voxelStorage/blockPacking.glsl"

void writeVoxelMap(vec3 worldPos, int rawBlockID, uint emission){
    uint packedData = packVoxelForStorage(rawBlockID,emission);

    ivec3 shift = getUnitShift();
    ivec3 areaPos = ivec3(floor(worldPos))+(VOXELIZATION_SIZE>>1)-shift;

    //TODO dont update whole thing each frame
    setBaseVoxData(packedData, areaPos,shift);
}