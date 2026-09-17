#define WRITES_VOX
#include "/lib/lighting/floodShadows/voxelHelper.glsl"
#include "/lib/voxelStorage/blockPacking.glsl"

const float midblockWeight = MIN_SCALE* 12.0/16.0;
const float normalWeight = -MIN_SCALE*3.0/64.0;

void writeVoxelMap(vec3 worldPos, int rawBlockID, vec3 toMidblock, uint emission){
    uint packedData = packVoxelForStorage(rawBlockID,emission);



    worldPos += midblockWeight*toMidblock;

    ivec3 shift = getUnitShift();
    ivec3 areaPos = ivec3(floor(worldPos))+(VOXELIZATION_SIZE>>1)-shift;

    //TODO dont update whole thing each frame
    setBaseVoxData(packedData, areaPos,shift);
}