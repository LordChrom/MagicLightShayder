#define WRITES_VOX
#include "/lib/lighting/floodShadows/voxelHelper.glsl"
#include "/lib/voxelStorage/blockPacking.glsl"

const float midblockWeight = MIN_SCALE* 12.0/16.0;
const float normalWeight = -MIN_SCALE*3.0/64.0;

void writeVoxelMap(vec3 worldPos, int rawBlockID, vec3 toMidblock, vec3 normal, uint emission){
//    if(max(max(abs(toMidblock.x),abs(toMidblock.y)),abs(toMidblock.z))>0.5)
//        return; //for blocks that dont fit in the box, altho not best solution

    uint packedData = packVoxelForStorage(rawBlockID,emission);



    worldPos += midblockWeight*toMidblock +normalWeight*normal;

    ivec3 intWorldPos = ivec3(floor(worldPos));

    //TODO dont update whole thing each frame
    setBaseVoxData(packedData, intWorldPos,getUnitShift());
}